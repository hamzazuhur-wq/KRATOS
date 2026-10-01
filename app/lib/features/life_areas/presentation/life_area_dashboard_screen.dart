import 'dart:math' as math;

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';

import 'package:intl/intl.dart';

import '../../../app/kratos_visuals.dart';
import '../../../app/kratos_tiers.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../goals/presentation/dialogs/create_goal_dialog.dart';
import '../../goals/presentation/goal_detail_screen.dart';
import '../../levels/data/levels_dashboard_repository.dart';
import '../../tasks/presentation/create_task_dialog.dart';

enum _DateFilter {
  today('Today'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  thisYear('This Year'),
  custom('Custom');

  final String label;
  const _DateFilter(this.label);
}

/// Vision & Long-Term Domain Dashboard Screen.
///
/// Replaces the legacy Live Area view with the full Vision & Long-Term review architecture:
/// - Breadcrumb context (`Vision & Long-Term > [Area Name]`)
/// - Period Date Range Bar (Today, This Week, This Month, This Year, Custom)
/// - 6-Metric KPI Strip
/// - Task Execution Progress Radial Chart + Drilldown Modal
/// - Development Effort Card + Top Point Sources + Points Breakdown Modal
/// - Goal Execution Bars (Completed vs Remaining Tasks) with tap-to-open GoalDetailScreen
/// - Time Trend Daily Chart
/// - Projects Section with progress bars
/// - What Happened Chronological Evidence Timeline
/// - Review Summary Section (Highlights, Needs Attention, Summary)
/// - Quick Actions (+ Goal, + Task, + Skill, + Project, + Activity)
class LifeAreaDashboardScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final LifeArea area;

  const LifeAreaDashboardScreen({
    super.key,
    required this.database,
    required this.ownerId,
    required this.area,
  });

  @override
  State<LifeAreaDashboardScreen> createState() =>
      _LifeAreaDashboardScreenState();
}

