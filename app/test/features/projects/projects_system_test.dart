import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/projects/data/projects_repository.dart';
import 'package:kratos_app/features/projects/domain/project_models.dart';
import 'package:kratos_app/features/xp/data/xp_ledger_writer_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DriftXpLedgerWriter xpWriter;
  late ProjectsRepository repository;
  const ownerId = 'project_test_user_001';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.progressionDao.ensureSeeded();

    final now = DateTime.now().toUtc();
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: ownerId,
            deviceId: 'dev_local',
            displayName: const drift.Value('Operative'),
            caption: const drift.Value('Projects Test'),
            avatarUrl: const drift.Value(''),
            timezone: 'UTC',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Seed test life areas
    await db
        .into(db.lifeAreas)
        .insert(
          LifeAreasCompanion.insert(
            id: 'area_tech',
            ownerId: ownerId,
            name: 'Technology & Engineering',
            color: const drift.Value('#00E5FF'),
            icon: const drift.Value('laptop'),
            sortOrder: 1,
            versionHlc: '0000000000000-0000-000000000000',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Seed a main goal (parentId == null)
    await db
        .into(db.goals)
        .insert(
          GoalsCompanion.insert(
            id: 'goal_main',
            ownerId: ownerId,
            rootId: 'goal_main',
            path: 'goal_main',
            depth: 0,
            status: 'active',
            progress: 0.0,
            lifeAreaId: const drift.Value('area_tech'),
            title: 'Master Systems Architecture',
            versionHlc: '0000000000000-0000-000000000000',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Seed a skill
    await db
        .into(db.skills)
        .insert(
          SkillsCompanion.insert(
            id: 'skill_flutter',
            ownerId: ownerId,
            name: 'Flutter & Dart',
            xpTotal: 0,
            level: 1,
            icon: const drift.Value('flutter_dash'),
            versionHlc: '0000000000000-0000-000000000000',
            createdAt: now,
            updatedAt: now,
          ),
        );

    xpWriter = DriftXpLedgerWriter(db);
    repository = ProjectsRepository(database: db, xpLedgerWriter: xpWriter);
  });

  tearDown(() async {
    await db.close();
  });

  group('1. Project Difficulty & XP Progression Engine', () {
    test('Difficulty scale 1..10 maps strictly to Roman numerals Ⅰ to Ⅹ', () {
      expect(ProjectDifficulty.toRoman(1), 'Ⅰ');
      expect(ProjectDifficulty.toRoman(2), 'Ⅱ');
      expect(ProjectDifficulty.toRoman(3), 'Ⅲ');
      expect(ProjectDifficulty.toRoman(4), 'Ⅳ');
      expect(ProjectDifficulty.toRoman(5), 'Ⅴ');
      expect(ProjectDifficulty.toRoman(6), 'Ⅵ');
      expect(ProjectDifficulty.toRoman(7), 'Ⅶ');
      expect(ProjectDifficulty.toRoman(8), 'Ⅷ');
      expect(ProjectDifficulty.toRoman(9), 'Ⅸ');
      expect(ProjectDifficulty.toRoman(10), 'Ⅹ');

      expect(ProjectDifficulty.fromRoman('Ⅰ'), 1);
      expect(ProjectDifficulty.fromRoman('Ⅴ'), 5);
      expect(ProjectDifficulty.fromRoman('Ⅹ'), 10);
    });

    test(
      'XP calculation keeps Project base XP and completion bonus separate',
      () {
        // Level 1: 100 XP
        expect(ProjectDifficultyXpCalculator.baseXp(1), 100);
        final levelOne = ProjectDifficultyXpCalculator.calculateXp(
          difficulty: 1,
        );
        expect(levelOne.baseXp, 100);
        expect(levelOne.bonusPoints, 30);
        expect(levelOne.totalXp, 130);

        // Level 5: 750 XP -> +30% completion bonus = 225 XP
        expect(ProjectDifficultyXpCalculator.baseXp(5), 750);
        final levelFive = ProjectDifficultyXpCalculator.calculateXp(
          difficulty: 5,
        );
        expect(levelFive.baseXp, 750);
        expect(levelFive.bonusPoints, 225);
        expect(levelFive.totalXp, 975);

        final levelSix = ProjectDifficultyXpCalculator.calculateXp(
          difficulty: 6,
        );
        expect(levelSix.baseXp, 1000);
        expect(levelSix.bonusPoints, 300);
        expect(levelSix.totalXp, 1300);

        // Level 8: 2250 XP -> +30% = 675 XP
        final levelEight = ProjectDifficultyXpCalculator.calculateXp(
          difficulty: 8,
        );
        expect(levelEight.baseXp, 2250);
        expect(levelEight.bonusPoints, 675);
        expect(levelEight.totalXp, 2925);
        expect(ProjectDifficultyXpCalculator.calculateCompletionBonus(75), 23);
      },
    );
  });

  group('2. Project Persistence & CRUD', () {
    test('Creates a real project in Drift SQLite with difficulty, cover, and skills', () async {
      final projectId = await repository.createProject(
        ownerId: ownerId,
        title: 'Project Nebula',
        description: 'Quantum compiler engine',
        difficulty: 7,
        lifeAreaId: 'area_tech',
        goalId: 'goal_main',
        coverImagePath: 'https://storage.kratos.io/covers/nebula.png',
        skillIds: {'skill_flutter'},
      );

      expect(projectId, isNotEmpty);

      // Verify row exists directly in Drift table
      final direct = await db.projectsDao.findById(projectId);
      expect(direct, isNotNull);
      expect(direct!.title, 'Project Nebula');
      expect(direct.difficulty, 7);
      expect(direct.lifeAreaId, 'area_tech');
      expect(direct.goalId, 'goal_main');
      expect(
        direct.coverImagePath,
        'https://storage.kratos.io/covers/nebula.png',
      );
      expect(direct.status, 'active');
      expect(direct.progress, 0.0);

      // Verify skill attachment link in junction table
      final skillLinks = await db.attachmentLinksDao.forEntity(
        projectId,
        'project',
      );
      expect(skillLinks.length, 1);
      expect(skillLinks.first.attachmentId, 'skill_flutter');
      expect(skillLinks.first.attachmentKind, 'skill');
    });

    test('Updates project metadata and status', () async {
      final projectId = await repository.createProject(
        ownerId: ownerId,
        title: 'Initial Title',
        difficulty: 3,
      );

      await repository.updateProject(
        projectId: projectId,
        ownerId: ownerId,
        title: 'Updated Title',
        description: 'Updated Description',
        difficulty: 5,
        status: 'paused',
        skillIds: {},
      );

      final updated = await db.projectsDao.findById(projectId);
      expect(updated!.title, 'Updated Title');
      expect(updated.description, 'Updated Description');
      expect(updated.difficulty, 5);
      expect(updated.status, 'paused');
    });

    test('Soft deletes project and marks deletedAt', () async {
      final projectId = await repository.createProject(
        ownerId: ownerId,
        title: 'To Be Deleted',
        difficulty: 2,
      );

      await repository.softDeleteProject(projectId, ownerId);

      final direct = await (db.select(
        db.projects,
      )..where((p) => p.id.equals(projectId))).getSingle();
      expect(direct.deletedAt, isNotNull);
    });
  });

  group('3. Dynamic "Assign To" Target Loader', () {
    test('Loads real targets for Life Area, Goal, and Level', () async {
      final lifeAreas = await repository.loadAssignmentTargets(
        ownerId,
        ProjectAssignmentType.lifeArea,
      );
      expect(lifeAreas.any((a) => a.id == 'area_tech'), isTrue);

      final goals = await repository.loadAssignmentTargets(
        ownerId,
        ProjectAssignmentType.goal,
      );
      expect(goals.any((g) => g.id == 'goal_main'), isTrue);
      expect(goals.first.type, ProjectAssignmentType.goal);

      final levels = await repository.loadAssignmentTargets(
        ownerId,
        ProjectAssignmentType.level,
      );
      expect(levels, isNotEmpty);
      expect(levels.first.type, ProjectAssignmentType.level);
    });
  });

  group('4. Roadmap Phases & Progress Calculation Chain', () {
    test(
      'Phases CRUD, ordering, and task-driven progress calculation',
      () async {
        final projectId = await repository.createProject(
          ownerId: ownerId,
          title: 'Autonomous Rover',
          difficulty: 6,
        );

        // Create 2 phases
        final phase1Id = await repository.createPhase(
          ownerId: ownerId,
          projectId: projectId,
          name: 'Phase 1: Hardware Design',
          sortOrder: 1,
        );

        final phase2Id = await repository.createPhase(
          ownerId: ownerId,
          projectId: projectId,
          name: 'Phase 2: Firmware & Navigation',
          sortOrder: 2,
        );

        final phase1 = await db.projectsDao.findPhaseById(phase1Id);
        final phase2 = await db.projectsDao.findPhaseById(phase2Id);
        expect(phase1!.sortOrder, 1);
        expect(phase2!.sortOrder, 2);

        // Add 2 tasks to Phase 1
        final now = DateTime.now().toUtc();
        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                id: 'task_cad_01',
                ownerId: ownerId,
                title: 'Complete CAD Chassis',
                priority: 2,
                sortOrder: 1,
                status: 'active',
                projectId: drift.Value(projectId),
                phaseId: drift.Value(phase1Id),
                versionHlc: '0000000000000-0000-000000000000',
                createdAt: now,
                updatedAt: now,
              ),
            );

        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                id: 'task_cad_02',
                ownerId: ownerId,
                title: 'Order CNC Components',
                priority: 2,
                sortOrder: 2,
                status: 'active',
                projectId: drift.Value(projectId),
                phaseId: drift.Value(phase1Id),
                versionHlc: '0000000000000-0000-000000000000',
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Re-calculate progress: 0 of 2 tasks completed -> Phase 1: 0% -> Project: 0%
        await repository.recalculateProjectProgress(projectId);
        var updatedProj = await db.projectsDao.findById(projectId);
        expect(updatedProj!.progress, 0.0);

        // Complete 1 task in Phase 1 -> 1/2 = 50%
        await db.tasksDao.updateStatus('task_cad_01', 'completed');
        await repository.recalculateProjectProgress(projectId);

        var updatedPhase1 = await db.projectsDao.findPhaseById(phase1Id);
        expect(updatedPhase1!.progress, 50.0);

        // Complete 2nd task in Phase 1 -> 2/2 = 100%, phase completes
        await db.tasksDao.updateStatus('task_cad_02', 'completed');
        await repository.recalculateProjectProgress(projectId);

        updatedPhase1 = await db.projectsDao.findPhaseById(phase1Id);
        expect(updatedPhase1!.progress, 100.0);
        expect(updatedPhase1.status, 'completed');

        // Project has 2 phases: Phase 1 is 100%, Phase 2 is 0% -> Project progress is (100 + 0) / 2 = 50%
        updatedProj = await db.projectsDao.findById(projectId);
        expect(updatedProj!.progress, 50.0);
      },
    );

    test('Progress calculator handles zero division safely', () {
      final emptyProgress = RoadmapProgressCalculator.computeProjectProgress(
        phases: [],
        tasksByPhaseId: {},
        unphasedProjectTasks: [],
      );
      expect(emptyProgress, 0.0);

      final phaseWithoutTasks = RoadmapProgressCalculator.computePhaseProgress(
        phaseTasks: [],
        phaseStatus: 'active',
      );
      expect(phaseWithoutTasks, 0.0);
    });
  });

  group('5. Cross-entity Linking: Activities, Notes, Files, Links', () {
    test('Links activities and stores polymorphic attachments via attachment_links', () async {
      final projectId = await repository.createProject(
        ownerId: ownerId,
        title: 'Core Engine',
        difficulty: 4,
      );

      // Seed an activity
      final now = DateTime.now().toUtc();
      await db
          .into(db.activities)
          .insert(
            ActivitiesCompanion.insert(
              id: 'act_sprint_review',
              ownerId: ownerId,
              name: 'Sprint Architecture Review',
              versionHlc: '0000000000000-0000-000000000000',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Link activity
      await repository.linkActivityToProject('act_sprint_review', projectId);
      final act = await (db.select(
        db.activities,
      )..where((a) => a.id.equals('act_sprint_review'))).getSingle();
      expect(act.projectId, projectId);

      // Attach Note
      final noteId = await repository.addNote(
        ownerId: ownerId,
        projectId: projectId,
        bodyText: 'We adopt event sourcing architecture.',
      );
      expect(noteId, isNotEmpty);

      // Attach External Link
      final linkId = await repository.addExternalLink(
        ownerId: ownerId,
        projectId: projectId,
        url: 'https://github.com/org/repo',
        title: 'Repository URL',
      );
      expect(linkId, isNotEmpty);

      // Attach File
      final fileId = await repository.addFile(
        ownerId: ownerId,
        projectId: projectId,
        filename: 'spec.pdf',
        storageKey: 'projects/spec.pdf',
        sizeBytes: 1048576,
      );
      expect(fileId, isNotEmpty);

      // Attach Idea
      final ideaId = await repository.addIdea(
        ownerId: ownerId,
        projectId: projectId,
        title: 'Neural Engine Optimizer',
        contentJson: '[{"type":"paragraph","content":"Speed up inference"}]',
      );
      expect(ideaId, isNotEmpty);

      // Load Aggregate Details
      final details = await repository.watchProjectWithDetails(projectId).first;
      expect(details, isNotNull);
      expect(details!.activities.length, 1);
      expect(details.notes.length, 1);
      expect(details.links.length, 1);
      expect(details.files.length, 1);
      expect(details.ideas.length, 1);
      expect(details.ideas.first.title, 'Neural Engine Optimizer');

      // Unlink Idea
      await repository.unlinkIdea(projectId: projectId, ideaId: ideaId);
      final detailsAfterUnlink = await repository.getProjectWithDetails(
        projectId,
      );
      expect(detailsAfterUnlink!.ideas.length, 0);
    });
  });

  group('6. Project Completion & XP Ledger Integration', () {
    test('Completing project awards calculated XP into Point Ledger with idempotency', () async {
      final projectId = await repository.createProject(
        ownerId: ownerId,
        title: 'Mission Critical Launch',
        difficulty: 5, // 750 XP
        lifeAreaId: 'area_tech',
      );

      // Complete project
      final xpAwarded = await repository.completeProject(
        projectId: projectId,
        ownerId: ownerId,
      );

      expect(xpAwarded!.totalXp, 975);

      // Verify project row state
      final updated = await db.projectsDao.findById(projectId);
      expect(updated!.status, 'completed');
      expect(updated.progress, 100.0);

      // Verify the separate completion bonus component in the XP Ledger.
      final ledgerEntries =
          await (db.select(db.xpLedger)..where(
                (x) => x.idempotencyKey.equals(
                  'project_completion_bonus_$projectId',
                ),
              ))
              .get();

      expect(ledgerEntries.length, 1);
      final entry = ledgerEntries.first;
      expect(entry.points, 975);
      expect(entry.basePoints, 750);
      expect(entry.bonusPoints, 225);
      expect(entry.sourceType, 'project');
      expect(entry.sourceId, projectId);
      expect(entry.action, 'project_completed');

      // Verify Allocation Lines for Hamilton-Hare apportionment
      final lines = await (db.select(
        db.xpAllocationLines,
      )..where((l) => l.ledgerId.equals(entry.id))).get();

      expect(lines.length, 1);
      expect(lines.first.lifeAreaId, 'area_tech');
      expect(lines.first.allocatedPoints, 975);

      // Idempotency: completing again does NOT double-award XP
      final repeatXp = await repository.completeProject(
        projectId: projectId,
        ownerId: ownerId,
      );
      expect(repeatXp, isNull);

      final totalLedgerCount =
          await (db.select(db.xpLedger)..where(
                (x) => x.idempotencyKey.equals(
                  'project_completion_bonus_$projectId',
                ),
              ))
              .get();
      expect(totalLedgerCount.length, 1); // Still exactly 1 entry!
    });
  });
}
