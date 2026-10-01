import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/domain/hlc.dart';
import 'package:kratos_app/domain/ids.dart';
import 'package:kratos_app/features/categories/data/categories_dao.dart';
import 'package:kratos_app/features/xp/data/xp_analytics_dao.dart';

void main() {
  late AppDatabase db;
  const ownerId = 'test-user-life-areas-123';
  final nodeId = Id.uuidV7();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.progressionDao.ensureSeeded();
  });

  tearDown(() async {
    await db.close();
  });

  group('Wave 1 & 2: Life Area Creation & Category Integration', () {
    test('creates Life Area category in Settings and links to new Life Area', () async {
      final categoriesDao = CategoriesDao(db);
      final categoryId = Id.uuidV7().value;
      final now = DateTime.now().toUtc();
      final hlc = Hlc.now(nodeId).toString();

      // 1. Create Life Area Category
      await categoriesDao.createCategory(
        category: CategoriesCompanion.insert(
          id: categoryId,
          ownerId: ownerId,
          name: 'Health & Vitality',
          categoryType: const drift.Value('life_area'),
          baseXp: 50,
          isImmutable: false,
          sortOrder: 1,
          versionHlc: hlc,
          createdAt: now,
          updatedAt: now,
        ),
        actions: [],
      );

      final lifeAreaCategories =
          await categoriesDao.categoriesByType(ownerId, 'life_area');
      expect(lifeAreaCategories.length, 1);
      expect(lifeAreaCategories.first.name, 'Health & Vitality');

      // 2. Create Life Area linked to Category
      final areaId = Id.uuidV7().value;
      await db.into(db.lifeAreas).insert(
            LifeAreasCompanion.insert(
              id: areaId,
              ownerId: ownerId,
              name: 'Physical Fitness',
              description: const drift.Value('Daily workouts and nutrition'),
              categoryId: drift.Value(categoryId),
              color: const drift.Value('#C6F135'),
              icon: const drift.Value('bolt'),
              sortOrder: 0,
              versionHlc: hlc,
              createdAt: now,
              updatedAt: now,
            ),
          );

      final insertedArea = await (db.select(db.lifeAreas)
            ..where((a) => a.id.equals(areaId)))
          .getSingle();

      expect(insertedArea.name, 'Physical Fitness');
      expect(insertedArea.categoryId, categoryId);
      expect(insertedArea.color, '#C6F135');
      expect(insertedArea.icon, 'bolt');
      expect(insertedArea.archivedAt, isNull);
    });
  });

  group('Wave 3, 5 & 6: Persistence, Relationships & Context Inheritance', () {
    test('Life Area maintains real relationships to Goals, Tasks, Projects and Activities', () async {
      final now = DateTime.now().toUtc();
      final hlc = Hlc.now(nodeId).toString();
      final areaId = Id.uuidV7().value;

      // Create Life Area
      await db.into(db.lifeAreas).insert(
            LifeAreasCompanion.insert(
              id: areaId,
              ownerId: ownerId,
              name: 'Deep Engineering',
              description: const drift.Value('Mastering systems architecture'),
              sortOrder: 0,
              versionHlc: hlc,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Create Goal inheriting Life Area
      final goalId = Id.uuidV7().value;
      await db.into(db.goals).insert(
            GoalsCompanion.insert(
              id: goalId,
              ownerId: ownerId,
              rootId: goalId,
              path: '/$goalId',
              depth: 0,
              title: 'Architect Distributed Consensus',
              lifeAreaId: drift.Value(areaId),
              status: 'active',
              progress: 0.0,
              versionHlc: hlc,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Create Task inheriting Life Area and Goal
      final taskId = Id.uuidV7().value;
      await db.into(db.tasks).insert(
            TasksCompanion.insert(
              id: taskId,
              ownerId: ownerId,
              title: 'Implement Paxos Engine',
              lifeAreaId: drift.Value(areaId),
              primaryGoalId: drift.Value(goalId),
              priority: 1,
              status: 'in_progress',
              sortOrder: 0,
              versionHlc: hlc,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Create Project inheriting Life Area
      final projectId = Id.uuidV7().value;
      await db.into(db.projects).insert(
            ProjectsCompanion.insert(
              id: projectId,
              ownerId: ownerId,
              title: 'Storage Engine 2.0',
              lifeAreaId: drift.Value(areaId),
              goalId: drift.Value(goalId),
              status: 'active',
              memberIds: '[]',
              versionHlc: hlc,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Create Activity inheriting Life Area
      final activityId = Id.uuidV7().value;
      await db.into(db.activities).insert(
            ActivitiesCompanion.insert(
              id: activityId,
              ownerId: ownerId,
              name: 'Read Distributed Systems Papers',
              lifeAreaId: drift.Value(areaId),
              versionHlc: hlc,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Verify all query joins
      final linkedGoals = await (db.select(db.goals)
            ..where((g) => g.lifeAreaId.equals(areaId)))
          .get();
      expect(linkedGoals.length, 1);
      expect(linkedGoals.first.id, goalId);

      final linkedTasks = await (db.select(db.tasks)
            ..where((t) => t.lifeAreaId.equals(areaId)))
          .get();
      expect(linkedTasks.length, 1);
      expect(linkedTasks.first.primaryGoalId, goalId);

      final linkedProjects = await (db.select(db.projects)
            ..where((p) => p.lifeAreaId.equals(areaId)))
          .get();
      expect(linkedProjects.length, 1);
      expect(linkedProjects.first.goalId, goalId);

      final linkedActivities = await (db.select(db.activities)
            ..where((a) => a.lifeAreaId.equals(areaId)))
          .get();
      expect(linkedActivities.length, 1);
      expect(linkedActivities.first.id, activityId);
    });
  });

  group('Wave 7: XP, Point Ledger & Progression Integration', () {
    test('XP allocation lines properly aggregate to Life Area and feed progression', () async {
      final now = DateTime.now().toUtc();
      final hlc = Hlc.now(nodeId).toString();
      final areaId = Id.uuidV7().value;

      await db.into(db.lifeAreas).insert(
            LifeAreasCompanion.insert(
              id: areaId,
              ownerId: ownerId,
              name: 'Creative Expression',
              sortOrder: 0,
              versionHlc: hlc,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Insert Ledger Event + Allocation Line for 250 XP
      final ledgerId = Id.uuidV7().value;
      await db.into(db.xpLedger).insert(
            XpLedgerCompanion.insert(
              id: ledgerId,
              ownerId: ownerId,
              idempotencyKey: 'idem-xp-$ledgerId',
              sourceType: 'task',
              sourceId: 'task-123',
              action: 'complete',
              points: 250,
              versionHlc: hlc,
              deviceId: 'device-1',
              createdAt: drift.Value(now),
            ),
          );

      await db.into(db.xpAllocationLines).insert(
            XpAllocationLinesCompanion.insert(
              id: Id.uuidV7().value,
              ledgerId: ledgerId,
              lifeAreaId: areaId,
              allocatedPoints: 250,
              percentage: 1.0,
              versionHlc: hlc,
              createdAt: drift.Value(now),
            ),
          );

      final xpDao = XpAnalyticsDao(db);
      final areaXp = await xpDao.totalXpForLifeArea(areaId);
      expect(areaXp, 250);

      final level = await db.progressionDao.findLevelForXp(areaXp);
      expect(level.level, greaterThanOrEqualTo(1));
    });
  });

  group('Wave 8: Edit, Archive and Restore Lifecycle', () {
    test('Editing and archiving Life Area preserves downstream entities', () async {
      final now = DateTime.now().toUtc();
      final hlc1 = Hlc.now(nodeId).toString();
      final areaId = Id.uuidV7().value;

      // 1. Insert
      await db.into(db.lifeAreas).insert(
            LifeAreasCompanion.insert(
              id: areaId,
              ownerId: ownerId,
              name: 'Original Domain',
              sortOrder: 0,
              versionHlc: hlc1,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Create linked task
      await db.into(db.tasks).insert(
            TasksCompanion.insert(
              id: Id.uuidV7().value,
              ownerId: ownerId,
              title: 'Preserved Task',
              lifeAreaId: drift.Value(areaId),
              priority: 1,
              status: 'open',
              sortOrder: 0,
              versionHlc: hlc1,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 2. Edit
      final hlc2 = Hlc.now(nodeId).toString();
      await (db.update(db.lifeAreas)..where((a) => a.id.equals(areaId))).write(
        LifeAreasCompanion(
          name: const drift.Value('Renamed Domain'),
          description: const drift.Value('Updated description'),
          versionHlc: drift.Value(hlc2),
          updatedAt: drift.Value(DateTime.now().toUtc()),
        ),
      );

      var updatedArea = await (db.select(db.lifeAreas)
            ..where((a) => a.id.equals(areaId)))
          .getSingle();
      expect(updatedArea.name, 'Renamed Domain');
      expect(updatedArea.description, 'Updated description');

      // 3. Archive
      final hlc3 = Hlc.now(nodeId).toString();
      await (db.update(db.lifeAreas)..where((a) => a.id.equals(areaId))).write(
        LifeAreasCompanion(
          archivedAt: drift.Value(DateTime.now().toUtc()),
          versionHlc: drift.Value(hlc3),
          updatedAt: drift.Value(DateTime.now().toUtc()),
        ),
      );

      var archivedArea = await (db.select(db.lifeAreas)
            ..where((a) => a.id.equals(areaId)))
          .getSingle();
      expect(archivedArea.archivedAt, isNotNull);

      // Verify active queries exclude archived
      final activeAreas = await (db.select(db.lifeAreas)
            ..where((a) =>
                a.ownerId.equals(ownerId) &
                a.archivedAt.isNull() &
                a.deletedAt.isNull()))
          .get();
      expect(activeAreas, isEmpty);

      // Downstream task still intact
      final task = await (db.select(db.tasks)
            ..where((t) => t.lifeAreaId.equals(areaId)))
          .getSingle();
      expect(task.title, 'Preserved Task');

      // 4. Restore
      final hlc4 = Hlc.now(nodeId).toString();
      await (db.update(db.lifeAreas)..where((a) => a.id.equals(areaId))).write(
        LifeAreasCompanion(
          archivedAt: const drift.Value(null),
          versionHlc: drift.Value(hlc4),
          updatedAt: drift.Value(DateTime.now().toUtc()),
        ),
      );

      final restoredAreas = await (db.select(db.lifeAreas)
            ..where((a) =>
                a.ownerId.equals(ownerId) &
                a.archivedAt.isNull() &
                a.deletedAt.isNull()))
          .get();
      expect(restoredAreas.length, 1);
      expect(restoredAreas.first.name, 'Renamed Domain');
    });
  });

  group('Wave 9 & 10: Full E2E Life Area Operations', () {
    test('complete multi-entity progression workflow inside Life Area', () async {
      final now = DateTime.now().toUtc();
      final hlc = Hlc.now(nodeId).toString();
      final areaId = Id.uuidV7().value;

      // 1. Create Domain
      await db.into(db.lifeAreas).insert(
            LifeAreasCompanion.insert(
              id: areaId,
              ownerId: ownerId,
              name: 'Executive Mastery',
              sortOrder: 0,
              versionHlc: hlc,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 2. Create Goal
      final goalId = Id.uuidV7().value;
      await db.into(db.goals).insert(
            GoalsCompanion.insert(
              id: goalId,
              ownerId: ownerId,
              rootId: goalId,
              path: '/$goalId',
              depth: 0,
              title: 'Launch Global Initiative',
              lifeAreaId: drift.Value(areaId),
              status: 'active',
              progress: 0.0,
              versionHlc: hlc,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 3. Create Sub-goal
      final subGoalId = Id.uuidV7().value;
      await db.into(db.goals).insert(
            GoalsCompanion.insert(
              id: subGoalId,
              ownerId: ownerId,
              parentId: drift.Value(goalId),
              rootId: goalId,
              path: '/$goalId/$subGoalId',
              depth: 1,
              title: 'Finalize Strategy Document',
              lifeAreaId: drift.Value(areaId),
              status: 'active',
              progress: 0.0,
              versionHlc: hlc,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 4. Create Task and Complete it
      final taskId = Id.uuidV7().value;
      await db.into(db.tasks).insert(
            TasksCompanion.insert(
              id: taskId,
              ownerId: ownerId,
              title: 'Draft Executive Summary',
              lifeAreaId: drift.Value(areaId),
              primaryGoalId: drift.Value(subGoalId),
              priority: 1,
              status: 'completed',
              completedAt: drift.Value(now),
              sortOrder: 0,
              versionHlc: hlc,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 5. Award XP for completed task
      final ledgerId = Id.uuidV7().value;
      await db.into(db.xpLedger).insert(
            XpLedgerCompanion.insert(
              id: ledgerId,
              ownerId: ownerId,
              idempotencyKey: 'idem-exec-$ledgerId',
              sourceType: 'task',
              sourceId: taskId,
              action: 'complete',
              points: 100,
              versionHlc: hlc,
              deviceId: 'device-1',
              createdAt: drift.Value(now),
            ),
          );

      await db.into(db.xpAllocationLines).insert(
            XpAllocationLinesCompanion.insert(
              id: Id.uuidV7().value,
              ledgerId: ledgerId,
              lifeAreaId: areaId,
              allocatedPoints: 100,
              percentage: 1.0,
              versionHlc: hlc,
              createdAt: drift.Value(now),
            ),
          );

      // 6. Verify Dashboard Metrics
      final xpDao = XpAnalyticsDao(db);
      final totalXp = await xpDao.totalXpForLifeArea(areaId);
      expect(totalXp, 100);

      final tasks = await (db.select(db.tasks)
            ..where((t) => t.lifeAreaId.equals(areaId)))
          .get();
      final completedCount =
          tasks.where((t) => t.status == 'completed').length;
      expect(completedCount, 1);

      final topGoals = await (db.select(db.goals)
            ..where((g) => g.lifeAreaId.equals(areaId) & g.parentId.isNull()))
          .get();
      expect(topGoals.length, 1);

      final subGoals = await (db.select(db.goals)
            ..where((g) => g.lifeAreaId.equals(areaId) & g.parentId.isNotNull()))
          .get();
      expect(subGoals.length, 1);
    });
  });
}
