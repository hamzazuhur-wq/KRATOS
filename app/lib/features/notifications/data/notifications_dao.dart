import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../domain/notification_models.dart';

/// SQLite persistence DAO for KRATOS Notifications (Phase 7).
/// Provides persistent read/dismissed tracking, event idempotency verification,
/// and Outbox synchronization integration without requiring build_runner regeneration.
class NotificationsDao {
  final AppDatabase db;
  bool _initialized = false;
  final _changeStreamController = StreamController<String>.broadcast();

  NotificationsDao(this.db);

  Stream<String> get onTableChanged => _changeStreamController.stream;

  Future<void> ensureTableExists() async {
    if (_initialized) return;
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY NOT NULL,
        owner_id TEXT NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        entity_type TEXT,
        entity_id TEXT,
        activity_event_id TEXT,
        severity TEXT NOT NULL DEFAULT 'info',
        read_at INTEGER,
        dismissed_at INTEGER,
        metadata TEXT NOT NULL DEFAULT '{}',
        version_hlc TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_notifications_owner_created 
      ON notifications (owner_id, created_at DESC);
    ''');
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_notifications_owner_unread 
      ON notifications (owner_id, read_at) WHERE read_at IS NULL;
    ''');
    await db.customStatement('''
      CREATE INDEX IF NOT EXISTS idx_notifications_activity_event 
      ON notifications (owner_id, activity_event_id);
    ''');
    _initialized = true;
  }

  Future<void> upsertNotification(
    NotificationRecord record, {
    bool enqueueOutbox = true,
    String? deviceId,
  }) async {
    await ensureTableExists();
    final now = DateTime.now().toUtc();
    final effectiveDeviceId = deviceId ?? 'local_device';
    final hlc = record.versionHlc.isNotEmpty
        ? record.versionHlc
        : Hlc.now(Id(effectiveDeviceId)).toString();

    await db.transaction(() async {
      await db.customInsert(
        '''
        INSERT INTO notifications (
          id, owner_id, type, title, body, entity_type, entity_id, activity_event_id,
          severity, read_at, dismissed_at, metadata, version_hlc, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          body = excluded.body,
          severity = excluded.severity,
          read_at = CASE WHEN notifications.read_at IS NOT NULL THEN notifications.read_at ELSE excluded.read_at END,
          dismissed_at = CASE WHEN notifications.dismissed_at IS NOT NULL THEN notifications.dismissed_at ELSE excluded.dismissed_at END,
          metadata = excluded.metadata,
          version_hlc = excluded.version_hlc,
          updated_at = excluded.updated_at
        ''',
        variables: [
          Variable.withString(record.id),
          Variable.withString(record.ownerId),
          Variable.withString(record.type),
          Variable.withString(record.title),
          Variable.withString(record.body),
          Variable.withString(record.entityType ?? ''),
          Variable.withString(record.entityId ?? ''),
          Variable.withString(record.activityEventId ?? ''),
          Variable.withString(record.severity.name),
          record.readAt != null
              ? Variable.withInt(record.readAt!.millisecondsSinceEpoch)
              : const Variable(null),
          record.dismissedAt != null
              ? Variable.withInt(record.dismissedAt!.millisecondsSinceEpoch)
              : const Variable(null),
          Variable.withString(jsonEncode(record.metadata)),
          Variable.withString(hlc),
          Variable.withInt(record.createdAt.millisecondsSinceEpoch),
          Variable.withInt(now.millisecondsSinceEpoch),
        ],
      );

      if (enqueueOutbox) {
        final payload = {
          'id': record.id,
          'owner_id': record.ownerId,
          'type': record.type,
          'title': record.title,
          'body': record.body,
          'entity_type': record.entityType,
          'entity_id': record.entityId,
          'activity_event_id': record.activityEventId,
          'severity': record.severity.name,
          'read_at': record.readAt?.toIso8601String(),
          'dismissed_at': record.dismissedAt?.toIso8601String(),
          'metadata': record.metadata,
          'version_hlc': hlc,
          'created_at': record.createdAt.toIso8601String(),
          'updated_at': now.toIso8601String(),
        };

        await db.into(db.syncOutbox).insert(
          SyncOutboxCompanion.insert(
            userId: record.ownerId,
            op: 'upsert',
            entity: 'notifications',
            entityId: record.id,
            payloadJson: jsonEncode(payload),
            hlc: hlc,
            deviceId: effectiveDeviceId,
          ),
        );
      }
    });

    _changeStreamController.add(record.ownerId);
  }

  Future<List<NotificationRecord>> getNotifications(
    String ownerId, {
    bool includeDismissed = false,
  }) async {
    await ensureTableExists();
    final query = includeDismissed
        ? 'SELECT * FROM notifications WHERE owner_id = ? ORDER BY created_at DESC'
        : 'SELECT * FROM notifications WHERE owner_id = ? AND dismissed_at IS NULL ORDER BY created_at DESC';

    final rows = await db.customSelect(
      query,
      variables: [Variable.withString(ownerId)],
    ).get();

    return rows.map(_mapRowToRecord).toList();
  }

  Stream<List<NotificationRecord>> watchNotifications(
    String ownerId, {
    bool includeDismissed = false,
  }) async* {
    await ensureTableExists();
    yield await getNotifications(ownerId, includeDismissed: includeDismissed);
    await for (final changedOwner in _changeStreamController.stream) {
      if (changedOwner == ownerId) {
        yield await getNotifications(ownerId, includeDismissed: includeDismissed);
      }
    }
  }

  Future<int> getUnreadCount(String ownerId) async {
    await ensureTableExists();
    final rows = await db.customSelect(
      'SELECT COUNT(*) as cnt FROM notifications WHERE owner_id = ? AND read_at IS NULL AND dismissed_at IS NULL',
      variables: [Variable.withString(ownerId)],
    ).get();

    if (rows.isEmpty) return 0;
    return rows.first.read<int>('cnt');
  }

  Future<bool> isActivityEventProcessed(String ownerId, String activityEventId) async {
    await ensureTableExists();
    final rows = await db.customSelect(
      'SELECT 1 FROM notifications WHERE owner_id = ? AND activity_event_id = ? LIMIT 1',
      variables: [
        Variable.withString(ownerId),
        Variable.withString(activityEventId),
      ],
    ).get();
    return rows.isNotEmpty;
  }

  Future<NotificationRecord?> getById(String id) async {
    await ensureTableExists();
    final rows = await db.customSelect(
      'SELECT * FROM notifications WHERE id = ? LIMIT 1',
      variables: [Variable.withString(id)],
    ).get();

    if (rows.isEmpty) return null;
    return _mapRowToRecord(rows.first);
  }

  Future<void> markAsRead(
    String id, {
    String? deviceId,
  }) async {
    await ensureTableExists();
    final existing = await getById(id);
    if (existing == null || existing.isRead) return;

    final now = DateTime.now().toUtc();
    final effectiveDeviceId = deviceId ?? 'local_device';
    final hlc = Hlc.now(Id(effectiveDeviceId)).toString();

    await db.transaction(() async {
      await db.customUpdate(
        'UPDATE notifications SET read_at = ?, version_hlc = ?, updated_at = ? WHERE id = ?',
        variables: [
          Variable.withInt(now.millisecondsSinceEpoch),
          Variable.withString(hlc),
          Variable.withInt(now.millisecondsSinceEpoch),
          Variable.withString(id),
        ],
      );

      final payload = {
        'id': id,
        'owner_id': existing.ownerId,
        'read_at': now.toIso8601String(),
        'version_hlc': hlc,
        'updated_at': now.toIso8601String(),
      };

      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion.insert(
          userId: existing.ownerId,
          op: 'update',
          entity: 'notifications',
          entityId: id,
          payloadJson: jsonEncode(payload),
          hlc: hlc,
          deviceId: effectiveDeviceId,
        ),
      );
    });

    _changeStreamController.add(existing.ownerId);
  }

  Future<void> markAllAsRead(
    String ownerId, {
    String? deviceId,
  }) async {
    await ensureTableExists();
    final unread = await db.customSelect(
      'SELECT id FROM notifications WHERE owner_id = ? AND read_at IS NULL AND dismissed_at IS NULL',
      variables: [Variable.withString(ownerId)],
    ).get();

    if (unread.isEmpty) return;

    final now = DateTime.now().toUtc();
    final effectiveDeviceId = deviceId ?? 'local_device';
    final hlc = Hlc.now(Id(effectiveDeviceId)).toString();

    await db.transaction(() async {
      await db.customUpdate(
        'UPDATE notifications SET read_at = ?, version_hlc = ?, updated_at = ? WHERE owner_id = ? AND read_at IS NULL',
        variables: [
          Variable.withInt(now.millisecondsSinceEpoch),
          Variable.withString(hlc),
          Variable.withInt(now.millisecondsSinceEpoch),
          Variable.withString(ownerId),
        ],
      );

      for (final row in unread) {
        final id = row.read<String>('id');
        final payload = {
          'id': id,
          'owner_id': ownerId,
          'read_at': now.toIso8601String(),
          'version_hlc': hlc,
          'updated_at': now.toIso8601String(),
        };

        await db.into(db.syncOutbox).insert(
          SyncOutboxCompanion.insert(
            userId: ownerId,
            op: 'update',
            entity: 'notifications',
            entityId: id,
            payloadJson: jsonEncode(payload),
            hlc: hlc,
            deviceId: effectiveDeviceId,
          ),
        );
      }
    });

    _changeStreamController.add(ownerId);
  }

  Future<void> dismiss(
    String id, {
    String? deviceId,
  }) async {
    await ensureTableExists();
    final existing = await getById(id);
    if (existing == null || existing.isDismissed) return;

    final now = DateTime.now().toUtc();
    final effectiveDeviceId = deviceId ?? 'local_device';
    final hlc = Hlc.now(Id(effectiveDeviceId)).toString();

    await db.transaction(() async {
      await db.customUpdate(
        'UPDATE notifications SET dismissed_at = ?, version_hlc = ?, updated_at = ? WHERE id = ?',
        variables: [
          Variable.withInt(now.millisecondsSinceEpoch),
          Variable.withString(hlc),
          Variable.withInt(now.millisecondsSinceEpoch),
          Variable.withString(id),
        ],
      );

      final payload = {
        'id': id,
        'owner_id': existing.ownerId,
        'dismissed_at': now.toIso8601String(),
        'version_hlc': hlc,
        'updated_at': now.toIso8601String(),
      };

      await db.into(db.syncOutbox).insert(
        SyncOutboxCompanion.insert(
          userId: existing.ownerId,
          op: 'update',
          entity: 'notifications',
          entityId: id,
          payloadJson: jsonEncode(payload),
          hlc: hlc,
          deviceId: effectiveDeviceId,
        ),
      );
    });

    _changeStreamController.add(existing.ownerId);
  }

  Future<void> clearAll(
    String ownerId, {
    String? deviceId,
  }) async {
    await ensureTableExists();
    final active = await db.customSelect(
      'SELECT id FROM notifications WHERE owner_id = ? AND dismissed_at IS NULL',
      variables: [Variable.withString(ownerId)],
    ).get();

    if (active.isEmpty) return;

    final now = DateTime.now().toUtc();
    final effectiveDeviceId = deviceId ?? 'local_device';
    final hlc = Hlc.now(Id(effectiveDeviceId)).toString();

    await db.transaction(() async {
      await db.customUpdate(
        'UPDATE notifications SET dismissed_at = ?, version_hlc = ?, updated_at = ? WHERE owner_id = ? AND dismissed_at IS NULL',
        variables: [
          Variable.withInt(now.millisecondsSinceEpoch),
          Variable.withString(hlc),
          Variable.withInt(now.millisecondsSinceEpoch),
          Variable.withString(ownerId),
        ],
      );

      for (final row in active) {
        final id = row.read<String>('id');
        final payload = {
          'id': id,
          'owner_id': ownerId,
          'dismissed_at': now.toIso8601String(),
          'version_hlc': hlc,
          'updated_at': now.toIso8601String(),
        };

        await db.into(db.syncOutbox).insert(
          SyncOutboxCompanion.insert(
            userId: ownerId,
            op: 'update',
            entity: 'notifications',
            entityId: id,
            payloadJson: jsonEncode(payload),
            hlc: hlc,
            deviceId: effectiveDeviceId,
          ),
        );
      }
    });

    _changeStreamController.add(ownerId);
  }

  NotificationRecord _mapRowToRecord(QueryRow row) {
    final rawMeta = row.read<String?>('metadata') ?? '{}';
    Map<String, dynamic> metadata = {};
    try {
      metadata = jsonDecode(rawMeta) as Map<String, dynamic>;
    } catch (_) {}

    final readAtEpoch = row.read<int?>('read_at');
    final dismissedAtEpoch = row.read<int?>('dismissed_at');
    final createdAtEpoch = row.read<int>('created_at');
    final updatedAtEpoch = row.read<int>('updated_at');

    final rawSeverity = row.read<String>('severity');
    NotificationSeverity severity;
    switch (rawSeverity.toLowerCase()) {
      case 'urgent':
        severity = NotificationSeverity.urgent;
        break;
      case 'warning':
        severity = NotificationSeverity.warning;
        break;
      default:
        severity = NotificationSeverity.info;
        break;
    }

    final entityType = row.read<String?>('entity_type');
    final entityId = row.read<String?>('entity_id');
    final activityEventId = row.read<String?>('activity_event_id');

    return NotificationRecord(
      id: row.read<String>('id'),
      ownerId: row.read<String>('owner_id'),
      type: row.read<String>('type'),
      title: row.read<String>('title'),
      body: row.read<String>('body'),
      entityType: entityType != null && entityType.isNotEmpty ? entityType : null,
      entityId: entityId != null && entityId.isNotEmpty ? entityId : null,
      activityEventId: activityEventId != null && activityEventId.isNotEmpty ? activityEventId : null,
      severity: severity,
      readAt: readAtEpoch != null ? DateTime.fromMillisecondsSinceEpoch(readAtEpoch, isUtc: true) : null,
      dismissedAt: dismissedAtEpoch != null ? DateTime.fromMillisecondsSinceEpoch(dismissedAtEpoch, isUtc: true) : null,
      metadata: metadata,
      versionHlc: row.read<String>('version_hlc'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtEpoch, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtEpoch, isUtc: true),
    );
  }

  void dispose() {
    _changeStreamController.close();
  }
}
