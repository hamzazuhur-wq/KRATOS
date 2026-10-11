import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/domain/ids.dart';
import 'package:kratos_app/features/calendar/presentation/calendar_screen.dart';
import 'package:kratos_app/features/home/data/due_today_repository.dart';
import 'package:kratos_app/features/home/data/home_dashboard_repository.dart';
import 'package:kratos_app/features/home/presentation/due_today_screen.dart';
import 'package:kratos_app/features/home/presentation/home_dashboard_screen.dart';
import 'package:kratos_app/features/levels/data/levels_dashboard_repository.dart';
import 'package:kratos_app/features/levels/presentation/levels_dashboard_screen.dart';
import 'package:kratos_app/features/onboarding/domain/onboarding_service.dart';
import 'package:kratos_app/features/profile/presentation/profile_screen.dart';
import 'package:kratos_app/features/projects/presentation/projects_screen.dart';
import 'package:kratos_app/features/tasks/data/task_dashboard_repository.dart';

/// Regression tests for the "stuck on skeleton" defects.
///
/// Root cause covered: Drift `customSelect().watch()` is not guaranteed to emit
/// an initial snapshot on every executor (notably web). The repositories now
/// yield an explicit first snapshot, and still react to later writes.
Future<T> firstMatching<T>(Stream<T> stream, bool Function(T) test) =>
    stream.firstWhere(test).timeout(const Duration(seconds: 5));

