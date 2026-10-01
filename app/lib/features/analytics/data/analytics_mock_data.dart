import 'dart:math' as math;

import '../domain/analytics_models.dart';

/// Static presentation-only data for the Analytics prototype.
/// No database, sync, XP, domain, or Supabase dependencies are allowed here.
abstract final class AnalyticsMockData {
  static const _areaNames = <String>[
    'Professional',
    'Mindset',
    'Sport',
    'Finance',
    'Learning',
    'Relationships',
  ];

  static List<({String id, String name})> get lifeAreas => [
    for (var i = 0; i < _areaNames.length; i++)
      (id: 'mock-area-${i + 1}', name: _areaNames[i]),
  ];

  static AnalyticsSnapshot snapshot({
    required AnalyticsDateRange range,
    String? lifeAreaId,
  }) {
    final days = math.max(1, range.dayCount);
    final areaScale = lifeAreaId == null ? 1.0 : 0.72;
    final daily = <DailyAnalyticsPoint>[];
    var cumulative = 0;
    for (var index = 0; index < days; index++) {
      final date = range.start.add(Duration(days: index));
      final wave = math.sin(index / 2.8) * 54 + math.cos(index / 5.2) * 28;
      final xp = math.max(40, (350 + wave + (index % 7) * 11).round());
      final tasks = 3 + index % 6;
      final goals = index % 5 == 0 ? 1 : 0;
      final projects = index % 11 == 0 ? 1 : 0;
      final decisions = 1 + index % 3;
      final activity = tasks + goals + projects + decisions;
      cumulative += xp;
      daily.add(
        DailyAnalyticsPoint(
          date: date,
          xp: xp,
          cumulativeXp: cumulative,
          tasksCompleted: tasks,
          goalsCompleted: goals,
          projectsCompleted: projects,
          sessionsCount: 2 + index % 4,
          decisionsCompleted: decisions,
          totalActivity: activity,
          completionRate: 0.68 + (index % 5) * 0.035,
          eventMarkers: [
            if (index % 13 == 0) 'Level Up',
            if (index % 11 == 0) 'Project Completed',
            if (index % 7 == 0) 'Milestone',
            if (index % 5 == 0) 'Goal Completed',
          ],
        ),
      );
    }

    final areas = <AnalyticsLifeAreaMetric>[];
    for (var i = 0; i < _areaNames.length; i++) {
      if (lifeAreaId != null && lifeAreaId != 'mock-area-${i + 1}') continue;
      final xp = (i == 0 ? 2800 : 1950 - i * 115) * areaScale;
      areas.add(
        AnalyticsLifeAreaMetric(
          id: 'mock-area-${i + 1}',
          name: _areaNames[i],
          xp: xp.round(),
          previousXp: (xp * 0.84).round(),
          level: 6 - (i ~/ 2),
          tier: i < 2 ? 'Momentum' : 'Foundation',
          currentStreak: 4 + (i % 6),
          longestStreak: 12 + i * 3,
          progress: 0.44 + i * 0.065,
          activityCount: 18 - i,
          completionCount: 12 - (i ~/ 2),
          trendPct: 8 + i * 2.5,
          color: _colors[i],
        ),
      );
    }

    final now = range.end.subtract(const Duration(days: 1));
    final goals = [
      _goal(
        'Launch Deitle',
        'Active',
        .72,
        860,
        8,
        'On Track',
        now.subtract(const Duration(days: 1)),
      ),
      _goal(
        'Learn Programming',
        'Active',
        .48,
        520,
        5,
        'Growing',
        now.subtract(const Duration(days: 3)),
      ),
      _goal('Build KRATOS', 'Active', .86, 1240, 13, 'On Track', now),
      _goal(
        'Improve Fitness',
        'Completed',
        1,
        740,
        11,
        'Completed',
        now.subtract(const Duration(days: 6)),
      ),
    ];
    final projects = [
      _project('KRATOS Analytics', 'Active', .78, 1320, 22, 17, now),
      _project(
        'Personal OS',
        'Active',
        .54,
        880,
        16,
        9,
        now.subtract(const Duration(days: 2)),
      ),
      _project(
        'Fitness Reset',
        'Completed',
        1,
        620,
        12,
        12,
        now.subtract(const Duration(days: 5)),
      ),
    ];

    const totalXp = 12480;
    return AnalyticsSnapshot(
      range: range,
      lifeAreaId: lifeAreaId,
      totalXp: totalXp,
      previousTotalXp: 10530,
      xpDelta: const MetricDelta(
        current: 12480,
        previous: 10530,
        changePct: 18.4,
        isPositive: true,
      ),
      positiveXp: totalXp,
      negativeXp: 0,
      xpVelocityDelta: const MetricDelta(
        current: 420,
        previous: 373,
        changePct: 12.6,
        isPositive: true,
      ),
      completionRateDelta: const MetricDelta(
        current: 78,
        previous: 73.5,
        changePct: 6.2,
        isPositive: true,
      ),
      consistencyDelta: const MetricDelta(
        current: 84,
        previous: 77,
        changePct: 9.1,
        isPositive: true,
      ),
      activeGoals: 3,
      completedGoals: 8,
      createdGoals: 11,
      activeProjects: 2,
      completedProjects: 5,
      createdProjects: 7,
      activeTasks: 34,
      completedTasks: 92,
      createdTasks: 118,
      createdDecisions: 23,
      completedDecisions: 18,
      activitiesStarted: 156,
      sessionsCompleted: 74,
      actualMinutes: 2840,
      currentStreak: 9,
      longestStreak: 24,
      activeDaysCount: (days * .84).round(),
      xpOverTime: [
        for (final point in daily)
          AnalyticsPoint(date: point.date, xp: point.xp),
      ],
      dailyGrowthSeries: daily,
      xpBySource: const {
        'Tasks': 6490,
        'Goals': 2620,
        'Projects': 1872,
        'Decisions': 998,
        'Other': 500,
      },
      lifeAreas: areas,
      goalHealth: goals,
      projectPerformance: projects,
      tasksByPriority: const {1: 22, 2: 48, 3: 31, 4: 17},
      tasksByLifeArea: const {
        'Professional': 34,
        'Mindset': 22,
        'Sport': 18,
        'Finance': 15,
        'Learning': 20,
        'Relationships': 9,
      },
      activityByDayOfWeek: const {
        1: 28,
        2: 34,
        3: 25,
        4: 38,
        5: 31,
        6: 19,
        7: 14,
      },
      activityByTimeOfDay: const {
        'Morning': 48,
        'Afternoon': 62,
        'Evening': 39,
        'Night': 17,
      },
      milestones: [
        MilestoneItem(
          id: 'm1',
          title: 'Level Up',
          description: 'Reached level 12',
          category: 'Level Up',
          date: DateTime(2026, 9, 24),
          xp: 420,
        ),
        MilestoneItem(
          id: 'm2',
          title: 'Goal Completed',
          description: 'Improve Fitness completed',
          category: 'Goal Completed',
          date: DateTime(2026, 9, 20),
          xp: 240,
        ),
        MilestoneItem(
          id: 'm3',
          title: 'XP Milestone',
          description: 'Crossed 12,000 XP',
          category: 'XP Milestone',
          date: DateTime(2026, 9, 17),
          xp: 500,
        ),
        MilestoneItem(
          id: 'm4',
          title: 'Streak Milestone',
          description: 'Seven active days in a row',
          category: 'Streak',
          date: DateTime(2026, 9, 12),
        ),
      ],
      recentActivity: [
        for (var i = 0; i < 10; i++)
          RecentActivityItem(
            id: 'r$i',
            title: _recentTitles[i % _recentTitles.length],
            sourceType: _recentTypes[i % _recentTypes.length],
            points: 40 + i * 12,
            timestamp: now.subtract(Duration(hours: i * 9)),
            lifeAreaName: _areaNames[i % _areaNames.length],
          ),
      ],
      insights: const [
        AnalyticsInsightItem(
          title: 'Learning is your fastest-growing area',
          description: 'Its momentum is trending above the previous period.',
          icon: 'trending_up',
        ),
        AnalyticsInsightItem(
          title: 'Finance has had low activity recently',
          description:
              'A lighter activity pattern is visible in the current window.',
          icon: 'warning_amber',
          isPositive: false,
        ),
        AnalyticsInsightItem(
          title: 'Activity increased while completion decreased',
          description: 'This prototype surfaces the comparison without inferring causality.',
          icon: 'compare_arrows',
          isPositive: false,
        ),
      ],
    );
  }

