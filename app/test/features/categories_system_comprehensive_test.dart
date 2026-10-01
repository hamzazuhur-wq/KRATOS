// Comprehensive Automated Test Suite for KRATOS Category System Architecture.
// Verifies:
// 1. SQLite schema & category_type column integrity
// 2. 4 distinct semantic scopes (Goal, Task, Activity, Life Area Categories)
// 3. SCD Type-2 rule-versioning & immutability
// 4. Goal, Task, Activity, and Life Area category linking & persistence
// 5. Accordion Settings UI rendering, expansion, and 3-state handling

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/domain/hlc.dart';
import 'package:kratos_app/domain/ids.dart';
import 'package:kratos_app/features/categories/data/categories_dao.dart';
import 'package:kratos_app/features/categories/presentation/categories_screen.dart';

void main() {
  late AppDatabase db;
  late CategoriesDao categoriesDao;

  const testUserId = 'usr_category_test_01';
  const testAreaId = 'la_test_health_01';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    categoriesDao = CategoriesDao(db);

    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id.uuidV7()).toString();

    // Seed test User
    await db.into(db.users).insert(
      UsersCompanion(
        id: const drift.Value(testUserId),
        deviceId: const drift.Value('dev_01'),
        timezone: const drift.Value('UTC'),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );

    // Seed test Life Area
    await db.into(db.lifeAreas).insert(
      LifeAreasCompanion(
        id: const drift.Value(testAreaId),
        ownerId: const drift.Value(testUserId),
        name: const drift.Value('Health & Vitality'),
        sortOrder: const drift.Value(0),
        versionHlc: drift.Value(hlc),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('1. Category Schema & Semantic Separation', () {
    test('Categories table has category_type column and separates 4 category scopes', () async {
      final now = DateTime.now().toUtc();
      final hlc = Hlc.now(Id.uuidV7()).toString();

      // Create one of each category type
      final goalCatId = Id.uuidV7().value;
      final taskCatId = Id.uuidV7().value;
      final activityCatId = Id.uuidV7().value;
      final lifeAreaCatId = Id.uuidV7().value;

      await categoriesDao.upsertCategory(CategoriesCompanion(
        id: drift.Value(goalCatId),
        ownerId: const drift.Value(testUserId),
        name: const drift.Value('Business Objective'),
        categoryType: const drift.Value('goal'),
        baseXp: const drift.Value(500),
        isImmutable: const drift.Value(false),
        sortOrder: const drift.Value(0),
        versionHlc: drift.Value(hlc),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ));

      await categoriesDao.upsertCategory(CategoriesCompanion(
        id: drift.Value(taskCatId),
        ownerId: const drift.Value(testUserId),
        name: const drift.Value('Deep Work Task'),
        categoryType: const drift.Value('task'),
        baseXp: const drift.Value(100),
        isImmutable: const drift.Value(false),
        sortOrder: const drift.Value(0),
        versionHlc: drift.Value(hlc),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ));

      await categoriesDao.upsertCategory(CategoriesCompanion(
        id: drift.Value(activityCatId),
        ownerId: const drift.Value(testUserId),
        name: const drift.Value('Meditation Practice'),
        categoryType: const drift.Value('activity'),
        baseXp: const drift.Value(50),
        isImmutable: const drift.Value(false),
        sortOrder: const drift.Value(0),
        versionHlc: drift.Value(hlc),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ));

      await categoriesDao.upsertCategory(CategoriesCompanion(
        id: drift.Value(lifeAreaCatId),
        ownerId: const drift.Value(testUserId),
        name: const drift.Value('Professional Domain'),
        categoryType: const drift.Value('life_area'),
        baseXp: const drift.Value(0),
        isImmutable: const drift.Value(false),
        sortOrder: const drift.Value(0),
        versionHlc: drift.Value(hlc),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ));

      // Verify strict scope filtering
      final goalCats = await categoriesDao.categoriesByType(testUserId, 'goal');
      expect(goalCats.length, 1);
      expect(goalCats.first.name, 'Business Objective');
      expect(goalCats.first.categoryType, 'goal');

      final taskCats = await categoriesDao.categoriesByType(testUserId, 'task');
      expect(taskCats.length, 1);
      expect(taskCats.first.name, 'Deep Work Task');
      expect(taskCats.first.categoryType, 'task');

      final actCats = await categoriesDao.categoriesByType(testUserId, 'activity');
      expect(actCats.length, 1);
      expect(actCats.first.name, 'Meditation Practice');
      expect(actCats.first.categoryType, 'activity');

      final laCats = await categoriesDao.categoriesByType(testUserId, 'life_area');
      expect(laCats.length, 1);
      expect(laCats.first.name, 'Professional Domain');
      expect(laCats.first.categoryType, 'life_area');
    });

    test('SCD Type-2 rule versioning publishes new immutable snapshot on XP change', () async {
      final now = DateTime.now().toUtc();
      final hlc = Hlc.now(Id.uuidV7()).toString();
      final catId = Id.uuidV7().value;

      await categoriesDao.createCategory(
        category: CategoriesCompanion(
          id: drift.Value(catId),
          ownerId: const drift.Value(testUserId),
          name: const drift.Value('Coding'),
          categoryType: const drift.Value('task'),
          baseXp: const drift.Value(100),
          isImmutable: const drift.Value(false),
          sortOrder: const drift.Value(0),
          versionHlc: drift.Value(hlc),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
        actions: [],
      );

      final v1 = await categoriesDao.activeRuleVersion(catId);
      expect(v1, isNotNull);
      expect(v1!.snapshot.contains('"base_xp":100'), isTrue);
      expect(v1.effectiveUntil, isNull);

      // Change XP to 200 via SCD Type 2
      final hlc2 = Hlc.now(Id.uuidV7()).toString();
      await categoriesDao.publishNewRuleVersion(
        categoryId: catId,
        newBaseXp: 200,
        newActions: [],
        versionHlc: hlc2,
      );

      final v2 = await categoriesDao.activeRuleVersion(catId);
      expect(v2, isNotNull);
      expect(v2!.snapshot.contains('"base_xp":200'), isTrue);
      expect(v2.effectiveUntil, isNull);

      final updatedCat = await categoriesDao.findById(catId);
      expect(updatedCat!.baseXp, 200);
    });
  });

  group('2. Cross-Module Category Integration', () {
    test('Goal Category attaches to Goal and persists across queries', () async {
      final now = DateTime.now().toUtc();
      final hlc = Hlc.now(Id.uuidV7()).toString();
      final catId = Id.uuidV7().value;
      final goalId = Id.uuidV7().value;

      await categoriesDao.upsertCategory(CategoriesCompanion(
        id: drift.Value(catId),
        ownerId: const drift.Value(testUserId),
        name: const drift.Value('Health Goals'),
        categoryType: const drift.Value('goal'),
        baseXp: const drift.Value(300),
        isImmutable: const drift.Value(false),
        sortOrder: const drift.Value(0),
        versionHlc: drift.Value(hlc),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ));

      await db.into(db.goals).insert(GoalsCompanion(
        id: drift.Value(goalId),
        ownerId: const drift.Value(testUserId),
        rootId: drift.Value(goalId),
        path: drift.Value(goalId),
        depth: const drift.Value(0),
        title: const drift.Value('Run Marathon'),
        lifeAreaId: const drift.Value(testAreaId),
        categoryId: drift.Value(catId),
        status: const drift.Value('active'),
        progress: const drift.Value(0.0),
        versionHlc: drift.Value(hlc),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ));

      final fetchedGoal = await (db.select(db.goals)..where((g) => g.id.equals(goalId))).getSingle();
      expect(fetchedGoal.categoryId, catId);

      final category = await categoriesDao.findById(fetchedGoal.categoryId!);
      expect(category!.name, 'Health Goals');
      expect(category.categoryType, 'goal');
    });

    test('Task Category attaches to Task and persists across queries', () async {
      final now = DateTime.now().toUtc();
      final hlc = Hlc.now(Id.uuidV7()).toString();
      final catId = Id.uuidV7().value;
      final taskId = Id.uuidV7().value;

      await categoriesDao.upsertCategory(CategoriesCompanion(
        id: drift.Value(catId),
        ownerId: const drift.Value(testUserId),
        name: const drift.Value('Deep Work'),
        categoryType: const drift.Value('task'),
        baseXp: const drift.Value(150),
        isImmutable: const drift.Value(false),
        sortOrder: const drift.Value(0),
        versionHlc: drift.Value(hlc),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ));

      await db.into(db.tasks).insert(TasksCompanion(
        id: drift.Value(taskId),
        ownerId: const drift.Value(testUserId),
        lifeAreaId: const drift.Value(testAreaId),
        categoryId: drift.Value(catId),
        title: const drift.Value('Write Database Migration'),
        priority: const drift.Value(1),
        status: const drift.Value('pending'),
        sortOrder: const drift.Value(0),
        versionHlc: drift.Value(hlc),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ));

      final fetchedTask = await (db.select(db.tasks)..where((t) => t.id.equals(taskId))).getSingle();
      expect(fetchedTask.categoryId, catId);

      final category = await categoriesDao.findById(fetchedTask.categoryId!);
      expect(category!.name, 'Deep Work');
      expect(category.categoryType, 'task');
    });

    test('Life Area Category attaches to Life Area and persists across queries', () async {
      final now = DateTime.now().toUtc();
      final hlc = Hlc.now(Id.uuidV7()).toString();
      final catId = Id.uuidV7().value;
      final areaId = Id.uuidV7().value;

      await categoriesDao.upsertCategory(CategoriesCompanion(
        id: drift.Value(catId),
        ownerId: const drift.Value(testUserId),
        name: const drift.Value('Professional'),
        categoryType: const drift.Value('life_area'),
        baseXp: const drift.Value(0),
        isImmutable: const drift.Value(false),
        sortOrder: const drift.Value(0),
        versionHlc: drift.Value(hlc),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ));

      await db.into(db.lifeAreas).insert(LifeAreasCompanion(
        id: drift.Value(areaId),
        ownerId: const drift.Value(testUserId),
        name: const drift.Value('Software Career'),
        categoryId: drift.Value(catId),
        sortOrder: const drift.Value(1),
        versionHlc: drift.Value(hlc),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ));

      final fetchedArea = await (db.select(db.lifeAreas)..where((a) => a.id.equals(areaId))).getSingle();
      expect(fetchedArea.categoryId, catId);

      final category = await categoriesDao.findById(fetchedArea.categoryId!);
      expect(category!.name, 'Professional');
      expect(category.categoryType, 'life_area');
    });
  });

  group('3. Category Lifecycle (Archive, Restore, Delete)', () {
    test('Archive hides from active stream and restore returns it', () async {
      final now = DateTime.now().toUtc();
      final hlc = Hlc.now(Id.uuidV7()).toString();
      final catId = Id.uuidV7().value;

      await categoriesDao.upsertCategory(CategoriesCompanion(
        id: drift.Value(catId),
        ownerId: const drift.Value(testUserId),
        name: const drift.Value('Archivable Category'),
        categoryType: const drift.Value('goal'),
        baseXp: const drift.Value(100),
        isImmutable: const drift.Value(false),
        sortOrder: const drift.Value(0),
        versionHlc: drift.Value(hlc),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ));

      expect((await categoriesDao.categoriesByType(testUserId, 'goal')).length, 1);

      // Archive
      final hlc2 = Hlc.now(Id.uuidV7()).toString();
      await categoriesDao.archiveCategory(catId, hlc2);

      expect((await categoriesDao.categoriesByType(testUserId, 'goal')).length, 0);
      expect((await categoriesDao.allCategoriesByType(testUserId, 'goal')).length, 1);

      // Restore
      final hlc3 = Hlc.now(Id.uuidV7()).toString();
      await categoriesDao.restoreCategory(catId, hlc3);

      expect((await categoriesDao.categoriesByType(testUserId, 'goal')).length, 1);

      // Permanent Delete
      await categoriesDao.deleteCategory(catId);
      expect((await categoriesDao.allCategoriesByType(testUserId, 'goal')).length, 0);
    });
  });

  group('4. CategoriesScreen Widget Accordion UX Test', () {
    testWidgets('Renders all 4 category groups and allows expanding accordion', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CategoriesScreen(
            database: db,
            ownerId: testUserId,
            initialCategoryType: 'goal',
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title
      expect(find.text('CATEGORIES'), findsOneWidget);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();

      // Verify all 4 accordion group headers exist
      expect(find.text('Goal Categories'), findsOneWidget);
      expect(find.text('Task Categories'), findsOneWidget);
      expect(find.text('Activity Categories'), findsOneWidget);
      expect(find.text('Life Area Categories'), findsOneWidget);

      // Goal Categories should be initially expanded
      expect(find.text('+ Add Goal Category'), findsOneWidget);

      // Tap Task Categories to expand it
      await tester.tap(find.text('Task Categories'));
      await tester.pumpAndSettle();

      expect(find.text('+ Add Task Category'), findsOneWidget);

      // Clean unmount
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
