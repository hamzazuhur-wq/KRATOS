import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kratos_app/app/app_shell.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/home/data/home_dashboard_repository.dart';
import 'package:kratos_app/features/home/presentation/home_dashboard_screen.dart';
import 'package:kratos_app/features/home/presentation/widgets/ending_today_section.dart';
import 'package:kratos_app/features/home/presentation/widgets/life_area_level_card.dart';
import 'package:kratos_app/features/home/presentation/widgets/quick_actions_row.dart';
import 'package:kratos_app/features/home/presentation/widgets/recent_activity_section.dart';
import 'package:kratos_app/features/home/presentation/widgets/xp_summary_card.dart';
import 'package:kratos_app/features/progression/data/overall_progression_repository.dart';
import 'package:kratos_app/features/streaks/presentation/streak_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  const ownerId = 'home_test_user_001';

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
            displayName: const drift.Value('Hamza Operative'),
            caption: const drift.Value('Build the life you actually want.'),
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

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: HeroMode(enabled: false, child: Material(child: child)),
    );
  }

  group('KRATOS Home Dashboard System Tests', () {
    testWidgets('1. Progression identity & Personal Caption persistence', (
      tester,
    ) async {
      final repo = HomeDashboardRepository(db);
      final initialData = await repo.getHomeDashboard(ownerId);

      expect(initialData.profile.displayName, equals('Hamza Operative'));
      expect(
        initialData.profile.caption,
        equals('Build the life you actually want.'),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          HomeDashboardScreen(database: db, ownerId: ownerId),
        ),
      );
      await tester.pumpAndSettle();

      // Check real name and caption rendered
      expect(find.text('Hamza Operative'), findsOneWidget);
      expect(find.text('Build the life you actually want.'), findsOneWidget);
      final overall = await OverallProgressionRepository(db)
          .getSnapshot(ownerId);
      expect(find.text(overall.progression.tier.toUpperCase()), findsOneWidget);
      expect(find.text('I'), findsWidgets);
      expect(find.text('0 XP'), findsAtLeast(1));
      expect(find.textContaining('Good morning'), findsNothing);
      expect(find.textContaining('Good afternoon'), findsNothing);
      expect(find.textContaining('Good evening'), findsNothing);

      // Verify caption editing via dialog
      await tester.tap(find.text('Build the life you actually want.'));
      await tester.pumpAndSettle();

      expect(find.text('Personal Caption / Sentence'), findsOneWidget);
      final inputFinder = find.byType(TextField);
      await tester.enterText(inputFinder, 'Disciplined execution every day.');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Verify persistence in DB
      final updatedUser = await (db.select(
        db.users,
      )..where((u) => u.id.equals(ownerId))).getSingle();
      expect(updatedUser.caption, equals('Disciplined execution every day.'));

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets(
      '2. Total XP Summary: calculated from real ledger & progression curves',
      (tester) async {
        final now = DateTime.now().toUtc();

        // Insert 2 real Life Areas
        await db
            .into(db.lifeAreas)
            .insert(
              LifeAreasCompanion.insert(
                id: 'la_fitness',
                ownerId: ownerId,
                name: 'Fitness',
                sortOrder: 1,
                versionHlc: '0',
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.lifeAreas)
            .insert(
              LifeAreasCompanion.insert(
                id: 'la_code',
                ownerId: ownerId,
                name: 'Engineering',
                sortOrder: 2,
                versionHlc: '0',
                createdAt: now,
                updatedAt: now,
              ),
            );

        // Insert real XP Ledger events with allocations
        await db
            .into(db.xpLedger)
            .insert(
              XpLedgerCompanion.insert(
                id: 'ledger_01',
                ownerId: ownerId,
                deviceId: 'dev_local',
                sourceType: 'task',
                sourceId: 't1',
                action: 'complete',
                points: 1500,
                idempotencyKey: 'idem_01',
                createdAt: drift.Value(now),
                versionHlc: '0',
              ),
            );
        await db
            .into(db.xpAllocationLines)
            .insert(
              XpAllocationLinesCompanion.insert(
                id: 'alloc_01',
                ledgerId: 'ledger_01',
                lifeAreaId: 'la_fitness',
                allocatedPoints: 1500,
                percentage: 1.0,
                versionHlc: '0',
              ),
            );

        await db
            .into(db.xpLedger)
            .insert(
              XpLedgerCompanion.insert(
                id: 'ledger_02',
                ownerId: ownerId,
                deviceId: 'dev_local',
                sourceType: 'session',
                sourceId: 's1',
                action: 'complete',
                points: 3500,
                idempotencyKey: 'idem_02',
                createdAt: drift.Value(now),
                versionHlc: '0',
              ),
            );
        await db
            .into(db.xpAllocationLines)
            .insert(
              XpAllocationLinesCompanion.insert(
                id: 'alloc_02',
                ledgerId: 'ledger_02',
                lifeAreaId: 'la_code',
                allocatedPoints: 3500,
                percentage: 1.0,
                versionHlc: '0',
              ),
            );

        final repo = HomeDashboardRepository(db);
        final data = await repo.getHomeDashboard(ownerId);

        // Total XP must equal exactly 1500 + 3500 = 5000 XP
        expect(data.aggregateProgression.totalXp, equals(5000));
        expect(
          data.aggregateProgression.maxRangeXp,
          greaterThan(data.aggregateProgression.minRangeXp),
        );
        expect(
          data.aggregateProgression.progressPct,
          greaterThanOrEqualTo(0.0),
        );

        await tester.pumpWidget(
          buildTestableWidget(
            XpSummaryCard(progression: data.aggregateProgression),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('5,000 XP'), findsOneWidget);
        expect(find.text('TOTAL XP'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Quick Actions: exactly 4 actions (no New Project) and real triggers',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(QuickActionsRow(database: db, ownerId: ownerId)),
        );
        await tester.pumpAndSettle();

        expect(find.text('New Task'), findsOneWidget);
        expect(find.text('New Goal'), findsOneWidget);
        expect(find.text('New Activity'), findsOneWidget);
        expect(find.text('Capture'), findsOneWidget);
        expect(find.text('New Project'), findsNothing);

        // Tap Capture -> opens QuickCaptureDialog
        await tester.tap(find.text('Capture'));
        await tester.pumpAndSettle();

        expect(find.text('QUICK CAPTURE'), findsOneWidget);
        expect(find.text('Voice ready'), findsOneWidget);

        FocusManager.instance.primaryFocus?.unfocus();
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      '4. Life Area Levels: Tier Visual System colors and real progress',
      (tester) async {
        // Test tier color mapping tokens
        expect(getTierColor('Wood'), equals(const Color(0xFF8D6E63)));
        expect(getTierColor('Bronze'), equals(const Color(0xFFCD7F32)));
        expect(getTierColor('Silver'), equals(const Color(0xFFC0C0C0)));
        expect(getTierColor('Gold'), equals(const Color(0xFFFFD700)));
        expect(getTierColor('Crystal'), equals(const Color(0xFF00E5FF)));
        expect(getTierColor('Diamond'), equals(const Color(0xFFB9F2FF)));
        expect(getTierColor('Mythic'), equals(const Color(0xFFC6F135)));

        final now = DateTime.now().toUtc();
        await db
            .into(db.lifeAreas)
            .insert(
              LifeAreasCompanion.insert(
                id: 'la_pro',
                ownerId: ownerId,
                name: 'Professional',
                sortOrder: 1,
                versionHlc: '0',
                createdAt: now,
                updatedAt: now,
              ),
            );

        final repo = HomeDashboardRepository(db);
        final data = await repo.getHomeDashboard(ownerId);
        expect(data.lifeAreaEntries.length, equals(1));
        expect(data.lifeAreaEntries.first.area.name, equals('Professional'));

        await tester.pumpWidget(
          buildTestableWidget(
            LifeAreaLevelCard(
              database: db,
              ownerId: ownerId,
              entry: data.lifeAreaEntries.first,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Professional'), findsOneWidget);
        expect(find.text('0 XP'), findsOneWidget);
      },
    );

    testWidgets(
      '5. Ending Today: surfaces only real items due today with alert treatment',
      (tester) async {
        final now = DateTime.now();
        final todayDue = DateTime(now.year, now.month, now.day, 16, 0);
        final tomorrowDue = todayDue.add(const Duration(days: 1));

        // Task 1: Due Today
        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                id: 'task_today',
                ownerId: ownerId,
                title: 'Complete System Migration',
                priority: 2,
                status: 'pending',
                sortOrder: 1,
                versionHlc: '0',
                dueDate: drift.Value(todayDue.toUtc()),
                createdAt: now.toUtc(),
                updatedAt: now.toUtc(),
              ),
            );

        // Task 2: Due Tomorrow (MUST NOT appear in Ending Today)
        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                id: 'task_tomorrow',
                ownerId: ownerId,
                title: 'Future Task',
                priority: 2,
                status: 'pending',
                sortOrder: 2,
                versionHlc: '0',
                dueDate: drift.Value(tomorrowDue.toUtc()),
                createdAt: now.toUtc(),
                updatedAt: now.toUtc(),
              ),
            );

        // Goal: Due Today
        await db
            .into(db.goals)
            .insert(
              GoalsCompanion.insert(
                id: 'goal_today',
                ownerId: ownerId,
                rootId: 'goal_today',
                path: '/goal_today',
                depth: 0,
                title: 'Launch KRATOS V1',
                status: 'in_progress',
                progress: 0.8,
                versionHlc: '0',
                dueDate: drift.Value(todayDue.toUtc()),
                createdAt: now.toUtc(),
                updatedAt: now.toUtc(),
              ),
            );

        final repo = HomeDashboardRepository(db);
        final data = await repo.getHomeDashboard(ownerId);

        expect(data.endingTodayItems.length, equals(2));
        expect(
          data.endingTodayItems.any(
            (i) => i.title == 'Complete System Migration',
          ),
          isTrue,
        );
        expect(
          data.endingTodayItems.any((i) => i.title == 'Launch KRATOS V1'),
          isTrue,
        );
        expect(
          data.endingTodayItems.any((i) => i.title == 'Future Task'),
          isFalse,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            EndingTodaySection(
              database: db,
              ownerId: ownerId,
              items: data.endingTodayItems,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Complete System Migration'), findsOneWidget);
        expect(find.text('Launch KRATOS V1'), findsOneWidget);
        expect(find.text('DUE TODAY'), findsNWidgets(2));
      },
    );

    testWidgets(
      '6. Recent items: sorts across tasks, goals, projects, sessions by timestamp',
      (tester) async {
        final now = DateTime.now().toUtc();

        await db
            .into(db.tasks)
            .insert(
              TasksCompanion.insert(
                id: 'recent_task',
                ownerId: ownerId,
                title: 'Refactor Navigation Engine',
                priority: 2,
                status: 'completed',
                sortOrder: 1,
                versionHlc: '0',
                completedAt: drift.Value(
                  now.subtract(const Duration(minutes: 10)),
                ),
                createdAt: now.subtract(const Duration(hours: 1)),
                updatedAt: now.subtract(const Duration(minutes: 10)),
              ),
            );

        await db
            .into(db.sessions)
            .insert(
              SessionsCompanion.insert(
                id: 'recent_sess',
                ownerId: ownerId,
                startedAt: now.subtract(const Duration(minutes: 30)),
                endedAt: drift.Value(now.subtract(const Duration(minutes: 15))),
                durationMs: const drift.Value(900000), // 15 min
                note: const drift.Value('Deep Focus Coding'),
                versionHlc: '0',
                createdAt: now.subtract(const Duration(minutes: 30)),
                updatedAt: now.subtract(const Duration(minutes: 15)),
              ),
            );

        final repo = HomeDashboardRepository(db);
        final data = await repo.getHomeDashboard(ownerId);

        expect(data.recentItems.length, greaterThanOrEqualTo(2));
        expect(
          data.recentItems.first.title,
          equals('Refactor Navigation Engine'),
        );
        expect(data.recentItems.first.isCompleted, isTrue);

        await tester.pumpWidget(
          buildTestableWidget(
            RecentActivitySection(
              database: db,
              ownerId: ownerId,
              items: data.recentItems,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Refactor Navigation Engine'), findsOneWidget);
        expect(find.text('Deep Focus Coding'), findsOneWidget);
      },
    );

    testWidgets(
      '7. Top Bar Streak control navigates to dedicated StreakScreen',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(AppShell(database: db, userId: ownerId)),
        );
        await tester.pumpAndSettle();

        // Find streak badge in top bar
        final streakFinder = find.text('0 DAYS');
        expect(streakFinder, findsAtLeast(1));

        // Tap streak badge
        await tester.tap(streakFinder.last);
        await tester.pumpAndSettle();

        // Verifies navigation to StreakScreen
        expect(find.byType(StreakScreen), findsOneWidget);
        expect(find.text('STREAK PROTOCOL'), findsOneWidget);
        expect(find.text('STREAK PROTOCOL INVARIANTS'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });
}
