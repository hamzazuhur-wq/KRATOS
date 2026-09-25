import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../attachments/data/attachments_dao.dart';
import '../../notes/data/notes_dao.dart';
import '../../streaks/domain/streak_service.dart';
import '../../tasks/data/junctions_dao.dart';
import '../../xp/domain/xp_allocation_math.dart';
import '../../xp/domain/xp_ledger_writer.dart';
import '../domain/project_models.dart';
import 'projects_dao.dart';

/// Repository for KRATOS Projects workspace, Roadmap phases, and cross-system integrations.
class ProjectsRepository {
  final AppDatabase database;
  final XpLedgerWriter xpLedgerWriter;
  final String deviceId;

  ProjectsRepository({
    required this.database,
    required this.xpLedgerWriter,
    this.deviceId = 'local_device',
  });

  ProjectsDao get _projectsDao => database.projectsDao;
  AttachmentsDao get _attachmentsDao => database.attachmentsDao;
  AttachmentLinksDao get _attachmentLinksDao => database.attachmentLinksDao;
  NotesDao get _notesDao => database.notesDao;

  // ─── Query & Watch ────────────────────────────────────────────────────────

  /// Reactive stream of all projects with aggregated details for dashboard cards.
  Stream<List<ProjectWithDetails>> watchProjects(
    String ownerId, {
    String? query,
    String? status,
    String? lifeAreaId,
    String? goalId,
    String? skillId,
  }) {
    final triggerStream = database.customSelect(
      'SELECT 1',
      readsFrom: {
        database.projects,
        database.projectPhases,
        database.tasks,
        database.activities,
        database.attachmentLinks,
        database.skills,
        database.files,
        database.notes,
        database.links,
        database.lifeAreas,
        database.goals,
      },
    ).watch();

    return (() async* {
      yield await getProjectsWithDetails(
        ownerId,
        query: query,
        status: status,
        lifeAreaId: lifeAreaId,
        goalId: goalId,
        skillId: skillId,
      );
      yield* triggerStream.asyncMap(
        (_) => getProjectsWithDetails(
          ownerId,
          query: query,
          status: status,
          lifeAreaId: lifeAreaId,
          goalId: goalId,
          skillId: skillId,
        ),
      );
    })();
  }

  /// Fetches unified list of projects for an owner with filtering and details.
  Future<List<ProjectWithDetails>> getProjectsWithDetails(
    String ownerId, {
    String? query,
    String? status,
    String? lifeAreaId,
    String? goalId,
    String? skillId,
  }) async {
    final rawProjects = await _projectsDao.allProjects(ownerId);
    final results = <ProjectWithDetails>[];

    for (final project in rawProjects) {
      // 1. Status filter
      if (status != null && status != 'all') {
        if (project.status.toLowerCase() != status.toLowerCase()) continue;
      }

      // 2. Life Area filter
      if (lifeAreaId != null && lifeAreaId.isNotEmpty) {
        if (project.lifeAreaId != lifeAreaId) continue;
      }

      // 3. Goal filter
      if (goalId != null && goalId.isNotEmpty) {
        if (project.goalId != goalId) continue;
      }

      // 4. Query filter
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        final matchTitle = project.title.toLowerCase().contains(q);
        final matchDesc = project.description?.toLowerCase().contains(q) ?? false;
        if (!matchTitle && !matchDesc) continue;
      }

      final details = await getProjectWithDetails(project.id);
      if (details == null) continue;

      // 5. Skill filter
      if (skillId != null && skillId.isNotEmpty) {
        if (!details.skills.any((s) => s.id == skillId)) continue;
      }

      results.add(details);
    }

