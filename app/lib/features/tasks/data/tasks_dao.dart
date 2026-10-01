// ignore_for_file: public_member_api_docs
// Wave 4: Tasks Drift DAO — minimal stub (full UX in Wave 9).

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/drift/core_tables.dart';

part 'tasks_dao.g.dart';

@DriftAccessor(tables: [Tasks])
class TasksDao extends DatabaseAccessor<AppDatabase> with _$TasksDaoMixin {
  TasksDao(super.db);

  /// Fetch all non-deleted tasks for a user.
  Future<List<Task>> allTasks(String ownerId) => (select(
    db.tasks,
  )..where((t) => t.ownerId.equals(ownerId) & t.deletedAt.isNull())).get();

  /// Fetch a single task by ID.
  Future<Task?> findById(String taskId) =>
      (select(db.tasks)..where((t) => t.id.equals(taskId))).getSingleOrNull();

  /// Insert or replace a task row.
  Future<void> upsert(TasksCompanion companion) =>
      into(db.tasks).insertOnConflictUpdate(companion);

  /// Soft-delete (sets deleted_at).
  Future<void> softDelete(String taskId, String deletedAt, String versionHlc) =>
      (update(db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          deletedAt: Value(DateTime.parse(deletedAt)),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Update task status and completion timestamp.
  Future<void> updateStatus(String taskId, String status) {
    final now = DateTime.now().toUtc();
    return (update(db.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        status: Value(status),
        completedAt: Value(status == 'completed' ? now : null),
        updatedAt: Value(now),
      ),
    );
  }
}
