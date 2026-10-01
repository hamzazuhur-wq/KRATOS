// ignore_for_file: public_member_api_docs
// Wave 34: Drift-backed GoalRepository implementation with outbox transactional consistency.
// Enforces Invariant #13 (Outbox in same transaction as domain write)
// and ADR-008 (Materialized path hierarchy).

import 'dart:convert';
import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/entities/goal.dart' as domain;
import '../../../domain/errors.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../../domain/repositories/goal_repository.dart';
import '../../../domain/timestamps.dart';
import 'goals_dao.dart';

class DriftGoalRepository implements GoalRepository {
  final GoalsDao _goalsDao;
  final AppDatabase _db;

  DriftGoalRepository(this._goalsDao, this._db);

  domain.Goal _toDomain(Goal row) {
    return domain.Goal(
      id: Id(row.id),
      ownerId: Id(row.ownerId),
      parentId: row.parentId != null ? Id(row.parentId!) : null,
      rootId: Id(row.rootId),
      path: row.path,
      depth: row.depth,
      title: row.title,
      description: row.description,
      lifeAreaId: row.lifeAreaId != null ? Id(row.lifeAreaId!) : null,
      categoryId: row.categoryId != null ? Id(row.categoryId!) : null,
      status: domain.GoalStatus.values.firstWhere(
        (s) => s.name == row.status,
        orElse: () => domain.GoalStatus.active,
      ),
      xpTarget: row.xpTarget,
      progress: row.progress,
      progressHlc: Hlc.parse(row.progressHlc ?? row.versionHlc),
      versionHlc: Hlc.parse(row.versionHlc),
      dueDate: row.dueDate != null ? Iso8601Timestamp.fromDateTime(row.dueDate!) : null,
      completedAt: row.completedAt != null ? Iso8601Timestamp.fromDateTime(row.completedAt!) : null,
      deletedAt: row.deletedAt != null ? Iso8601Timestamp.fromDateTime(row.deletedAt!) : null,
      createdAt: Iso8601Timestamp.fromDateTime(row.createdAt),
      updatedAt: Iso8601Timestamp.fromDateTime(row.updatedAt),
    );
  }

  GoalsCompanion _toCompanion(domain.Goal goal) {
    return GoalsCompanion(
      id: Value(goal.id.value),
      ownerId: Value(goal.ownerId.value),
      parentId: Value(goal.parentId?.value),
      rootId: Value(goal.rootId.value),
      path: Value(goal.path),
      depth: Value(goal.depth),
      title: Value(goal.title),
      description: Value(goal.description),
      lifeAreaId: Value(goal.lifeAreaId?.value),
      categoryId: Value(goal.categoryId?.value),
      status: Value(goal.status.name),
      xpTarget: Value(goal.xpTarget),
      progress: Value(goal.progress),
      progressHlc: Value(goal.progressHlc.toString()),
      dueDate: Value(goal.dueDate?.value),
      completedAt: Value(goal.completedAt?.value),
      deletedAt: Value(goal.deletedAt?.value),
      versionHlc: Value(goal.versionHlc.toString()),
      createdAt: Value(goal.createdAt.value),
      updatedAt: Value(goal.updatedAt.value),
    );
  }

  @override
  Future<domain.Goal?> findById(Id id) async {
    final row = await _goalsDao.findById(id.value);
    return row != null ? _toDomain(row) : null;
  }

