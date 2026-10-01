import 'dart:convert';
import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';

/// Repository for Decision operations with atomic Drift persistence,
/// HLC clock updates, and Outbox enqueuing (Invariant #13).
class DecisionsSyncRepository {
  final AppDatabase database;
  final String deviceId;

  DecisionsSyncRepository({
    required this.database,
    required this.deviceId,
  });

  Future<String> createDecision({
    required String ownerId,
    required String title,
    String? content,
    String? goalId,
    String? projectId,
    String? lifeAreaId,
    String? categoryId,
  }) async {
    final id = Id.uuidV7();
    final hlc = Hlc.now(Id(deviceId));
    final now = DateTime.now().toUtc();

    await database.transaction(() async {
      await database.into(database.decisions).insert(
        DecisionsCompanion.insert(
          id: id.value,
          ownerId: ownerId,
          title: title,
          content: Value(content),
          status: const Value('pending'),
          goalId: Value(goalId),
          projectId: Value(projectId),
          lifeAreaId: Value(lifeAreaId),
          categoryId: Value(categoryId),
          versionHlc: hlc.toString(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      final payload = {
        'id': id.value,
        'owner_id': ownerId,
        'title': title,
        'content': content,
        'status': 'pending',
        'goal_id': goalId,
        'project_id': projectId,
        'life_area_id': lifeAreaId,
        'category_id': categoryId,
        'resolved_at': null,
        'deleted_at': null,
        'deleted_by': null,
        'deleted_reason': null,
        'version_hlc': hlc.toString(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      await database.into(database.syncOutbox).insert(
        SyncOutboxCompanion.insert(
          userId: ownerId,
          op: 'insert',
          entity: 'decisions',
          entityId: id.value,
          payloadJson: jsonEncode(payload),
          hlc: hlc.toString(),
          deviceId: deviceId,
        ),
      );
    });

    return id.value;
  }

  Future<void> resolveDecision({
    required String decisionId,
    required String ownerId,
  }) async {
    final hlc = Hlc.now(Id(deviceId));
    final now = DateTime.now().toUtc();

    await database.transaction(() async {
      await (database.update(database.decisions)
            ..where((d) => d.id.equals(decisionId) & d.ownerId.equals(ownerId)))
          .write(
        DecisionsCompanion(
          status: const Value('resolved'),
          resolvedAt: Value(now),
          versionHlc: Value(hlc.toString()),
          updatedAt: Value(now),
        ),
      );

      final payload = {
        'id': decisionId,
        'owner_id': ownerId,
        'status': 'resolved',
        'resolved_at': now.toIso8601String(),
        'version_hlc': hlc.toString(),
        'updated_at': now.toIso8601String(),
      };

      await database.into(database.syncOutbox).insert(
        SyncOutboxCompanion.insert(
          userId: ownerId,
          op: 'update',
          entity: 'decisions',
          entityId: decisionId,
          payloadJson: jsonEncode(payload),
          hlc: hlc.toString(),
          deviceId: deviceId,
        ),
      );
    });
  }

  Future<void> softDeleteDecision({
    required String decisionId,
    required String ownerId,
    String? reason,
  }) async {
    final hlc = Hlc.now(Id(deviceId));
    final now = DateTime.now().toUtc();

    await database.transaction(() async {
      await (database.update(database.decisions)
            ..where((d) => d.id.equals(decisionId) & d.ownerId.equals(ownerId)))
          .write(
        DecisionsCompanion(
          deletedAt: Value(now),
          deletedBy: Value(ownerId),
          deletedReason: Value(reason),
          versionHlc: Value(hlc.toString()),
          updatedAt: Value(now),
        ),
      );

      // Record local tombstone (Invariant #14)
      await database.into(database.syncTombstones).insertOnConflictUpdate(
        SyncTombstonesCompanion(
          id: Value(Id.uuidV7().value),
          userId: Value(ownerId),
          entity: const Value('decisions'),
          entityId: Value(decisionId),
          deletedAt: Value(now),
          deletedHlc: Value(hlc.toString()),
          deletedBy: Value(ownerId),
          reason: Value(reason),
        ),
      );

      final payload = {
        'id': decisionId,
        'deleted_at': now.toIso8601String(),
        'deleted_by': ownerId,
        'deleted_reason': reason,
        'version_hlc': hlc.toString(),
      };

      await database.into(database.syncOutbox).insert(
        SyncOutboxCompanion.insert(
          userId: ownerId,
          op: 'delete',
          entity: 'decisions',
          entityId: decisionId,
          payloadJson: jsonEncode(payload),
          hlc: hlc.toString(),
          deviceId: deviceId,
        ),
      );
    });
  }

  Future<List<Decision>> listActiveDecisions(String ownerId) {
    return (database.select(database.decisions)
          ..where((d) => d.ownerId.equals(ownerId) & d.deletedAt.isNull())
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .get();
  }
}
