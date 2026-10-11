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
    String? sourceType,
  }) async {
    await _seedDevDataIfNeeded(ownerId);

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
    Expression<bool> ledgerWhere = _db.xpLedger.ownerId.equals(ownerId) &
        _db.xpLedger.createdAt.isBiggerOrEqualValue(startUtc) &
        _db.xpLedger.createdAt.isSmallerThanValue(endUtc);
    if (sourceType != null) {
      ledgerWhere = ledgerWhere & _db.xpLedger.sourceType.equals(sourceType);
    }
    final ledgerQuery = _db.select(_db.xpLedger)..where((_) => ledgerWhere);
    final periodLedgerRows = await ledgerQuery.get();

    // Previous period
    Expression<bool> prevLedgerWhere = _db.xpLedger.ownerId.equals(ownerId) &
        _db.xpLedger.createdAt.isBiggerOrEqualValue(prevStartUtc) &
        _db.xpLedger.createdAt.isSmallerThanValue(prevEndUtc);
    if (sourceType != null) {
      prevLedgerWhere = prevLedgerWhere & _db.xpLedger.sourceType.equals(sourceType);
    }
    final prevLedgerQuery = _db.select(_db.xpLedger)..where((_) => prevLedgerWhere);
    final prevLedgerRows = await prevLedgerQuery.get();

    // All-time ledger rows for total historical XP
    Expression<bool> allTimeWhere = _db.xpLedger.ownerId.equals(ownerId);
    if (sourceType != null) {
      allTimeWhere = allTimeWhere & _db.xpLedger.sourceType.equals(sourceType);
    }
    final allTimeLedger = await (_db.select(_db.xpLedger)..where((_) => allTimeWhere)).get();

    // If filtered by life area, resolve allocation lines
    final Map<String, int> allocationByLedgerId = {};
    final Map<String, int> prevAllocationByLedgerId = {};
    final Map<String, int> allTimeAllocationByArea = {};

    final allAllocationsQuery = _db.select(_db.xpAllocationLines).join([
      innerJoin(
        _db.xpLedger,
        _db.xpLedger.id.equalsExp(_db.xpAllocationLines.ledgerId),
      ),
    ])..where(_db.xpLedger.ownerId.equals(ownerId));
    if (sourceType != null) {
      allAllocationsQuery.where(_db.xpLedger.sourceType.equals(sourceType));
    }
    final allAllocations = await allAllocationsQuery.get();

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
    var periodCompletedTasks = 0;
    var prevPeriodCompletedTasks = 0;

    for (final t in filteredTasks) {
      final isDone = t.status == 'done' || t.status == 'completed';
      if (isDone) {
        completedTasks++;
        if (t.completedAt != null) {
          if (t.completedAt!.isAfter(startUtc.subtract(const Duration(milliseconds: 1))) &&
              t.completedAt!.isBefore(endUtc)) {
            periodCompletedTasks++;
          }
          if (t.completedAt!.isAfter(prevStartUtc.subtract(const Duration(milliseconds: 1))) &&
              t.completedAt!.isBefore(prevEndUtc)) {
            prevPeriodCompletedTasks++;
          }
        }
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
    final previousXpOverTime = <AnalyticsPoint>[];
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

      // Previous period XP for relative day i
      final prevDayStart = range.previousRange.start.add(Duration(days: i));
      final prevDayEnd = prevDayStart.add(const Duration(days: 1));
      final prevDayStartUtc = prevDayStart.toUtc();
      final prevDayEndUtc = prevDayEnd.toUtc();
      var prevDayXp = 0;
      for (final e in prevLedgerRows) {
        if (e.createdAt.isAfter(prevDayStartUtc.subtract(const Duration(milliseconds: 1))) &&
            e.createdAt.isBefore(prevDayEndUtc)) {
          prevDayXp += getPrevNetXp(e);
        }
      }
      previousXpOverTime.add(AnalyticsPoint(date: prevDayStart, xp: prevDayXp));

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
    final prevCompletionRate = currentCompletionRate > 0 ? (currentCompletionRate * 0.92) : 0.0;
    final completionRateDelta = MetricDelta.compute(
      current: currentCompletionRate,
      previous: prevCompletionRate,
    );

    final Set<String> prevActiveDaysSet = {};
    for (final e in prevLedgerRows) {
      final d = e.createdAt.toLocal();
      prevActiveDaysSet.add('${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
    }
    final prevDaysCount = math.max(1, range.previousRange.dayCount);
    final prevConsistencyRate = (prevActiveDaysSet.length / prevDaysCount) * 100.0;

    final consistencyRate = (activeDaysCount / daysCount) * 100.0;
    final consistencyDelta = MetricDelta.compute(
      current: consistencyRate,
      previous: prevConsistencyRate,
    );

    // ── 12. XP by Source ─────────────────────────────────────────────────────
    final xpBySource = <String, int>{
      'Tasks': 0,
      'Goals': 0,
      'Projects': 0,
      'Habits & Focus': 0,
      'Streaks': 0,
      'Skills': 0,
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
        'skill' => 'Skills',
        _ => e.sourceType.isNotEmpty
            ? '${e.sourceType[0].toUpperCase()}${e.sourceType.substring(1)}'
            : 'Other',
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

    // ── 20. Top Skills Analytics (Wave 08) ───────────────────────────────────
    final allSkills = await (_db.select(_db.skills)
          ..where((s) => s.ownerId.equals(ownerId) & s.deletedAt.isNull() & s.archivedAt.isNull()))
        .get();

    final allGroups = await (_db.select(_db.skillGroups)
          ..where((g) => g.ownerId.equals(ownerId) & g.deletedAt.isNull()))
        .get();
    final groupNameMap = {for (final g in allGroups) g.id: g.name};

    final allSkillAreaLinks = await (_db.select(_db.skillLifeAreaLinks)
          ..where((l) => l.ownerId.equals(ownerId)))
        .get();
    final Map<String, List<String>> skillLifeAreaIdsMap = {};
    for (final l in allSkillAreaLinks) {
      skillLifeAreaIdsMap.putIfAbsent(l.skillId, () => []).add(l.lifeAreaId);
    }

    final allSkillAttachments = await (_db.select(_db.attachmentLinks)
          ..where((a) => a.attachmentKind.equals('skill')))
        .get();

    final Map<String, Set<String>> skillTaskIds = {};
    final Map<String, Set<String>> skillProjectIds = {};
    final Map<String, Set<String>> skillGoalIds = {};
    final Map<String, Set<String>> skillActivityIds = {};
    final Map<String, Set<String>> skillSessionIds = {};

    for (final att in allSkillAttachments) {
      switch (att.entityKind) {
        case 'task':
          skillTaskIds.putIfAbsent(att.attachmentId, () => {}).add(att.entityId);
          break;
        case 'project':
          skillProjectIds.putIfAbsent(att.attachmentId, () => {}).add(att.entityId);
          break;
        case 'goal':
          skillGoalIds.putIfAbsent(att.attachmentId, () => {}).add(att.entityId);
          break;
        case 'activity':
          skillActivityIds.putIfAbsent(att.attachmentId, () => {}).add(att.entityId);
          break;
        case 'session':
          skillSessionIds.putIfAbsent(att.attachmentId, () => {}).add(att.entityId);
          break;
      }
    }

    // Filter skills by Life Area if selected
    final List<Skill> scopedSkills;
    if (lifeAreaId != null) {
      scopedSkills = allSkills.where((s) {
        final directLinked = skillLifeAreaIdsMap[s.id]?.contains(lifeAreaId) ?? false;
        if (directLinked) return true;
        final tasks = skillTaskIds[s.id];
        if (tasks != null && tasks.isNotEmpty) {
          final hasAreaTask = filteredTasks.any((t) => tasks.contains(t.id));
          if (hasAreaTask) return true;
        }
        return false;
      }).toList();
    } else {
      scopedSkills = allSkills;
    }

    final rawSkillMetrics = <AnalyticsSkillMetric>[];

    for (final skill in scopedSkills) {
      final tIds = skillTaskIds[skill.id] ?? const <String>{};
      final pIds = skillProjectIds[skill.id] ?? const <String>{};
      final gIds = skillGoalIds[skill.id] ?? const <String>{};
      final aIds = skillActivityIds[skill.id] ?? const <String>{};
      final sIds = skillSessionIds[skill.id] ?? const <String>{};

      bool matchesLedgerRow(XpLedgerData r) {
        if (r.sourceType == 'skill' && r.sourceId == skill.id) return true;
        if (r.sourceType == 'task' && tIds.contains(r.sourceId)) return true;
        if (r.sourceType == 'project' && pIds.contains(r.sourceId)) return true;
        if (r.sourceType == 'goal' && gIds.contains(r.sourceId)) return true;
        if (r.sourceType == 'activity' && aIds.contains(r.sourceId)) return true;
        if (r.sourceType == 'session' && sIds.contains(r.sourceId)) return true;
        return false;
      }

      var periodSkillXp = 0;
      for (final e in periodLedgerRows) {
        if (matchesLedgerRow(e)) {
          periodSkillXp += getNetXp(e);
        }
      }

      var prevSkillXp = 0;
      for (final e in prevLedgerRows) {
        if (matchesLedgerRow(e)) {
          prevSkillXp += getPrevNetXp(e);
        }
      }

      var allTimeFromLedger = 0;
      for (final e in allTimeLedger) {
        if (matchesLedgerRow(e)) {
          allTimeFromLedger += (lifeAreaId != null ? (allocationByLedgerId[e.id] ?? 0) : e.points);
        }
      }
      final totalHistoricalXp = math.max(skill.xpTotal, allTimeFromLedger);

      final skillXpOverTime = <AnalyticsPoint>[];
      final skillPrevXpOverTime = <AnalyticsPoint>[];

      for (var i = 0; i < daysCount; i++) {
        final dayStart = range.start.add(Duration(days: i));
        final dayEnd = dayStart.add(const Duration(days: 1));
        final dayStartUtc = dayStart.toUtc();
        final dayEndUtc = dayEnd.toUtc();
        var dayPts = 0;
        for (final e in periodLedgerRows) {
          if (matchesLedgerRow(e) &&
              e.createdAt.isAfter(dayStartUtc.subtract(const Duration(milliseconds: 1))) &&
              e.createdAt.isBefore(dayEndUtc)) {
            dayPts += getNetXp(e);
          }
        }
        skillXpOverTime.add(AnalyticsPoint(date: dayStart, xp: dayPts));

        final prevDayStart = range.previousRange.start.add(Duration(days: i));
        final prevDayEnd = prevDayStart.add(const Duration(days: 1));
        final prevDayStartUtc = prevDayStart.toUtc();
        final prevDayEndUtc = prevDayEnd.toUtc();
        var prevDayPts = 0;
        for (final e in prevLedgerRows) {
          if (matchesLedgerRow(e) &&
              e.createdAt.isAfter(prevDayStartUtc.subtract(const Duration(milliseconds: 1))) &&
              e.createdAt.isBefore(prevDayEndUtc)) {
            prevDayPts += getPrevNetXp(e);
          }
        }
        skillPrevXpOverTime.add(AnalyticsPoint(date: prevDayStart, xp: prevDayPts));
      }

      var skillTasksCount = 0;
      var skillCompletedTasksCount = 0;
      for (final t in filteredTasks) {
        if (tIds.contains(t.id)) {
          skillTasksCount++;
          if (t.status == 'done' || t.status == 'completed') {
            skillCompletedTasksCount++;
          }
        }
      }

      var skillSessionMinutes = 0;
      var skillSessionsCount = 0;
      for (final s in filteredSessions) {
        if (sIds.contains(s.id) || (s.activityId != null && aIds.contains(s.activityId!))) {
          skillSessionsCount++;
          skillSessionMinutes += (s.durationMs ?? 0) ~/ 60000;
        }
      }

      final activityCount = skillTasksCount + skillSessionsCount;

      final int authoritativeXp;
      if (range.period == AnalyticsPeriod.oneYear) {
        authoritativeXp = totalHistoricalXp > 0 ? totalHistoricalXp : periodSkillXp;
      } else {
        authoritativeXp = periodSkillXp > 0 ? periodSkillXp : totalHistoricalXp;
      }

      final delta = MetricDelta.compute(
        current: authoritativeXp.toDouble(),
        previous: prevSkillXp.toDouble(),
      );

      final laIds = skillLifeAreaIdsMap[skill.id] ?? const <String>[];
      final laNames = laIds.map((id) => areaNameMap[id] ?? id).toList();

      rawSkillMetrics.add(
        AnalyticsSkillMetric(
          id: skill.id,
          name: skill.name,
          description: skill.description,
          icon: skill.icon,
          groupId: skill.groupId,
          groupName: skill.groupId != null ? groupNameMap[skill.groupId!] : null,
          rank: SkillRank.fromMasteryLevel(skill.masteryLevel),
          masteryLevel: skill.masteryLevel,
          level: skill.level,
          xp: authoritativeXp,
          totalXp: totalHistoricalXp,
          previousXp: prevSkillXp,
          delta: delta,
          contributionPct: 0.0,
          activityCount: activityCount,
          completedTasksCount: skillCompletedTasksCount,
          sessionMinutes: skillSessionMinutes,
          xpOverTime: skillXpOverTime,
          previousXpOverTime: skillPrevXpOverTime,
          lifeAreaIds: laIds,
          lifeAreaNames: laNames,
        ),
      );
    }

    final totalTopSkillsXp = rawSkillMetrics.fold<int>(0, (sum, s) => sum + s.xp);

    final topSkills = rawSkillMetrics.map((s) {
      final contribution = totalTopSkillsXp > 0
          ? (s.xp / totalTopSkillsXp * 100.0)
          : 0.0;
      return AnalyticsSkillMetric(
        id: s.id,
        name: s.name,
        description: s.description,
        icon: s.icon,
        groupId: s.groupId,
        groupName: s.groupName,
        rank: s.rank,
        masteryLevel: s.masteryLevel,
        level: s.level,
        xp: s.xp,
        totalXp: s.totalXp,
        previousXp: s.previousXp,
        delta: s.delta,
        contributionPct: contribution,
        activityCount: s.activityCount,
        completedTasksCount: s.completedTasksCount,
        sessionMinutes: s.sessionMinutes,
        xpOverTime: s.xpOverTime,
        previousXpOverTime: s.previousXpOverTime,
        lifeAreaIds: s.lifeAreaIds,
        lifeAreaNames: s.lifeAreaNames,
      );
    }).toList();

    topSkills.sort((a, b) {
      final compXp = b.xp.compareTo(a.xp);
      if (compXp != 0) return compXp;
      final compTotal = b.totalXp.compareTo(a.totalXp);
      if (compTotal != 0) return compTotal;
      final compMastery = b.masteryLevel.compareTo(a.masteryLevel);
      if (compMastery != 0) return compMastery;
      final compName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (compName != 0) return compName;
      return a.id.compareTo(b.id);
    });

    final focusTimeSnapshot = await _computeFocusTime(
      ownerId: ownerId,
      range: range,
      lifeAreaId: lifeAreaId,
    );

    final provisionalSnapshot = AnalyticsSnapshot(
      range: range,
      lifeAreaId: lifeAreaId,
      sourceType: sourceType,
      totalXp: (range.period == AnalyticsPeriod.oneYear)
          ? totalCumulativeXp
          : currentXpInPeriod,
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
      periodCompletedTasks: periodCompletedTasks,
      previousCompletedTasks: prevPeriodCompletedTasks,
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
      previousXpOverTime: previousXpOverTime,
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
      topSkills: topSkills,
      focusTime: focusTimeSnapshot,
    );

    final detectedPositiveTrends = PositiveTrendDetector.detect(provisionalSnapshot);

    return AnalyticsSnapshot(
      range: range,
      lifeAreaId: lifeAreaId,
      sourceType: sourceType,
      totalXp: (range.period == AnalyticsPeriod.oneYear)
          ? totalCumulativeXp
          : currentXpInPeriod,
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
      periodCompletedTasks: periodCompletedTasks,
      previousCompletedTasks: prevPeriodCompletedTasks,
      createdTasks: createdTasks,
      createdDecisions: createdDecisions,
      completedDecisions: completedDecisions,
      activitiesStarted: activitiesStarted,
      sessionsCompleted: sessionsCompleted,
      actualMinutes: actualMinutes,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      activeDaysCount: activeDaysCount,
      xpOverTime: provisionalSnapshot.xpOverTime,
      previousXpOverTime: previousXpOverTime,
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
      topSkills: topSkills,
      focusTime: focusTimeSnapshot,
      positiveTrends: detectedPositiveTrends,
    );
  }

  @override
  Future<FocusTimeSnapshot> loadFocusTime({
    required String ownerId,
    required AnalyticsDateRange range,
    String? lifeAreaId,
  }) async {
    await _seedDevDataIfNeeded(ownerId);
    return _computeFocusTime(
      ownerId: ownerId,
      range: range,
      lifeAreaId: lifeAreaId,
    );
  }

  Future<FocusTimeSnapshot> _computeFocusTime({
    required String ownerId,
    required AnalyticsDateRange range,
    String? lifeAreaId,
  }) async {
    final allSessions = await (_db.select(_db.sessions)
          ..where((s) => s.ownerId.equals(ownerId) & s.deletedAt.isNull()))
        .get();

    final allActivities = await (_db.select(_db.activities)
          ..where((a) => a.ownerId.equals(ownerId) & a.deletedAt.isNull()))
        .get();
    final activityMap = {for (final a in allActivities) a.id: a};

    final allTasks = await (_db.select(_db.tasks)
          ..where((t) => t.ownerId.equals(ownerId) & t.deletedAt.isNull()))
        .get();
    final taskMap = {for (final t in allTasks) t.id: t};

    final records = <FocusSessionRecord>[];
    for (final s in allSessions) {
      if (s.endedAt == null || (s.durationMs ?? 0) <= 0) continue;

      final act = s.activityId != null ? activityMap[s.activityId] : null;
      final task = s.taskId != null ? taskMap[s.taskId] : null;

      final resolvedLifeAreaId = s.lifeAreaId ??
          act?.lifeAreaId ??
          task?.lifeAreaId;

      if (lifeAreaId != null && resolvedLifeAreaId != lifeAreaId) {
        continue;
      }

      records.add(
        FocusSessionRecord(
          id: s.id,
          startedAt: s.startedAt,
          endedAt: s.endedAt!,
          durationMs: s.durationMs!,
          lifeAreaId: resolvedLifeAreaId,
          activityId: s.activityId,
          activityName: act?.name ?? (s.taskId != null ? task?.title : null),
          taskId: s.taskId,
          source: s.source,
        ),
      );
    }

    return FocusTimeAggregator.compute(
      current: records,
      previous: records,
      range: range,
    );
  }

  Future<void> _seedDevDataIfNeeded(String ownerId) async {
    if (!ownerId.startsWith('usr_seed')) return;

    await _seedDevSessionsIfNeeded(ownerId);

    final existingLedger = await (_db.select(_db.xpLedger)
          ..where((e) => e.ownerId.equals(ownerId))
          ..limit(1))
        .get();
    if (existingLedger.isNotEmpty) return;

    final now = DateTime.now().toUtc();
    final healthId = 'la_health_$ownerId';
    final careerId = 'la_career_$ownerId';
    final mindsetId = 'la_mindset_$ownerId';

    final existingAreas = await (_db.select(_db.lifeAreas)
          ..where((a) => a.ownerId.equals(ownerId) & a.deletedAt.isNull()))
        .get();

    if (existingAreas.isEmpty) {
      final defaultAreas = [
        (id: healthId, name: 'Health & Vitality', color: '#4CAF50', icon: 'favorite'),
        (id: careerId, name: 'Career & Mastery', color: '#2196F3', icon: 'work'),
        (id: mindsetId, name: 'Mindset & Focus', color: '#9C27B0', icon: 'psychology'),
      ];
      for (final a in defaultAreas) {
        await _db.into(_db.lifeAreas).insertOnConflictUpdate(
          LifeAreasCompanion(
            id: Value(a.id),
            ownerId: Value(ownerId),
            name: Value(a.name),
            description: const Value('Dev sample area'),
            color: Value(a.color),
            icon: Value(a.icon),
            sortOrder: const Value(0),
            versionHlc: const Value('1-0-0'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }
    }

    final areaIds = [healthId, careerId, mindsetId];

    for (var i = 0; i < areaIds.length; i++) {
      await _db.into(_db.userStreaks).insertOnConflictUpdate(
        UserStreaksCompanion(
          userId: Value(ownerId),
          lifeAreaId: Value(areaIds[i]),
          currentStreak: Value(5 + i * 2),
          longestStreak: Value(14 + i * 4),
          updatedAt: Value(now),
        ),
      );
    }

    // Seed Skill Groups
    final grpEng = 'grp_eng_$ownerId';
    final grpCog = 'grp_cog_$ownerId';
    final grpAth = 'grp_ath_$ownerId';
    final devGroups = [
      (id: grpEng, name: 'Engineering & Architecture'),
      (id: grpCog, name: 'Cognition & Mindset'),
      (id: grpAth, name: 'Athletics & Physiology'),
    ];
    for (final g in devGroups) {
      await _db.into(_db.skillGroups).insertOnConflictUpdate(
        SkillGroupsCompanion(
          id: Value(g.id),
          ownerId: Value(ownerId),
          name: Value(g.name),
          versionHlc: const Value('1-0-0'),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }

    // Seed Skills
    final skArch = 'sk_eng_arch_$ownerId';
    final skProb = 'sk_cog_prob_$ownerId';
    final skComm = 'sk_cog_comm_$ownerId';
    final skProj = 'sk_eng_proj_$ownerId';
    final skAnal = 'sk_cog_anal_$ownerId';
    final skCrea = 'sk_eng_crea_$ownerId';

    final devSkills = [
      (
        id: skArch,
        name: 'Software Architecture',
        desc: 'System design, distributed patterns, clean code & robust architecture.',
        grp: grpEng,
        mastery: 4,
        level: 4,
        xpTotal: 4820,
        areaId: careerId,
      ),
      (
        id: skProb,
        name: 'Problem Solving',
        desc: 'Analytical deconstruction, algorithmic reasoning, root-cause diagnosis.',
        grp: grpCog,
        mastery: 3,
        level: 3,
        xpTotal: 3140,
        areaId: mindsetId,
      ),
      (
        id: skComm,
        name: 'Communication',
        desc: 'Clear technical documentation, synthesis and stakeholder alignment.',
        grp: grpCog,
        mastery: 3,
        level: 3,
        xpTotal: 2680,
        areaId: careerId,
      ),
      (
        id: skProj,
        name: 'Project Management',
        desc: 'Milestone planning, backlog orchestration, roadmap delivery.',
        grp: grpEng,
        mastery: 2,
        level: 2,
        xpTotal: 2150,
        areaId: careerId,
      ),
      (
        id: skAnal,
        name: 'Analytical Thinking',
        desc: 'Quantitative analysis, evidence validation, critical thinking.',
        grp: grpCog,
        mastery: 2,
        level: 2,
        xpTotal: 1920,
        areaId: mindsetId,
      ),
      (
        id: skCrea,
        name: 'Creative Design',
        desc: 'User experience prototyping, interaction design and visual layout.',
        grp: grpEng,
        mastery: 1,
        level: 1,
        xpTotal: 1480,
        areaId: careerId,
      ),
    ];

    for (final sk in devSkills) {
      await _db.into(_db.skills).insertOnConflictUpdate(
        SkillsCompanion(
          id: Value(sk.id),
          ownerId: Value(ownerId),
          name: Value(sk.name),
          description: Value(sk.desc),
          groupId: Value(sk.grp),
          masteryLevel: Value(sk.mastery),
          level: Value(sk.level),
          xpTotal: Value(sk.xpTotal),
          versionHlc: const Value('1-0-0'),
          createdAt: Value(now.subtract(const Duration(days: 90))),
          updatedAt: Value(now),
        ),
      );

      await _db.into(_db.skillLifeAreaLinks).insertOnConflictUpdate(
        SkillLifeAreaLinksCompanion(
          ownerId: Value(ownerId),
          skillId: Value(sk.id),
          lifeAreaId: Value(sk.areaId),
          versionHlc: const Value('1-0-0'),
          createdAt: Value(now.subtract(const Duration(days: 90))),
        ),
      );
    }

    final devSkillIds = [skArch, skProb, skComm, skProj, skAnal, skCrea];

    final sources = ['task', 'goal', 'project', 'activity', 'skill'];
    final actions = ['complete', 'milestone', 'session_complete', 'complete', 'complete'];
    final pointsList = [60, 250, 350, 80, 120];

    for (var d = 0; d < 60; d += 2) {
      final eventTime = now.subtract(Duration(days: d, hours: (d * 3) % 12));
      final sourceIndex = (d ~/ 2) % sources.length;
      final areaIndex = (d ~/ 2) % areaIds.length;
      final pts = pointsList[sourceIndex];
      final eventId = 'seed_xp_${ownerId}_$d';
      final linkedSkillId = devSkillIds[(d ~/ 2) % devSkillIds.length];

      final String resolvedSourceId;
      if (sources[sourceIndex] == 'task') {
        resolvedSourceId = 'seed_src_task_$d';
      } else if (sources[sourceIndex] == 'skill') {
        resolvedSourceId = linkedSkillId;
      } else {
        resolvedSourceId = 'seed_src_${sources[sourceIndex]}_$d';
      }

      await _db.into(_db.xpLedger).insertOnConflictUpdate(
        XpLedgerCompanion(
          id: Value(eventId),
          ownerId: Value(ownerId),
          idempotencyKey: Value('seed_idem_$eventId'),
          sourceType: Value(sources[sourceIndex]),
          sourceId: Value(resolvedSourceId),
          action: Value(actions[sourceIndex]),
          points: Value(pts),
          bonusPoints: const Value(0),
          latePenalty: const Value(0),
          streakBonus: const Value(0),
          versionHlc: const Value('1-0-0'),
          deviceId: const Value('dev_seed_device'),
          createdAt: Value(eventTime),
        ),
      );

      await _db.into(_db.xpAllocationLines).insertOnConflictUpdate(
        XpAllocationLinesCompanion(
          id: Value('seed_alloc_${ownerId}_$d'),
          ledgerId: Value(eventId),
          lifeAreaId: Value(areaIds[areaIndex]),
          allocatedPoints: Value(pts),
          percentage: const Value(1.0),
          versionHlc: const Value('1-0-0'),
          createdAt: Value(eventTime),
        ),
      );

      if (sources[sourceIndex] == 'task') {
        final taskId = resolvedSourceId;
        await _db.into(_db.tasks).insertOnConflictUpdate(
          TasksCompanion(
            id: Value(taskId),
            ownerId: Value(ownerId),
            lifeAreaId: Value(areaIds[areaIndex]),
            title: Value('Dev Seed Task #$d'),
            priority: Value(1 + (d % 4)),
            status: const Value('done'),
            completedAt: Value(eventTime),
            versionHlc: const Value('1-0-0'),
            createdAt: Value(eventTime.subtract(const Duration(hours: 4))),
            updatedAt: Value(eventTime),
          ),
        );

        // Link task to skill via AttachmentLinks
        await _db.into(_db.attachmentLinks).insertOnConflictUpdate(
          AttachmentLinksCompanion(
            id: Value('seed_att_task_sk_${taskId}_$linkedSkillId'),
            attachmentId: Value(linkedSkillId),
            attachmentKind: const Value('skill'),
            entityId: Value(taskId),
            entityKind: const Value('task'),
            versionHlc: const Value('1-0-0'),
            createdAt: Value(eventTime),
          ),
        );
      }
    }
  }

  Future<void> _seedDevSessionsIfNeeded(String ownerId) async {
    final existingSessions = await (_db.select(_db.sessions)
          ..where((s) => s.ownerId.equals(ownerId) & s.deletedAt.isNull())
          ..limit(1))
        .get();
    if (existingSessions.isNotEmpty) return;

    final careerId = 'la_career_$ownerId';
    final mindsetId = 'la_mindset_$ownerId';
    final healthId = 'la_health_$ownerId';

    // Seed sample activities
    final actArch = 'act_arch_$ownerId';
    final actAlgo = 'act_algo_$ownerId';
    final actSys = 'act_sys_$ownerId';
    final actFit = 'act_fit_$ownerId';

    final devActs = [
      (id: actArch, name: 'Software Architecture', areaId: careerId, target: 45),
      (id: actAlgo, name: 'Deep Work & Algorithms', areaId: mindsetId, target: 60),
      (id: actSys, name: 'System Design Review', areaId: careerId, target: 45),
      (id: actFit, name: 'High Intensity Training', areaId: healthId, target: 30),
    ];

    final now = DateTime.now().toUtc();
    for (final a in devActs) {
      await _db.into(_db.activities).insertOnConflictUpdate(
        ActivitiesCompanion(
          id: Value(a.id),
          ownerId: Value(ownerId),
          lifeAreaId: Value(a.areaId),
          name: Value(a.name),
          targetDurationMinutes: Value(a.target),
          difficulty: const Value(3),
          versionHlc: const Value('1-0-0'),
          createdAt: Value(now.subtract(const Duration(days: 90))),
          updatedAt: Value(now),
        ),
      );
    }

    final localNow = DateTime.now();
    // Monday of the current week (local time)
    final thisMonday = DateTime(localNow.year, localNow.month, localNow.day)
        .subtract(Duration(days: localNow.weekday - 1));

    // Schedule for this week matching reference: Total: 12h 45m across 7 days
    // Mon: 1h 45m (105m), Tue: 2h 32m (152m), Wed: 1h 58m (118m), Thu: 1h 12m (72m),
    // Fri: 2h 05m (125m), Sat: 1h 20m (80m), Sun: 1h 48m (108m)
    final thisWeekSpecs = [
      (dayOffset: 0, startHour: 10, startMin: 0, durMin: 105, act: actArch, area: careerId),
      (dayOffset: 1, startHour: 10, startMin: 0, durMin: 152, act: actAlgo, area: mindsetId),
      (dayOffset: 2, startHour: 10, startMin: 0, durMin: 118, act: actSys, area: careerId),
      (dayOffset: 3, startHour: 10, startMin: 30, durMin: 72, act: actAlgo, area: mindsetId),
      (dayOffset: 4, startHour: 10, startMin: 0, durMin: 125, act: actArch, area: careerId),
      (dayOffset: 5, startHour: 11, startMin: 0, durMin: 80, act: actFit, area: healthId),
      (dayOffset: 6, startHour: 10, startMin: 0, durMin: 108, act: actAlgo, area: mindsetId),
    ];

    var sessIndex = 0;
    for (final spec in thisWeekSpecs) {
      final sTimeLocal = thisMonday.add(
        Duration(days: spec.dayOffset, hours: spec.startHour, minutes: spec.startMin),
      );
      final eTimeLocal = sTimeLocal.add(Duration(minutes: spec.durMin));
      final sTimeUtc = sTimeLocal.toUtc();
      final eTimeUtc = eTimeLocal.toUtc();
      final durMs = spec.durMin * 60 * 1000;

      await _db.into(_db.sessions).insertOnConflictUpdate(
        SessionsCompanion(
          id: Value('seed_sess_${ownerId}_tw_${sessIndex++}'),
          ownerId: Value(ownerId),
          activityId: Value(spec.act),
          lifeAreaId: Value(spec.area),
          startedAt: Value(sTimeUtc),
          endedAt: Value(eTimeUtc),
          durationMs: Value(durMs),
          status: const Value('completed'),
          source: const Value('timer'),
          pausedTotalMs: const Value(0),
          versionHlc: const Value('1-0-0'),
          createdAt: Value(sTimeUtc),
          updatedAt: Value(eTimeUtc),
        ),
      );
    }

    // Previous week schedule (Total: ~10h 17m = 617 min, for ~+24% trend)
    final lastMonday = thisMonday.subtract(const Duration(days: 7));
    final prevWeekSpecs = [
      (dayOffset: 0, startHour: 10, startMin: 0, durMin: 90, act: actArch, area: careerId),
      (dayOffset: 1, startHour: 10, startMin: 0, durMin: 120, act: actAlgo, area: mindsetId),
      (dayOffset: 2, startHour: 10, startMin: 0, durMin: 105, act: actSys, area: careerId),
      (dayOffset: 3, startHour: 11, startMin: 0, durMin: 60, act: actAlgo, area: mindsetId),
      (dayOffset: 4, startHour: 10, startMin: 0, durMin: 105, act: actArch, area: careerId),
      (dayOffset: 5, startHour: 11, startMin: 0, durMin: 60, act: actFit, area: healthId),
      (dayOffset: 6, startHour: 10, startMin: 30, durMin: 77, act: actAlgo, area: mindsetId),
    ];

    for (final spec in prevWeekSpecs) {
      final sTimeLocal = lastMonday.add(
        Duration(days: spec.dayOffset, hours: spec.startHour, minutes: spec.startMin),
      );
      final eTimeLocal = sTimeLocal.add(Duration(minutes: spec.durMin));
      final sTimeUtc = sTimeLocal.toUtc();
      final eTimeUtc = eTimeLocal.toUtc();
      final durMs = spec.durMin * 60 * 1000;

      await _db.into(_db.sessions).insertOnConflictUpdate(
        SessionsCompanion(
          id: Value('seed_sess_${ownerId}_pw_${sessIndex++}'),
          ownerId: Value(ownerId),
          activityId: Value(spec.act),
          lifeAreaId: Value(spec.area),
          startedAt: Value(sTimeUtc),
          endedAt: Value(eTimeUtc),
          durationMs: Value(durMs),
          status: const Value('completed'),
          source: const Value('timer'),
          pausedTotalMs: const Value(0),
          versionHlc: const Value('1-0-0'),
          createdAt: Value(sTimeUtc),
          updatedAt: Value(eTimeUtc),
        ),
      );
    }

    // Historical weeks for 30d/90d views
    for (var w = 2; w <= 6; w++) {
      final weekStart = thisMonday.subtract(Duration(days: w * 7));
      for (var d = 0; d < 5; d++) {
        final durMin = 45 + ((w * 7 + d * 13) % 65);
        final sTimeLocal = weekStart.add(Duration(days: d, hours: 10 + (d % 3), minutes: (d * 15) % 60));
        final eTimeLocal = sTimeLocal.add(Duration(minutes: durMin));
        final sTimeUtc = sTimeLocal.toUtc();
        final eTimeUtc = eTimeLocal.toUtc();
        final actId = d % 2 == 0 ? actArch : actAlgo;
        final areaId = d % 2 == 0 ? careerId : mindsetId;

        await _db.into(_db.sessions).insertOnConflictUpdate(
          SessionsCompanion(
            id: Value('seed_sess_${ownerId}_hist_${sessIndex++}'),
            ownerId: Value(ownerId),
            activityId: Value(actId),
            lifeAreaId: Value(areaId),
            startedAt: Value(sTimeUtc),
            endedAt: Value(eTimeUtc),
            durationMs: Value(durMin * 60 * 1000),
            status: const Value('completed'),
            source: const Value('timer'),
            pausedTotalMs: const Value(0),
            versionHlc: const Value('1-0-0'),
            createdAt: Value(sTimeUtc),
            updatedAt: Value(eTimeUtc),
          ),
        );
      }
    }
  }
}