class _LifeAreaDashboardScreenState extends State<LifeAreaDashboardScreen> {
  _DateFilter _dateFilter = _DateFilter.thisWeek;
  DateTimeRange? _customRange;
  late Future<_DashboardSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = _loadDashboardSnapshot();
  }

  DateTimeRange _resolveDateRange() {
    final now = DateTime.now();
    switch (_dateFilter) {
      case _DateFilter.today:
        final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case _DateFilter.thisWeek:
        final weekday = now.weekday; // 1 = Mon, 7 = Sun
        final monday = now.subtract(Duration(days: weekday - 1));
        final start = DateTime(monday.year, monday.month, monday.day, 0, 0, 0);
        final sunday = monday.add(const Duration(days: 6));
        final end = DateTime(
          sunday.year,
          sunday.month,
          sunday.day,
          23,
          59,
          59,
          999,
        );
        return DateTimeRange(start: start, end: end);
      case _DateFilter.thisMonth:
        final start = DateTime(now.year, now.month, 1, 0, 0, 0);
        final nextMonth = now.month == 12
            ? DateTime(now.year + 1, 1, 1)
            : DateTime(now.year, now.month + 1, 1);
        final end = nextMonth.subtract(const Duration(milliseconds: 1));
        return DateTimeRange(start: start, end: end);
      case _DateFilter.thisYear:
        final start = DateTime(now.year, 1, 1, 0, 0, 0);
        final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
      case _DateFilter.custom:
        if (_customRange != null) {
          final start = DateTime(
            _customRange!.start.year,
            _customRange!.start.month,
            _customRange!.start.day,
            0,
            0,
            0,
          );
          final end = DateTime(
            _customRange!.end.year,
            _customRange!.end.month,
            _customRange!.end.day,
            23,
            59,
            59,
            999,
          );
          return DateTimeRange(start: start, end: end);
        }
        final start = DateTime(now.year, now.month, now.day, 0, 0, 0);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
    }
  }

  Future<_DashboardSnapshot> _loadDashboardSnapshot() async {
    final areaId = widget.area.id;
    final range = _resolveDateRange();
    final startUtc = range.start.toUtc();
    final endUtc = range.end.toUtc();

    // 1. Fetch Goals
    final allGoals =
        await (widget.database.select(widget.database.goals)
              ..where(
                (g) =>
                    g.ownerId.equals(widget.ownerId) &
                    g.lifeAreaId.equals(areaId) &
                    g.deletedAt.isNull(),
              )
              ..orderBy([(g) => drift.OrderingTerm.desc(g.createdAt)]))
            .get();

    final topLevelGoals = allGoals.where((g) => g.parentId == null).toList();
    final subGoals = allGoals.where((g) => g.parentId != null).toList();

    // 2. Fetch Tasks
    final allTasks =
        await (widget.database.select(widget.database.tasks)
              ..where(
                (t) =>
                    t.ownerId.equals(widget.ownerId) &
                    t.lifeAreaId.equals(areaId) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.createdAt)]))
            .get();

    // Completed in period
    final completedInPeriodTasks = allTasks.where((t) {
      if (t.status != 'completed' || t.completedAt == null) return false;
      return t.completedAt!.isAfter(startUtc) &&
          t.completedAt!.isBefore(endUtc);
    }).toList();

    // Currently open tasks
    final openTasks = allTasks.where((t) => t.status != 'completed').toList();
    final inProgressTasks = allTasks
        .where((t) => t.status == 'in_progress')
        .toList();
    final blockedTasks = allTasks.where((t) => t.status == 'blocked').toList();

    final totalScopedTasks = completedInPeriodTasks.length + openTasks.length;
    final taskExecutionPercent = totalScopedTasks > 0
        ? ((completedInPeriodTasks.length / totalScopedTasks) * 100).round()
        : 0;

    // 3. Fetch Projects
    final allProjects =
        await (widget.database.select(widget.database.projects)
              ..where(
                (p) =>
                    p.ownerId.equals(widget.ownerId) &
                    p.lifeAreaId.equals(areaId) &
                    p.deletedAt.isNull(),
              )
              ..orderBy([(p) => drift.OrderingTerm.desc(p.createdAt)]))
            .get();

    // 4. Fetch Activities in period
    final periodActivities =
        await (widget.database.select(widget.database.activities)
              ..where(
                (a) =>
                    a.ownerId.equals(widget.ownerId) &
                    a.lifeAreaId.equals(areaId) &
                    a.deletedAt.isNull() &
                    a.archivedAt.isNull() &
                    a.createdAt.isBiggerOrEqualValue(startUtc) &
                    a.createdAt.isSmallerOrEqualValue(endUtc),
              )
              ..orderBy([(a) => drift.OrderingTerm.desc(a.createdAt)]))
            .get();

    // 5. Fetch XP and Points breakdown
    // Query xp_allocation_lines joined with xp_ledger
    final xpQuery =
        widget.database.select(widget.database.xpAllocationLines).join([
          drift.innerJoin(
            widget.database.xpLedger,
            widget.database.xpLedger.id.equalsExp(
              widget.database.xpAllocationLines.ledgerId,
            ),
          ),
        ])..where(
          widget.database.xpLedger.ownerId.equals(widget.ownerId) &
              widget.database.xpAllocationLines.lifeAreaId.equals(areaId) &
              widget.database.xpLedger.reversalEventId.isNull() &
              widget.database.xpLedger.createdAt.isBiggerOrEqualValue(
                startUtc,
              ) &
              widget.database.xpLedger.createdAt.isSmallerOrEqualValue(endUtc),
        );

    final xpRows = await xpQuery.get();
    int totalDevPoints = 0;
    final pointsBySource = <String, int>{};
    final List<_XpEventItem> xpEvents = [];

    for (final row in xpRows) {
      final line = row.readTable(widget.database.xpAllocationLines);
      final ledger = row.readTable(widget.database.xpLedger);
      totalDevPoints += line.allocatedPoints;
      final src = ledger.sourceType.isEmpty ? 'Task' : ledger.sourceType;
      pointsBySource[src] = (pointsBySource[src] ?? 0) + line.allocatedPoints;
      xpEvents.add(
        _XpEventItem(
          id: ledger.id,
          sourceType: src,
          action: ledger.action,
          points: line.allocatedPoints,
          basePoints: ledger.basePoints ?? line.allocatedPoints,
          bonusPoints: ledger.bonusPoints,
          streakBonus: ledger.streakBonus,
          createdAt: ledger.createdAt,
        ),
      );
    }

    // Sort XP sources descending
    final sortedSources =
        pointsBySource.entries
            .map((e) => _SourcePointBreakdown(source: e.key, points: e.value))
            .toList()
          ..sort((a, b) => b.points.compareTo(a.points));

    // 6. Calculate Goals Progressed & Sub-goals Progressed
    final completedTaskGoalIds = completedInPeriodTasks
        .map((t) => t.primaryGoalId)
        .whereType<String>()
        .toSet();
    final progressedGoalIds = {...completedTaskGoalIds};

    final goalsProgressed = topLevelGoals
        .where((g) => progressedGoalIds.contains(g.id))
        .length;
    final subGoalsProgressed = subGoals
        .where((g) => progressedGoalIds.contains(g.id))
        .length;

    // 7. Calculate Projects Advanced
    final completedTaskProjectIds = completedInPeriodTasks
        .map((t) => t.projectId)
        .whereType<String>()
        .toSet();
    final projectsAdvanced = allProjects
        .where(
          (p) =>
              completedTaskProjectIds.contains(p.id) ||
              p.updatedAt.isAfter(startUtc),
        )
        .length;

    // 8. Goal Execution Rows (Completed vs Remaining per top-level goal)
    final goalRows = <_GoalExecutionRow>[];
    for (final goal in topLevelGoals) {
      final goalTasks = allTasks
          .where((t) => t.primaryGoalId == goal.id)
          .toList();
      final compTasks = goalTasks.where((t) => t.status == 'completed').length;
      final remTasks = goalTasks.length - compTasks;
      goalRows.add(
        _GoalExecutionRow(
          goal: goal,
          completedTasks: compTasks,
          remainingTasks: remTasks < 0 ? 0 : remTasks,
          totalTasks: goalTasks.length,
        ),
      );
    }

    // 9. Project Summaries with task completion
    final projectRows = <_ProjectAnalysisRow>[];
    for (final project in allProjects) {
      final pTasks = allTasks.where((t) => t.projectId == project.id).toList();
      final compTasks = pTasks.where((t) => t.status == 'completed').length;
      projectRows.add(
        _ProjectAnalysisRow(
          project: project,
          totalTasks: pTasks.length,
          completedTasks: compTasks,
          status: project.status,
        ),
      );
    }

    // 10. Daily Trend across the period (up to 14 data points)
    final trendDays = _computeDailyTrend(
      range,
      xpEvents,
      completedInPeriodTasks,
      periodActivities,
    );

    // 11. Timeline of what happened
    final timeline = <_TimelineItem>[];
    for (final t in completedInPeriodTasks) {
      timeline.add(
        _TimelineItem(
          type: _TimelineType.task,
          title: t.title,
          subtitle: 'Task completed',
          timestamp: t.completedAt ?? t.updatedAt,
          badge: 'COMPLETED',
        ),
      );
    }
    for (final a in periodActivities) {
      timeline.add(
        _TimelineItem(
          type: _TimelineType.activity,
          title: a.name,
          subtitle: a.description ?? 'Activity logged',
          timestamp: a.createdAt,
          badge: 'ACTIVITY',
        ),
      );
    }
    for (final x in xpEvents) {
      timeline.add(
        _TimelineItem(
          type: _TimelineType.xp,
          title: '+${x.points} XP from ${x.sourceType}',
          subtitle: x.action,
          timestamp: x.createdAt,
          badge: '+${x.points} XP',
        ),
      );
    }
    timeline.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return _DashboardSnapshot(
      dateRange: range,
      totalDevPoints: totalDevPoints,
      xpEventCount: xpEvents.length,
      topSources: sortedSources,
      xpEvents: xpEvents,
      tasksCompletedInPeriod: completedInPeriodTasks.length,
      tasksTotalScoped: totalScopedTasks,
      tasksOpen: openTasks.length,
      tasksInProgress: inProgressTasks.length,
      tasksBlocked: blockedTasks.length,
      taskExecutionPercent: taskExecutionPercent,
      allAreaTasks: allTasks,
      completedInPeriodTasksList: completedInPeriodTasks,
      openTasksList: openTasks,
      projectsAdvanced: projectsAdvanced,
      goalsProgressed: goalsProgressed,
      subGoalsProgressed: subGoalsProgressed,
      activitiesLogged: periodActivities.length,
      topLevelGoals: topLevelGoals,
      subGoals: subGoals,
      goalRows: goalRows,
      projectRows: projectRows,
      trend: trendDays,
      timeline: timeline,
    );
  }

  List<_DailyTrendPoint> _computeDailyTrend(
    DateTimeRange range,
    List<_XpEventItem> xpEvents,
    List<Task> completedTasks,
    List<Activity> activities,
  ) {
    final daysCount = range.end.difference(range.start).inDays + 1;
    final count = math.min(math.max(daysCount, 1), 14);
    final points = <_DailyTrendPoint>[];

    for (int i = 0; i < count; i++) {
      final dayDate = range.start.add(Duration(days: i));
      final dayStart = DateTime(
        dayDate.year,
        dayDate.month,
        dayDate.day,
        0,
        0,
        0,
      ).toUtc();
      final dayEnd = DateTime(
        dayDate.year,
        dayDate.month,
        dayDate.day,
        23,
        59,
        59,
        999,
      ).toUtc();

      int dayXp = 0;
      for (final x in xpEvents) {
        if (x.createdAt.isAfter(dayStart) && x.createdAt.isBefore(dayEnd)) {
          dayXp += x.points;
        }
      }

      int dayTasks = 0;
      for (final t in completedTasks) {
        if (t.completedAt != null &&
            t.completedAt!.isAfter(dayStart) &&
            t.completedAt!.isBefore(dayEnd)) {
          dayTasks++;
        }
      }

      int dayActivities = 0;
      for (final a in activities) {
        if (a.createdAt.isAfter(dayStart) && a.createdAt.isBefore(dayEnd)) {
          dayActivities++;
        }
      }

      points.add(
        _DailyTrendPoint(
          label: DateFormat('E d').format(dayDate),
          date: dayDate,
          xp: dayXp,
          tasksCompleted: dayTasks,
          activitiesLogged: dayActivities,
        ),
      );
    }
    return points;
  }

  void _refresh() {
    setState(() {
      _snapshotFuture = _loadDashboardSnapshot();
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 2),
      initialDateRange:
          _customRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFC6F135),
              onPrimary: Color(0xFF0D0D0D),
              surface: Color(0xFF161616),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customRange = picked;
        _dateFilter = _DateFilter.custom;
        _snapshotFuture = _loadDashboardSnapshot();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFC6F135)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.area.name.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.w900,
            letterSpacing: 1.8,
            fontSize: 15,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const KratosEnvironment(),
          FutureBuilder<_DashboardSnapshot>(
            future: _snapshotFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.redAccent,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Could not load domain dashboard',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${snapshot.error}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _refresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC6F135)),
                );
              }

              final data = snapshot.data!;
              return RefreshIndicator(
                onRefresh: () async => _refresh(),
                color: const Color(0xFFC6F135),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
                  children: [
                    // 1. Breadcrumb context
                    _buildBreadcrumb(context),
                    const SizedBox(height: 12),

                    // 2. Header
                    _buildHeader(context),
                    const SizedBox(height: 16),

                    // 3. Quick Actions
                    _buildQuickActionsBar(context),
                    const SizedBox(height: 16),

                    // 4. Date Range Filter Bar
                    _buildDateRangeBar(context, data.dateRange),
                    const SizedBox(height: 16),

                    // 5. Compact 6-Metric KPI Strip
                    _buildKpiStrip(data),
                    const SizedBox(height: 16),

                    // 6. Execution & Points Row (Task Execution Radial + Development Effort)
                    _buildExecutionAndPointsRow(context, data),
                    const SizedBox(height: 16),

                    // 7. Goal Execution Comparison
                    _buildGoalExecutionSection(context, data),
                    const SizedBox(height: 16),

                    // 8. Time Trend Section
                    _buildTimeTrendSection(data),
                    const SizedBox(height: 16),

                    // 9. Projects Section
                    _buildProjectsSection(context, data),
                    const SizedBox(height: 16),

                    // 10. What Happened Timeline Section
                    _buildWhatHappenedSection(data),
                    const SizedBox(height: 16),

                    // 11. Review Summary Section
                    _buildReviewSummarySection(data),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ 1. Breadcrumb â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildBreadcrumb(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(),
          child: const Text(
            'Vision & Long-Term',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right, color: Colors.white30, size: 14),
        const SizedBox(width: 6),
        Text(
          widget.area.name,
          style: const TextStyle(
            color: Color(0xFFC6F135),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // â”€â”€â”€ 2. Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildHeader(BuildContext context) {
    return KratosGlassCard(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC6F135).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.visibility,
                    color: Color(0xFFC6F135),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'DOMAIN DASHBOARD',
                  style: TextStyle(
                    color: Color(0xFFC6F135),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${widget.area.name} â€” Dashboard',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.area.description?.isNotEmpty == true
                  ? widget.area.description!
                  : 'Period execution, development effort and progress for this Vision domain.',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            StreamBuilder<List<LevelsDashboardEntry>>(
              stream: LevelsDashboardRepository(widget.database)
                  .watchProgressions(widget.ownerId),
              builder: (context, snapshot) {
                final entries = snapshot.data;
                final matching = entries
                    ?.where((item) => item.area.id == widget.area.id)
                    .toList();
                final entry = matching == null || matching.isEmpty
                    ? null
                    : matching.first;
                if (entry == null) return const SizedBox.shrink();
                final color = KratosTierSystem.getColor(
                  entry.progression.tier,
                  entry.progression.tierColor,
                );
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    KratosTierSystem.buildTierPill(
                      entry.progression.tier,
                      customColor: color,
                    ),
                    Text(
                      'LEVEL ${entry.progression.level}',
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      '${NumberFormat('#,###').format(entry.progression.totalXp)} XP',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ 3. Quick Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildQuickActionsBar(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ActionButton(
            icon: Icons.track_changes,
            label: '+ Goal',
            onTap: _addGoal,
          ),
          const SizedBox(width: 8),
          _ActionButton(icon: Icons.add_task, label: '+ Task', onTap: _addTask),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.psychology,
            label: '+ Skill',
            onTap: _addSkill,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.folder_special,
            label: '+ Project',
            onTap: _addProject,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.local_activity,
            label: '+ Activity',
            onTap: _addActivity,
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ 4. Date Range Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildDateRangeBar(BuildContext context, DateTimeRange range) {
    final formatter = DateFormat('MMM d, yyyy');
    final formattedText =
        '${formatter.format(range.start)} â€“ ${formatter.format(range.end)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _DateFilter.values.map((f) {
              final isSelected = _dateFilter == f;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(f.label),
                  selected: isSelected,
                  selectedColor: const Color(0xFFC6F135),
                  backgroundColor: const Color(0xFF161616),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? const Color(0xFF0D0D0D)
                        : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                    fontSize: 11,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFFC6F135)
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                  onSelected: (_) {
                    if (f == _DateFilter.custom) {
                      _pickCustomRange();
                    } else {
                      setState(() {
                        _dateFilter = f;
                        _snapshotFuture = _loadDashboardSnapshot();
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 12, color: Colors.white38),
              const SizedBox(width: 6),
              Text(
                formattedText,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // â”€â”€â”€ 5. Compact 6-Metric KPI Strip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildKpiStrip(_DashboardSnapshot data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _KpiCell(
                  label: 'Dev Points',
                  value: '+${data.totalDevPoints}',
                  hint: 'XP in this period',
                  valueColor: const Color(0xFFC6F135),
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(
                child: _KpiCell(
                  label: 'Tasks',
                  value:
                      '${data.tasksCompletedInPeriod} / ${data.tasksTotalScoped}',
                  hint: 'Done / Total scoped',
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(
                child: _KpiCell(
                  label: 'Projects',
                  value: '${data.projectsAdvanced}',
                  hint: 'Advanced in period',
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 20),
          Row(
            children: [
              Expanded(
                child: _KpiCell(
                  label: 'Goals',
                  value: '${data.goalsProgressed}',
                  hint: 'Goals progressed',
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(
                child: _KpiCell(
                  label: 'Sub-goals',
                  value: '${data.subGoalsProgressed}',
                  hint: 'Sub-goals progressed',
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white12),
              Expanded(
                child: _KpiCell(
                  label: 'Activities',
                  value: '${data.activitiesLogged}',
                  hint: 'Logged in period',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // â”€â”€â”€ 6. Execution & Points Row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildExecutionAndPointsRow(
    BuildContext context,
    _DashboardSnapshot data,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final children = [
          // Card 1: Task Execution Progress
          Expanded(
            flex: isWide ? 1 : 0,
            child: KratosGlassCard(
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TASK EXECUTION PROGRESS',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Completed tasks Ã· total scoped tasks',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: CircularProgressIndicator(
                              value: data.tasksTotalScoped > 0
                                  ? (data.tasksCompletedInPeriod /
                                        data.tasksTotalScoped)
                                  : 0.0,
                              strokeWidth: 10,
                              backgroundColor: Colors.white10,
                              color: const Color(0xFFC6F135),
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${data.taskExecutionPercent}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                              const Text(
                                'Done',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _TaskStatPill(
                          label: 'Done',
                          count: data.tasksCompletedInPeriod,
                          color: const Color(0xFFC6F135),
                        ),
                        _TaskStatPill(
                          label: 'In Progress',
                          count: data.tasksInProgress,
                          color: Colors.orangeAccent,
                        ),
                        _TaskStatPill(
                          label: 'Open',
                          count: data.tasksOpen,
                          color: Colors.white60,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => _openTaskDrilldown(context, data),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC6F135),
                        side: BorderSide(
                          color: const Color(0xFFC6F135).withValues(alpha: 0.3),
                        ),
                        minimumSize: const Size(double.infinity, 36),
                      ),
                      child: const Text(
                        'View Task Drilldown',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isWide) const SizedBox(height: 12),
          if (isWide) const SizedBox(width: 12),
          // Card 2: Development Effort
          Expanded(
            flex: isWide ? 1 : 0,
            child: KratosGlassCard(
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DEVELOPMENT EFFORT',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '+${data.totalDevPoints}',
                          style: const TextStyle(
                            color: Color(0xFFC6F135),
                            fontWeight: FontWeight.w900,
                            fontSize: 32,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Points Earned',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                    Text(
                      '${data.xpEventCount} XP events recorded in this period',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'TOP POINT SOURCES',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (data.topSources.isEmpty)
                      const Text(
                        'No Development Points recorded in this period.',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      )
                    else
                      ...data.topSources.take(3).map((s) {
                        final pct = data.totalDevPoints > 0
                            ? (s.points / data.totalDevPoints)
                            : 0.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    s.source,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                  Text(
                                    '+${s.points} XP',
                                    style: const TextStyle(
                                      color: Color(0xFFC6F135),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              LinearProgressIndicator(
                                value: pct,
                                backgroundColor: Colors.white10,
                                color: const Color(0xFFC6F135),
                                minHeight: 3,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _openPointsBreakdown(context, data),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC6F135),
                        side: BorderSide(
                          color: const Color(0xFFC6F135).withValues(alpha: 0.3),
                        ),
                        minimumSize: const Size(double.infinity, 36),
                      ),
                      child: const Text(
                        'View Points Breakdown',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ];

        return isWide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              )
            : Column(children: children);
      },
    );
  }

  // â”€â”€â”€ 7. Goal Execution Comparison â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildGoalExecutionSection(
    BuildContext context,
    _DashboardSnapshot data,
  ) {
    return KratosGlassCard(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GOAL EXECUTION â€” COMPLETED VS REMAINING TASKS',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Factual task counts per top-level goal. Tap a goal to open details.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 14),
            if (data.goalRows.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No goals linked to this Vision domain yet.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              )
            else
              ...data.goalRows.map(
                (row) => InkWell(
                  onTap: () => Navigator.of(context).push(
                    KratosMaterialPageRoute(
                      builder: (_) => GoalDetailScreen(
                        database: widget.database,
                        ownerId: widget.ownerId,
                        goalId: row.goal.id,
                      ),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                row.goal.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  '${row.completedTasks} done',
                                  style: const TextStyle(
                                    color: Color(0xFFC6F135),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  ' / ',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  '${row.remainingTasks} rem',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 14,
                                  color: Colors.white38,
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 8,
                            child: row.totalTasks == 0
                                ? Container(color: Colors.white10)
                                : Row(
                                    children: [
                                      if (row.completedTasks > 0)
                                        Expanded(
                                          flex: row.completedTasks,
                                          child: Container(
                                            color: const Color(0xFFC6F135),
                                          ),
                                        ),
                                      if (row.remainingTasks > 0)
                                        Expanded(
                                          flex: row.remainingTasks,
                                          child: Container(
                                            color: Colors.white.withValues(
                                              alpha: 0.18,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ 8. Time Trend Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildTimeTrendSection(_DashboardSnapshot data) {
    return KratosGlassCard(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TIME TREND',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Daily values across the selected period.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: data.trend.isEmpty
                  ? const Center(
                      child: Text(
                        'No trend activity in this period.',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: data.trend.map((pt) {
                        final maxXp = data.trend
                            .map((e) => e.xp)
                            .fold(1, math.max);
                        final heightFactor = maxXp > 0
                            ? (pt.xp / maxXp).clamp(0.08, 1.0)
                            : 0.08;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (pt.xp > 0)
                                  Text(
                                    '+${pt.xp}',
                                    style: const TextStyle(
                                      color: Color(0xFFC6F135),
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 60 * heightFactor,
                                  decoration: BoxDecoration(
                                    color: pt.xp > 0
                                        ? const Color(0xFFC6F135)
                                        : Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  pt.label,
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 8,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ 9. Projects Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildProjectsSection(BuildContext context, _DashboardSnapshot data) {
    return KratosGlassCard(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PROJECTS',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  '${data.projectRows.length} Total',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (data.projectRows.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'No active projects in this domain.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              )
            else
              ...data.projectRows.map((p) {
                final pct = p.totalTasks > 0
                    ? (p.completedTasks / p.totalTasks)
                    : 0.0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              p.project.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: p.status == 'active'
                                  ? const Color(0xFFC6F135)
                                        .withValues(alpha: 0.15)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              p.status.toUpperCase(),
                              style: TextStyle(
                                color: p.status == 'active'
                                    ? const Color(0xFFC6F135)
                                    : Colors.white60,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${p.completedTasks} of ${p.totalTasks} tasks completed',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '${(pct * 100).round()}%',
                            style: const TextStyle(
                              color: Color(0xFFC6F135),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: pct,
                        backgroundColor: Colors.white10,
                        color: const Color(0xFFC6F135),
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ 10. What Happened Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildWhatHappenedSection(_DashboardSnapshot data) {
    return KratosGlassCard(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WHAT HAPPENED',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Chronological evidence timeline for this period.',
              style: TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 14),
            if (data.timeline.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No recorded actions or evidence in this period.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              )
            else
              ...data.timeline.take(8).map((item) {
                IconData icon;
                Color iconColor;
                switch (item.type) {
                  case _TimelineType.task:
                    icon = Icons.check_circle_outline;
                    iconColor = const Color(0xFFC6F135);
                    break;
                  case _TimelineType.activity:
                    icon = Icons.local_activity_outlined;
                    iconColor = Colors.orangeAccent;
                    break;
                  case _TimelineType.xp:
                    icon = Icons.bolt;
                    iconColor = const Color(0xFFC6F135);
                    break;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 14),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.subtitle} â€¢ ${DateFormat('MMM d, h:mm a').format(item.timestamp.toLocal())}',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.badge,
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ 11. Review Summary Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Widget _buildReviewSummarySection(_DashboardSnapshot data) {
    return KratosGlassCard(
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'REVIEW SUMMARY',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            // Progress Highlights
            _SummaryBlock(
              title: 'PROGRESS HIGHLIGHTS',
              color: const Color(0xFFC6F135),
              items: [
                if (data.totalDevPoints > 0)
                  'Gained +${data.totalDevPoints} Dev Points from ${data.xpEventCount} activity events.',
                if (data.tasksCompletedInPeriod > 0)
                  'Completed ${data.tasksCompletedInPeriod} tasks (${data.taskExecutionPercent}% period scoped completion).',
                if (data.goalsProgressed > 0)
                  'Advanced ${data.goalsProgressed} top-level goals and ${data.subGoalsProgressed} sub-goals.',
                if (data.totalDevPoints == 0 &&
                    data.tasksCompletedInPeriod == 0)
                  'No completions recorded for this period yet. Choose a wider date range or complete pending tasks.',
              ],
            ),
            const SizedBox(height: 12),
            // Needs Attention
            _SummaryBlock(
              title: 'NEEDS ATTENTION',
              color: Colors.orangeAccent,
              items: [
                if (data.tasksBlocked > 0)
                  '${data.tasksBlocked} tasks are currently blocked and require review.',
                if (data.tasksOpen > 0)
                  '${data.tasksOpen} tasks remain pending in this domain.',
                if (data.goalRows.any(
                  (g) => g.remainingTasks > 0 && g.completedTasks == 0,
                ))
                  'Some goals have open tasks with zero progress yet.',
                if (data.tasksBlocked == 0 && data.tasksOpen == 0)
                  'All scoped tasks are clear. Domain is operating smoothly.',
              ],
            ),
          ],
        ),
      ),
    );
  }

  // â”€â”€â”€ Drilldowns â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _openTaskDrilldown(BuildContext context, _DashboardSnapshot data) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskDrilldownSheet(
        snapshot: data,
        onOpenGoal: (goalId) => Navigator.of(context).push(
          KratosMaterialPageRoute(
            builder: (_) => GoalDetailScreen(
              database: widget.database,
              ownerId: widget.ownerId,
              goalId: goalId,
            ),
          ),
        ),
      ),
    );
  }

  void _openPointsBreakdown(BuildContext context, _DashboardSnapshot data) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _PointsBreakdownSheet(areaName: widget.area.name, snapshot: data),
    );
  }

  // â”€â”€â”€ Quick Actions Handlers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _addGoal() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateGoalDialog(
        database: widget.database,
        ownerId: widget.ownerId,
        defaultLifeAreaId: widget.area.id,
        onGoalCreated: (_) {},
      ),
    );
    _refresh();
  }

  Future<void> _addTask() async {
    await showDialog<void>(
      context: context,
      builder: (_) => CreateTaskDialog(
        database: widget.database,
        ownerId: widget.ownerId,
        initialLifeAreaId: widget.area.id,
      ),
    );
    _refresh();
  }

  Future<void> _addProject() async {
    final draft = await _nameDescriptionDialog('NEW PROJECT', 'Project title');
    if (draft == null) return;
    final id = Id.uuidV7();
    final now = DateTime.now().toUtc();
    await widget.database
        .into(widget.database.projects)
        .insert(
          ProjectsCompanion.insert(
            id: id.value,
            ownerId: widget.ownerId,
            lifeAreaId: drift.Value(widget.area.id),
            title: draft.$1,
            description: drift.Value(draft.$2),
            status: 'active',
            memberIds: '[]',
            versionHlc: Hlc.now(id).toString(),
            createdAt: now,
            updatedAt: now,
          ),
        );
    _refresh();
  }

  Future<void> _addSkill() async {
    final draft = await _nameDescriptionDialog('NEW SKILL', 'Skill name');
    if (draft == null) return;
    final id = Id.uuidV7();
    final now = DateTime.now().toUtc();
    await widget.database
        .into(widget.database.skills)
        .insert(
          SkillsCompanion.insert(
            id: id.value,
            ownerId: widget.ownerId,
            name: draft.$1,
            description: drift.Value(draft.$2),
            xpTotal: 0,
            level: 1,
            icon: const drift.Value('âš¡'),
            versionHlc: Hlc.now(id).toString(),
            createdAt: now,
            updatedAt: now,
          ),
        );
    _refresh();
  }

  Future<void> _addActivity() async {
    final draft = await _nameDescriptionDialog('NEW ACTIVITY', 'Activity name');
    if (draft == null) return;
    final id = Id.uuidV7();
    final now = DateTime.now().toUtc();
    await widget.database
        .into(widget.database.activities)
        .insert(
          ActivitiesCompanion.insert(
            id: id.value,
            ownerId: widget.ownerId,
            lifeAreaId: drift.Value(widget.area.id),
            name: draft.$1,
            description: drift.Value(draft.$2),
            versionHlc: Hlc.now(id).toString(),
            createdAt: now,
            updatedAt: now,
          ),
        );
    _refresh();
  }

  Future<(String, String?)?> _nameDescriptionDialog(
    String title,
    String hint,
  ) => showDialog<(String, String?)>(
    context: context,
    builder: (_) => _NameDescriptionDialog(title: title, hint: hint),
  );
}

// â”€â”€â”€ Support Models & Snapshot â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DashboardSnapshot {
  final DateTimeRange dateRange;
  final int totalDevPoints;
  final int xpEventCount;
  final List<_SourcePointBreakdown> topSources;
  final List<_XpEventItem> xpEvents;
  final int tasksCompletedInPeriod;
  final int tasksTotalScoped;
  final int tasksOpen;
  final int tasksInProgress;
  final int tasksBlocked;
  final int taskExecutionPercent;
  final List<Task> allAreaTasks;
  final List<Task> completedInPeriodTasksList;
  final List<Task> openTasksList;
  final int projectsAdvanced;
  final int goalsProgressed;
  final int subGoalsProgressed;
  final int activitiesLogged;
  final List<Goal> topLevelGoals;
  final List<Goal> subGoals;
  final List<_GoalExecutionRow> goalRows;
  final List<_ProjectAnalysisRow> projectRows;
  final List<_DailyTrendPoint> trend;
  final List<_TimelineItem> timeline;

  const _DashboardSnapshot({
    required this.dateRange,
    required this.totalDevPoints,
    required this.xpEventCount,
    required this.topSources,
    required this.xpEvents,
    required this.tasksCompletedInPeriod,
    required this.tasksTotalScoped,
    required this.tasksOpen,
    required this.tasksInProgress,
    required this.tasksBlocked,
    required this.taskExecutionPercent,
    required this.allAreaTasks,
    required this.completedInPeriodTasksList,
    required this.openTasksList,
    required this.projectsAdvanced,
    required this.goalsProgressed,
    required this.subGoalsProgressed,
    required this.activitiesLogged,
    required this.topLevelGoals,
    required this.subGoals,
    required this.goalRows,
    required this.projectRows,
    required this.trend,
    required this.timeline,
  });
}

class _SourcePointBreakdown {
  final String source;
  final int points;
  const _SourcePointBreakdown({required this.source, required this.points});
}

class _XpEventItem {
  final String id;
  final String sourceType;
  final String action;
  final int points;
  final int basePoints;
  final int bonusPoints;
  final int streakBonus;
  final DateTime createdAt;
  const _XpEventItem({
    required this.id,
    required this.sourceType,
    required this.action,
    required this.points,
    required this.basePoints,
    required this.bonusPoints,
    required this.streakBonus,
    required this.createdAt,
  });
}

class _GoalExecutionRow {
  final Goal goal;
  final int completedTasks;
  final int remainingTasks;
  final int totalTasks;
  const _GoalExecutionRow({
    required this.goal,
    required this.completedTasks,
    required this.remainingTasks,
    required this.totalTasks,
  });
}

class _ProjectAnalysisRow {
  final Project project;
  final int totalTasks;
  final int completedTasks;
  final String status;
  const _ProjectAnalysisRow({
    required this.project,
    required this.totalTasks,
    required this.completedTasks,
    required this.status,
  });
}

class _DailyTrendPoint {
  final String label;
  final DateTime date;
  final int xp;
  final int tasksCompleted;
  final int activitiesLogged;
  const _DailyTrendPoint({
    required this.label,
    required this.date,
    required this.xp,
    required this.tasksCompleted,
    required this.activitiesLogged,
  });
}

enum _TimelineType { task, activity, xp }

class _TimelineItem {
  final _TimelineType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final String badge;
  const _TimelineItem({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.badge,
  });
}

// â”€â”€â”€ Supporting Widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFC6F135).withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFFC6F135)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiCell extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  final Color? valueColor;

  const _KpiCell({
    required this.label,
    required this.value,
    required this.hint,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          hint,
          style: const TextStyle(color: Colors.white38, fontSize: 9),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _TaskStatPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _TaskStatPill({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  final String title;
  final Color color;
  final List<String> items;

  const _SummaryBlock({
    required this.title,
    required this.color,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'â€¢ ',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Drilldown Bottom Sheets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TaskDrilldownSheet extends StatelessWidget {
  final _DashboardSnapshot snapshot;
  final ValueChanged<String>? onOpenGoal;

  const _TaskDrilldownSheet({required this.snapshot, this.onOpenGoal});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white24, width: 0.5)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'TASK DRILLDOWN',
              style: TextStyle(
                color: Color(0xFFC6F135),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${snapshot.tasksCompletedInPeriod} completed â€¢ ${snapshot.tasksOpen} open (${snapshot.taskExecutionPercent}% executed)',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'COMPLETED IN PERIOD',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            if (snapshot.completedInPeriodTasksList.isEmpty)
              const Text(
                'No completed tasks in this period.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              )
            else
              ...snapshot.completedInPeriodTasksList.map(
                (t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.check_circle,
                    color: Color(0xFFC6F135),
                  ),
                  title: Text(
                    t.title,
                    style: const TextStyle(
                      color: Colors.white,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text(
                    'Completed ${t.completedAt != null ? DateFormat('MMM d, h:mm a').format(t.completedAt!.toLocal()) : ''}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  trailing: t.primaryGoalId != null
                      ? TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onOpenGoal?.call(t.primaryGoalId!);
                          },
                          child: const Text(
                            'Open Goal',
                            style: TextStyle(
                              color: Color(0xFFC6F135),
                              fontSize: 11,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'CURRENTLY OPEN TASKS',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            if (snapshot.openTasksList.isEmpty)
              const Text(
                'No open tasks in this domain.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              )
            else
              ...snapshot.openTasksList.map(
                (t) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    t.status == 'in_progress'
                        ? Icons.play_circle
                        : Icons.radio_button_unchecked,
                    color: t.status == 'in_progress'
                        ? Colors.orangeAccent
                        : Colors.white38,
                  ),
                  title: Text(
                    t.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Status: ${t.status}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  trailing: t.primaryGoalId != null
                      ? TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            onOpenGoal?.call(t.primaryGoalId!);
                          },
                          child: const Text(
                            'Open Goal',
                            style: TextStyle(
                              color: Color(0xFFC6F135),
                              fontSize: 11,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PointsBreakdownSheet extends StatelessWidget {
  final String areaName;
  final _DashboardSnapshot snapshot;

  const _PointsBreakdownSheet({required this.areaName, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Colors.white24, width: 0.5)),
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$areaName â€” POINTS BREAKDOWN',
              style: const TextStyle(
                color: Color(0xFFC6F135),
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Total Dev Points: +${snapshot.totalDevPoints} XP (${snapshot.xpEvents.length} events)',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text(
              'POINT SOURCES SUMMARY',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            ...snapshot.topSources.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.source,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '+${s.points} XP',
                      style: const TextStyle(
                        color: Color(0xFFC6F135),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 24),
            const Text(
              'INDIVIDUAL XP LEDGER EVENTS',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            if (snapshot.xpEvents.isEmpty)
              const Text(
                'No ledger events found in this date range.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              )
            else
              ...snapshot.xpEvents.map(
                (e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bolt, color: Color(0xFFC6F135)),
                  title: Text(
                    '${e.sourceType} â€¢ ${e.action}',
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  subtitle: Text(
                    'Base: ${e.basePoints} | Bonus: ${e.bonusPoints} | Streak: ${e.streakBonus} â€¢ ${DateFormat('MMM d, h:mm a').format(e.createdAt.toLocal())}',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                  trailing: Text(
                    '+${e.points} XP',
                    style: const TextStyle(
                      color: Color(0xFFC6F135),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NameDescriptionDialog extends StatefulWidget {
  final String title;
  final String hint;

  const _NameDescriptionDialog({required this.title, required this.hint});

  @override
  State<_NameDescriptionDialog> createState() => _NameDescriptionDialogState();
}

class _NameDescriptionDialogState extends State<_NameDescriptionDialog> {
  final _title = TextEditingController();
  final _desc = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141414),
      insetPadding: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: const TextStyle(
                color: Color(0xFFC6F135),
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: widget.hint,
                labelStyle: const TextStyle(color: Colors.white60),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: TextStyle(color: Colors.white60),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final t = _title.text.trim();
                    if (t.isEmpty) return;
                    Navigator.of(context).pop((
                      t,
                      _desc.text.trim().isEmpty ? null : _desc.text.trim(),
                    ));
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFC6F135),
                    foregroundColor: const Color(0xFF0D0D0D),
                  ),
                  child: const Text(
                    'Create',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
