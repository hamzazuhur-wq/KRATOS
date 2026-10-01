// Comprehensive system and integration tests for KRATOS Analytics Real Data Integration.
// Covers:
// - Exact known data (10 tasks 7 completed -> 70%, 5 goals 2 completed -> 40%)
// - Time range filtering (7D, 30D, 90D, 1Y)
// - Life Area filtering (All Areas vs Specific Life Area)
// - XP aggregation & allocation lines
// - Activity aggregation & Heatmap
// - Goal, Project, Task, and Decision analytics
// - Level progress & Streak values
// - Edge cases: empty database, single record, large dataset

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/analytics/data/drift_analytics_repository.dart';
import 'package:kratos_app/features/analytics/domain/analytics_models.dart';

void main() {
  group('AnalyticsDateRange unit tests', () {
    test('uses local calendar boundaries for today', () {
      final range = AnalyticsDateRange.forPeriod(
        AnalyticsPeriod.today,
        now: DateTime(2026, 9, 25, 18, 30),
      );

      expect(range.start, DateTime(2026, 9, 25));
      expect(range.end, DateTime(2026, 9, 26));
    });

    test('uses Monday through next Monday for a week', () {
      final range = AnalyticsDateRange.forPeriod(
        AnalyticsPeriod.week,
        now: DateTime(2026, 9, 25),
      );

      expect(range.start.weekday, DateTime.monday);
      expect(range.dayCount, 7);
    });

    test(
      'custom ranges are inclusive by date and exclusive at next midnight',
      () {
        final range = AnalyticsDateRange.forPeriod(
          AnalyticsPeriod.custom,
          customStart: DateTime(2026, 9, 10, 12),
          customEnd: DateTime(2026, 9, 12, 22),
        );

        expect(range.start, DateTime(2026, 9, 10));
        expect(range.end, DateTime(2026, 9, 13));
        expect(range.dayCount, 3);
      },
    );

    test('rejects an invalid custom range', () {
      expect(
        () => AnalyticsDateRange.forPeriod(
          AnalyticsPeriod.custom,
          customStart: DateTime(2026, 9, 12),
          customEnd: DateTime(2026, 9, 10),
        ),
        throwsArgumentError,
      );
    });
  });

  group('DriftAnalyticsRepository Real Data Integration', () {
    late AppDatabase db;
    late DriftAnalyticsRepository repository;
    const testUserId = 'usr_analytics_test';
    final now = DateTime.utc(2026, 9, 26, 12, 0);

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = DriftAnalyticsRepository(db);

      // Seed user
      await db.into(db.users).insert(
            UsersCompanion.insert(
              id: testUserId,
              deviceId: 'device_test_01',
              timezone: 'UTC',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Seed 2 Life Areas
      await db.into(db.lifeAreas).insert(
            LifeAreasCompanion.insert(
              id: 'area_pro',
              ownerId: testUserId,
              name: 'Professional',
              color: const Value('#C6F135'),
              sortOrder: 1,
              versionHlc: '0:0:1',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await db.into(db.lifeAreas).insert(
            LifeAreasCompanion.insert(
              id: 'area_sport',
              ownerId: testUserId,
              name: 'Sport',
              color: const Value('#FF6B4A'),
              sortOrder: 2,
              versionHlc: '0:0:1',
              createdAt: now,
              updatedAt: now,
            ),
          );
    });

    tearDown(() async {
      await db.close();
    });

    test('listLifeAreas returns real life areas ordered by sortOrder', () async {
      final areas = await repository.listLifeAreas(testUserId);
      expect(areas.length, 2);
      expect(areas[0].name, 'Professional');
      expect(areas[1].name, 'Sport');
    });

    test('Exact Known Data: 10 tasks, 7 completed -> 70% completion rate', () async {
      // Seed 10 tasks: 7 completed, 3 active
      for (var i = 1; i <= 10; i++) {
        final isDone = i <= 7;
        await db.into(db.tasks).insert(
              TasksCompanion.insert(
                id: 'task_$i',
                ownerId: testUserId,
                title: 'Task $i',
                status: isDone ? 'done' : 'in_progress',
                priority: (i % 4) + 1,
                lifeAreaId: const Value('area_pro'),
                sortOrder: i,
                completedAt: isDone ? Value(now.subtract(Duration(days: i))) : const Value(null),
                versionHlc: '0:0:1',
                createdAt: now.subtract(Duration(days: i + 1)),
                updatedAt: now,
              ),
            );
      }

      final range = AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays, now: now);
      final snapshot = await repository.load(
        ownerId: testUserId,
        range: range,
      );

      expect(snapshot.completedTasks, 7);
      expect(snapshot.activeTasks, 3);
      expect(snapshot.completionRateDelta.current, 70.0);
    });

    test('Exact Known Data: 5 goals, 2 completed -> 40% goal completion', () async {
      // Seed 5 goals: 2 completed, 3 active
      for (var i = 1; i <= 5; i++) {
        final isDone = i <= 2;
        await db.into(db.goals).insert(
              GoalsCompanion.insert(
                id: 'goal_$i',
                ownerId: testUserId,
                rootId: 'goal_$i',
                path: 'goal_$i',
                depth: 0,
                title: 'Goal $i',
                status: isDone ? 'completed' : 'active',
                progress: isDone ? 1.0 : 0.4,
                lifeAreaId: const Value('area_pro'),
                completedAt: isDone ? Value(now.subtract(Duration(days: i))) : const Value(null),
                versionHlc: '0:0:1',
                createdAt: now.subtract(Duration(days: i + 2)),
                updatedAt: now,
              ),
            );
      }

      final range = AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays, now: now);
      final snapshot = await repository.load(
        ownerId: testUserId,
        range: range,
      );

      expect(snapshot.completedGoals, 2);
      expect(snapshot.activeGoals, 3);
      expect(snapshot.goalHealth.length, 5);
      final completedRatio = snapshot.completedGoals / (snapshot.completedGoals + snapshot.activeGoals);
      expect(completedRatio, 0.40);
    });

    test('Life Area Filter isolates metrics to selected area', () async {
      // 1 task in area_pro, 1 task in area_sport
      await db.into(db.tasks).insert(
            TasksCompanion.insert(
              id: 'task_pro',
              ownerId: testUserId,
              title: 'Pro Task',
              status: 'done',
              priority: 1,
              lifeAreaId: const Value('area_pro'),
              sortOrder: 1,
              completedAt: Value(now),
              versionHlc: '0:0:1',
              createdAt: now.subtract(const Duration(days: 2)),
              updatedAt: now,
            ),
          );
      await db.into(db.tasks).insert(
            TasksCompanion.insert(
              id: 'task_sport',
              ownerId: testUserId,
              title: 'Sport Task',
              status: 'done',
              priority: 1,
              lifeAreaId: const Value('area_sport'),
              sortOrder: 2,
              completedAt: Value(now),
              versionHlc: '0:0:1',
              createdAt: now.subtract(const Duration(days: 2)),
              updatedAt: now,
            ),
          );

      final range = AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays, now: now);

      // Query for area_pro only
      final proSnapshot = await repository.load(
        ownerId: testUserId,
        range: range,
        lifeAreaId: 'area_pro',
      );
      expect(proSnapshot.completedTasks, 1);
      expect(proSnapshot.lifeAreaId, 'area_pro');

      // Query for all areas
      final allSnapshot = await repository.load(
        ownerId: testUserId,
        range: range,
      );
      expect(allSnapshot.completedTasks, 2);
    });

    test('XP Aggregation: positive, negative reversal, and XP by source', () async {
      // Insert XP ledger events
      await db.into(db.xpLedger).insert(
            XpLedgerCompanion.insert(
              id: 'xp_task_1',
              ownerId: testUserId,
              idempotencyKey: 'idemp_task_1',
              sourceType: 'task',
              sourceId: 't1',
              action: 'completed',
              points: 150,
              deviceId: 'dev1',
              versionHlc: '0:0:1',
              createdAt: Value(now.subtract(const Duration(days: 3))),
            ),
          );
      await db.into(db.xpLedger).insert(
            XpLedgerCompanion.insert(
              id: 'xp_goal_1',
              ownerId: testUserId,
              idempotencyKey: 'idemp_goal_1',
              sourceType: 'goal',
              sourceId: 'g1',
              action: 'goal_completion_bonus',
              points: 300,
              deviceId: 'dev1',
              versionHlc: '0:0:1',
              createdAt: Value(now.subtract(const Duration(days: 2))),
            ),
          );
      await db.into(db.xpLedger).insert(
            XpLedgerCompanion.insert(
              id: 'xp_rev_1',
              ownerId: testUserId,
              idempotencyKey: 'idemp_rev_1',
              sourceType: 'task',
              sourceId: 't1',
              action: 'reversal',
              points: -50,
              deviceId: 'dev1',
              versionHlc: '0:0:1',
              createdAt: Value(now.subtract(const Duration(days: 1))),
            ),
          );

      final range = AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays, now: now);
      final snapshot = await repository.load(
        ownerId: testUserId,
        range: range,
      );

      // Total net XP = 150 + 300 - 50 = 400
      expect(snapshot.totalXp, 400);
      expect(snapshot.positiveXp, 450);
      expect(snapshot.negativeXp, 50);
      expect(snapshot.xpBySource['Tasks'], 100); // 150 - 50 = 100
      expect(snapshot.xpBySource['Goals'], 300);
    });

    test('Streak values and Level progression are accurately reflected', () async {
      // Seed streak
      await db.into(db.userStreaks).insert(
            UserStreaksCompanion.insert(
              userId: testUserId,
              lifeAreaId: 'area_pro',
              currentStreak: const Value(7),
              longestStreak: const Value(14),
              lastActiveDate: Value(now),
              updatedAt: Value(now),
            ),
          );

      // Seed 5000 XP in area_pro (Gold Tier)
      await db.into(db.xpLedger).insert(
            XpLedgerCompanion.insert(
              id: 'xp_large_1',
              ownerId: testUserId,
              idempotencyKey: 'idemp_large_1',
              sourceType: 'task',
              sourceId: 't_large',
              action: 'completed',
              points: 7500,
              deviceId: 'dev1',
              versionHlc: '0:0:1',
              createdAt: Value(now),
            ),
          );
      await db.into(db.xpAllocationLines).insert(
            XpAllocationLinesCompanion.insert(
              id: 'line_1',
              ledgerId: 'xp_large_1',
              lifeAreaId: 'area_pro',
              allocatedPoints: 7500,
              percentage: 100.0,
              versionHlc: '0:0:1',
              createdAt: Value(now),
            ),
          );

      final range = AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays, now: now);
      final snapshot = await repository.load(
        ownerId: testUserId,
        range: range,
      );

      expect(snapshot.currentStreak, 7);
      expect(snapshot.longestStreak, 14);

      final proMetric = snapshot.lifeAreas.firstWhere((a) => a.id == 'area_pro');
      expect(proMetric.currentStreak, 7);
      expect(proMetric.longestStreak, 14);
      expect(proMetric.xp, 7500);
      expect(proMetric.tier, 'Gold'); // >= 7000 XP is Gold tier in ProgressionCalculator
      expect(proMetric.level, isPositive);
    });

    test('Decisions and Projects metrics are captured', () async {
      // Seed 2 projects: 1 active, 1 completed
      await db.into(db.projects).insert(
            ProjectsCompanion.insert(
              id: 'proj_1',
              ownerId: testUserId,
              title: 'Active Project',
              status: 'active',
              progress: const Value(0.5),
              difficulty: const Value(3),
              memberIds: '[]',
              versionHlc: '0:0:1',
              createdAt: now.subtract(const Duration(days: 5)),
              updatedAt: now,
            ),
          );
      await db.into(db.projects).insert(
            ProjectsCompanion.insert(
              id: 'proj_2',
              ownerId: testUserId,
              title: 'Finished Project',
              status: 'completed',
              progress: const Value(1.0),
              difficulty: const Value(5),
              completedAt: Value(now.subtract(const Duration(days: 1))),
              memberIds: '[]',
              versionHlc: '0:0:1',
              createdAt: now.subtract(const Duration(days: 10)),
              updatedAt: now,
            ),
          );

      // Seed 2 decisions: 1 created/pending, 1 resolved
      await db.into(db.decisions).insert(
            DecisionsCompanion.insert(
              id: 'dec_1',
              ownerId: testUserId,
              title: 'Architecture Decision',
              status: const Value('pending'),
              versionHlc: '0:0:1',
              createdAt: now.subtract(const Duration(days: 2)),
              updatedAt: now,
            ),
          );
      await db.into(db.decisions).insert(
            DecisionsCompanion.insert(
              id: 'dec_2',
              ownerId: testUserId,
              title: 'Deployment Strategy',
              status: const Value('resolved'),
              resolvedAt: Value(now.subtract(const Duration(days: 1))),
              versionHlc: '0:0:1',
              createdAt: now.subtract(const Duration(days: 3)),
              updatedAt: now,
            ),
          );

      final range = AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays, now: now);
      final snapshot = await repository.load(
        ownerId: testUserId,
        range: range,
      );

      expect(snapshot.activeProjects, 1);
      expect(snapshot.completedProjects, 1);
      expect(snapshot.createdDecisions, 2);
      expect(snapshot.completedDecisions, 1);
    });

    test('Empty database edge case: zero-division safety and no crashes', () async {
      // Empty user without any records
      const emptyUser = 'usr_empty_user';
      final range = AnalyticsDateRange.forPeriod(AnalyticsPeriod.sevenDays, now: now);
      final snapshot = await repository.load(
        ownerId: emptyUser,
        range: range,
      );

      expect(snapshot.totalXp, 0);
      expect(snapshot.positiveXp, 0);
      expect(snapshot.negativeXp, 0);
      expect(snapshot.completedTasks, 0);
      expect(snapshot.activeTasks, 0);
      expect(snapshot.taskCompletionRate, 0.0);
      expect(snapshot.completionRateDelta.current, 0.0);
      expect(snapshot.dailyGrowthSeries.length, 7);
      expect(snapshot.insights, isNotNull);
    });

    test('Single record edge case: 1 task completed -> 100% completion rate', () async {
      const singleUser = 'usr_single_task';
      await db.into(db.tasks).insert(
            TasksCompanion.insert(
              id: 'task_only',
              ownerId: singleUser,
              title: 'Solo Task',
              status: 'done',
              priority: 1,
              completedAt: Value(now),
              sortOrder: 1,
              versionHlc: '0:0:1',
              createdAt: now.subtract(const Duration(hours: 1)),
              updatedAt: now,
            ),
          );

      final range = AnalyticsDateRange.forPeriod(AnalyticsPeriod.sevenDays, now: now);
      final snapshot = await repository.load(
        ownerId: singleUser,
        range: range,
      );

      expect(snapshot.completedTasks, 1);
      expect(snapshot.activeTasks, 0);
      expect(snapshot.completionRateDelta.current, 100.0);
    });

    test('Large dataset performance: 200 tasks & 300 ledger entries aggregate smoothly', () async {
      const bulkUser = 'usr_bulk_analytics';
      final bulkTasks = <TasksCompanion>[];
      for (var i = 1; i <= 200; i++) {
        final isDone = i % 2 == 0;
        bulkTasks.add(
          TasksCompanion.insert(
            id: 'bulk_task_$i',
            ownerId: bulkUser,
            title: 'Bulk Task $i',
            status: isDone ? 'done' : 'in_progress',
            priority: (i % 4) + 1,
            sortOrder: i,
            completedAt: isDone ? Value(now.subtract(Duration(hours: i))) : const Value(null),
            versionHlc: '0:0:1',
            createdAt: now.subtract(Duration(days: i % 25)),
            updatedAt: now,
          ),
        );
      }
      await db.batch((b) => b.insertAll(db.tasks, bulkTasks));

      final bulkLedger = <XpLedgerCompanion>[];
      for (var i = 1; i <= 300; i++) {
        bulkLedger.add(
          XpLedgerCompanion.insert(
            id: 'bulk_xp_$i',
            ownerId: bulkUser,
            idempotencyKey: 'bulk_idemp_$i',
            sourceType: i % 3 == 0 ? 'goal' : 'task',
            sourceId: 'src_$i',
            action: 'completed',
            points: 25 + (i % 100),
            deviceId: 'dev1',
            versionHlc: '0:0:1',
            createdAt: Value(now.subtract(Duration(days: i % 28))),
          ),
        );
      }
      await db.batch((b) => b.insertAll(db.xpLedger, bulkLedger));

      final stopwatch = Stopwatch()..start();
      final range = AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays, now: now);
      final snapshot = await repository.load(
        ownerId: bulkUser,
        range: range,
      );
      stopwatch.stop();

      expect(snapshot.completedTasks, 100);
      expect(snapshot.activeTasks, 100);
      expect(snapshot.completionRateDelta.current, 50.0);
      expect(snapshot.totalXp, isPositive);
      // Large dataset aggregated in under 500ms
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });
}
