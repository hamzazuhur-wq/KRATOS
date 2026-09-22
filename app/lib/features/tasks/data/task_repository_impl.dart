// Wave 4: Drift implementation of TaskRepository.
// Bridges Drift rows ↔ domain Task entities + outbox enqueue.

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
    primaryGoalId: row.primaryGoalId != null ? Id(row.primaryGoalId!) : null,
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
      'completed' => TaskStatus.completed,
      'cancelled' => TaskStatus.cancelled,
      _ => TaskStatus.pending,
    };

String _statusToString(TaskStatus s) => switch (s) {
      TaskStatus.pending => 'pending',
      TaskStatus.inProgress => 'in_progress',
      TaskStatus.completed => 'completed',
      TaskStatus.cancelled => 'cancelled',
    };

/// Drift-backed implementation of [TaskRepository].
class DriftTaskRepository implements TaskRepository {
  final AppDatabase _db;
  final TasksDao _dao;

  DriftTaskRepository(this._db) : _dao = TasksDao(_db);

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
  Future<void> save(Task task) => _db.transaction(() async {
        await _dao.upsert(TasksCompanion(
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
          primaryGoalId: Value(task.primaryGoalId?.value),
          notes: Value(task.notes),
          dueDate: Value(task.dueDate),
          xpReward: Value(task.xpReward),
          recurringRule: Value(task.recurringRule),
          completedAt: Value(task.completedAt),
          deletedAt: Value(task.deletedAt),
        ));
        // Outbox enqueue in same transaction
        await _db.into(_db.syncOutbox).insert(SyncOutboxCompanion(
              id: Value(Id.uuidV7().value),
              userId: Value(task.ownerId.value),
              tableName: const Value('tasks'),
              rowId: Value(task.id.value),
              operation: Value(task.deletedAt != null ? 'DELETE' : 'UPSERT'),
              hlc: Value(task.versionHlc.toString()),
            ));
      });

  @override
  Future<void> delete(Id taskId) async {
    await _dao.softDelete(taskId.value, DateTime.now().toUtc().toIso8601String());
  }
}
