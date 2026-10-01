// Wave 4: Drift implementation of TaskRepository.
// Bridges Drift rows ↔ domain Task entities + outbox enqueue.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart'
    hide Task; // Avoid collision with domain Task
import '../../../data/drift/app_database.dart' as db_types;
import '../../../domain/entities/task.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../../domain/repositories/junction_repositories.dart';
import 'tasks_dao.dart';

/// Converts a Drift [db_types.Task] row to a domain [Task].
Task _rowToDomain(db_types.Task row) {
  return Task.fromData(
    id: Id(row.id),
    ownerId: Id(row.ownerId),
    title: row.title,
    status: _parseStatus(row.status),
    priority: row.priority,
    sortOrder: row.sortOrder,
    versionHlc: Hlc.parse(row.versionHlc),
    createdAt: row.createdAt,
    projectId: row.projectId != null ? Id(row.projectId!) : null,
    phaseId: row.phaseId != null ? Id(row.phaseId!) : null,
    lifeAreaId: row.lifeAreaId != null ? Id(row.lifeAreaId!) : null,
    primaryGoalId: row.primaryGoalId != null ? Id(row.primaryGoalId!) : null,
    categoryId: row.categoryId != null ? Id(row.categoryId!) : null,
    notes: row.notes,
    dueDate: row.dueDate,
    xpReward: row.xpReward,
    recurringRule: row.recurringRule,
    completedAt: row.completedAt,
    deletedAt: row.deletedAt,
  );
}

TaskStatus _parseStatus(String s) => switch (s) {
  'pending' => TaskStatus.pending,
  'in_progress' => TaskStatus.inProgress,
  'paused' => TaskStatus.paused,
  'open' => TaskStatus.pending,
  'active' => TaskStatus.pending,
  'done' => TaskStatus.completed,
  'cancelled' => TaskStatus.cancelled,
  'completed' => TaskStatus.completed,
  _ => TaskStatus.pending,
};

String _statusToString(TaskStatus s) => switch (s) {
  TaskStatus.pending => 'pending',
  TaskStatus.inProgress => 'in_progress',
  TaskStatus.paused => 'paused',
  TaskStatus.completed => 'completed',
  TaskStatus.cancelled => 'cancelled',
};

String _statusToServer(TaskStatus s) => switch (s) {
  TaskStatus.pending => 'open',
  TaskStatus.inProgress => 'in_progress',
  TaskStatus.paused => 'paused',
  TaskStatus.completed => 'done',
  TaskStatus.cancelled => 'cancelled',
};

/// Drift-backed implementation of [TaskRepository].
class DriftTaskRepository implements TaskRepository {
  final AppDatabase _db;
  final TasksDao _dao;

  DriftTaskRepository(this._db) : _dao = TasksDao(_db);

  Future<String> _deviceIdFor({required Id ownerId, Id? fallback}) async {
    final user = await (_db.select(
      _db.users,
    )..where((row) => row.id.equals(ownerId.value))).getSingleOrNull();
    for (final candidate in [user?.deviceId, fallback?.value]) {
      if (candidate != null && Id(candidate).isUuidV7) return candidate;
    }
    throw StateError(
      'A UUID device identity is required to journal task changes.',
    );
  }

  @override
  Future<Task?> findById(Id taskId) async {
    final row = await _dao.findById(taskId.value);
    return row != null ? _rowToDomain(row) : null;
  }

  @override
  Future<List<Task>> fetchAll(Id ownerId) async {
    final rows = await _dao.allTasks(ownerId.value);
    return rows.map(_rowToDomain).toList();
  }

  @override
  Future<void> save(Task task) async {
    final deviceId = await _deviceIdFor(
      ownerId: task.ownerId,
      fallback: task.versionHlc.nodeId,
    );
    await _db.transaction(() async {
      await _dao.upsert(
        TasksCompanion(
          id: Value(task.id.value),
          ownerId: Value(task.ownerId.value),
          title: Value(task.title),
          status: Value(_statusToString(task.status)),
          priority: Value(task.priority),
          sortOrder: Value(task.sortOrder),
          versionHlc: Value(task.versionHlc.toString()),
          createdAt: Value(task.createdAt),
          updatedAt: Value(DateTime.now().toUtc()),
          projectId: Value(task.projectId?.value),
          phaseId: Value(task.phaseId?.value),
          lifeAreaId: Value(task.lifeAreaId?.value),
          primaryGoalId: Value(task.primaryGoalId?.value),
          categoryId: Value(task.categoryId?.value),
          notes: Value(task.notes),
          dueDate: Value(task.dueDate),
          xpReward: Value(task.xpReward),
          recurringRule: Value(task.recurringRule),
          completedAt: Value(task.completedAt),
          deletedAt: Value(task.deletedAt),
        ),
      );
      // Outbox enqueue in same transaction
      await _db
          .into(_db.syncOutbox)
          .insert(
            SyncOutboxCompanion(
              userId: Value(task.ownerId.value),
              op: Value(task.deletedAt != null ? 'delete' : 'upsert'),
              entity: const Value('tasks'),
              entityId: Value(task.id.value),
              payloadJson: Value(
                jsonEncode({
                  'title': task.title,
                  'status': _statusToServer(task.status),
                  'priority': task.priority,
                  'sort_order': task.sortOrder,
                  'project_id': task.projectId?.value,
                  'phase_id': task.phaseId?.value,
                  'life_area_id': task.lifeAreaId?.value,
                  'primary_goal_id': task.primaryGoalId?.value,
                  'category_id': task.categoryId?.value,
                  'notes': task.notes,
                  'due_date': task.dueDate?.toUtc().toIso8601String(),
                  'xp_reward': task.xpReward,
                  'recurring_rule': task.recurringRule,
                  'completed_at': task.completedAt?.toUtc().toIso8601String(),
                }),
              ),
              hlc: Value(task.versionHlc.toString()),
              deviceId: Value(deviceId),
            ),
          );
    });
  }

  @override
  Future<void> delete(Id taskId) async {
    final row = await _dao.findById(taskId.value);
    if (row == null || row.deletedAt != null) return;
    final deviceId = await _deviceIdFor(ownerId: Id(row.ownerId));
    final clock = Hlc.now(Id(deviceId));
    final deletedAt = DateTime.now().toUtc();
    await _db.transaction(() async {
      await _dao.softDelete(
        taskId.value,
        deletedAt.toIso8601String(),
        clock.toString(),
      );
      await _db
          .into(_db.syncOutbox)
          .insert(
            SyncOutboxCompanion(
              userId: Value(row.ownerId),
              op: const Value('delete'),
              entity: const Value('tasks'),
              entityId: Value(row.id),
              payloadJson: Value(
                jsonEncode({
                  'title': row.title,
                  'status': row.status,
                  'priority': row.priority,
                  'sort_order': row.sortOrder,
                }),
              ),
              hlc: Value(clock.toString()),
              deviceId: Value(deviceId),
            ),
          );
    });
  }
}
