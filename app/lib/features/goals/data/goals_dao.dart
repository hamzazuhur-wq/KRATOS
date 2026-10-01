// ignore_for_file: public_member_api_docs
// Wave 34: Drift DAO for Goals and Sub-goals.
// Supports hierarchical materialized paths (ADR-008, synthesis §1.G)
// and unlimited recursive sub-goal traversal.

import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';
import '../../../data/drift/core_tables.dart';

part 'goals_dao.g.dart';

@DriftAccessor(tables: [Goals, TaskGoalLinks, Tasks])
class GoalsDao extends DatabaseAccessor<AppDatabase> with _$GoalsDaoMixin {
  GoalsDao(super.db);

  /// Fetch all non-deleted goals for owner.
  Future<List<Goal>> allGoals(String ownerId) => (select(db.goals)
        ..where((g) => g.ownerId.equals(ownerId) & g.deletedAt.isNull())
        ..orderBy([(g) => OrderingTerm.asc(g.createdAt)]))
      .get();

  /// Watch all non-deleted goals for owner.
  Stream<List<Goal>> watchAllGoals(String ownerId) => (select(db.goals)
        ..where((g) => g.ownerId.equals(ownerId) & g.deletedAt.isNull())
        ..orderBy([(g) => OrderingTerm.asc(g.createdAt)]))
      .watch();

  /// Fetch root goals (no parent) for owner.
  Future<List<Goal>> rootGoals(String ownerId) => (select(db.goals)
        ..where((g) =>
            g.ownerId.equals(ownerId) &
            g.parentId.isNull() &
            g.deletedAt.isNull())
        ..orderBy([(g) => OrderingTerm.asc(g.createdAt)]))
      .get();

  /// Watch root goals for owner.
  Stream<List<Goal>> watchRootGoals(String ownerId) => (select(db.goals)
        ..where((g) =>
            g.ownerId.equals(ownerId) &
            g.parentId.isNull() &
            g.deletedAt.isNull())
        ..orderBy([(g) => OrderingTerm.asc(g.createdAt)]))
      .watch();

  /// Fetch immediate children of a parent goal.
  Future<List<Goal>> childrenOf(String parentId) => (select(db.goals)
        ..where((g) => g.parentId.equals(parentId) & g.deletedAt.isNull())
        ..orderBy([(g) => OrderingTerm.asc(g.createdAt)]))
      .get();

  /// Watch immediate children of a parent goal.
  Stream<List<Goal>> watchChildrenOf(String parentId) => (select(db.goals)
        ..where((g) => g.parentId.equals(parentId) & g.deletedAt.isNull())
        ..orderBy([(g) => OrderingTerm.asc(g.createdAt)]))
      .watch();

  /// Fetch all descendants of a root goal.
  Future<List<Goal>> descendantsOfRoot(String rootId) => (select(db.goals)
        ..where((g) => g.rootId.equals(rootId) & g.deletedAt.isNull())
        ..orderBy([(g) => OrderingTerm.asc(g.depth)]))
      .get();

  /// Find single goal by ID.
  Future<Goal?> findById(String id) =>
      (select(db.goals)..where((g) => g.id.equals(id))).getSingleOrNull();

  /// Watch single goal by ID.
  Stream<Goal?> watchById(String id) =>
      (select(db.goals)..where((g) => g.id.equals(id))).watchSingleOrNull();

  /// Upsert goal.
  Future<void> upsert(GoalsCompanion companion) =>
      into(db.goals).insertOnConflictUpdate(companion);

  /// Update goal fields.
  Future<void> updateGoal({
    required String goalId,
    required String title,
    String? description,
    String? lifeAreaId,
    String? categoryId,
    String? status,
    String? versionHlc,
  }) =>
      (update(db.goals)..where((g) => g.id.equals(goalId))).write(
        GoalsCompanion(
          title: Value(title),
          description: Value(description),
          lifeAreaId: Value(lifeAreaId),
          categoryId: Value(categoryId),
          status: status != null ? Value(status) : const Value.absent(),
          versionHlc: versionHlc != null ? Value(versionHlc) : const Value.absent(),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Update progress.
  Future<void> updateProgress({
    required String goalId,
    required double progress,
    required String progressHlc,
    required String versionHlc,
  }) =>
      (update(db.goals)..where((g) => g.id.equals(goalId))).write(
        GoalsCompanion(
          progress: Value(progress),
          progressHlc: Value(progressHlc),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Mark goal completed.
  Future<void> completeGoal({
    required String goalId,
    required String versionHlc,
  }) =>
      (update(db.goals)..where((g) => g.id.equals(goalId))).write(
        GoalsCompanion(
          status: const Value('completed'),
          progress: const Value(1.0),
          completedAt: Value(DateTime.now().toUtc()),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Soft delete goal.
  Future<void> softDelete({
    required String goalId,
    required String deletedBy,
    required String versionHlc,
  }) =>
      (update(db.goals)..where((g) => g.id.equals(goalId))).write(
        GoalsCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          deletedBy: Value(deletedBy),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
}
