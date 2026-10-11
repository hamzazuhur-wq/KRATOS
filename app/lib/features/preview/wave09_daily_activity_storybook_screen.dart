import 'package:flutter/material.dart';

import '../../app/kratos_theme_controller.dart';
import '../analytics/domain/analytics_models.dart';
import '../analytics/presentation/widgets/analytics_daily_activity_card.dart';

/// Wave 09: This Week / Daily Activity Storybook Screen.
///
/// Exhaustive interactive visual QA harness for the Daily Activity section:
/// 1. Standard Week (7 days with Thursday peak matching visual spec)
/// 2. Zero State (all 0 XP, 0 tasks, clean empty baseline, no fake data)
/// 3. Partial Data: XP Only (XP exists, 0 tasks)
/// 4. Partial Data: Tasks Only (0 XP, tasks exist)
/// 5. Deterministic Tie-Breaker (equal XP, tie broken by tasks)
/// 6. Loading Skeleton State
/// 7. 30-Day Range (longer series testing responsiveness)
/// 8. Large Numbers (> 10,000 XP values)
/// 9. Themes: Dark Volcanic & Light Architectural Ceramic
class Wave09DailyActivityStorybookScreen extends StatefulWidget {
  const Wave09DailyActivityStorybookScreen({super.key});

  @override
  State<Wave09DailyActivityStorybookScreen> createState() =>
      _Wave09DailyActivityStorybookScreenState();
}

enum _DailyPreset {
  standardWeek,
  zeroActivity,
  xpOnly,
  tasksOnly,
  tieBreaker,
  loadingSkeleton,
  thirtyDays,
  largeNumbers,
}

enum _ViewportPreset { desktop, tablet, mobile }

