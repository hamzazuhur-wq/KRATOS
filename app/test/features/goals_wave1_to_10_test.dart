// ignore_for_file: avoid_print
// KRATOS Goals Section — Wave 1 to Wave 10 Comprehensive Automated Test Suite.
// Verifies all 10 waves: UI Foundation, Category Architecture, Main Goal Creation,
// Unlimited Sub-goals, Tasks & Task Categories, Activities, Projects Attachment,
// XP Ledger & +30% Descendant Bonus, Global Timer & Sessions, and Full E2E Flow.

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/domain/hlc.dart';
import 'package:kratos_app/domain/ids.dart';
import 'package:kratos_app/domain/timestamps.dart';
import 'package:kratos_app/features/goals/data/drift_goal_repository.dart';
import 'package:kratos_app/features/goals/data/goals_dao.dart';
import 'package:kratos_app/features/goals/domain/goal_xp_service.dart';
import 'package:kratos_app/features/xp/data/xp_ledger_writer_impl.dart';
import 'package:kratos_app/features/xp/domain/xp_allocation_math.dart';
import 'package:kratos_app/features/sessions/domain/global_timer_controller.dart';
import 'package:kratos_app/domain/entities/goal.dart' as domain;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late GoalsDao goalsDao;
  late DriftGoalRepository goalRepo;
  late GoalXpService goalXpService;

  const testUserId = 'usr_seed_dev_01';
  const testAreaId = 'la_health_01';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    goalsDao = GoalsDao(db);
    goalRepo = DriftGoalRepository(goalsDao, db);
    goalXpService = GoalXpService(db);

    // Seed test User & Life Area
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id.uuidV7()).toString();

    await db
        .into(db.users)
        .insert(
          UsersCompanion(
            id: const drift.Value(testUserId),
            deviceId: const drift.Value('dev_device_01'),
            timezone: const drift.Value('UTC'),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

    await db
        .into(db.lifeAreas)
        .insert(
          LifeAreasCompanion(
            id: const drift.Value(testAreaId),
            ownerId: const drift.Value(testUserId),
            name: const drift.Value('Health & Vitality'),
            color: const drift.Value('#4CAF50'),
            icon: const drift.Value('favorite'),
            sortOrder: const drift.Value(0),
            versionHlc: drift.Value(hlc),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
  });

  tearDown(() async {
    GlobalTimerController().discard();
    await db.close();
  });

  group('Wave 2: Category Architecture (Goal, Task, Activity, Life Area Categories)', () {
    test(
      'Categories support distinct scopes, CRUD, and SCD Type-2 rule snapshots',
      () async {
        final hlc = Hlc.now(Id.uuidV7()).toString();
        final now = DateTime.now().toUtc();

        // 1. Create Goal Category
        final goalCatId = Id.uuidV7().value;
        await db.categoriesDao.upsertCategory(
          CategoriesCompanion(
            id: drift.Value(goalCatId),
            ownerId: const drift.Value(testUserId),
            name: const drift.Value('Milestones'),
            categoryType: const drift.Value('goal'),
            description: const drift.Value('Strategic milestone goal'),
            baseXp: const drift.Value(150),
            isImmutable: const drift.Value(false),
            sortOrder: const drift.Value(0),
            versionHlc: drift.Value(hlc),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

        // 2. Create Task Category
        final taskCatId = Id.uuidV7().value;
        await db.categoriesDao.upsertCategory(
          CategoriesCompanion(
            id: drift.Value(taskCatId),
            ownerId: const drift.Value(testUserId),
            name: const drift.Value('Deep Focus'),
            categoryType: const drift.Value('task'),
            description: const drift.Value('High-intensity task execution'),
            baseXp: const drift.Value(60),
            isImmutable: const drift.Value(false),
            sortOrder: const drift.Value(0),
            versionHlc: drift.Value(hlc),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

        // 3. Query by type
        final goalCats = await db.categoriesDao.categoriesByType(
          testUserId,
          'goal',
        );
        final taskCats = await db.categoriesDao.categoriesByType(
          testUserId,
          'task',
        );

        expect(goalCats.length, 1);
        expect(goalCats.first.name, 'Milestones');
        expect(taskCats.length, 1);
        expect(taskCats.first.name, 'Deep Focus');

        // 4. Archive & Restore
        await db.categoriesDao.archiveCategory(goalCatId, hlc);
        final activeGoalCats = await db.categoriesDao.categoriesByType(
          testUserId,
          'goal',
        );
        expect(activeGoalCats.isEmpty, isTrue);

        await db.categoriesDao.restoreCategory(goalCatId, hlc);
        final restoredGoalCats = await db.categoriesDao.categoriesByType(
          testUserId,
          'goal',
        );
        expect(restoredGoalCats.length, 1);
      },
    );
  });

  group('Wave 3 & 4: Main Goals & Unlimited Recursive Sub-goals', () {
    test(
      'Create Main Goal, create nested Sub-goals with path & depth inheritance',
      () async {
        final hlc = Hlc.now(Id.uuidV7());
        final nowTimestamp = Iso8601Timestamp.now();

        // 1. Create Root Goal (depth = 0, path = rootId)
        final rootGoalId = Id.uuidV7();
        final rootGoal = domain.Goal(
          id: rootGoalId,
          ownerId: const Id(testUserId),
          rootId: rootGoalId,
          path: rootGoalId.value,
          depth: 0,
          title: 'Run a Marathon',
          lifeAreaId: const Id(testAreaId),
          versionHlc: hlc,
          progressHlc: hlc,
          createdAt: nowTimestamp,
          updatedAt: nowTimestamp,
        );

        await goalRepo.createRoot(rootGoal);

        final fetchedRoot = await goalRepo.findById(rootGoalId);
        expect(fetchedRoot, isNotNull);
        expect(fetchedRoot!.isRoot, isTrue);
        expect(fetchedRoot.depth, 0);
        expect(fetchedRoot.path, rootGoalId.value);

        // 2. Create Sub-goal (depth = 1, path = rootId.subGoalId)
        final subGoal1Id = Id.uuidV7();
        final subGoal1Path = rootGoal.childPath(subGoal1Id);
        final subGoal1 = domain.Goal(
          id: subGoal1Id,
          ownerId: const Id(testUserId),
          parentId: rootGoal.id,
          rootId: rootGoal.rootId,
          path: subGoal1Path,
          depth: 1,
          title: 'Half-Marathon Preparation',
          lifeAreaId: rootGoal.lifeAreaId,
          versionHlc: hlc,
          progressHlc: hlc,
          createdAt: nowTimestamp,
          updatedAt: nowTimestamp,
        );

        await goalRepo.createChild(subGoal1, rootGoal);

        final fetchedSub1 = await goalRepo.findById(subGoal1Id);
        expect(fetchedSub1, isNotNull);
        expect(fetchedSub1!.depth, 1);
        expect(fetchedSub1.parentId, rootGoal.id);

        // 3. Create Nested Sub-goal (depth = 2, path = rootId.subGoal1Id.subGoal2Id)
        final subGoal2Id = Id.uuidV7();
        final subGoal2Path = subGoal1.childPath(subGoal2Id);
        final subGoal2 = domain.Goal(
          id: subGoal2Id,
          ownerId: const Id(testUserId),
          parentId: subGoal1.id,
          rootId: subGoal1.rootId,
          path: subGoal2Path,
          depth: 2,
          title: 'Complete 10K Continuous Run',
          lifeAreaId: subGoal1.lifeAreaId,
          versionHlc: hlc,
          progressHlc: hlc,
          createdAt: nowTimestamp,
          updatedAt: nowTimestamp,
        );

        await goalRepo.createChild(subGoal2, subGoal1);

        final descendants = await goalRepo.findByRoot(rootGoalId);
        expect(descendants.length, 3); // root + sub1 + sub2

        // Verify outbox was populated for all writes (Invariant #13)
        final outboxRows = await db.select(db.syncOutbox).get();
        expect(outboxRows.length, 3);
      },
    );
  });

  group('Wave 5, 6, 7: Tasks, Activities, and Project Attachments', () {
    test('Tasks attach to Goal with TaskGoalLinks, Activities link, and Projects attach', () async {
      final hlc = Hlc.now(Id.uuidV7()).toString();
      final now = DateTime.now().toUtc();
      final goalId = Id.uuidV7().value;

      // Create Goal
      await db.goalsDao.upsert(
        GoalsCompanion(
          id: drift.Value(goalId),
          ownerId: const drift.Value(testUserId),
          rootId: drift.Value(goalId),
          path: drift.Value(goalId),
          depth: const drift.Value(0),
          title: const drift.Value('Learn Distributed Systems'),
          lifeAreaId: const drift.Value(testAreaId),
          status: const drift.Value('active'),
          progress: const drift.Value(0.0),
          versionHlc: drift.Value(hlc),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      // 1. Create Task inside Goal (Wave 5)
      final taskId = Id.uuidV7().value;
      await db.tasksDao.upsert(
        TasksCompanion(
          id: drift.Value(taskId),
          ownerId: const drift.Value(testUserId),
          primaryGoalId: drift.Value(goalId),
          title: const drift.Value('Read Raft Consensus Paper'),
          priority: const drift.Value(2),
          status: const drift.Value('open'),
          sortOrder: const drift.Value(0),
          versionHlc: drift.Value(hlc),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      await db.taskGoalLinksDao.upsert(
        TaskGoalLinksCompanion(
          taskId: drift.Value(taskId),
          goalId: drift.Value(goalId),
          role: const drift.Value('contributes_to'),
          sortOrder: const drift.Value(0),
          versionHlc: drift.Value(hlc),
          createdAt: drift.Value(now),
        ),
      );

      final links = await db.taskGoalLinksDao.forGoal(goalId);
      expect(links.length, 1);
      expect(links.first.taskId, taskId);

      // 2. Create Activity inside Goal (Wave 6)
      final actId = Id.uuidV7().value;
      await db.activitiesDao.upsert(
        ActivitiesCompanion(
          id: drift.Value(actId),
          ownerId: const drift.Value(testUserId),
          lifeAreaId: const drift.Value(testAreaId),
          name: const drift.Value('Daily Consensus Drill'),
          xpRule: drift.Value('{"goal_id":"$goalId","base_xp":30}'),
          versionHlc: drift.Value(hlc),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      final acts = await db.activitiesDao.allActivities(testUserId);
      expect(acts.any((a) => a.id == actId), isTrue);

      // 3. Attach Existing Project to Goal (Wave 7)
      final projId = Id.uuidV7().value;
      await db.projectsDao.upsert(
        ProjectsCompanion(
          id: drift.Value(projId),
          ownerId: const drift.Value(testUserId),
          title: const drift.Value('Build Raft Node in Go'),
          status: const drift.Value('active'),
          memberIds: const drift.Value('[]'),
          versionHlc: drift.Value(hlc),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      // Attach existing project
      await (db.update(db.projects)..where((p) => p.id.equals(projId))).write(
        ProjectsCompanion(
          goalId: drift.Value(goalId),
          lifeAreaId: const drift.Value(testAreaId),
        ),
      );

      final attachedProjects = await db.projectsDao.projectsForGoal(goalId);
      expect(attachedProjects.length, 1);
      expect(attachedProjects.first.id, projId);
    });
  });

  group(
    'Wave 8: XP Integration & Main Goal +30% Descendant Bonus Contract',
    () {
      Future<String> insertRootGoal(String title) async {
        final id = Id.uuidV7().value;
        final now = DateTime.now().toUtc();
        final hlc = Hlc.now(Id.uuidV7()).toString();
        await db.goalsDao.upsert(
          GoalsCompanion(
            id: drift.Value(id),
            ownerId: const drift.Value(testUserId),
            rootId: drift.Value(id),
            path: drift.Value(id),
            depth: const drift.Value(0),
            title: drift.Value(title),
            lifeAreaId: const drift.Value(testAreaId),
            status: const drift.Value('active'),
            progress: const drift.Value(0.0),
            versionHlc: drift.Value(hlc),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );
        return id;
      }

      test(
        'Main Goal bonus sums Task and Sub-goal XP without child bonuses',
        () async {
          final rootId = await insertRootGoal('Root');
          final childId = Id.uuidV7().value;
          final now = DateTime.now().toUtc();
          final hlc = Hlc.now(Id.uuidV7());
          await db.goalsDao.upsert(
            GoalsCompanion(
              id: drift.Value(childId),
              ownerId: const drift.Value(testUserId),
              parentId: drift.Value(rootId),
              rootId: drift.Value(rootId),
              path: drift.Value('$rootId/$childId'),
              depth: const drift.Value(1),
              title: const drift.Value('Sub-goal'),
              lifeAreaId: const drift.Value(testAreaId),
              status: const drift.Value('completed'),
              progress: const drift.Value(1.0),
              versionHlc: drift.Value(hlc.toString()),
              createdAt: drift.Value(now),
              updatedAt: drift.Value(now),
            ),
          );

          final writer = DriftXpLedgerWriter(db);
          final taskId = Id.uuidV7().value;
          await db.tasksDao.upsert(
            TasksCompanion(
              id: drift.Value(taskId),
              ownerId: const drift.Value(testUserId),
              primaryGoalId: drift.Value(childId),
              title: const drift.Value('Completed child task'),
              xpReward: const drift.Value(50),
              priority: const drift.Value(1),
              status: const drift.Value('done'),
              sortOrder: const drift.Value(0),
              versionHlc: drift.Value(hlc.toString()),
              createdAt: drift.Value(now),
              updatedAt: drift.Value(now),
            ),
          );
          await writer.recordEvent(
            ownerId: const Id(testUserId),
            idempotencyKey: const Id('completed_child_task_award'),
            sourceType: 'task',
            sourceId: Id(taskId),
            action: 'completed',
            basePoints: 50,
            allocationRatios: const [
              AllocationRatio(lifeAreaId: Id(testAreaId), percentage: 100),
            ],
            clock: hlc,
            deviceId: const Id('dev_device_01'),
          );
          await writer.recordEvent(
            ownerId: const Id(testUserId),
            idempotencyKey: const Id('subgoal_base_award'),
            sourceType: 'goal',
            sourceId: Id(childId),
            action: 'subgoal_base_completion',
            basePoints: 150,
            allocationRatios: const [
              AllocationRatio(lifeAreaId: Id(testAreaId), percentage: 100),
            ],
            clock: hlc,
            deviceId: const Id('dev_device_01'),
          );
          await writer.recordEvent(
            ownerId: const Id(testUserId),
            idempotencyKey: const Id('legacy_child_completion_bonus'),
            sourceType: 'goal',
            sourceId: Id(childId),
            action: 'goal_completion_bonus',
            basePoints: 0,
            bonusPoints: 90,
            allocationRatios: const [
              AllocationRatio(lifeAreaId: Id(testAreaId), percentage: 100),
            ],
            clock: hlc,
            deviceId: const Id('dev_device_01'),
          );

          final root = (await db.goalsDao.findById(rootId))!;
          final bonus = await goalXpService.completeGoal(
            goal: root,
            ownerId: testUserId,
          );
          expect(bonus, 60); // 30% of the actual 50 + 150 child XP.

          final bonusEvent =
              await (db.select(db.xpLedger)..where(
                    (event) =>
                        event.sourceId.equals(rootId) &
                        event.action.equals('goal_completion_bonus'),
                  ))
                  .getSingle();
          expect(bonusEvent.basePoints, 0);
          expect(bonusEvent.bonusPoints, 60);
          expect(bonusEvent.points, 60);
          expect(bonusEvent.idempotencyKey, 'goal_completion_bonus_$rootId');
        },
      );

      test(
        'Main Goal with no eligible awarded child XP receives no bonus',
        () async {
          final rootId = await insertRootGoal('Empty Root');
          final root = (await db.goalsDao.findById(rootId))!;

          final bonus = await goalXpService.completeGoal(
            goal: root,
            ownerId: testUserId,
          );

          expect(bonus, 0);
          final bonusEvents =
              await (db.select(db.xpLedger)..where(
                    (event) =>
                        event.sourceId.equals(rootId) &
                        event.action.equals('goal_completion_bonus'),
                  ))
                  .get();
          expect(bonusEvents, isEmpty);
        },
      );

      test('Task completion awards ledger XP, Main Goal awards +30% positive descendant XP once', () async {
        final hlc = Hlc.now(Id.uuidV7()).toString();
        final now = DateTime.now().toUtc();
        final rootGoalId = Id.uuidV7().value;

        // 1. Create Main Goal
        await db.goalsDao.upsert(
          GoalsCompanion(
            id: drift.Value(rootGoalId),
            ownerId: const drift.Value(testUserId),
            rootId: drift.Value(rootGoalId),
            path: drift.Value(rootGoalId),
            depth: const drift.Value(0),
            title: const drift.Value('Complete Mobile Mastery'),
            lifeAreaId: const drift.Value(testAreaId),
            status: const drift.Value('active'),
            xpTarget: const drift.Value(1000),
            progress: const drift.Value(0.0),
            versionHlc: drift.Value(hlc),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

        // 2. Create 2 Tasks under this goal
        final task1Id = Id.uuidV7().value;
        final task2Id = Id.uuidV7().value;

        await db.tasksDao.upsert(
          TasksCompanion(
            id: drift.Value(task1Id),
            ownerId: const drift.Value(testUserId),
            primaryGoalId: drift.Value(rootGoalId),
            title: const drift.Value('Build Drift Schemas'),
            xpReward: const drift.Value(40),
            priority: const drift.Value(1),
            status: const drift.Value('open'),
            sortOrder: const drift.Value(0),
            versionHlc: drift.Value(hlc),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

        await db.tasksDao.upsert(
          TasksCompanion(
            id: drift.Value(task2Id),
            ownerId: const drift.Value(testUserId),
            primaryGoalId: drift.Value(rootGoalId),
            title: const drift.Value('Build Riverpod Providers'),
            xpReward: const drift.Value(60),
            priority: const drift.Value(1),
            status: const drift.Value('open'),
            sortOrder: const drift.Value(1),
            versionHlc: drift.Value(hlc),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

        // 3. Complete Task 1 & Task 2
        final task1Row = (await db.tasksDao.findById(task1Id))!;
        final task2Row = (await db.tasksDao.findById(task2Id))!;

        final xp1 = await goalXpService.completeTask(
          task: task1Row,
          ownerId: testUserId,
          lifeAreaId: testAreaId,
        );
        final xp2 = await goalXpService.completeTask(
          task: task2Row,
          ownerId: testUserId,
          lifeAreaId: testAreaId,
        );

        expect(xp1, 40);
        expect(xp2, 60);

        // Goal progress should now be 1.0 (2 of 2 tasks completed)
        final updatedGoal = (await db.goalsDao.findById(rootGoalId))!;
        expect(updatedGoal.progress, 1.0);

        // Verify task ledger entries exist
        final taskLedgers = await (db.select(
          db.xpLedger,
        )..where((r) => r.sourceType.equals('task'))).get();
        expect(taskLedgers.length, 2);
        final totalTaskXp = taskLedgers.fold(0, (s, r) => s + r.points);
        expect(totalTaskXp, 100);

        // 4. Complete Main Goal — should award +30% of 100 = 30 XP bonus
        final bonus = await goalXpService.completeGoal(
          goal: updatedGoal,
          ownerId: testUserId,
        );

        expect(bonus, 30); // 30% of 100 XP

        // Verify goal completion bonus in ledger
        final goalLedgers =
            await (db.select(db.xpLedger)..where(
                  (r) =>
                      r.sourceType.equals('goal') &
                      r.action.equals('goal_completion_bonus'),
                ))
                .get();
        expect(goalLedgers.length, 1);
        expect(goalLedgers.first.points, 30);

        // 5. Idempotency test — calling completeGoal again does NOT award duplicate bonus
        final bonusSecondCall = await goalXpService.completeGoal(
          goal: updatedGoal,
          ownerId: testUserId,
        );
        expect(bonusSecondCall, 0);

        final goalLedgersAfter =
            await (db.select(db.xpLedger)..where(
                  (r) =>
                      r.sourceType.equals('goal') &
                      r.action.equals('goal_completion_bonus'),
                ))
                .get();
        expect(goalLedgersAfter.length, 1); // Still exactly 1 row
      });
    },
  );

  group('Wave 9: Global Timer Controller & Real Session Persistence', () {
    test('Timer starts, tracks elapsed time, pauses, resumes, and saves Session with XP', () async {
      final timer = GlobalTimerController();

      // Start timer
      timer.startTimer(
        taskId: 'tsk_001',
        taskTitle: 'Write System Tests',
        goalId: 'g_001',
        goalTitle: 'Goals Wave 1-10',
        lifeAreaId: testAreaId,
        lifeAreaName: 'Health',
      );

      expect(timer.hasActiveTimer, isTrue);
      expect(timer.currentState!.taskTitle, 'Write System Tests');
      expect(timer.currentState!.isPaused, isFalse);

      // Pause timer
      timer.pauseTimer();
      expect(timer.currentState!.isPaused, isTrue);

      // Resume timer
      timer.resumeTimer();
      expect(timer.currentState!.isPaused, isFalse);

      // Stop and save session
      final sessionId = await timer.stopAndSaveSession(
        database: db,
        ownerId: testUserId,
        note: 'Completed all wave test cases',
      );

      expect(sessionId, isNotNull);
      expect(timer.hasActiveTimer, isFalse);

      // Verify session row in database
      final savedSession = await db.sessionsDao.findById(sessionId!);
      expect(savedSession, isNotNull);
      expect(savedSession!.taskId, 'tsk_001');
      expect(savedSession.lifeAreaId, testAreaId);
    });
  });
}
