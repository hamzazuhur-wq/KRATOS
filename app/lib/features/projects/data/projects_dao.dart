// ignore_for_file: public_member_api_docs
// Wave 9: Drift DAO for Projects.
// Projects are goal-linked or life-area-linked work containers.
// They are NOT XP owners — XP flows through tasks and sessions within projects.

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/drift/core_tables.dart';

part 'projects_dao.g.dart';

@DriftAccessor(tables: [Projects])
class ProjectsDao extends DatabaseAccessor<AppDatabase>
    with _$ProjectsDaoMixin {
  ProjectsDao(super.db);

  /// All active projects for owner (not deleted).
  Future<List<Project>> allProjects(String ownerId) =>
      (select(db.projects)
            ..where(
                (p) => p.ownerId.equals(ownerId) & p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm.asc(p.title)]))
          .get();

  /// Projects linked to a goal.
  Future<List<Project>> projectsForGoal(String goalId) =>
      (select(db.projects)
            ..where(
                (p) => p.goalId.equals(goalId) & p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm.asc(p.title)]))
          .get();

  /// Projects for a life area.
  Future<List<Project>> projectsForLifeArea(String lifeAreaId) =>
      (select(db.projects)
            ..where((p) =>
                p.lifeAreaId.equals(lifeAreaId) & p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm.asc(p.title)]))
          .get();

  Future<Project?> findById(String id) =>
      (select(db.projects)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<void> upsert(ProjectsCompanion companion) =>
      into(db.projects).insertOnConflictUpdate(companion);

  /// Mark a project as completed (status = 'completed').
  Future<void> complete(String projectId, String versionHlc) =>
      (update(db.projects)..where((p) => p.id.equals(projectId))).write(
        ProjectsCompanion(
          status: const Value('completed'),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> softDelete(
          String projectId, String deletedBy, String versionHlc) =>
      (update(db.projects)..where((p) => p.id.equals(projectId))).write(
        ProjectsCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          deletedBy: Value(deletedBy),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
}
