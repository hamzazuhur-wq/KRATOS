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
    String? sourceType,
  }) {
    final days = math.max(1, range.dayCount);
    final areaScale = lifeAreaId == null ? 1.0 : 0.45;
    final sourceScale = switch (sourceType?.toLowerCase()) {
      'task' => 0.52,
      'goal' => 0.22,
      'project' => 0.16,
      'activity' => 0.10,
      'skill' => 0.08,
      _ => 1.0,
    };

    final daily = <DailyAnalyticsPoint>[];
    final previousDaily = <AnalyticsPoint>[];
    var cumulative = 0;
    for (var index = 0; index < days; index++) {
      final date = range.start.add(Duration(days: index));
      final wave = math.sin(index / 2.8) * 54 + math.cos(index / 5.2) * 28;
      final rawXp = math.max(40, (350 + wave + (index % 7) * 11).round());
      final xp = (rawXp * areaScale * sourceScale).round();
      final tasks = math.max(1, ((3 + index % 6) * areaScale).round());
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
          completionRate: (0.68 + (index % 5) * 0.035).clamp(0.0, 1.0),
          eventMarkers: [
            if (index % 13 == 0) 'Level Up',
            if (index % 11 == 0) 'Project Completed',
            if (index % 7 == 0) 'Milestone',
            if (index % 5 == 0) 'Goal Completed',
          ],
        ),
      );

      final prevDate = range.previousRange.start.add(Duration(days: index));
      final prevWave = math.sin(index / 3.4) * 48 + math.cos(index / 4.6) * 24;
      final prevRawXp = math.max(30, (308 + prevWave + (index % 6) * 9).round());
      final prevXp = (prevRawXp * areaScale * sourceScale).round();
      previousDaily.add(AnalyticsPoint(date: prevDate, xp: prevXp));
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

    final totalXp = cumulative;
    final prevDays = math.max(1, range.previousRange.dayCount);
    final prevTotalXp = (totalXp * (prevDays / days) * 0.88).round();
    final xpDelta = MetricDelta.compute(
      current: totalXp.toDouble(),
      previous: prevTotalXp.toDouble(),
    );

    final currentVelocity = totalXp / days;
    final prevVelocity = prevTotalXp / prevDays;
    final xpVelocityDelta = MetricDelta.compute(
      current: currentVelocity,
      previous: prevVelocity,
    );

    final completionRateCurrent = switch (sourceType?.toLowerCase()) {
      'task' => 82.0,
      'goal' => 74.0,
      'project' => 68.0,
      'activity' => 88.0,
      _ => 78.0,
    };
    final completionRatePrev = completionRateCurrent - 4.5;
    final completionRateDelta = MetricDelta.compute(
      current: completionRateCurrent,
      previous: completionRatePrev,
    );

    final activeDaysCount = math.min(
      days,
      math.max(1, (days * (sourceType != null ? 0.60 : 0.72) * (lifeAreaId != null ? 0.85 : 1.0)).round()),
    );
    final consistencyPercent = (activeDaysCount / days) * 100.0;
    final prevActiveDaysCount = math.max(1, (prevDays * 0.65).round());
    final prevConsistencyPercent = (prevActiveDaysCount / prevDays) * 100.0;
    final consistencyDelta = MetricDelta.compute(
      current: consistencyPercent,
      previous: prevConsistencyPercent,
    );

    final streakVal = math.min(activeDaysCount, math.max(3, (activeDaysCount * 0.6).round()));

    final mockSkillDefs = [
      (
        id: 'skill-1',
        name: 'Systems Architecture',
        group: 'Software Engineering',
        areaId: 'mock-area-1',
        areaName: 'Professional',
        rank: SkillRank.s,
        baseXp: 3840,
        allTime: 18450,
        prevRatio: 0.78,
        tasks: 28,
        sessions: 14,
        minutes: 620,
      ),
      (
        id: 'skill-2',
        name: 'Deep Work & Focus',
        group: 'Cognitive Mastery',
        areaId: 'mock-area-2',
        areaName: 'Mindset',
        rank: SkillRank.a,
        baseXp: 2620,
        allTime: 12800,
        prevRatio: 0.84,
        tasks: 19,
        sessions: 22,
        minutes: 840,
      ),
      (
        id: 'skill-3',
        name: 'Data Analysis',
        group: 'Analytics & Strategy',
        areaId: 'mock-area-1',
        areaName: 'Professional',
        rank: SkillRank.a,
        baseXp: 2150,
        allTime: 9600,
        prevRatio: 0.89,
        tasks: 16,
        sessions: 11,
        minutes: 480,
      ),
      (
        id: 'skill-4',
        name: 'Technical Writing',
        group: 'Communication',
        areaId: 'mock-area-5',
        areaName: 'Learning',
        rank: SkillRank.b,
        baseXp: 1640,
        allTime: 7200,
        prevRatio: 1.08,
        tasks: 12,
        sessions: 8,
        minutes: 360,
      ),
      (
        id: 'skill-5',
        name: 'Problem Decomposition',
        group: 'Strategic Thinking',
        areaId: 'mock-area-2',
        areaName: 'Mindset',
        rank: SkillRank.b,
        baseXp: 1280,
        allTime: 5400,
        prevRatio: 0.92,
        tasks: 10,
        sessions: 6,
        minutes: 270,
      ),
      (
        id: 'skill-6',
        name: 'Agile Execution',
        group: 'Project Delivery',
        areaId: 'mock-area-1',
        areaName: 'Professional',
        rank: SkillRank.c,
        baseXp: 960,
        allTime: 3900,
        prevRatio: 0.85,
        tasks: 8,
        sessions: 5,
        minutes: 210,
      ),
    ];

    final filteredSkillDefs = mockSkillDefs.where((s) {
      if (lifeAreaId != null && s.areaId != lifeAreaId) return false;
      return true;
    }).toList();

    var totalMockSkillXp = 0;
    final computedSkillRows = filteredSkillDefs.map((def) {
      final pXp = (def.baseXp * areaScale * sourceScale).round();
      final prevXp = (pXp * def.prevRatio).round();
      totalMockSkillXp += pXp;
      return (def: def, pXp: pXp, prevXp: prevXp);
    }).toList();

    final mockTopSkills = computedSkillRows.map((item) {
      final def = item.def;
      final pXp = item.pXp;
      final prevXp = item.prevXp;
      final delta = MetricDelta.compute(
        current: pXp.toDouble(),
        previous: prevXp.toDouble(),
      );
      final contribution = totalMockSkillXp > 0
          ? (pXp / totalMockSkillXp) * 100.0
          : 0.0;

      final skillDaily = <AnalyticsPoint>[];
      final skillPrevDaily = <AnalyticsPoint>[];
      for (var idx = 0; idx < days; idx++) {
        final d = range.start.add(Duration(days: idx));
        final factor = (math.sin((idx + def.tasks) / 2.0) + 1.2) / 2.4;
        final dayXp = ((pXp / days) * factor).round();
        skillDaily.add(AnalyticsPoint(date: d, xp: math.max(0, dayXp)));

        final prevD = range.previousRange.start.add(Duration(days: idx));
        final prevDayXp = ((prevXp / days) * factor).round();
        skillPrevDaily.add(AnalyticsPoint(date: prevD, xp: math.max(0, prevDayXp)));
      }

      return AnalyticsSkillMetric(
        id: def.id,
        name: def.name,
        groupName: def.group,
        lifeAreaId: def.areaId,
        lifeAreaName: def.areaName,
        rank: def.rank,
        periodXp: pXp,
        previousPeriodXp: prevXp,
        xpDelta: delta,
        allTimeXp: (def.allTime * areaScale).round(),
        contributionPct: contribution,
        activityCount: def.tasks + def.sessions,
        completedTasksCount: def.tasks,
        sessionsCount: def.sessions,
        focusMinutes: def.minutes,
        xpOverTime: skillDaily,
        previousXpOverTime: skillPrevDaily,
      );
    }).toList();

    final totalTasksInPeriod = daily.fold<int>(0, (sum, d) => sum + d.tasksCompleted);
    final prevTasksInPeriod = (totalTasksInPeriod * 0.85).round();

    return AnalyticsSnapshot(
      range: range,
      lifeAreaId: lifeAreaId,
      sourceType: sourceType,
      totalXp: totalXp,
      previousTotalXp: prevTotalXp,
      xpDelta: xpDelta,
      positiveXp: totalXp,
      negativeXp: 0,
      xpVelocityDelta: xpVelocityDelta,
      completionRateDelta: completionRateDelta,
      consistencyDelta: consistencyDelta,
      activeGoals: 3,
      completedGoals: 8,
      createdGoals: 11,
      activeProjects: 2,
      completedProjects: 5,
      createdProjects: 7,
      activeTasks: 34,
      completedTasks: 92,
      periodCompletedTasks: totalTasksInPeriod,
      previousCompletedTasks: prevTasksInPeriod,
      createdTasks: 118,
      createdDecisions: 23,
      completedDecisions: 18,
      activitiesStarted: 156,
      sessionsCompleted: 74,
      actualMinutes: 2840,
      currentStreak: streakVal,
      longestStreak: math.max(streakVal + 5, 14),
      activeDaysCount: activeDaysCount,
      xpOverTime: [
        for (final point in daily)
          AnalyticsPoint(date: point.date, xp: point.xp),
      ],
      previousXpOverTime: previousDaily,
      dailyGrowthSeries: daily,
      xpBySource: {
        'Tasks': (sourceType == null || sourceType.toLowerCase() == 'task')
            ? (6490 * areaScale).round()
            : 0,
        'Goals': (sourceType == null || sourceType.toLowerCase() == 'goal')
            ? (2620 * areaScale).round()
            : 0,
        'Projects': (sourceType == null || sourceType.toLowerCase() == 'project')
            ? (1872 * areaScale).round()
            : 0,
        'Habits & Focus': (sourceType == null ||
                sourceType.toLowerCase() == 'activity' ||
                sourceType.toLowerCase() == 'session')
            ? (1240 * areaScale).round()
            : 0,
        'Skills': (sourceType == null || sourceType.toLowerCase() == 'skill')
            ? (850 * areaScale).round()
            : 0,
        'Decisions': (sourceType == null) ? (998 * areaScale).round() : 0,
        'Other': (sourceType == null) ? (500 * areaScale).round() : 0,
      },
      lifeAreas: areas,
      topSkills: mockTopSkills,
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
      focusTime: _buildMockFocusTime(range, lifeAreaId),
    );
  }

  static FocusTimeSnapshot _buildMockFocusTime(
    AnalyticsDateRange range,
    String? lifeAreaId,
  ) {
    final prev = FocusTimeAggregator.previousRange(range);
    final records = <FocusSessionRecord>[];

    // Reference weekday specs: Mon=105m, Tue=152m, Wed=118m, Thu=72m, Fri=125m, Sat=80m, Sun=108m
    const durMinutesByWeekday = [105, 152, 118, 72, 125, 80, 108];
    const actNames = [
      'Software Architecture',
      'Deep Focus & Algorithms',
      'System Design Review',
      'Deep Focus & Algorithms',
      'Software Architecture',
      'Athletic Conditioning',
      'Deep Focus & Algorithms',
    ];
    const areaIds = [
      'mock-area-1',
      'mock-area-2',
      'mock-area-1',
      'mock-area-2',
      'mock-area-1',
      'mock-area-3',
      'mock-area-2',
    ];

    var id = 0;
    // Iterate from prev.start to range.end
    for (var d = DateTime(prev.start.year, prev.start.month, prev.start.day);
        d.isBefore(range.end);
        d = DateTime(d.year, d.month, d.day + 1)) {
      final wIndex = d.weekday - 1;
      final area = areaIds[wIndex];
      if (lifeAreaId != null && area != lifeAreaId) continue;

      // Slight scale difference for previous period to produce ~24% growth
      final isCurrent = !d.isBefore(range.start);
      final scale = isCurrent ? 1.0 : 0.81;
      final durMin = (durMinutesByWeekday[wIndex] * scale).round();
      if (durMin <= 0) continue;

      final startLocal = DateTime(d.year, d.month, d.day, 10, (wIndex * 7) % 30);
      final dur = Duration(minutes: durMin);
      records.add(
        FocusSessionRecord(
          id: 'mock-sess-${id++}',
          startedAt: startLocal.toUtc(),
          endedAt: startLocal.add(dur).toUtc(),
          durationMs: dur.inMilliseconds,
          lifeAreaId: area,
          activityId: 'mock-act-${wIndex + 1}',
          activityName: actNames[wIndex],
          source: 'timer',
        ),
      );
    }

    return FocusTimeAggregator.compute(
      current: records,
      previous: records,
      range: range,
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
