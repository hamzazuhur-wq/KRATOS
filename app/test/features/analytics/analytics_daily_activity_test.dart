import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/kratos_theme.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/analytics/data/drift_analytics_repository.dart';
import 'package:kratos_app/features/analytics/domain/analytics_models.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/analytics_daily_activity_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Wave 09: Best Day & Metric Calculations', () {
    test('Best Day calculation selects highest XP day with deterministic tie-breaking', () {
      final monday = DateTime(2026, 10, 5);
      final days = [
        DailyAnalyticsPoint(date: monday, xp: 320, tasksCompleted: 8),
        DailyAnalyticsPoint(date: monday.add(const Duration(days: 1)), xp: 180, tasksCompleted: 5),
        DailyAnalyticsPoint(date: monday.add(const Duration(days: 2)), xp: 260, tasksCompleted: 6),
        DailyAnalyticsPoint(date: monday.add(const Duration(days: 3)), xp: 380, tasksCompleted: 9), // Thursday
        DailyAnalyticsPoint(date: monday.add(const Duration(days: 4)), xp: 220, tasksCompleted: 5),
        DailyAnalyticsPoint(date: monday.add(const Duration(days: 5)), xp: 90, tasksCompleted: 2),
        DailyAnalyticsPoint(date: monday.add(const Duration(days: 6)), xp: 150, tasksCompleted: 4),
      ];

      // Identify best day
      DailyAnalyticsPoint? bestDay;
      var maxDayXp = 0;
      var maxDayTasks = 0;
      for (final d in days) {
        if (d.xp > maxDayXp ||
            (d.xp == maxDayXp && d.tasksCompleted > maxDayTasks && d.xp > 0)) {
          maxDayXp = d.xp;
          maxDayTasks = d.tasksCompleted;
          bestDay = d;
        }
      }

      expect(bestDay, isNotNull);
      expect(bestDay!.date.weekday, DateTime.thursday);
      expect(bestDay.xp, 380);
      expect(bestDay.tasksCompleted, 9);
    });

    test('Tie breaker favors higher tasksCompleted when XP is equal', () {
      final monday = DateTime(2026, 10, 5);
      final days = [
        DailyAnalyticsPoint(date: monday, xp: 300, tasksCompleted: 4),
        DailyAnalyticsPoint(date: monday.add(const Duration(days: 1)), xp: 300, tasksCompleted: 8), // Tuesday ties XP, more tasks
      ];

      DailyAnalyticsPoint? bestDay;
      var maxDayXp = 0;
      var maxDayTasks = 0;
      for (final d in days) {
        if (d.xp > maxDayXp ||
            (d.xp == maxDayXp && d.tasksCompleted > maxDayTasks && d.xp > 0)) {
          maxDayXp = d.xp;
          maxDayTasks = d.tasksCompleted;
          bestDay = d;
        }
      }

      expect(bestDay, isNotNull);
      expect(bestDay!.date.weekday, DateTime.tuesday);
      expect(bestDay.tasksCompleted, 8);
    });

    test('Zero activity period produces null Best Day and 0 deltas without NaN', () {
      final monday = DateTime(2026, 10, 5);
      final days = List.generate(7, (i) => DailyAnalyticsPoint(
        date: monday.add(Duration(days: i)),
        xp: 0,
        tasksCompleted: 0,
      ));

      DailyAnalyticsPoint? bestDay;
      var maxDayXp = 0;
      var maxDayTasks = 0;
      for (final d in days) {
        if (d.xp > maxDayXp ||
            (d.xp == maxDayXp && d.tasksCompleted > maxDayTasks && d.xp > 0)) {
          maxDayXp = d.xp;
          maxDayTasks = d.tasksCompleted;
          bestDay = d;
        }
      }
      if (maxDayXp == 0 && days.every((d) => d.tasksCompleted == 0)) {
        bestDay = null;
      }

      expect(bestDay, isNull);

      final delta = MetricDelta.compute(current: 0, previous: 0);
      expect(delta.changePct, 0.0);
      expect(delta.isNeutral, true);
      expect(delta.changePct.isNaN, false);
      expect(delta.changePct.isInfinite, false);
    });

    test('Total XP equals exact sum of daily XP values', () {
      final days = [
        DailyAnalyticsPoint(date: DateTime(2026, 10, 5), xp: 320, tasksCompleted: 8),
        DailyAnalyticsPoint(date: DateTime(2026, 10, 6), xp: 180, tasksCompleted: 5),
        DailyAnalyticsPoint(date: DateTime(2026, 10, 7), xp: 260, tasksCompleted: 6),
        DailyAnalyticsPoint(date: DateTime(2026, 10, 8), xp: 380, tasksCompleted: 9),
        DailyAnalyticsPoint(date: DateTime(2026, 10, 9), xp: 220, tasksCompleted: 5),
        DailyAnalyticsPoint(date: DateTime(2026, 10, 10), xp: 90, tasksCompleted: 2),
        DailyAnalyticsPoint(date: DateTime(2026, 10, 11), xp: 150, tasksCompleted: 4),
      ];

      final totalXp = days.fold<int>(0, (sum, d) => sum + d.xp);
      final totalTasks = days.fold<int>(0, (sum, d) => sum + d.tasksCompleted);

      expect(totalXp, 1600);
      expect(totalTasks, 39);
      expect((totalXp / days.length).round(), 229);
    });
  });

  group('DriftAnalyticsRepository Real Data Aggregation', () {
    late AppDatabase db;
    late DriftAnalyticsRepository repository;
    const testUserId = 'usr_daily_test';

    // Monday Oct 5, 2026 00:00:00 Local
    final mondayLocal = DateTime(2026, 10, 5);
    final weekRange = AnalyticsDateRange(
      start: mondayLocal,
      end: mondayLocal.add(const Duration(days: 7)),
      period: AnalyticsPeriod.week,
    );

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = DriftAnalyticsRepository(db);

      // 1. Seed user
      await db.into(db.users).insert(
        UsersCompanion.insert(
          id: testUserId,
          deviceId: 'device_daily_test',
          timezone: 'UTC',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      // 2. Seed Life Areas: Career & Health
      await db.into(db.lifeAreas).insert(
        LifeAreasCompanion.insert(
          id: 'la_career',
          ownerId: testUserId,
          name: 'Career & Mastery',
          sortOrder: 1,
          versionHlc: '0:0:1',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );
      await db.into(db.lifeAreas).insert(
        LifeAreasCompanion.insert(
          id: 'la_health',
          ownerId: testUserId,
          name: 'Health & Vitality',
          sortOrder: 2,
          versionHlc: '0:0:1',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
        ),
      );

      // 3. Seed exact daily XP and tasks across the week
      // Monday: 320 XP, 8 tasks
      // Thursday: 380 XP, 9 tasks
      // Saturday: 90 XP, 2 tasks
      final testDays = [
        (dayOffset: 0, xp: 320, tasks: 8, areaId: 'la_career', source: 'task'),
        (dayOffset: 3, xp: 380, tasks: 9, areaId: 'la_career', source: 'task'),
        (dayOffset: 5, xp: 90, tasks: 2, areaId: 'la_health', source: 'goal'),
      ];

      for (final item in testDays) {
        final dayDate = mondayLocal.add(Duration(days: item.dayOffset));
        // Put event at 14:00 local on that day
        final eventTimeUtc = dayDate.add(const Duration(hours: 14)).toUtc();

        final ledgerId = 'xp_day_${item.dayOffset}';
        await db.into(db.xpLedger).insert(
          XpLedgerCompanion.insert(
            id: ledgerId,
            ownerId: testUserId,
            idempotencyKey: 'idem_$ledgerId',
            sourceType: item.source,
            sourceId: 'src_$ledgerId',
            action: 'completed',
            points: item.xp,
            deviceId: 'dev_daily',
            versionHlc: '0:0:1',
            createdAt: Value(eventTimeUtc),
          ),
        );

        await db.into(db.xpAllocationLines).insert(
          XpAllocationLinesCompanion.insert(
            id: 'alloc_$ledgerId',
            ledgerId: ledgerId,
            lifeAreaId: item.areaId,
            allocatedPoints: item.xp,
            percentage: 1.0,
            versionHlc: '0:0:1',
            createdAt: Value(eventTimeUtc),
          ),
        );

        for (var t = 0; t < item.tasks; t++) {
          final taskId = 'task_${item.dayOffset}_$t';
          await db.into(db.tasks).insert(
            TasksCompanion.insert(
              id: taskId,
              ownerId: testUserId,
              lifeAreaId: Value(item.areaId),
              title: 'Task $taskId',
              status: 'done',
              priority: 1,
              sortOrder: t,
              completedAt: Value(eventTimeUtc),
              versionHlc: '0:0:1',
              createdAt: eventTimeUtc.subtract(const Duration(hours: 1)),
              updatedAt: eventTimeUtc,
            ),
          );
        }
      }
    });

    tearDown(() async => db.close());

    test('aggregates daily XP and tasks from persisted records correctly', () async {
      final snapshot = await repository.load(
        ownerId: testUserId,
        range: weekRange,
      );

      final series = snapshot.dailyGrowthSeries;
      expect(series.length, 7);

      // Monday (dayOffset 0)
      expect(series[0].xp, 320);
      expect(series[0].tasksCompleted, 8);

      // Tuesday (dayOffset 1) -> 0
      expect(series[1].xp, 0);
      expect(series[1].tasksCompleted, 0);

      // Thursday (dayOffset 3)
      expect(series[3].xp, 380);
      expect(series[3].tasksCompleted, 9);

      // Saturday (dayOffset 5)
      expect(series[5].xp, 90);
      expect(series[5].tasksCompleted, 2);

      // Verify total sum
      final totalXp = series.fold<int>(0, (sum, d) => sum + d.xp);
      final totalTasks = series.fold<int>(0, (sum, d) => sum + d.tasksCompleted);
      expect(totalXp, 320 + 380 + 90);
      expect(totalTasks, 8 + 9 + 2);
      expect(snapshot.totalXp, totalXp);
      expect(snapshot.periodCompletedTasks, totalTasks);
    });

    test('Life Area filter isolates daily metrics to specified Life Area', () async {
      // Filter strictly by Health & Vitality (which only has Saturday 90 XP, 2 tasks)
      final snapshot = await repository.load(
        ownerId: testUserId,
        range: weekRange,
        lifeAreaId: 'la_health',
      );

      final series = snapshot.dailyGrowthSeries;
      expect(series[0].xp, 0); // Monday Career XP excluded
      expect(series[0].tasksCompleted, 0); // Monday Career tasks excluded
      expect(series[3].xp, 0); // Thursday Career XP excluded
      expect(series[5].xp, 90); // Saturday Health XP included
      expect(series[5].tasksCompleted, 2); // Saturday Health tasks included
      expect(snapshot.totalXp, 90);
      expect(snapshot.periodCompletedTasks, 2);
    });

    test('Source filter isolates daily XP to specified Source type', () async {
      // Filter strictly by 'goal' (which only Saturday has)
      final snapshot = await repository.load(
        ownerId: testUserId,
        range: weekRange,
        sourceType: 'goal',
      );

      final series = snapshot.dailyGrowthSeries;
      expect(series[0].xp, 0); // Monday task XP excluded
      expect(series[3].xp, 0); // Thursday task XP excluded
      expect(series[5].xp, 90); // Saturday goal XP included
      expect(snapshot.totalXp, 90);
    });

    test('Timezone boundary: 23:30 local event belongs to correct local calendar day', () async {
      // Add an event on Wednesday at 23:30 local time
      final wednesdayNightLocal = DateTime(2026, 10, 7, 23, 30);
      final wednesdayNightUtc = wednesdayNightLocal.toUtc();

      await db.into(db.xpLedger).insert(
        XpLedgerCompanion.insert(
          id: 'xp_wed_night',
          ownerId: testUserId,
          idempotencyKey: 'idem_wed_night',
          sourceType: 'task',
          sourceId: 'src_wed_night',
          action: 'completed',
          points: 150,
          deviceId: 'dev_daily',
          versionHlc: '0:0:1',
          createdAt: Value(wednesdayNightUtc),
        ),
      );

      final snapshot = await repository.load(
        ownerId: testUserId,
        range: weekRange,
      );

      final series = snapshot.dailyGrowthSeries;
      // Wednesday is dayOffset 2
      expect(series[2].xp, 150);
      // Thursday (dayOffset 3) should still have only 380, NOT absorbing Wednesday night
      expect(series[3].xp, 380);
    });
  });

  group('AnalyticsDailyActivityCard Widget Tests', () {
    testWidgets('renders This Week header, chart, best day, and 7 daily cards', (tester) async {
      final monday = DateTime(2026, 10, 5);
      final days = [
        DailyAnalyticsPoint(date: monday, xp: 320, tasksCompleted: 8),
        DailyAnalyticsPoint(date: monday.add(const Duration(days: 1)), xp: 180, tasksCompleted: 5),
        DailyAnalyticsPoint(date: monday.add(const Duration(days: 2)), xp: 260, tasksCompleted: 6),
        DailyAnalyticsPoint(date: monday.add(const Duration(days: 3)), xp: 380, tasksCompleted: 9),
        DailyAnalyticsPoint(date: monday.add(const Duration(days: 4)), xp: 220, tasksCompleted: 5),
        DailyAnalyticsPoint(date: monday.add(const Duration(days: 5)), xp: 90, tasksCompleted: 2),
        DailyAnalyticsPoint(date: monday.add(const Duration(days: 6)), xp: 150, tasksCompleted: 4),
      ];

      final snapshot = AnalyticsSnapshot(
        range: AnalyticsDateRange(start: monday, end: monday.add(const Duration(days: 7)), period: AnalyticsPeriod.week),
        lifeAreaId: null,
        totalXp: 1600,
        previousTotalXp: 1428,
        xpDelta: const MetricDelta(current: 1600, previous: 1428, changePct: 12.0, isPositive: true),
        positiveXp: 1600,
        negativeXp: 0,
        xpVelocityDelta: const MetricDelta(current: 229, previous: 204, changePct: 12.0, isPositive: true),
        completionRateDelta: const MetricDelta(current: 85, previous: 72, changePct: 18.0, isPositive: true),
        consistencyDelta: const MetricDelta(current: 90, previous: 80, changePct: 12.5, isPositive: true),
        activeGoals: 3,
        completedGoals: 2,
        activeProjects: 2,
        completedProjects: 1,
        activeTasks: 12,
        completedTasks: 39,
        periodCompletedTasks: 39,
        previousCompletedTasks: 33,
        activitiesStarted: 42,
        sessionsCompleted: 24,
        actualMinutes: 980,
        currentStreak: 7,
        longestStreak: 18,
        xpOverTime: const [],
        dailyGrowthSeries: days,
        xpBySource: const {},
        lifeAreas: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsDailyActivityCard(
                snapshot: snapshot,
                periodSubtitle: 'vs previous week',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.text('This Week'), findsWidgets);
      expect(find.text('Your daily activity and XP progress. See how consistent you are across the week.'), findsOneWidget);

      // Best Day
      expect(find.text('Best Day'), findsWidgets);
      expect(find.text('Thursday'), findsWidgets);
      expect(find.textContaining('380 XP'), findsWidgets);
      expect(find.textContaining('9 tasks'), findsWidgets);

      // 3 Stat Cards
      expect(find.text('Total XP'), findsOneWidget);
      expect(find.text('1,600'), findsOneWidget);
      expect(find.text('Tasks Completed'), findsWidgets);
      expect(find.text('39'), findsOneWidget);
      expect(find.text('Avg. per Day'), findsOneWidget);
      expect(find.text('229 XP'), findsOneWidget);

      // Daily cards (Mon through Sun)
      expect(find.text('Mon'), findsWidgets);
      expect(find.text('Tue'), findsWidgets);
      expect(find.text('Wed'), findsWidgets);
      expect(find.text('Thu'), findsWidgets);
      expect(find.text('Fri'), findsWidgets);
      expect(find.text('Sat'), findsWidgets);
      expect(find.text('Sun'), findsWidgets);
    });

    testWidgets('renders zero activity clean empty state without crashing', (tester) async {
      final monday = DateTime(2026, 10, 5);
      final days = List.generate(7, (i) => DailyAnalyticsPoint(
        date: monday.add(Duration(days: i)),
        xp: 0,
        tasksCompleted: 0,
      ));

      final emptySnapshot = AnalyticsSnapshot(
        range: AnalyticsDateRange(start: monday, end: monday.add(const Duration(days: 7)), period: AnalyticsPeriod.week),
        lifeAreaId: null,
        totalXp: 0,
        previousTotalXp: 0,
        xpDelta: const MetricDelta(current: 0, previous: 0, changePct: 0, isPositive: true, isNeutral: true),
        positiveXp: 0,
        negativeXp: 0,
        xpVelocityDelta: const MetricDelta(current: 0, previous: 0, changePct: 0, isPositive: true, isNeutral: true),
        completionRateDelta: const MetricDelta(current: 0, previous: 0, changePct: 0, isPositive: true, isNeutral: true),
        consistencyDelta: const MetricDelta(current: 0, previous: 0, changePct: 0, isPositive: true, isNeutral: true),
        activeGoals: 0,
        completedGoals: 0,
        activeProjects: 0,
        completedProjects: 0,
        activeTasks: 0,
        completedTasks: 0,
        periodCompletedTasks: 0,
        previousCompletedTasks: 0,
        activitiesStarted: 0,
        sessionsCompleted: 0,
        actualMinutes: 0,
        currentStreak: 0,
        longestStreak: 0,
        xpOverTime: const [],
        dailyGrowthSeries: days,
        xpBySource: const {},
        lifeAreas: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsDailyActivityCard(
                snapshot: emptySnapshot,
                periodSubtitle: 'vs previous week',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No peak day
      expect(find.text('No Peak Day'), findsOneWidget);
      expect(find.text('0 XP  •  0 tasks'), findsOneWidget);

      // Totals
      expect(find.text('0'), findsWidgets);
      expect(find.text('0 XP'), findsWidgets);
    });
  });
}
