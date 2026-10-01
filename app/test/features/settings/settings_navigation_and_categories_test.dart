import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/app_shell.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/domain/hlc.dart';
import 'package:kratos_app/domain/ids.dart';
import 'package:kratos_app/features/categories/data/categories_dao.dart';
import 'package:kratos_app/features/categories/presentation/categories_screen.dart';
import 'package:kratos_app/features/settings/presentation/settings_screen.dart';

void main() {
  late AppDatabase db;
  const ownerId = 'test-settings-user-456';
  final nodeId = Id.uuidV7();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.progressionDao.ensureSeeded();
  });

  tearDown(() async {
    await db.close();
  });

  group('Navigation & Settings Architecture', () {
    testWidgets(
      'AppShell drawer renders flat navigation items and no section headers',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: AppShell(database: db, userId: ownerId),
          ),
        );
        await tester.pumpAndSettle();

        // Open Drawer
        final menuButton = find.byIcon(Icons.menu);
        expect(menuButton, findsOneWidget);
        await tester.tap(menuButton);
        await tester.pumpAndSettle();

        // Flat navigation items
        expect(find.text('Home', skipOffstage: false), findsWidgets);
        expect(find.text('Tasks', skipOffstage: false), findsWidgets);
        expect(find.text('Goals', skipOffstage: false), findsWidgets);
        expect(find.text('Activities', skipOffstage: false), findsWidgets);
        expect(find.text('Stats', skipOffstage: false), findsWidgets);
        expect(find.text('Levels', skipOffstage: false), findsWidgets);
        expect(find.text('Life Areas', skipOffstage: false), findsWidgets);
        expect(find.text('Skills', skipOffstage: false), findsWidgets);
        expect(find.text('Projects', skipOffstage: false), findsWidgets);
        expect(find.text('Settings', skipOffstage: false), findsWidgets);

        // Section headers are removed
        expect(find.text('MAIN NAVIGATION', skipOffstage: false), findsNothing);
        expect(
          find.text('SYSTEM CONFIGURATION', skipOffstage: false),
          findsNothing,
        );

        // Verify Levels & Tiers Settings is REMOVED from Settings section
        expect(
          find.text('Levels & Tiers Settings', skipOffstage: false),
          findsNothing,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'SettingsScreen renders configuration sections and does not contain Levels Dashboard',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: SettingsScreen(database: db, ownerId: ownerId),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('SETTINGS', skipOffstage: false), findsOneWidget);
        expect(
          find.text('SYSTEM CONFIGURATION', skipOffstage: false),
          findsOneWidget,
        );
        expect(find.text('XP Engine', skipOffstage: false), findsOneWidget);
        expect(
          find.text('PROGRESSION & RULES', skipOffstage: false),
          findsNothing,
        );
        expect(
          find.text('Progression & Tier Rules', skipOffstage: false),
          findsNothing,
        );
        expect(
          find.text('Database Backup & Restore', skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text('Storage & Trash Recovery', skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text('System Diagnostics', skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.text('Privacy Policy & Data Security', skipOffstage: false),
          findsOneWidget,
        );

        // Verify Levels is NOT a setting item
        expect(
          find.text('Levels Dashboard', skipOffstage: false),
          findsNothing,
        );

        await tester.tap(find.text('XP Engine'));
        await tester.pumpAndSettle();
        expect(find.text('TASK'), findsOneWidget);
        expect(find.text('ACTIVITY'), findsOneWidget);
        expect(find.text('SUB-GOAL'), findsOneWidget);
        expect(find.text('SKILL'), findsOneWidget);
        expect(find.text('Goal Categories'), findsNothing);
        expect(find.textContaining('Add Category'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets('CategoriesScreen displays all 4 expandable category groups', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: CategoriesScreen(database: db, ownerId: ownerId),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CATEGORIES', skipOffstage: false), findsOneWidget);
      expect(
        find.text(
          'Manage the categories used throughout KRATOS.',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      expect(find.text('Goal Categories', skipOffstage: false), findsOneWidget);
      expect(find.text('Task Categories', skipOffstage: false), findsOneWidget);
      expect(
        find.text('Activity Categories', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('Life Area Categories', skipOffstage: false),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });

  group('Category Management & Persistence', () {
    test('CategoriesDao persists, updates, archives, and restores categories per type', () async {
      final categoriesDao = CategoriesDao(db);
      final now = DateTime.now().toUtc();
      final hlc1 = Hlc.now(nodeId).toString();
      final goalCatId = Id.uuidV7().value;

      // 1. Create Goal Category
      await categoriesDao.createCategory(
        category: CategoriesCompanion.insert(
          id: goalCatId,
          ownerId: ownerId,
          name: 'High Impact Business',
          categoryType: const drift.Value('goal'),
          baseXp: 100,
          isImmutable: false,
          sortOrder: 1,
          versionHlc: hlc1,
          createdAt: now,
          updatedAt: now,
        ),
        actions: [],
      );

      var goalCats = await categoriesDao.categoriesByType(ownerId, 'goal');
      expect(goalCats.length, 1);
      expect(goalCats.first.name, 'High Impact Business');

      // 2. Create Task Category
      final taskCatId = Id.uuidV7().value;
      await categoriesDao.createCategory(
        category: CategoriesCompanion.insert(
          id: taskCatId,
          ownerId: ownerId,
          name: 'Deep Code',
          categoryType: const drift.Value('task'),
          baseXp: 40,
          isImmutable: false,
          sortOrder: 1,
          versionHlc: hlc1,
          createdAt: now,
          updatedAt: now,
        ),
        actions: [],
      );

      var taskCats = await categoriesDao.categoriesByType(ownerId, 'task');
      expect(taskCats.length, 1);
      expect(taskCats.first.name, 'Deep Code');

      // Verify separation: task categories do not mix with goal categories
      goalCats = await categoriesDao.categoriesByType(ownerId, 'goal');
      expect(goalCats.length, 1);
      expect(goalCats.first.id, goalCatId);

      // 3. Edit Category
      final hlc2 = Hlc.now(nodeId).toString();
      await categoriesDao.updateCategory(
        categoryId: goalCatId,
        name: 'Enterprise Strategy',
        versionHlc: hlc2,
      );

      goalCats = await categoriesDao.categoriesByType(ownerId, 'goal');
      expect(goalCats.first.name, 'Enterprise Strategy');

      // 4. Archive Category
      final hlc3 = Hlc.now(nodeId).toString();
      await categoriesDao.archiveCategory(goalCatId, hlc3);

      var activeGoalCats = await categoriesDao.categoriesByType(
        ownerId,
        'goal',
      );
      expect(activeGoalCats, isEmpty);

      var allGoalCats = await categoriesDao.allCategoriesByType(
        ownerId,
        'goal',
      );
      expect(allGoalCats.length, 1);
      expect(allGoalCats.first.archivedAt, isNotNull);

      // 5. Restore Category
      final hlc4 = Hlc.now(nodeId).toString();
      await categoriesDao.restoreCategory(goalCatId, hlc4);

      activeGoalCats = await categoriesDao.categoriesByType(ownerId, 'goal');
      expect(activeGoalCats.length, 1);
      expect(activeGoalCats.first.archivedAt, isNull);
    });
  });
}
