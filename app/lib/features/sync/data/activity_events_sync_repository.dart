import 'dart:convert';
import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';

/// Repository for ActivityEvent operations with atomic Drift persistence,
/// HLC clock tracking, and Outbox enqueuing (Invariant #13).
class ActivityEventsSyncRepository {
  final AppDatabase database;
  final String deviceId;

  ActivityEventsSyncRepository({
    required this.database,
    required this.deviceId,
  });

  Future<String> recordEvent({
    required String ownerId,
    required String eventType,
    required String entityType,
    String? entityId,
    String? lifeAreaId,
    Map<String, dynamic> metadata = const {},
    DateTime? occurredAt,
  }) async {
    final id = Id.uuidV7();
    final hlc = Hlc.now(Id(deviceId));
    final timestamp = occurredAt ?? DateTime.now().toUtc();
    final metadataStr = jsonEncode(metadata);

    await database.transaction(() async {
      await database.into(database.activityEvents).insert(
        ActivityEventsCompanion.insert(
          id: id.value,
          ownerId: ownerId,
          eventType: eventType,
          entityType: entityType,
          entityId: Value(entityId),
          lifeAreaId: Value(lifeAreaId),
          metadata: Value(metadataStr),
          occurredAt: timestamp,
          versionHlc: hlc.toString(),
          createdAt: DateTime.now().toUtc(),
        ),
      );

      final payload = {
        'id': id.value,
        'owner_id': ownerId,
        'event_type': eventType,
        'entity_type': entityType,
        'entity_id': entityId,
        'life_area_id': lifeAreaId,
        'metadata': metadata,
        'occurred_at': timestamp.toIso8601String(),
        'version_hlc': hlc.toString(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      await database.into(database.syncOutbox).insert(
        SyncOutboxCompanion.insert(
          userId: ownerId,
          op: 'insert',
          entity: 'activity_events',
          entityId: id.value,
          payloadJson: jsonEncode(payload),
          hlc: hlc.toString(),
          deviceId: deviceId,
        ),
      );
    });

    return id.value;
  }

  Future<List<ActivityEvent>> listRecentEvents(
    String ownerId, {
    int limit = 50,
  }) {
    return (database.select(database.activityEvents)
          ..where((e) => e.ownerId.equals(ownerId))
          ..orderBy([(e) => OrderingTerm.desc(e.occurredAt)])
          ..limit(limit))
        .get();
  }
}