    return results;
  }

  /// Reactive stream for a single project workspace.
  Stream<ProjectWithDetails?> watchProjectWithDetails(String projectId) {
    final triggerStream = database.customSelect(
      'SELECT 1',
      readsFrom: {
        database.projects,
        database.projectPhases,
        database.tasks,
        database.activities,
        database.attachmentLinks,
        database.skills,
        database.files,
        database.notes,
        database.links,
        database.lifeAreas,
        database.goals,
      },
    ).watch();

    return (() async* {
      yield await getProjectWithDetails(projectId);
      yield* triggerStream.asyncMap((_) => getProjectWithDetails(projectId));
    })();
  }

  /// Unified loader for a single project with all relations and live progress.
  Future<ProjectWithDetails?> getProjectWithDetails(String projectId) async {
    final project = await _projectsDao.findById(projectId);
    if (project == null || project.deletedAt != null) return null;

    // Life Area
    LifeArea? lifeArea;
    if (project.lifeAreaId != null) {
      lifeArea = await (database.select(database.lifeAreas)
            ..where((a) => a.id.equals(project.lifeAreaId!)))
          .getSingleOrNull();
    }

    // Goal & Sub-goal
    Goal? goal;
    Goal? subGoal;
    if (project.goalId != null) {
      final goalRow = await (database.select(database.goals)
            ..where((g) => g.id.equals(project.goalId!)))
          .getSingleOrNull();
      if (goalRow != null) {
        if (goalRow.parentId != null) {
          subGoal = goalRow;
          goal = await (database.select(database.goals)
                ..where((g) => g.id.equals(goalRow.parentId!)))
              .getSingleOrNull();
        } else {
          goal = goalRow;
        }
      }
    }

    // Level
    String? levelName;
    if (project.levelId != null) {
      final curve = await (database.select(database.levelCurves)
            ..where((c) => c.level.equals(project.levelId!)))
          .getSingleOrNull();
      if (curve != null) {
        levelName = curve.name ?? 'Level ${curve.level}';
      }
    }

    // Skills
    final skillLinks = await _attachmentLinksDao.forEntity(projectId, 'project');
    final skillIds = skillLinks
        .where((l) => l.attachmentKind == 'skill')
        .map((l) => l.attachmentId)
        .toSet();

    final skills = <Skill>[];
    if (skillIds.isNotEmpty) {
      skills.addAll(
        await (database.select(database.skills)
              ..where((s) => s.id.isIn(skillIds) & s.deletedAt.isNull()))
            .get(),
      );
    }

    // Phases
    final phases = await _projectsDao.phasesForProject(projectId);

    // Tasks
    final tasks = await (database.select(database.tasks)
          ..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull()))
        .get();

    // Activities
    final activities = await (database.select(database.activities)
          ..where((a) => a.projectId.equals(projectId) & a.deletedAt.isNull()))
        .get();

    // Files
    final fileLinks = skillLinks.where((l) => l.attachmentKind == 'file').toList();
    final fileIds = fileLinks.map((l) => l.attachmentId).toSet();
    final files = <File>[];
    if (fileIds.isNotEmpty) {
      files.addAll(
        await (database.select(database.files)
              ..where((f) => f.id.isIn(fileIds) & f.deletedAt.isNull()))
            .get(),
      );
    }

    // Notes
    final noteLinks = skillLinks.where((l) => l.attachmentKind == 'note').toList();
    final noteIds = noteLinks.map((l) => l.attachmentId).toSet();
    final notes = <Note>[];
    if (noteIds.isNotEmpty) {
      notes.addAll(
        await (database.select(database.notes)
              ..where((n) => n.id.isIn(noteIds) & n.deletedAt.isNull()))
            .get(),
      );
    }

    // Links
    final linkLinks = skillLinks.where((l) => l.attachmentKind == 'link').toList();
    final linkIds = linkLinks.map((l) => l.attachmentId).toSet();
    final links = <Link>[];
    if (linkIds.isNotEmpty) {
      links.addAll(
        await (database.select(database.links)
              ..where((l) => l.id.isIn(linkIds) & l.deletedAt.isNull()))
            .get(),
      );
    }

    // Compute progress
    final tasksByPhase = <String, List<Task>>{};
    final unphasedTasks = <Task>[];
    for (final task in tasks) {
      if (task.phaseId != null) {
        tasksByPhase.putIfAbsent(task.phaseId!, () => []).add(task);
      } else {
        unphasedTasks.add(task);
      }
    }

    final computedProgress = RoadmapProgressCalculator.computeProjectProgress(
      phases: phases,
      tasksByPhaseId: tasksByPhase,
      unphasedProjectTasks: unphasedTasks,
    );

    // Keep cached progress in sync if changed
    if ((project.progress - computedProgress).abs() > 0.001) {
      await _projectsDao.updateProgress(
        project.id,
        computedProgress,
        Hlc.now(Id.uuidV7()).toString(),
      );
    }

    return ProjectWithDetails(
      project: project,
      lifeArea: lifeArea,
      goal: goal,
      subGoal: subGoal,
      levelName: levelName,
      skills: skills,
      phases: phases,
      tasks: tasks,
      activities: activities,
      files: files,
      notes: notes,
      links: links,
      progress: computedProgress,
    );
  }

  // ─── Project Mutations ───────────────────────────────────────────────────

  /// Creates a new Project and immediately persists all relations.
  Future<String> createProject({
    required String ownerId,
    required String title,
    String? description,
    int difficulty = 1,
    String? lifeAreaId,
    String? goalId,
    int? levelId,
    Set<String> skillIds = const {},
    String? coverImagePath,
    DateTime? dueDate,
  }) async {
    final now = DateTime.now().toUtc();
    final id = Id.uuidV7();
    final hlc = Hlc.now(id);

    final companion = ProjectsCompanion.insert(
      id: id.value,
      ownerId: ownerId,
      title: title.trim(),
      description: Value(description?.trim().isEmpty == true ? null : description?.trim()),
      status: 'active',
      difficulty: Value(difficulty.clamp(1, 10)),
      lifeAreaId: Value(lifeAreaId),
      goalId: Value(goalId),
      levelId: Value(levelId),
      coverImagePath: Value(coverImagePath),
      progress: const Value(0.0),
      dueDate: Value(dueDate),
      memberIds: '[]',
      versionHlc: hlc.toString(),
      createdAt: now,
      updatedAt: now,
    );

    await _projectsDao.upsert(companion);
    await _enqueueSync(
      ownerId: ownerId,
      op: 'insert',
      entity: 'projects',
      entityId: id.value,
      payload: {
        'id': id.value,
        'owner_id': ownerId,
        'title': title.trim(),
        'description': description?.trim(),
        'difficulty': difficulty,
        'life_area_id': lifeAreaId,
        'goal_id': goalId,
        'level_id': levelId,
        'cover_image_path': coverImagePath,
        'status': 'active',
        'progress': 0.0,
      },
    );

    // Link skills
    await _replaceProjectSkills(id.value, skillIds, ownerId);

    return id.value;
  }

  /// Updates an existing Project.
  Future<void> updateProject({
    required String projectId,
    required String ownerId,
    required String title,
    String? description,
    required int difficulty,
    String? lifeAreaId,
    String? goalId,
    int? levelId,
    required Set<String> skillIds,
    String? coverImagePath,
    String? status,
    DateTime? dueDate,
  }) async {
    final existing = await _projectsDao.findById(projectId);
    if (existing == null) return;

    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id.uuidV7());

    await _projectsDao.upsert(
      existing.toCompanion(true).copyWith(
            title: Value(title.trim()),
            description: Value(description?.trim().isEmpty == true ? null : description?.trim()),
            difficulty: Value(difficulty.clamp(1, 10)),
            lifeAreaId: Value(lifeAreaId),
            goalId: Value(goalId),
            levelId: Value(levelId),
            coverImagePath: Value(coverImagePath),
            status: Value(status ?? existing.status),
            dueDate: Value(dueDate),
            versionHlc: Value(hlc.toString()),
            updatedAt: Value(now),
          ),
    );

    await _enqueueSync(
      ownerId: ownerId,
      op: 'update',
      entity: 'projects',
      entityId: projectId,
      payload: {
        'id': projectId,
        'title': title.trim(),
        'description': description?.trim(),
        'difficulty': difficulty,
        'life_area_id': lifeAreaId,
        'goal_id': goalId,
        'level_id': levelId,
        'cover_image_path': coverImagePath,
        'status': status ?? existing.status,
      },
    );

    await _replaceProjectSkills(projectId, skillIds, ownerId);
  }

  /// Completes a Project and awards audited XP according to Difficulty.
  Future<ProjectXpBreakdown?> completeProject({
    required String projectId,
    required String ownerId,
  }) async {
    final project = await _projectsDao.findById(projectId);
    if (project == null || project.status == 'completed') return null;

    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id.uuidV7());

    // 1. Mark completed
    await _projectsDao.complete(projectId, hlc.toString());
    await _enqueueSync(
      ownerId: ownerId,
      op: 'update',
      entity: 'projects',
      entityId: projectId,
      payload: {'id': projectId, 'status': 'completed', 'updated_at': now.toIso8601String()},
    );

    // 2. Check if Main Goal (+30% bonus)
    var isMainGoal = false;
    if (project.goalId != null) {
      final goal = await (database.select(database.goals)
            ..where((g) => g.id.equals(project.goalId!)))
          .getSingleOrNull();
      if (goal != null && goal.parentId == null) {
        isMainGoal = true;
      }
    }

    final xpBreakdown = ProjectDifficultyXpCalculator.calculateXp(
      difficulty: project.difficulty,
      isMainGoal: isMainGoal,
    );

    // 3. Resolve Life Area for XP allocation
    String? targetLifeAreaId = project.lifeAreaId;
    if (targetLifeAreaId == null && project.goalId != null) {
      final goal = await (database.select(database.goals)
            ..where((g) => g.id.equals(project.goalId!)))
          .getSingleOrNull();
      targetLifeAreaId = goal?.lifeAreaId;
    }
    if (targetLifeAreaId == null) {
      final firstArea = await (database.select(database.lifeAreas)
            ..where((a) => a.ownerId.equals(ownerId) & a.deletedAt.isNull())
            ..limit(1))
          .getSingleOrNull();
      targetLifeAreaId = firstArea?.id;
    }

    // 4. Award XP via Point Ledger
    if (targetLifeAreaId != null && xpBreakdown.totalXp > 0) {
      final idempotencyKey = Id('proj_comp_${project.id}');
      try {
        final streakService = StreakService(database);
        final streakInfo = await streakService.getStreakForLifeArea(
          userId: Id(ownerId),
          lifeAreaId: Id(targetLifeAreaId),
        );
        final streakBonus = streakInfo.calculateStreakBonus(xpBreakdown.baseXp);

        await xpLedgerWriter.recordEvent(
          ownerId: Id(ownerId),
          idempotencyKey: idempotencyKey,
          sourceType: 'project',
          sourceId: Id(project.id),
          action: 'project_completed',
          basePoints: xpBreakdown.baseXp,
          bonusPoints: xpBreakdown.bonusPoints,
          streakBonus: streakBonus,
          allocationRatios: [
            AllocationRatio(
              lifeAreaId: Id(targetLifeAreaId),
              percentage: 100.0,
            ),
          ],
          clock: hlc,
          deviceId: Id(deviceId),
        );

        await streakService.logActivity(
          userId: Id(ownerId),
          lifeAreaId: Id(targetLifeAreaId),
          activityDate: now,
          versionHlc: hlc.toString(),
        );
      } catch (_) {
        // Idempotency check handled inside writer
      }
    }

    return xpBreakdown;
  }

  /// Soft deletes a project.
  Future<void> softDeleteProject(String projectId, String ownerId) async {
    final hlc = Hlc.now(Id.uuidV7());
    await _projectsDao.softDelete(projectId, ownerId, hlc.toString());
    await _enqueueSync(
      ownerId: ownerId,
      op: 'delete',
      entity: 'projects',
      entityId: projectId,
      payload: {'id': projectId, 'deleted_at': DateTime.now().toUtc().toIso8601String()},
    );
  }

  // ─── Roadmap Phases CRUD ─────────────────────────────────────────────────

  /// Adds a new Phase to a Project roadmap.
  Future<String> createPhase({
    required String projectId,
    required String ownerId,
    required String name,
    String? description,
    int sortOrder = 0,
  }) async {
    final now = DateTime.now().toUtc();
    final id = Id.uuidV7();
    final hlc = Hlc.now(id);

    final companion = ProjectPhasesCompanion.insert(
      id: id.value,
      projectId: projectId,
      name: name.trim(),
      description: Value(description?.trim().isEmpty == true ? null : description?.trim()),
      sortOrder: Value(sortOrder),
      status: const Value('active'),
      progress: const Value(0.0),
      versionHlc: hlc.toString(),
      createdAt: now,
      updatedAt: now,
    );

    await _projectsDao.upsertPhase(companion);
    await _enqueueSync(
      ownerId: ownerId,
      op: 'insert',
      entity: 'project_phases',
      entityId: id.value,
      payload: {
        'id': id.value,
        'project_id': projectId,
        'name': name.trim(),
        'description': description?.trim(),
        'sort_order': sortOrder,
        'status': 'active',
        'progress': 0.0,
      },
    );

    await recalculateProjectProgress(projectId);
    return id.value;
  }

  /// Updates a Phase.
  Future<void> updatePhase({
    required String phaseId,
    required String projectId,
    required String ownerId,
    required String name,
    String? description,
    String? status,
    int? sortOrder,
  }) async {
    final existing = await _projectsDao.findPhaseById(phaseId);
    if (existing == null) return;

    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id.uuidV7());
    final newStatus = status ?? existing.status;
    final completedAt = newStatus == 'completed' ? (existing.completedAt ?? now) : null;

    await _projectsDao.upsertPhase(
      existing.toCompanion(true).copyWith(
            name: Value(name.trim()),
            description: Value(description?.trim().isEmpty == true ? null : description?.trim()),
            status: Value(newStatus),
            completedAt: Value(completedAt),
            sortOrder: Value(sortOrder ?? existing.sortOrder),
            versionHlc: Value(hlc.toString()),
            updatedAt: Value(now),
          ),
    );

    await _enqueueSync(
      ownerId: ownerId,
      op: 'update',
      entity: 'project_phases',
      entityId: phaseId,
      payload: {
        'id': phaseId,
        'name': name.trim(),
        'description': description?.trim(),
        'status': newStatus,
        'sort_order': sortOrder ?? existing.sortOrder,
      },
    );

    await recalculateProjectProgress(projectId);
  }

  /// Soft deletes a Phase.
  Future<void> softDeletePhase(String phaseId, String projectId, String ownerId) async {
    final hlc = Hlc.now(Id.uuidV7());
    await _projectsDao.softDeletePhase(phaseId, ownerId, hlc.toString());

    // Unlink any tasks attached to this phase
    await (database.update(database.tasks)..where((t) => t.phaseId.equals(phaseId))).write(
      const TasksCompanion(phaseId: Value(null)),
    );

    await _enqueueSync(
      ownerId: ownerId,
      op: 'delete',
      entity: 'project_phases',
      entityId: phaseId,
      payload: {'id': phaseId, 'deleted_at': DateTime.now().toUtc().toIso8601String()},
    );

    await recalculateProjectProgress(projectId);
  }

  /// Reorders phases in sequence.
  Future<void> reorderPhases(String projectId, List<String> phaseIdsInOrder) async {
    final hlc = Hlc.now(Id.uuidV7());
    final now = DateTime.now().toUtc();

    for (var i = 0; i < phaseIdsInOrder.length; i++) {
      final pId = phaseIdsInOrder[i];
      await (database.update(database.projectPhases)..where((p) => p.id.equals(pId))).write(
        ProjectPhasesCompanion(
          sortOrder: Value(i),
          versionHlc: Value(hlc.toString()),
          updatedAt: Value(now),
        ),
      );
    }
  }

  /// Recomputes progress for all Phases in a Project, updates each Phase,
  /// and updates the Project aggregate progress in the database.
  Future<double> recalculateProjectProgress(String projectId) async {
    final phases = await _projectsDao.phasesForProject(projectId);
    final tasks = await (database.select(database.tasks)
          ..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull()))
        .get();

    final tasksByPhase = <String, List<Task>>{};
    final unphasedTasks = <Task>[];
    for (final task in tasks) {
      if (task.phaseId != null) {
        tasksByPhase.putIfAbsent(task.phaseId!, () => []).add(task);
      } else {
        unphasedTasks.add(task);
      }
    }

    final hlc = Hlc.now(Id.uuidV7());

    // Update each phase progress
    for (final phase in phases) {
      final pTasks = tasksByPhase[phase.id] ?? const [];
      final computed = RoadmapProgressCalculator.computePhaseProgress(
        phaseTasks: pTasks,
        phaseStatus: phase.status,
      );
      final isAllDone = pTasks.isNotEmpty && pTasks.every((t) => t.status == 'completed');
      final targetStatus = isAllDone ? 'completed' : phase.status;
      final statusChanged = targetStatus != phase.status;

      if ((phase.progress - computed).abs() > 0.001 || statusChanged) {
        await _projectsDao.upsertPhase(
          phase.toCompanion(true).copyWith(
                progress: Value(computed),
                status: Value(targetStatus),
                completedAt: Value(targetStatus == 'completed' ? (phase.completedAt ?? DateTime.now().toUtc()) : null),
                versionHlc: Value(hlc.toString()),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
        );
      }
    }

    // Update project progress
    final projectProgress = RoadmapProgressCalculator.computeProjectProgress(
      phases: phases,
      tasksByPhaseId: tasksByPhase,
      unphasedProjectTasks: unphasedTasks,
    );

    await _projectsDao.updateProgress(projectId, projectProgress, hlc.toString());
    return projectProgress;
  }

  // ─── Tasks & Activities Linking ──────────────────────────────────────────

  /// Links a Task to a Project and optional Phase.
  Future<void> linkTaskToProject(String taskId, String projectId, {String? phaseId}) async {
    final hlc = Hlc.now(Id.uuidV7());
    await (database.update(database.tasks)..where((t) => t.id.equals(taskId))).write(
      TasksCompanion(
        projectId: Value(projectId),
        phaseId: Value(phaseId),
        versionHlc: Value(hlc.toString()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    await recalculateProjectProgress(projectId);
  }

  /// Links an Activity to a Project.
  Future<void> linkActivityToProject(String activityId, String projectId) async {
    final hlc = Hlc.now(Id.uuidV7());
    await (database.update(database.activities)..where((a) => a.id.equals(activityId))).write(
      ActivitiesCompanion(
        projectId: Value(projectId),
        versionHlc: Value(hlc.toString()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  // ─── Attachments: Notes, Files, Links ────────────────────────────────────

  /// Adds a rich Note to a Project (and optional Roadmap Phase).
  Future<String> addNote({
    required String ownerId,
    required String projectId,
    String? phaseId,
    required String bodyText,
    String? bodyMarkdown,
  }) async {
    final now = DateTime.now().toUtc();
    final noteId = Id.uuidV7();
    final linkId = Id.uuidV7();
    final hlc = Hlc.now(noteId);

    await _notesDao.upsertNote(
      NotesCompanion.insert(
        id: noteId.value,
        ownerId: ownerId,
        bodyText: bodyText,
        bodyMarkdown: Value(bodyMarkdown),
        pinned: false,
        versionHlc: hlc.toString(),
        createdAt: now,
        updatedAt: now,
      ),
    );

    final targetEntityId = phaseId ?? projectId;
    final targetEntityKind = phaseId != null ? 'roadmap_phase' : 'project';

    await _attachmentLinksDao.upsert(
      AttachmentLinksCompanion.insert(
        id: linkId.value,
        attachmentId: noteId.value,
        attachmentKind: 'note',
        entityId: targetEntityId,
        entityKind: targetEntityKind,
        versionHlc: hlc.toString(),
        createdAt: now,
      ),
    );

    return noteId.value;
  }

  /// Adds an External Link to a Project (and optional Roadmap Phase).
  Future<String> addExternalLink({
    required String ownerId,
    required String projectId,
    String? phaseId,
    required String url,
    String? title,
    String? description,
  }) async {
    final now = DateTime.now().toUtc();
    final linkRecordId = Id.uuidV7();
    final junctionLinkId = Id.uuidV7();
    final hlc = Hlc.now(linkRecordId);

    await _attachmentsDao.upsertLink(
      LinksCompanion.insert(
        id: linkRecordId.value,
        ownerId: ownerId,
        url: url.trim(),
        title: Value(title?.trim().isEmpty == true ? null : title?.trim()),
        description: Value(description?.trim().isEmpty == true ? null : description?.trim()),
        versionHlc: hlc.toString(),
        createdAt: now,
      ),
    );

    final targetEntityId = phaseId ?? projectId;
    final targetEntityKind = phaseId != null ? 'roadmap_phase' : 'project';

    await _attachmentLinksDao.upsert(
      AttachmentLinksCompanion.insert(
        id: junctionLinkId.value,
        attachmentId: linkRecordId.value,
        attachmentKind: 'link',
        entityId: targetEntityId,
        entityKind: targetEntityKind,
        versionHlc: hlc.toString(),
        createdAt: now,
      ),
    );

    return linkRecordId.value;
  }

  /// Adds a File attachment metadata to a Project (and optional Roadmap Phase).
  Future<String> addFile({
    required String ownerId,
    required String projectId,
    String? phaseId,
    required String filename,
    required String storageKey,
    String? mime,
    required int sizeBytes,
    String? sha256,
  }) async {
    final now = DateTime.now().toUtc();
    final fileId = Id.uuidV7();
    final junctionLinkId = Id.uuidV7();
    final hlc = Hlc.now(fileId);

    await _attachmentsDao.upsertFile(
      FilesCompanion.insert(
        id: fileId.value,
        ownerId: ownerId,
        storageKey: storageKey,
        filename: Value(filename),
        mime: Value(mime),
        sizeBytes: sizeBytes,
        sha256: Value(sha256),
        versionHlc: hlc.toString(),
        createdAt: now,
      ),
    );

    final targetEntityId = phaseId ?? projectId;
    final targetEntityKind = phaseId != null ? 'roadmap_phase' : 'project';

    await _attachmentLinksDao.upsert(
      AttachmentLinksCompanion.insert(
        id: junctionLinkId.value,
        attachmentId: fileId.value,
        attachmentKind: 'file',
        entityId: targetEntityId,
        entityKind: targetEntityKind,
        versionHlc: hlc.toString(),
        createdAt: now,
      ),
    );

    return fileId.value;
  }

  /// Deletes an attachment (removes junction link and soft deletes the attachment).
  Future<void> deleteAttachment({
    required String attachmentId,
    required String attachmentKind,
    required String ownerId,
  }) async {
    final hlc = Hlc.now(Id.uuidV7());

    // 1. Remove junction link
    final links = await (database.select(database.attachmentLinks)
          ..where((l) => l.attachmentId.equals(attachmentId)))
        .get();
    for (final l in links) {
      await _attachmentLinksDao.remove(l.id);
    }

    // 2. Soft delete underlying entity
    if (attachmentKind == 'note') {
      await _notesDao.softDeleteNote(attachmentId, ownerId, hlc.toString());
    } else if (attachmentKind == 'file') {
      await _attachmentsDao.softDeleteFile(attachmentId, ownerId, hlc.toString());
    } else if (attachmentKind == 'link') {
      await _attachmentsDao.softDeleteLink(attachmentId, ownerId, hlc.toString());
    }
  }

  // ─── Dual "Assign To" Target Options ─────────────────────────────────────

  /// Dynamically loads real persisted entities based on the selected target type.
  Future<List<ProjectAssignmentTarget>> loadAssignmentTargets(
    String ownerId,
    ProjectAssignmentType type,
  ) async {
    switch (type) {
      case ProjectAssignmentType.lifeArea:
        final areas = await (database.select(database.lifeAreas)
              ..where((a) => a.ownerId.equals(ownerId) & a.deletedAt.isNull())
              ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
            .get();
        return areas
            .map((a) => ProjectAssignmentTarget(
                  id: a.id,
                  title: a.name,
                  colorHex: a.color,
                  type: ProjectAssignmentType.lifeArea,
                ))
            .toList();

      case ProjectAssignmentType.goal:
        final goals = await (database.select(database.goals)
              ..where(
                (g) =>
                    g.ownerId.equals(ownerId) &
                    g.parentId.isNull() &
                    g.deletedAt.isNull(),
              )
              ..orderBy([(g) => OrderingTerm.asc(g.title)]))
            .get();
        return goals
            .map((g) => ProjectAssignmentTarget(
                  id: g.id,
                  title: g.title,
                  subtitle: 'Main Goal',
                  type: ProjectAssignmentType.goal,
                ))
            .toList();

      case ProjectAssignmentType.subGoal:
        final subGoals = await (database.select(database.goals)
              ..where(
                (g) =>
                    g.ownerId.equals(ownerId) &
                    g.parentId.isNotNull() &
                    g.deletedAt.isNull(),
              )
              ..orderBy([(g) => OrderingTerm.asc(g.title)]))
            .get();
        return subGoals
            .map((g) => ProjectAssignmentTarget(
                  id: g.id,
                  title: g.title,
                  subtitle: 'Sub-goal',
                  type: ProjectAssignmentType.subGoal,
                ))
            .toList();

      case ProjectAssignmentType.level:
        await database.progressionDao.ensureSeeded();
        final curves = await database.progressionDao.allCurves();
        final tiers = await database.progressionDao.allTiers();
        final tierMap = {for (final t in tiers) t.ordinal: t};

        return curves.map((c) {
          final tier = tierMap[((c.level - 1) ~/ 10) + 1] ??
              (tiers.isNotEmpty ? tiers.first : null);
          final tierName = c.tierName ?? tier?.name ?? 'Tier';
          final name = c.name?.isNotEmpty == true
              ? c.name!
              : '$tierName ${ProjectDifficulty.toRoman(((c.level - 1) % 10) + 1)}';

          return ProjectAssignmentTarget(
            id: c.level.toString(),
            title: name,
            subtitle: 'Level ${c.level} • ${c.cumulativeXpRequired} XP',
            colorHex: tier?.color,
            type: ProjectAssignmentType.level,
          );
        }).toList();
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Future<void> _replaceProjectSkills(
    String projectId,
    Set<String> skillIds,
    String ownerId,
  ) async {
    final current = await _attachmentLinksDao.forEntity(projectId, 'project');
    for (final link in current.where((l) => l.attachmentKind == 'skill')) {
      await _attachmentLinksDao.remove(link.id);
    }
    for (final skillId in skillIds) {
      final linkId = Id.uuidV7();
      await _attachmentLinksDao.upsert(
        AttachmentLinksCompanion.insert(
          id: linkId.value,
          attachmentId: skillId,
          attachmentKind: 'skill',
          entityId: projectId,
          entityKind: 'project',
          versionHlc: Hlc.now(linkId).toString(),
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  Future<void> _enqueueSync({
    required String ownerId,
    required String op,
    required String entity,
    required String entityId,
    required Map<String, dynamic> payload,
  }) async {
    final hlc = Hlc.now(Id.uuidV7());
    await database.into(database.syncOutbox).insert(
          SyncOutboxCompanion.insert(
            userId: ownerId,
            op: op,
            entity: entity,
            entityId: entityId,
            payloadJson: jsonEncode(payload),
            hlc: hlc.toString(),
            deviceId: deviceId,
          ),
        );
  }
}
