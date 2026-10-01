import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/app_shell.dart';
import 'package:kratos_app/app/kratos_visuals.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/levels/presentation/levels_dashboard_screen.dart';
import 'package:kratos_app/features/life_areas/presentation/life_areas_screen.dart';
import 'package:kratos_app/features/profile/presentation/profile_screen.dart';
import 'package:kratos_app/features/projects/presentation/projects_screen.dart';
import 'package:kratos_app/features/settings/presentation/settings_screen.dart';
import 'package:kratos_app/features/skills/presentation/skills_registry_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  const testUserId = 'test_nav_user_001';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.progressionDao.ensureSeeded();

    final now = DateTime.now().toUtc();
    await db.into(db.users).insert(
          UsersCompanion.insert(
            id: testUserId,
            deviceId: 'dev_test',
            displayName: const drift.Value('Kratos Operative'),
            caption: const drift.Value('Relentless focus'),
            avatarUrl: const drift.Value(''),
            timezone: 'UTC',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp(Widget child) {
    return MaterialApp(
      home: HeroMode(
        enabled: false,
        child: child,
      ),
    );
  }

  group('KRATOS Final Navigation Structure — Mobile Tests', () {
    testWidgets('Mobile view renders exactly 5 bottom navigation items in order', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildApp(
          AppShell(
            database: db,
            userId: testUserId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bottomNavFinder = find.byType(KratosGlassBottomBar);
      expect(bottomNavFinder, findsOneWidget);

      final bottomNav = tester.widget<KratosGlassBottomBar>(bottomNavFinder);
      expect(bottomNav.items.length, equals(6));
      expect(bottomNav.items[0].label, equals('Home'));
      expect(bottomNav.items[1].label, equals('Tasks'));
      expect(bottomNav.items[2].label, equals('Goals'));
      expect(bottomNav.items[3].label, equals('Activities'));
      expect(bottomNav.items[4].label, equals('Ideas'));
      expect(bottomNav.items[5].label, equals('Stats'));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('Tapping bottom navigation items switches tabs preserving state', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildApp(
          AppShell(
            database: db,
            userId: testUserId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bottomNavFinder = find.byType(KratosGlassBottomBar);
      expect(tester.widget<KratosGlassBottomBar>(bottomNavFinder).currentIndex, equals(0));

      // Tap Tasks (index 1)
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(tester.widget<KratosGlassBottomBar>(bottomNavFinder).currentIndex, equals(1));

      // Tap Goals (index 2)
      await tester.tap(find.text('Goals'));
      await tester.pumpAndSettle();
      expect(tester.widget<KratosGlassBottomBar>(bottomNavFinder).currentIndex, equals(2));

      // Tap Activities (index 3)
      await tester.tap(find.text('Activities'));
      await tester.pumpAndSettle();
      expect(tester.widget<KratosGlassBottomBar>(bottomNavFinder).currentIndex, equals(3));

      // Tap Ideas (index 4)
      await tester.tap(find.text('Ideas'));
      await tester.pumpAndSettle();
      expect(tester.widget<KratosGlassBottomBar>(bottomNavFinder).currentIndex, equals(4));

      // Tap Stats (index 5)
      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();
      expect(tester.widget<KratosGlassBottomBar>(bottomNavFinder).currentIndex, equals(5));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('Mobile drawer contains all 11 items in exact order and NO section headings', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool signedOut = false;

      await tester.pumpWidget(
        buildApp(
          AppShell(
            database: db,
            userId: testUserId,
            onSignOut: () {
              signedOut = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      final menuBtn = find.byIcon(Icons.menu);
      expect(menuBtn, findsOneWidget);
      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      // Check Profile header at top
      expect(find.text('Kratos Operative'), findsAtLeast(1));

      // Verify all 10 remaining items are present
      expect(find.text('Home', skipOffstage: false), findsWidgets);
      expect(find.text('Tasks', skipOffstage: false), findsWidgets);
      expect(find.text('Goals', skipOffstage: false), findsWidgets);
      expect(find.text('Activities', skipOffstage: false), findsWidgets);
      expect(find.text('Idea Capture', skipOffstage: false), findsWidgets);
      expect(find.text('Stats', skipOffstage: false), findsWidgets);
      expect(find.text('Levels', skipOffstage: false), findsWidgets);
      expect(find.text('Life Areas', skipOffstage: false), findsWidgets);
      expect(find.text('Skills', skipOffstage: false), findsWidgets);
      expect(find.text('Projects', skipOffstage: false), findsWidgets);
      expect(find.text('Settings', skipOffstage: false), findsWidgets);
      expect(find.text('Sign Out', skipOffstage: false), findsOneWidget);

      // Verify NO category/section headers exist
      expect(find.text('MAIN NAVIGATION', skipOffstage: false), findsNothing);
      expect(find.text('SYSTEM CONFIGURATION', skipOffstage: false), findsNothing);
      expect(find.text('MANAGEMENT', skipOffstage: false), findsNothing);
      expect(find.text('GROWTH', skipOffstage: false), findsNothing);

      // Tap Sign Out
      await tester.tap(find.text('Sign Out', skipOffstage: false));
      await tester.pumpAndSettle();
      expect(signedOut, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('Tapping non-tab items in drawer pushes their screens', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildApp(
          AppShell(
            database: db,
            userId: testUserId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Open drawer & tap Levels
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Levels'));
      await tester.pumpAndSettle();
      expect(find.byType(LevelsDashboardScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(LevelsDashboardScreen))).pop();
      await tester.pumpAndSettle();

      // 2. Open drawer & tap Life Areas
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Life Areas'));
      await tester.pumpAndSettle();
      expect(find.byType(LifeAreasScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(LifeAreasScreen))).pop();
      await tester.pumpAndSettle();

      // 3. Open drawer & tap Skills
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skills'));
      await tester.pumpAndSettle();
      expect(find.byType(SkillsRegistryScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(SkillsRegistryScreen))).pop();
      await tester.pumpAndSettle();

      // 4. Open drawer & tap Projects
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Projects'));
      await tester.pumpAndSettle();
      expect(find.byType(ProjectsScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(ProjectsScreen))).pop();
      await tester.pumpAndSettle();

      // 5. Open drawer & tap Settings
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
      await tester.pumpAndSettle();

      // 6. Open drawer & tap Profile header
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      final profileLabel = find.descendant(
        of: find.byType(Drawer),
        matching: find.textContaining('Operative', skipOffstage: false),
      ).first;
      await tester.ensureVisible(profileLabel);
      await tester.tap(profileLabel);
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });

  group('KRATOS Final Navigation Structure — Desktop Tests', () {
    testWidgets('Desktop view (width >= 840) shows persistent sidebar and hides bottom nav', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildApp(
          AppShell(
            database: db,
            userId: testUserId,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Bottom nav is hidden on desktop
      expect(find.byType(BottomNavigationBar), findsNothing);

      // Persistent sidebar items are visible on screen
      expect(find.text('Kratos Operative'), findsAtLeast(1));
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Goals'), findsOneWidget);
      expect(find.text('Activities'), findsOneWidget);
      expect(find.text('Idea Capture'), findsOneWidget);
      expect(find.text('Stats'), findsOneWidget);
      expect(find.text('Levels'), findsOneWidget);
      expect(find.text('Life Areas'), findsOneWidget);
      expect(find.text('Skills'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