void main() {
  late AppDatabase db;
  late String ownerId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ownerId = Id.uuidV7().value;
    final now = DateTime.now().toUtc();
    await db.into(db.users).insert(UsersCompanion.insert(
          id: ownerId,
          deviceId: 'device_reg_001',
          timezone: 'UTC',
          createdAt: now,
          updatedAt: now,
        ));
  });

  tearDown(() async => db.close());

  Future<void> insertTask(String title, DateTime due) async {
    final now = DateTime.now().toUtc();
    await db.into(db.tasks).insert(TasksCompanion.insert(
          id: Id.uuidV7().value,
          ownerId: ownerId,
          title: title,
          status: 'pending',
          priority: 2,
          sortOrder: 0,
          versionHlc: '1:0:local',
          createdAt: now,
          updatedAt: now,
          dueDate: Value(due),
        ));
  }

  test('Due Today emits an initial snapshot, then reacts to writes', () async {
    final stream = DueTodayRepository(db).watchDueOverview(ownerId);
    final first = await stream.first.timeout(const Duration(seconds: 5));
    expect(first.isEmpty, isTrue);

    final reactive = firstMatching(
      DueTodayRepository(db).watchDueOverview(ownerId),
      (o) => o.overdueCount == 1,
    );
    await insertTask('Missed', DateTime.now().subtract(const Duration(days: 2)));
    expect((await reactive).overdue.single.title, 'Missed');
  });

  test('Tasks emits an initial snapshot, then reacts to writes', () async {
    final repo = TaskDashboardRepository(db);
    Stream<List<TaskDashboardItem>> watch() => repo.watchTasks(
          ownerId: ownerId,
          status: TaskDashboardStatus.active,
          time: TaskDashboardTime.today,
        );

    expect(await watch().first.timeout(const Duration(seconds: 5)), isEmpty);

    final reactive = firstMatching(watch(), (l) => l.length == 1);
    await insertTask('Today task', DateTime.now());
    expect((await reactive).single.title, 'Today task');
  });

  test('Levels emits an initial snapshot, then reacts to writes', () async {
    final repo = LevelsDashboardRepository(db);
    expect(
      await repo.watchProgressions(ownerId).first.timeout(
            const Duration(seconds: 5),
          ),
      isEmpty,
    );

    final reactive = firstMatching(
      repo.watchProgressions(ownerId),
      (l) => l.length == 1,
    );
    final now = DateTime.now().toUtc();
    await db.into(db.lifeAreas).insert(LifeAreasCompanion.insert(
          id: Id.uuidV7().value,
          ownerId: ownerId,
          name: 'Health',
          sortOrder: 0,
          versionHlc: '1:0:local',
          createdAt: now,
          updatedAt: now,
        ));
    expect((await reactive).single.area.name, 'Health');
  });

  testWidgets('Calendar shows a clear error state, not an endless spinner',
      (tester) async {
    // A missing table makes the calendar query throw: loading must end in an
    // error state rather than an endless spinner.
    final broken = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(broken.close);
    await broken.customStatement('DROP TABLE tasks');
    await tester.pumpWidget(MaterialApp(
      home: CalendarScreen(database: broken, ownerId: ownerId),
    ));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Unable to load calendar'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Projects filters apply client-side from one stream',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now().toUtc();
    for (final title in ['Alpha build', 'Beta launch']) {
      await db.into(db.projects).insert(ProjectsCompanion.insert(
            id: Id.uuidV7().value,
            ownerId: ownerId,
            title: title,
            memberIds: '[]',
            status: 'active',
            versionHlc: '1:0:local',
            createdAt: now,
            updatedAt: now,
          ));
    }

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: ProjectsScreen(database: db, ownerId: ownerId),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Alpha build'), findsWidgets);
    expect(find.text('Beta launch'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'alpha');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Alpha build'), findsWidgets);
    expect(find.text('Beta launch'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('LevelsDashboardScreen renders seeded life area progression cards',
      (tester) async {
    final devUserId = 'usr_seed_dev_test_levels';
    await OnboardingService(db).bootstrapDevUser(userId: devUserId);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: LevelsDashboardScreen(database: db, ownerId: devUserId),
    ));
    await tester.pumpAndSettle();

    expect(find.text('LEVELS'), findsWidgets);
    expect(find.text('Health & Vitality'), findsWidgets);
    expect(find.text('Career & Mastery'), findsWidgets);
    expect(find.text('Mindset & Focus'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('DueTodayScreen renders seeded tasks without infinite spinner',
      (tester) async {
    final devUserId = 'usr_seed_dev_test_due';
    await OnboardingService(db).bootstrapDevUser(userId: devUserId);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: DueTodayScreen(database: db, ownerId: devUserId),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Execute Deep Work Protocol'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('ProfileScreen renders seeded profile without loading spinner',
      (tester) async {
    final devUserId = 'usr_seed_dev_test_profile';
    await OnboardingService(db).bootstrapDevUser(userId: devUserId);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: ProfileScreen(database: db, userId: devUserId),
    ));
    await tester.pumpAndSettle();

    expect(find.text('LOADING IDENTITY'), findsNothing);
    expect(find.text('Dev Operative'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('HomeDashboardScreen renders dashboard without permanent skeleton',
      (tester) async {
    final devUserId = 'usr_seed_dev_test_home';
    await OnboardingService(db).bootstrapDevUser(userId: devUserId);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark(),
      home: HomeDashboardScreen(database: db, ownerId: devUserId),
    ));
    await tester.pumpAndSettle();

    // Verify all central dashboard cards visibly render
    expect(find.text('Dev Operative'), findsWidgets);
    expect(find.text('TOTAL XP'), findsWidgets);
    expect(find.text('TASKS'), findsWidgets);
    expect(find.text('GOALS'), findsWidgets);
    expect(find.text('PROJECTS'), findsWidgets);
    expect(find.text('STREAK'), findsWidgets);
    expect(find.text('LIFE AREA LEVELS'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });

  test('HomeDashboardRepository handles recent items safely and promptly', () async {
    final devUserId = 'usr_seed_dev_test_home_repo';
    await OnboardingService(db).bootstrapDevUser(userId: devUserId);

    final repo = HomeDashboardRepository(db);
    final data = await repo.getHomeDashboard(devUserId);

    expect(data.profile.displayName, equals('Dev Operative'));
    expect(data.workSummary.activeTasks, greaterThanOrEqualTo(1));
    expect(data.lifeAreaEntries.length, equals(3));
    expect(data.recentItems, isA<List>());
  });

  test('HomeDashboardRepository survives nonessential query failure without failing dashboard', () async {
    final devUserId = 'usr_seed_dev_test_home_failure';
    await OnboardingService(db).bootstrapDevUser(userId: devUserId);

    // Simulate database error on nonessential table used in _getRecentItems
    await db.customStatement('DROP TABLE activity_events');

    final repo = HomeDashboardRepository(db);
    final data = await repo.getHomeDashboard(devUserId);

    // Core dashboard data resolves intact despite secondary failure
    expect(data.profile.displayName, equals('Dev Operative'));
    expect(data.workSummary.activeTasks, greaterThanOrEqualTo(1));
    expect(data.lifeAreaEntries.length, equals(3));
    expect(data.recentItems, isA<List>());
  });
}