  static GoalHealthItem _goal(
    String title,
    String status,
    double progress,
    int xp,
    int activity,
    String momentum,
    DateTime date,
  ) => GoalHealthItem(
    id: 'goal-${title.hashCode}',
    title: title,
    status: status,
    progress: progress,
    xpEarned: xp,
    activityCount: activity,
    momentum: momentum,
    trend: progress * 100,
    lastActivityDate: date,
  );
  static ProjectPerformanceItem _project(
    String title,
    String status,
    double progress,
    int xp,
    int tasks,
    int completed,
    DateTime date,
  ) => ProjectPerformanceItem(
    id: 'project-${title.hashCode}',
    title: title,
    status: status,
    progress: progress,
    difficulty: 3,
    xpEarned: xp,
    tasksCount: tasks,
    completedTasksCount: completed,
    lastActivityDate: date,
  );

  static const _colors = [
    '#C6F135',
    '#00BCD4',
    '#FF9500',
    '#7CFFB2',
    '#9B8CFF',
    '#FF6B4A',
  ];
  static const _recentTitles = [
    'Task completed',
    'Goal progress updated',
    'Project completed',
    'Decision resolved',
    'Level up',
    'Achievement unlocked',
  ];
  static const _recentTypes = [
    'task',
    'goal',
    'project',
    'decision',
    'level',
    'achievement',
  ];
}
