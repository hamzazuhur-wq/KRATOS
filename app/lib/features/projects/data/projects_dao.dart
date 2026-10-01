// ignore_for_file: public_member_api_docs
// Wave 9: Drift DAO for Projects.
// Projects are goal-linked or life-area-linked work containers.
// They are NOT XP owners — XP flows through tasks and sessions within projects.

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/drift/core_tables.dart';

part 'projects_dao.g.dart';

@DriftAccessor(tables: [Projects, ProjectPhases])
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

  /// Mark a project as completed (status = 'completed', progress = 100.0).
  Future<void> complete(String projectId, String versionHlc) =>
      (update(db.projects)..where((p) => p.id.equals(projectId))).write(
        ProjectsCompanion(
          status: const Value('completed'),
          progress: const Value(100.0),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> updateProgress(String projectId, double progress, String versionHlc) =>
      (update(db.projects)..where((p) => p.id.equals(projectId))).write(
        ProjectsCompanion(
          progress: Value(progress),
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

  // ─── Project Phases (Roadmap) ──────────────────────────────────────────

  Future<List<ProjectPhase>> phasesForProject(String projectId) =>
      (select(db.projectPhases)
            ..where((p) => p.projectId.equals(projectId) & p.deletedAt.isNull())
            ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
          .get();

  Future<ProjectPhase?> findPhaseById(String id) =>
      (select(db.projectPhases)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<void> upsertPhase(ProjectPhasesCompanion companion) =>
      into(db.projectPhases).insertOnConflictUpdate(companion);

  Future<void> updatePhaseProgress(
    String phaseId,
    double progress,
    String versionHlc,
  ) =>
      (update(db.projectPhases)..where((p) => p.id.equals(phaseId))).write(
        ProjectPhasesCompanion(
          progress: Value(progress),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> updatePhaseStatus(
    String phaseId,
    String status,
    String versionHlc, {
    DateTime? completedAt,
  }) =>
      (update(db.projectPhases)..where((p) => p.id.equals(phaseId))).write(
        ProjectPhasesCompanion(
          status: Value(status),
          completedAt: Value(completedAt),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> softDeletePhase(
    String phaseId,
    String deletedBy,
    String versionHlc,
  ) =>
      (update(db.projectPhases)..where((p) => p.id.equals(phaseId))).write(
        ProjectPhasesCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          deletedBy: Value(deletedBy),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
}