class _Wave09DailyActivityStorybookScreenState
    extends State<Wave09DailyActivityStorybookScreen> {
  _DailyPreset _preset = _DailyPreset.standardWeek;
  _ViewportPreset _viewport = _ViewportPreset.desktop;
  String? _selectedLifeAreaId;
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.week;

  static const _lifeAreas = [
    (id: 'la_career', name: 'Career & Wealth'),
    (id: 'la_health', name: 'Physical Health'),
    (id: 'la_mind', name: 'Knowledge & Mind'),
  ];

  @override
  void initState() {
    super.initState();
    final p = Uri.base.queryParameters['preset'];
    if (p == 'empty' || p == 'zero' || p == 'zeroActivity') {
      _preset = _DailyPreset.zeroActivity;
    } else if (p == 'skeleton' || p == 'loading' || p == 'loadingSkeleton') {
      _preset = _DailyPreset.loadingSkeleton;
    } else if (p == 'xp_only' || p == 'xpOnly') {
      _preset = _DailyPreset.xpOnly;
    } else if (p == 'tasks_only' || p == 'tasksOnly') {
      _preset = _DailyPreset.tasksOnly;
    } else if (p == 'tie' || p == 'tieBreaker') {
      _preset = _DailyPreset.tieBreaker;
    } else if (p == '30d' || p == 'thirtyDays') {
      _preset = _DailyPreset.thirtyDays;
      _selectedPeriod = AnalyticsPeriod.thirtyDays;
    } else if (p == 'large' || p == 'largeNumbers') {
      _preset = _DailyPreset.largeNumbers;
    }
  }

  AnalyticsSnapshot _createSnapshot() {
    final now = DateTime.now().toLocal();
    final monday = now.subtract(Duration(days: now.weekday - 1));

    switch (_preset) {
      case _DailyPreset.zeroActivity:
        final days = List.generate(7, (i) {
          final date = monday.add(Duration(days: i));
          return DailyAnalyticsPoint(
            date: date,
            xp: 0,
            tasksCompleted: 0,
            goalsCompleted: 0,
            projectsCompleted: 0,
            sessionsCount: 0,
          );
        });
        return AnalyticsSnapshot(
          range: AnalyticsDateRange(start: monday, end: monday.add(const Duration(days: 7)), period: AnalyticsPeriod.week),
          lifeAreaId: _selectedLifeAreaId,
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

      case _DailyPreset.xpOnly:
        final xpVals = [320, 180, 260, 380, 220, 90, 150];
        final days = List.generate(7, (i) {
          final date = monday.add(Duration(days: i));
          return DailyAnalyticsPoint(
            date: date,
            xp: xpVals[i],
            tasksCompleted: 0,
          );
        });
        return _buildSnapshotFromDaily(days, prevXp: 1400, prevTasks: 0);

      case _DailyPreset.tasksOnly:
        final taskVals = [8, 5, 6, 9, 5, 2, 4];
        final days = List.generate(7, (i) {
          final date = monday.add(Duration(days: i));
          return DailyAnalyticsPoint(
            date: date,
            xp: 0,
            tasksCompleted: taskVals[i],
          );
        });
        return _buildSnapshotFromDaily(days, prevXp: 0, prevTasks: 30);

      case _DailyPreset.tieBreaker:
        // Mon and Thu both have 380 XP, but Thu has 9 tasks vs Mon's 4
        final days = [
          DailyAnalyticsPoint(date: monday, xp: 380, tasksCompleted: 4),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 1)), xp: 180, tasksCompleted: 5),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 2)), xp: 260, tasksCompleted: 6),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 3)), xp: 380, tasksCompleted: 9),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 4)), xp: 220, tasksCompleted: 5),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 5)), xp: 90, tasksCompleted: 2),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 6)), xp: 150, tasksCompleted: 4),
        ];
        return _buildSnapshotFromDaily(days, prevXp: 1500, prevTasks: 32);

      case _DailyPreset.largeNumbers:
        final days = [
          DailyAnalyticsPoint(date: monday, xp: 12400, tasksCompleted: 28),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 1)), xp: 8900, tasksCompleted: 15),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 2)), xp: 15600, tasksCompleted: 34),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 3)), xp: 21000, tasksCompleted: 42),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 4)), xp: 9400, tasksCompleted: 18),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 5)), xp: 4200, tasksCompleted: 8),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 6)), xp: 7500, tasksCompleted: 12),
        ];
        return _buildSnapshotFromDaily(days, prevXp: 68000, prevTasks: 130);

      case _DailyPreset.thirtyDays:
        final start30 = now.subtract(const Duration(days: 29));
        final days = List.generate(30, (i) {
          final date = start30.add(Duration(days: i));
          final xp = ((i % 7) == 3) ? 380 : ((i % 7) * 45 + 80);
          final tasks = ((i % 7) == 3) ? 9 : ((i % 5) + 2);
          return DailyAnalyticsPoint(date: date, xp: xp, tasksCompleted: tasks);
        });
        return _buildSnapshotFromDaily(
          days,
          prevXp: 4500,
          prevTasks: 110,
          period: AnalyticsPeriod.thirtyDays,
        );

      case _DailyPreset.standardWeek:
      case _DailyPreset.loadingSkeleton:
        // Matches visual reference exactly: Mon 320/8, Tue 180/5, Wed 260/6, Thu 380/9, Fri 220/5, Sat 90/2, Sun 150/4
        final days = [
          DailyAnalyticsPoint(date: monday, xp: 320, tasksCompleted: 8),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 1)), xp: 180, tasksCompleted: 5),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 2)), xp: 260, tasksCompleted: 6),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 3)), xp: 380, tasksCompleted: 9),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 4)), xp: 220, tasksCompleted: 5),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 5)), xp: 90, tasksCompleted: 2),
          DailyAnalyticsPoint(date: monday.add(const Duration(days: 6)), xp: 150, tasksCompleted: 4),
        ];
        return _buildSnapshotFromDaily(days, prevXp: 1428, prevTasks: 33);
    }
  }

  AnalyticsSnapshot _buildSnapshotFromDaily(
    List<DailyAnalyticsPoint> days, {
    required int prevXp,
    required int prevTasks,
    AnalyticsPeriod period = AnalyticsPeriod.week,
  }) {
    final totalXp = days.fold<int>(0, (sum, d) => sum + d.xp);
    final totalTasks = days.fold<int>(0, (sum, d) => sum + d.tasksCompleted);

    final start = days.first.date;
    final end = days.last.date.add(const Duration(days: 1));

    return AnalyticsSnapshot(
      range: AnalyticsDateRange(start: start, end: end, period: period),
      lifeAreaId: _selectedLifeAreaId,
      totalXp: totalXp,
      previousTotalXp: prevXp,
      xpDelta: MetricDelta.compute(current: totalXp.toDouble(), previous: prevXp.toDouble()),
      positiveXp: totalXp,
      negativeXp: 0,
      xpVelocityDelta: const MetricDelta(current: 220, previous: 195, changePct: 12.8, isPositive: true),
      completionRateDelta: const MetricDelta(current: 78, previous: 72, changePct: 8.3, isPositive: true),
      consistencyDelta: const MetricDelta(current: 85, previous: 80, changePct: 6.25, isPositive: true),
      activeGoals: 3,
      completedGoals: 2,
      activeProjects: 2,
      completedProjects: 1,
      activeTasks: 12,
      completedTasks: 39,
      periodCompletedTasks: totalTasks,
      previousCompletedTasks: prevTasks,
      activitiesStarted: 42,
      sessionsCompleted: 24,
      actualMinutes: 980,
      currentStreak: 7,
      longestStreak: 18,
      xpOverTime: [for (final d in days) AnalyticsPoint(date: d.date, xp: d.xp)],
      dailyGrowthSeries: days,
      xpBySource: {'Tasks': (totalXp * 0.65).round(), 'Goals': (totalXp * 0.35).round()},
      lifeAreas: const [],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final snapshot = _createSnapshot();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF060806) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Wave 09: This Week Storybook'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Theme Toggle
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () {
              KratosThemeController.instance.setThemeMode(
                isDark ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),
          const SizedBox(width: 8),
          // Viewport Selector
          DropdownButton<_ViewportPreset>(
            value: _viewport,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: _ViewportPreset.desktop, child: Text('Desktop (1440)')),
              DropdownMenuItem(value: _ViewportPreset.tablet, child: Text('Tablet (1024)')),
              DropdownMenuItem(value: _ViewportPreset.mobile, child: Text('Mobile (430)')),
            ],
            onChanged: (v) => setState(() => _viewport = v!),
          ),
          const SizedBox(width: 8),
          // Preset Selector
          DropdownButton<_DailyPreset>(
            value: _preset,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: _DailyPreset.standardWeek, child: Text('Standard Week')),
              DropdownMenuItem(value: _DailyPreset.zeroActivity, child: Text('Zero Activity')),
              DropdownMenuItem(value: _DailyPreset.xpOnly, child: Text('XP Only')),
              DropdownMenuItem(value: _DailyPreset.tasksOnly, child: Text('Tasks Only')),
              DropdownMenuItem(value: _DailyPreset.tieBreaker, child: Text('Tie Breaker')),
              DropdownMenuItem(value: _DailyPreset.loadingSkeleton, child: Text('Loading Skeleton')),
              DropdownMenuItem(value: _DailyPreset.thirtyDays, child: Text('30 Days Range')),
              DropdownMenuItem(value: _DailyPreset.largeNumbers, child: Text('Large Numbers')),
            ],
            onChanged: (p) => setState(() => _preset = p!),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: switch (_viewport) {
                _ViewportPreset.desktop => 1340,
                _ViewportPreset.tablet => 960,
                _ViewportPreset.mobile => 430,
              },
            ),
            child: AnalyticsDailyActivityCard(
              snapshot: snapshot,
              isLoading: _preset == _DailyPreset.loadingSkeleton,
              periodSubtitle: _selectedPeriod == AnalyticsPeriod.week
                  ? 'vs previous week'
                  : 'vs previous period',
              lifeAreas: _lifeAreas,
              selectedLifeAreaId: _selectedLifeAreaId,
              onLifeAreaChanged: (id) => setState(() => _selectedLifeAreaId = id),
              selectedPeriod: _selectedPeriod,
              onPeriodChanged: (p) => setState(() => _selectedPeriod = p),
              onRetry: () {},
            ),
          ),
        ),
      ),
    );
  }
}