  @override
  Future<List<domain.Goal>> findRootsByOwner(Id ownerId) async {
    final rows = await _goalsDao.rootGoals(ownerId.value);
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<domain.Goal>> findChildrenOf(Id parentId) async {
    final rows = await _goalsDao.childrenOf(parentId.value);
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<domain.Goal>> findByRoot(Id rootId) async {
    final rows = await _goalsDao.descendantsOfRoot(rootId.value);
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> createRoot(domain.Goal goal) async {
    if (!goal.isRoot) {
      throw ValidationError('depth', 'createRoot called with non-root goal');
    }
    await _db.transaction(() async {
      await _goalsDao.upsert(_toCompanion(goal));
      await _enqueueOutbox(
        ownerId: goal.ownerId.value,
        op: 'upsert',
        entityId: goal.id.value,
        versionHlc: goal.versionHlc.toString(),
        payload: {
          'id': goal.id.value,
          'owner_id': goal.ownerId.value,
          'root_id': goal.rootId.value,
          'path': goal.path,
          'depth': goal.depth,
          'title': goal.title,
          'description': goal.description,
          'life_area_id': goal.lifeAreaId?.value,
          'category_id': goal.categoryId?.value,
          'status': goal.status.name,
          'xp_target': goal.xpTarget,
          'progress': goal.progress,
        },
      );
    });
  }

  @override
  Future<void> createChild(domain.Goal goal, domain.Goal parent) async {
    if (goal.parentId != parent.id) {
      throw ValidationError('parentId', 'Child parentId does not match parent id');
    }
    await _db.transaction(() async {
      await _goalsDao.upsert(_toCompanion(goal));
      await _enqueueOutbox(
        ownerId: goal.ownerId.value,
        op: 'upsert',
        entityId: goal.id.value,
        versionHlc: goal.versionHlc.toString(),
        payload: {
          'id': goal.id.value,
          'owner_id': goal.ownerId.value,
          'parent_id': goal.parentId?.value,
          'root_id': goal.rootId.value,
          'path': goal.path,
          'depth': goal.depth,
          'title': goal.title,
          'description': goal.description,
          'life_area_id': goal.lifeAreaId?.value,
          'category_id': goal.categoryId?.value,
          'status': goal.status.name,
          'xp_target': goal.xpTarget,
          'progress': goal.progress,
        },
      );
    });
  }

  @override
  Future<void> reparent(domain.Goal goal, domain.Goal newParent, Hlc newHlc) async {
    final newPath = newParent.childPath(goal.id);
    final newDepth = newParent.depth + 1;
    await _db.transaction(() async {
      await (_db.update(_db.goals)..where((g) => g.id.equals(goal.id.value))).write(
        GoalsCompanion(
          parentId: Value(newParent.id.value),
          rootId: Value(newParent.rootId.value),
          path: Value(newPath),
          depth: Value(newDepth),
          versionHlc: Value(newHlc.toString()),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      await _enqueueOutbox(
        ownerId: goal.ownerId.value,
        op: 'update',
        entityId: goal.id.value,
        versionHlc: newHlc.toString(),
        payload: {
          'parent_id': newParent.id.value,
          'root_id': newParent.rootId.value,
          'path': newPath,
          'depth': newDepth,
        },
      );
    });
  }

  @override
  Future<void> archive(Id id, Hlc newHlc) async {
    final goal = await findById(id);
    if (goal == null) return;
    await _db.transaction(() async {
      await (_db.update(_db.goals)..where((g) => g.id.equals(id.value))).write(
        GoalsCompanion(
          status: const Value('abandoned'),
          versionHlc: Value(newHlc.toString()),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      await _enqueueOutbox(
        ownerId: goal.ownerId.value,
        op: 'update',
        entityId: id.value,
        versionHlc: newHlc.toString(),
        payload: {'status': 'abandoned'},
      );
    });
  }

  @override
  Future<void> delete(Id id, Hlc newHlc) async {
    final goal = await findById(id);
    if (goal == null) return;
    final now = DateTime.now().toUtc();
    await _db.transaction(() async {
      await (_db.update(_db.goals)..where((g) => g.id.equals(id.value))).write(
        GoalsCompanion(
          deletedAt: Value(now),
          deletedBy: Value(goal.ownerId.value),
          versionHlc: Value(newHlc.toString()),
          updatedAt: Value(now),
        ),
      );
      await _enqueueOutbox(
        ownerId: goal.ownerId.value,
        op: 'delete',
        entityId: id.value,
        versionHlc: newHlc.toString(),
        payload: {'deleted_at': now.toIso8601String()},
      );
    });
  }

  Future<void> _enqueueOutbox({
    required String ownerId,
    required String op,
    required String entityId,
    required String versionHlc,
    required Map<String, dynamic> payload,
  }) async {
    await _db.into(_db.syncOutbox).insert(
      SyncOutboxCompanion.insert(
        userId: ownerId,
        op: op,
        entity: 'goals',
        entityId: entityId,
        payloadJson: jsonEncode(payload),
        hlc: versionHlc,
        deviceId: 'local_device',
      ),
    );
  }
}
