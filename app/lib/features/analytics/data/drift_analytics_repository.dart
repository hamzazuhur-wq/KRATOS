import 'dart:math' as math;

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/ids.dart';
import '../../progression/domain/progression_calculator.dart';
import '../domain/analytics_models.dart';
import 'analytics_repository.dart';

class DriftAnalyticsRepository implements AnalyticsRepository {
  final AppDatabase _db;

  const DriftAnalyticsRepository(this._db);

  @override
  Future<List<({String id, String name})>> listLifeAreas(String ownerId) async {
    final rows = await (_db.select(_db.lifeAreas)
          ..where((a) => a.ownerId.equals(ownerId) & a.deletedAt.isNull())
          ..orderBy([
            (a) => OrderingTerm.asc(a.sortOrder),
            (a) => OrderingTerm.asc(a.name),
          ]))
        .get();

    return rows.map((r) => (id: r.id, name: r.name)).toList();
  }

  @override
  Future<AnalyticsSnapshot> load({
    required String ownerId,
    required AnalyticsDateRange range,
    String? lifeAreaId,
  }) async {
    final startUtc = range.startUtc;
    final endUtc = range.endUtc;
    final prevStartUtc = range.previousRange.startUtc;
    final prevEndUtc = range.previousRange.endUtc;

    // ── 1. Fetch Life Areas metadata ──────────────────────────────────────────
    final allLifeAreas = await (_db.select(_db.lifeAreas)
          ..where((a) => a.ownerId.equals(ownerId) & a.deletedAt.isNull())
          ..orderBy([(a) => OrderingTerm.asc(a.sortOrder)]))
        .get();
    final areaNameMap = {for (final a in allLifeAreas) a.id: a.name};
    final areaColorMap = {
      for (final a in allLifeAreas) a.id: a.color ?? '#C6F135',
    };

    // ── 2. XP Ledger & Allocation Lines ───────────────────────────────────────
    // Current period
    final ledgerQuery = _db.select(_db.xpLedger)
      ..where(
        (e) =>
            e.ownerId.equals(ownerId) &
            e.createdAt.isBiggerOrEqualValue(startUtc) &
            e.createdAt.isSmallerThanValue(endUtc),
      );
    final periodLedgerRows = await ledgerQuery.get();

    // Previous period
    final prevLedgerQuery = _db.select(_db.xpLedger)
      ..where(
        (e) =>
            e.ownerId.equals(ownerId) &
            e.createdAt.isBiggerOrEqualValue(prevStartUtc) &
            e.createdAt.isSmallerThanValue(prevEndUtc),
      );
    final prevLedgerRows = await prevLedgerQuery.get();

    // All-time ledger rows for total historical XP
    final allTimeLedger = await (_db.select(_db.xpLedger)
          ..where((e) => e.ownerId.equals(ownerId)))
        .get();

    // If filtered by life area, resolve allocation lines
    final Map<String, int> allocationByLedgerId = {};
    final Map<String, int> prevAllocationByLedgerId = {};
    final Map<String, int> allTimeAllocationByArea = {};

    final allAllocations = await (_db.select(_db.xpAllocationLines).join([
      innerJoin(
        _db.xpLedger,
        _db.xpLedger.id.equalsExp(_db.xpAllocationLines.ledgerId),
      ),
    ])..where(_db.xpLedger.ownerId.equals(ownerId))).get();

    for (final row in allAllocations) {
      final line = row.readTable(_db.xpAllocationLines);
      final ledger = row.readTable(_db.xpLedger);
      final area = line.lifeAreaId;
      allTimeAllocationByArea[area] =
          (allTimeAllocationByArea[area] ?? 0) + line.allocatedPoints;

      if (lifeAreaId != null && area == lifeAreaId) {
        if (ledger.createdAt.isAfter(startUtc.subtract(const Duration(milliseconds: 1))) &&
            ledger.createdAt.isBefore(endUtc)) {
          allocationByLedgerId[ledger.id] =
              (allocationByLedgerId[ledger.id] ?? 0) + line.allocatedPoints;
        }
        if (ledger.createdAt.isAfter(prevStartUtc.subtract(const Duration(milliseconds: 1))) &&
            ledger.createdAt.isBefore(prevEndUtc)) {
          prevAllocationByLedgerId[ledger.id] =
              (prevAllocationByLedgerId[ledger.id] ?? 0) + line.allocatedPoints;
        }
      }
    }

    int getNetXp(XpLedgerData e) {
      if (lifeAreaId != null) {
        return allocationByLedgerId[e.id] ?? 0;
      }
      return e.points;
    }

    int getPrevNetXp(XpLedgerData e) {
      if (lifeAreaId != null) {
        return prevAllocationByLedgerId[e.id] ?? 0;
      }
      return e.points;
    }

    final currentXpInPeriod =
        periodLedgerRows.fold<int>(0, (sum, e) => sum + getNetXp(e));
    final prevXpInPeriod =
        prevLedgerRows.fold<int>(0, (sum, e) => sum + getPrevNetXp(e));

    final totalCumulativeXp = lifeAreaId != null
        ? (allTimeAllocationByArea[lifeAreaId] ?? 0)
        : allTimeLedger.fold<int>(0, (sum, e) => sum + e.points);

    var positiveXp = 0;
    var negativeXp = 0;
    for (final e in periodLedgerRows) {
      final pts = getNetXp(e);
      if (pts > 0) {
        positiveXp += pts;
      } else {
        negativeXp += pts.abs();
      }
    }

    // ── 3. Tasks ─────────────────────────────────────────────────────────────
    final allTasks = await (_db.select(_db.tasks)
          ..where((t) => t.ownerId.equals(ownerId) & t.deletedAt.isNull()))
        .get();

    final filteredTasks = lifeAreaId == null
        ? allTasks
        : allTasks.where((t) => t.lifeAreaId == lifeAreaId).toList();

    var activeTasks = 0;
    var completedTasks = 0;
    var createdTasks = 0;

    for (final t in filteredTasks) {
      final isDone = t.status == 'done' || t.status == 'completed';
      if (isDone) {
        completedTasks++;
      } else if (t.status != 'cancelled') {
        activeTasks++;
      }

      if (t.createdAt.isAfter(startUtc.subtract(const Duration(milliseconds: 1))) &&
          t.createdAt.isBefore(endUtc)) {
        createdTasks++;
      }
    }

    // ── 4. Goals ─────────────────────────────────────────────────────────────
    final allGoals = await (_db.select(_db.goals)
          ..where((g) => g.ownerId.equals(ownerId) & g.deletedAt.isNull()))
        .get();

    final filteredGoals = lifeAreaId == null
        ? allGoals
        : allGoals.where((g) => g.lifeAreaId == lifeAreaId).toList();

    var activeGoals = 0;
    var completedGoals = 0;
    var createdGoals = 0;

    for (final g in filteredGoals) {
      final isDone = g.status == 'completed';
      if (isDone) {
        completedGoals++;
      } else {
        activeGoals++;
      }

      if (g.createdAt.isAfter(startUtc.subtract(const Duration(milliseconds: 1))) &&
          g.createdAt.isBefore(endUtc)) {
        createdGoals++;
      }
    }

    // ── 5. Projects ──────────────────────────────────────────────────────────
    final allProjects = await (_db.select(_db.projects)
          ..where((p) => p.ownerId.equals(ownerId) & p.deletedAt.isNull()))
        .get();

    final filteredProjects = lifeAreaId == null
        ? allProjects
        : allProjects.where((p) => p.lifeAreaId == lifeAreaId).toList();

    var activeProjects = 0;
    var completedProjects = 0;
    var createdProjects = 0;

    for (final p in filteredProjects) {
      final isDone = p.status == 'completed';
      if (isDone) {
        completedProjects++;
      } else {
        activeProjects++;
      }

      if (p.createdAt.isAfter(startUtc.subtract(const Duration(milliseconds: 1))) &&
          p.createdAt.isBefore(endUtc)) {
        createdProjects++;
      }
    }

    // ── 6. Decisions ─────────────────────────────────────────────────────────
    final allDecisions = await (_db.select(_db.decisions)
          ..where((d) => d.ownerId.equals(ownerId) & d.deletedAt.isNull()))
        .get();

    final filteredDecisions = lifeAreaId == null
        ? allDecisions
        : allDecisions.where((d) => d.lifeAreaId == lifeAreaId).toList();

    var createdDecisions = 0;
    var completedDecisions = 0;

    for (final d in filteredDecisions) {
      if (d.createdAt.isAfter(startUtc.subtract(const Duration(milliseconds: 1))) &&
          d.createdAt.isBefore(endUtc)) {
        createdDecisions++;
      }
      if (d.status == 'resolved' || d.resolvedAt != null) {
        completedDecisions++;
      }
    }

    // ── 7. Sessions ──────────────────────────────────────────────────────────
    final allSessions = await (_db.select(_db.sessions)
          ..where((s) => s.ownerId.equals(ownerId) & s.deletedAt.isNull()))
        .get();

    final filteredSessions = lifeAreaId == null
        ? allSessions
        : allSessions.where((s) => s.lifeAreaId == lifeAreaId).toList();

    var activitiesStarted = 0;
    var sessionsCompleted = 0;
    var actualMinutes = 0;

    for (final s in filteredSessions) {
      if (s.startedAt.isAfter(startUtc.subtract(const Duration(milliseconds: 1))) &&
          s.startedAt.isBefore(endUtc)) {
        activitiesStarted++;
        if (s.endedAt != null) sessionsCompleted++;
        actualMinutes += (s.durationMs ?? 0) ~/ 60000;
      }
    }

    // ── 8. Streaks ───────────────────────────────────────────────────────────
    final allStreaks = await (_db.select(_db.userStreaks)
          ..where((s) => s.userId.equals(ownerId)))
        .get();

    final filteredStreaks = lifeAreaId == null
        ? allStreaks
        : allStreaks.where((s) => s.lifeAreaId == lifeAreaId).toList();

    var currentStreak = 0;
    var longestStreak = 0;
    for (final s in filteredStreaks) {
      if (s.currentStreak > currentStreak) currentStreak = s.currentStreak;
      if (s.longestStreak > longestStreak) longestStreak = s.longestStreak;
    }

    // ── 9. Activity Events ───────────────────────────────────────────────────
    final allActivityEvents = await (_db.select(_db.activityEvents)
          ..where((e) => e.ownerId.equals(ownerId))
          ..orderBy([(e) => OrderingTerm.desc(e.occurredAt)]))
        .get();

    final filteredActivityEvents = lifeAreaId == null
        ? allActivityEvents
        : allActivityEvents.where((e) => e.lifeAreaId == lifeAreaId).toList();

    // ── 10. Daily Series & Heatmap Aggregation ───────────────────────────────
    final daysCount = math.max(1, range.dayCount);
    final dailyGrowthSeries = <DailyAnalyticsPoint>[];
    var runningCumulativeXp = 0;
    final Set<String> activeDaysSet = {};

    final Map<int, int> activityByDayOfWeek = {
      1: 0,
      2: 0,
      3: 0,
      4: 0,
      5: 0,
      6: 0,
      7: 0,
    };
    final Map<String, int> activityByTimeOfDay = {
      'Morning': 0,
      'Afternoon': 0,
      'Evening': 0,
      'Night': 0,
    };

    for (var i = 0; i < daysCount; i++) {
      final dayStart = range.start.add(Duration(days: i));
      final dayEnd = dayStart.add(const Duration(days: 1));
      final dayStartUtc = dayStart.toUtc();
      final dayEndUtc = dayEnd.toUtc();
      final dayKey =
          '${dayStart.year}-${dayStart.month.toString().padLeft(2, '0')}-${dayStart.day.toString().padLeft(2, '0')}';

      // XP for day
      var dayXp = 0;
      for (final e in periodLedgerRows) {
        if (e.createdAt.isAfter(dayStartUtc.subtract(const Duration(milliseconds: 1))) &&
            e.createdAt.isBefore(dayEndUtc)) {
          dayXp += getNetXp(e);
        }
      }
      runningCumulativeXp += dayXp;

      // Tasks completed on day
      var dayTasksCompleted = 0;
      for (final t in filteredTasks) {
        if (t.completedAt != null &&
            t.completedAt!.isAfter(dayStartUtc.subtract(const Duration(milliseconds: 1))) &&
            t.completedAt!.isBefore(dayEndUtc)) {
          dayTasksCompleted++;
        }
      }

      // Goals completed on day
      var dayGoalsCompleted = 0;
      for (final g in filteredGoals) {
        if (g.completedAt != null &&
            g.completedAt!.isAfter(dayStartUtc.subtract(const Duration(milliseconds: 1))) &&
            g.completedAt!.isBefore(dayEndUtc)) {
          dayGoalsCompleted++;
        }
      }

      // Projects completed on day
      var dayProjectsCompleted = 0;
      for (final p in filteredProjects) {
        if (p.completedAt != null &&
            p.completedAt!.isAfter(dayStartUtc.subtract(const Duration(milliseconds: 1))) &&
            p.completedAt!.isBefore(dayEndUtc)) {
          dayProjectsCompleted++;
        }
      }

      // Sessions on day
      var daySessionsCount = 0;
      for (final s in filteredSessions) {
        if (s.startedAt.isAfter(dayStartUtc.subtract(const Duration(milliseconds: 1))) &&
            s.startedAt.isBefore(dayEndUtc)) {
          daySessionsCount++;
          // Time of day bucket
          final localHour = s.startedAt.toLocal().hour;
          if (localHour >= 6 && localHour < 12) {
            activityByTimeOfDay['Morning'] =
                (activityByTimeOfDay['Morning'] ?? 0) + 1;
          } else if (localHour >= 12 && localHour < 18) {
            activityByTimeOfDay['Afternoon'] =
                (activityByTimeOfDay['Afternoon'] ?? 0) + 1;
          } else if (localHour >= 18 && localHour < 22) {
            activityByTimeOfDay['Evening'] =
                (activityByTimeOfDay['Evening'] ?? 0) + 1;
          } else {
            activityByTimeOfDay['Night'] =
                (activityByTimeOfDay['Night'] ?? 0) + 1;
          }
        }
      }

      // Decisions resolved on day
      var dayDecisionsCompleted = 0;
      for (final d in filteredDecisions) {
        if (d.resolvedAt != null &&
            d.resolvedAt!.isAfter(dayStartUtc.subtract(const Duration(milliseconds: 1))) &&
            d.resolvedAt!.isBefore(dayEndUtc)) {
          dayDecisionsCompleted++;
        }
      }

      final dayTotalActivity = dayTasksCompleted +
          dayGoalsCompleted +
          dayProjectsCompleted +
          daySessionsCount +
          dayDecisionsCompleted;

      if (dayTotalActivity > 0 || dayXp > 0) {
        activeDaysSet.add(dayKey);
        activityByDayOfWeek[dayStart.weekday] =
            (activityByDayOfWeek[dayStart.weekday] ?? 0) + dayTotalActivity;
      }

      // Event markers on day
      final markers = <String>[];
      if (dayGoalsCompleted > 0) markers.add('Goal Completed');
      if (dayProjectsCompleted > 0) markers.add('Project Completed');
      if (dayXp >= 200) markers.add('XP Milestone');

      final completionRate = (dayTasksCompleted + dayGoalsCompleted + dayProjectsCompleted) > 0
          ? ((dayTasksCompleted + dayGoalsCompleted + dayProjectsCompleted) /
                  (dayTotalActivity > 0 ? dayTotalActivity : 1))
              .clamp(0.0, 1.0)
          : 0.0;

      dailyGrowthSeries.add(
        DailyAnalyticsPoint(
          date: dayStart,
          xp: dayXp,
          cumulativeXp: runningCumulativeXp,
          tasksCompleted: dayTasksCompleted,
          goalsCompleted: dayGoalsCompleted,
          projectsCompleted: dayProjectsCompleted,
          sessionsCount: daySessionsCount,
          decisionsCompleted: dayDecisionsCompleted,
          totalActivity: dayTotalActivity,
          completionRate: completionRate,
          eventMarkers: markers,
        ),
      );
    }

    final activeDaysCount = activeDaysSet.length;

    // ── 11. Metrics Deltas ───────────────────────────────────────────────────
    final xpDelta = MetricDelta.compute(
      current: currentXpInPeriod.toDouble(),
      previous: prevXpInPeriod.toDouble(),
    );

    final currentVelocity = currentXpInPeriod / daysCount;
    final prevVelocity = prevXpInPeriod / (range.previousRange.dayCount > 0 ? range.previousRange.dayCount : 1);
    final xpVelocityDelta = MetricDelta.compute(
      current: currentVelocity,
      previous: prevVelocity,
    );

    final totalTrackedTasks = activeTasks + completedTasks;
    final currentCompletionRate = totalTrackedTasks > 0
        ? (completedTasks / totalTrackedTasks) * 100.0
        : (completedTasks > 0 ? 100.0 : 0.0);
    final completionRateDelta = MetricDelta.compute(
      current: currentCompletionRate,
      previous: 0.0,
    );

    final consistencyRate = (activeDaysCount / daysCount) * 100.0;
    final consistencyDelta = MetricDelta.compute(
      current: consistencyRate,
      previous: 0.0,
    );

    // ── 12. XP by Source ─────────────────────────────────────────────────────
    final xpBySource = <String, int>{
      'Tasks': 0,
      'Goals': 0,
      'Projects': 0,
      'Habits & Focus': 0,
      'Streaks': 0,
      'Other': 0,
    };

    for (final e in periodLedgerRows) {
      final pts = getNetXp(e);
      final key = switch (e.sourceType.toLowerCase()) {
        'task' => 'Tasks',
        'goal' => 'Goals',
        'project' => 'Projects',
        'session' || 'activity' => 'Habits & Focus',
        'streak' => 'Streaks',
        _ => 'Other',
      };
      xpBySource[key] = (xpBySource[key] ?? 0) + pts;
    }

    // ── 13. Life Area Metrics (Progression, Tier, Streaks) ────────────────────
    final lifeAreas = <AnalyticsLifeAreaMetric>[];
    for (final area in allLifeAreas) {
      if (lifeAreaId != null && area.id != lifeAreaId) continue;

      final areaXp = allTimeAllocationByArea[area.id] ?? 0;
      final progression = ProgressionCalculator.calculate(
        totalXp: areaXp,
        lifeAreaId: Id(area.id),
      );

      final streakRow = allStreaks
          .where((s) => s.lifeAreaId == area.id)
          .firstOrNull;

      final areaTasks = allTasks.where((t) => t.lifeAreaId == area.id).toList();
      final areaCompletedTasks =
          areaTasks.where((t) => t.status == 'done' || t.status == 'completed').length;
      final areaSessions =
          allSessions.where((s) => s.lifeAreaId == area.id).length;

      lifeAreas.add(
        AnalyticsLifeAreaMetric(
          id: area.id,
          name: area.name,
          xp: areaXp,
          previousXp: (areaXp * 0.85).round(),
          level: progression.level,
          tier: progression.tier,
          currentStreak: streakRow?.currentStreak ?? 0,
          longestStreak: streakRow?.longestStreak ?? 0,
          progress: progression.progressPct / 100.0,
          activityCount: areaTasks.length + areaSessions,
          completionCount: areaCompletedTasks,
          trendPct: progression.progressPct,
          color: areaColorMap[area.id] ?? '#C6F135',
        ),
      );
    }

    // ── 14. Goal Health ──────────────────────────────────────────────────────
    final goalHealth = <GoalHealthItem>[];
    for (final g in filteredGoals) {
      final isDone = g.status == 'completed';
      final momentum = isDone
          ? 'Completed'
          : (g.progress >= 0.7
              ? 'On Track'
              : (g.progress >= 0.3 ? 'Growing' : 'Needs Focus'));

      goalHealth.add(
        GoalHealthItem(
          id: g.id,
          title: g.title,
          lifeAreaId: g.lifeAreaId,
          lifeAreaName: g.lifeAreaId != null ? areaNameMap[g.lifeAreaId!] : null,
          status: isDone ? 'Completed' : 'Active',
          progress: g.progress,
          xpTarget: g.xpTarget,
          xpEarned: (g.progress * (g.xpTarget ?? 500)).round(),
          activityCount: allTasks.where((t) => t.primaryGoalId == g.id).length,
          lastActivityDate: g.completedAt ?? g.updatedAt,
          momentum: momentum,
          trend: g.progress * 100.0,
        ),
      );
    }

    // ── 15. Project Performance ──────────────────────────────────────────────
    final projectPerformance = <ProjectPerformanceItem>[];
    for (final p in filteredProjects) {
      final isDone = p.status == 'completed';
      final pTasks = allTasks.where((t) => t.projectId == p.id).toList();
      final pCompleted =
          pTasks.where((t) => t.status == 'done' || t.status == 'completed').length;

      projectPerformance.add(
        ProjectPerformanceItem(
          id: p.id,
          title: p.title,
          lifeAreaId: p.lifeAreaId,
          lifeAreaName: p.lifeAreaId != null ? areaNameMap[p.lifeAreaId!] : null,
          status: isDone ? 'Completed' : 'Active',
          progress: p.progress,
          difficulty: p.difficulty,
          xpEarned: (p.progress * 1000).round(),
          tasksCount: pTasks.length,
          completedTasksCount: pCompleted,
          lastActivityDate: p.completedAt ?? p.updatedAt,
        ),
      );
    }

    // ── 16. Task Breakdown Maps ──────────────────────────────────────────────
    final Map<int, int> tasksByPriority = {1: 0, 2: 0, 3: 0, 4: 0};
    final Map<String, int> tasksByLifeArea = {};

    for (final t in filteredTasks) {
      tasksByPriority[t.priority] = (tasksByPriority[t.priority] ?? 0) + 1;
      if (t.lifeAreaId != null) {
        final aName = areaNameMap[t.lifeAreaId!] ?? t.lifeAreaId!;
        tasksByLifeArea[aName] = (tasksByLifeArea[aName] ?? 0) + 1;
      }
    }

    // ── 17. Milestones (Real Events) ─────────────────────────────────────────
    final milestones = <MilestoneItem>[];

    for (final g in filteredGoals) {
      if (g.completedAt != null) {
        milestones.add(
          MilestoneItem(
            id: 'm-goal-${g.id}',
            title: 'Goal Completed',
            description: '${g.title} achieved',
            category: 'Goal Completed',
            date: g.completedAt!,
            xp: g.xpTarget ?? 500,
          ),
        );
      }
    }

    for (final p in filteredProjects) {
      if (p.completedAt != null) {
        milestones.add(
          MilestoneItem(
            id: 'm-proj-${p.id}',
            title: 'Project Completed',
            description: '${p.title} launched',
            category: 'Project Completed',
            date: p.completedAt!,
          ),
        );
      }
    }

    final achievements = await (_db.select(_db.achievements)
          ..where((a) => a.ownerId.equals(ownerId)))
        .get();

    for (final ach in achievements) {
      milestones.add(
        MilestoneItem(
          id: 'm-ach-${ach.id}',
          title: 'Achievement Unlocked',
          description: ach.kind.replaceAll('_', ' ').toUpperCase(),
          category: 'Achievement',
          date: ach.awardedAt,
        ),
      );
    }

    for (final e in filteredActivityEvents) {
      if (e.eventType == 'streak_extended') {
        milestones.add(
          MilestoneItem(
            id: 'm-streak-${e.id}',
            title: 'Streak Milestone',
            description: 'Maintained active streak',
            category: 'Streak',
            date: e.occurredAt,
          ),
        );
      } else if (e.eventType == 'level_up') {
        milestones.add(
          MilestoneItem(
            id: 'm-lvl-${e.id}',
            title: 'Level Up',
            description: 'Advanced to next level',
            category: 'Level Up',
            date: e.occurredAt,
          ),
        );
      }
    }

    milestones.sort((a, b) => b.date.compareTo(a.date));

    // ── 18. Recent Activity (Real Events) ────────────────────────────────────
    final recentActivity = <RecentActivityItem>[];

    for (final r in periodLedgerRows.take(15)) {
      final taskMatch = r.sourceType == 'task'
          ? allTasks.where((t) => t.id == r.sourceId).firstOrNull
          : null;
      final title = taskMatch != null
          ? 'Completed task: ${taskMatch.title}'
          : '${r.sourceType.toUpperCase()} ${r.action.replaceAll('_', ' ')}';

      recentActivity.add(
        RecentActivityItem(
          id: r.id,
          title: title,
          sourceType: r.sourceType,
          points: getNetXp(r),
          timestamp: r.createdAt,
          lifeAreaName: taskMatch?.lifeAreaId != null
              ? areaNameMap[taskMatch!.lifeAreaId!]
              : null,
        ),
      );
    }

    // ── 19. Rule-Based Insights (Pure Data-Driven, No Fluff) ──────────────────
    final insights = <AnalyticsInsightItem>[];

    if (lifeAreas.isNotEmpty) {
      final sortedAreas = List<AnalyticsLifeAreaMetric>.from(lifeAreas)
        ..sort((a, b) => b.xp.compareTo(a.xp));
      final topArea = sortedAreas.first;
      insights.add(
        AnalyticsInsightItem(
          title: '${topArea.name} is your highest XP domain',
          description:
              'Accumulated ${topArea.xp} XP reaching Level ${topArea.level} (${topArea.tier}).',
          icon: 'trending_up',
          isPositive: true,
        ),
      );

      final lowestArea = sortedAreas.last;
      if (lowestArea.id != topArea.id && lowestArea.xp < topArea.xp / 2) {
        insights.add(
          AnalyticsInsightItem(
            title: '${lowestArea.name} has lower momentum',
            description:
                'Recorded ${lowestArea.activityCount} total actions. Consider scheduling focus here.',
            icon: 'warning_amber',
            isPositive: false,
          ),
        );
      }
    }

    if (createdTasks > 0) {
      if (completedTasks >= createdTasks) {
        insights.add(
          AnalyticsInsightItem(
            title: 'Positive task throughput',
            description:
                'Completed $completedTasks tasks with a $createdTasks incoming rate.',
            icon: 'check_circle_outline',
            isPositive: true,
          ),
        );
      } else if (completedTasks < createdTasks / 2 && createdTasks > 5) {
        insights.add(
          AnalyticsInsightItem(
            title: 'Task backlog is accumulating',
            description:
                '$createdTasks tasks created versus $completedTasks completions in this period.',
            icon: 'compare_arrows',
            isPositive: false,
          ),
        );
      }
    }

    if (activeGoals > 0 && completedGoals == 0 && createdGoals == 0) {
      insights.add(
        AnalyticsInsightItem(
          title: '$activeGoals active goals currently in progress',
          description:
              'Steady focus maintained across existing long-term initiatives.',
          icon: 'flag_outlined',
          isPositive: true,
        ),
      );
    }

    return AnalyticsSnapshot(
      range: range,
      lifeAreaId: lifeAreaId,
      totalXp: totalCumulativeXp,
      previousTotalXp: prevXpInPeriod,
      xpDelta: xpDelta,
      positiveXp: positiveXp,
      negativeXp: negativeXp,
      xpVelocityDelta: xpVelocityDelta,
      completionRateDelta: completionRateDelta,
      consistencyDelta: consistencyDelta,
      activeGoals: activeGoals,
      completedGoals: completedGoals,
      createdGoals: createdGoals,
      activeProjects: activeProjects,
      completedProjects: completedProjects,
      createdProjects: createdProjects,
      activeTasks: activeTasks,
      completedTasks: completedTasks,
      createdTasks: createdTasks,
      createdDecisions: createdDecisions,
      completedDecisions: completedDecisions,
      activitiesStarted: activitiesStarted,
      sessionsCompleted: sessionsCompleted,
      actualMinutes: actualMinutes,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      activeDaysCount: activeDaysCount,
      xpOverTime: [
        for (final p in dailyGrowthSeries)
          AnalyticsPoint(date: p.date, xp: p.xp),
      ],
      dailyGrowthSeries: dailyGrowthSeries,
      xpBySource: xpBySource,
      lifeAreas: lifeAreas,
      goalHealth: goalHealth,
      projectPerformance: projectPerformance,
      tasksByPriority: tasksByPriority,
      tasksByLifeArea: tasksByLifeArea,
      activityByDayOfWeek: activityByDayOfWeek,
      activityByTimeOfDay: activityByTimeOfDay,
      milestones: milestones,
      recentActivity: recentActivity,
      insights: insights,
    );
  }
}
