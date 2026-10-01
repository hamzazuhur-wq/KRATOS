import 'package:flutter/foundation.dart';

enum AnalyticsPeriod {
  sevenDays,
  thirtyDays,
  ninetyDays,
  oneYear,
  today,
  week,
  month,
  year,
  custom,
}

extension AnalyticsPeriodLabel on AnalyticsPeriod {
  String get label => switch (this) {
    AnalyticsPeriod.sevenDays => '7D',
    AnalyticsPeriod.thirtyDays => '30D',
    AnalyticsPeriod.ninetyDays => '90D',
    AnalyticsPeriod.oneYear => '1Y',
    AnalyticsPeriod.today => 'Today',
    AnalyticsPeriod.week => 'This Week',
    AnalyticsPeriod.month => 'This Month',
    AnalyticsPeriod.year => 'This Year',
    AnalyticsPeriod.custom => 'Custom',
  };
}

@immutable
class AnalyticsDateRange {
  final DateTime start;
  final DateTime end;

  const AnalyticsDateRange({required this.start, required this.end});

  factory AnalyticsDateRange.forPeriod(
    AnalyticsPeriod period, {
    DateTime? now,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    final localNow = (now ?? DateTime.now()).toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    switch (period) {
      case AnalyticsPeriod.sevenDays:
        final start = today.subtract(const Duration(days: 6));
        return AnalyticsDateRange(
          start: start,
          end: today.add(const Duration(days: 1)),
        );
      case AnalyticsPeriod.thirtyDays:
        final start = today.subtract(const Duration(days: 29));
        return AnalyticsDateRange(
          start: start,
          end: today.add(const Duration(days: 1)),
        );
      case AnalyticsPeriod.ninetyDays:
        final start = today.subtract(const Duration(days: 89));
        return AnalyticsDateRange(
          start: start,
          end: today.add(const Duration(days: 1)),
        );
      case AnalyticsPeriod.oneYear:
        final start = today.subtract(const Duration(days: 364));
        return AnalyticsDateRange(
          start: start,
          end: today.add(const Duration(days: 1)),
        );
      case AnalyticsPeriod.today:
        return AnalyticsDateRange(
          start: today,
          end: today.add(const Duration(days: 1)),
        );
      case AnalyticsPeriod.week:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return AnalyticsDateRange(
          start: monday,
          end: monday.add(const Duration(days: 7)),
        );
      case AnalyticsPeriod.month:
        final start = DateTime(today.year, today.month);
        return AnalyticsDateRange(
          start: start,
          end: DateTime(today.year, today.month + 1),
        );
      case AnalyticsPeriod.year:
        final start = DateTime(today.year);
        return AnalyticsDateRange(start: start, end: DateTime(today.year + 1));
      case AnalyticsPeriod.custom:
        if (customStart == null || customEnd == null) {
          throw ArgumentError('Custom analytics ranges require both dates.');
        }
        final start = DateTime(
          customStart.year,
          customStart.month,
          customStart.day,
        );
        final end = DateTime(
          customEnd.year,
          customEnd.month,
          customEnd.day,
        ).add(const Duration(days: 1));
        if (!end.isAfter(start)) {
          throw ArgumentError('Analytics end date must be after start date.');
        }
        return AnalyticsDateRange(start: start, end: end);
    }
  }

  DateTime get startUtc => start.toUtc();
  DateTime get endUtc => end.toUtc();
  int get dayCount => end.difference(start).inDays;

  AnalyticsDateRange get previousRange {
    final duration = end.difference(start);
    return AnalyticsDateRange(start: start.subtract(duration), end: start);
  }
}

@immutable
class MetricDelta {
  final double current;
  final double previous;
  final double changePct;
  final bool isPositive;
  final bool isNeutral;

  const MetricDelta({
    required this.current,
    required this.previous,
    required this.changePct,
    required this.isPositive,
    this.isNeutral = false,
  });

  factory MetricDelta.compute({
    required double current,
    required double previous,
  }) {
    if (previous == 0) {
      if (current == 0) {
        return const MetricDelta(
          current: 0,
          previous: 0,
          changePct: 0,
          isPositive: true,
          isNeutral: true,
        );
      }
      return MetricDelta(
        current: current,
        previous: 0,
        changePct: 100,
        isPositive: current >= 0,
      );
    }
    final pct = ((current - previous) / previous.abs()) * 100.0;
    return MetricDelta(
      current: current,
      previous: previous,
      changePct: pct,
      isPositive: pct >= 0,
      isNeutral: pct.abs() < 0.1,
    );
  }
}

@immutable
class AnalyticsLifeAreaMetric {
  final String id;
  final String name;
  final int xp;
  final int previousXp;
  final int level;
  final String tier;
  final int currentStreak;
  final int longestStreak;
  final double progress;
  final int activityCount;
  final int completionCount;
  final double trendPct;
  final String color;

  const AnalyticsLifeAreaMetric({
    required this.id,
    required this.name,
    required this.xp,
    this.previousXp = 0,
    required this.level,
    required this.tier,
    required this.currentStreak,
    required this.longestStreak,
    this.progress = 0.0,
    this.activityCount = 0,
    this.completionCount = 0,
    this.trendPct = 0.0,
    this.color = '#C6F135',
  });
}

@immutable
class AnalyticsPoint {
  final DateTime date;
  final int xp;

  const AnalyticsPoint({required this.date, required this.xp});
}

@immutable
class DailyAnalyticsPoint {
  final DateTime date;
  final int xp;
  final int cumulativeXp;
  final int tasksCompleted;
  final int goalsCompleted;
  final int projectsCompleted;
  final int sessionsCount;
  final int decisionsCompleted;
  final int totalActivity;
  final double completionRate;
  final List<String> eventMarkers;

  const DailyAnalyticsPoint({
    required this.date,
    required this.xp,
    this.cumulativeXp = 0,
    this.tasksCompleted = 0,
    this.goalsCompleted = 0,
    this.projectsCompleted = 0,
    this.sessionsCount = 0,
    this.decisionsCompleted = 0,
    this.totalActivity = 0,
    this.completionRate = 0.0,
    this.eventMarkers = const [],
  });
}

@immutable
class GoalHealthItem {
  final String id;
  final String title;
  final String? lifeAreaId;
  final String? lifeAreaName;
  final String status;
  final double progress;
  final int? xpTarget;
  final int xpEarned;
  final int activityCount;
  final DateTime? lastActivityDate;
  final String momentum;
  final double trend;

  const GoalHealthItem({
    required this.id,
    required this.title,
    this.lifeAreaId,
    this.lifeAreaName,
    required this.status,
    required this.progress,
    this.xpTarget,
    required this.xpEarned,
    required this.activityCount,
    this.lastActivityDate,
    required this.momentum,
    required this.trend,
  });
}

@immutable
class ProjectPerformanceItem {
  final String id;
  final String title;
  final String? lifeAreaId;
  final String? lifeAreaName;
  final String status;
  final double progress;
  final int difficulty;
  final int xpEarned;
  final int tasksCount;
  final int completedTasksCount;
  final DateTime? lastActivityDate;

  const ProjectPerformanceItem({
    required this.id,
    required this.title,
    this.lifeAreaId,
    this.lifeAreaName,
    required this.status,
    required this.progress,
    required this.difficulty,
    required this.xpEarned,
    required this.tasksCount,
    required this.completedTasksCount,
    this.lastActivityDate,
  });
}

@immutable
class MilestoneItem {
  final String id;
  final String title;
  final String description;
  final String category; // 'Level Up', 'Goal Completed', 'Project Completed', 'Streak', 'Achievement', 'XP Milestone'
  final DateTime date;
  final int? xp;

  const MilestoneItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.date,
    this.xp,
  });
}

@immutable
class RecentActivityItem {
  final String id;
  final String title;
  final String sourceType;
  final int points;
  final DateTime timestamp;
  final String? lifeAreaName;

  const RecentActivityItem({
    required this.id,
    required this.title,
    required this.sourceType,
    required this.points,
    required this.timestamp,
    this.lifeAreaName,
  });
}

@immutable
class AnalyticsInsightItem {
  final String title;
  final String description;
  final String icon;
  final bool isPositive;

  const AnalyticsInsightItem({
    required this.title,
    required this.description,
    required this.icon,
    this.isPositive = true,
  });
}

@immutable
class AnalyticsSnapshot {
  final AnalyticsDateRange range;
  final String? lifeAreaId;
  final int totalXp;
  final int previousTotalXp;
  final MetricDelta xpDelta;
  final int positiveXp;
  final int negativeXp;
  final MetricDelta xpVelocityDelta;
  final MetricDelta completionRateDelta;
  final MetricDelta consistencyDelta;

  // Tracked work metrics
  final int activeGoals;
  final int completedGoals;
  final int createdGoals;
  final int activeProjects;
  final int completedProjects;
  final int createdProjects;
  final int activeTasks;
  final int completedTasks;
  final int createdTasks;
  final int createdDecisions;
  final int completedDecisions;
  final int activitiesStarted;
  final int sessionsCompleted;
  final int actualMinutes;
  final int currentStreak;
  final int longestStreak;
  final int activeDaysCount;

  // Breakdown & Time Series
  final List<AnalyticsPoint> xpOverTime;
  final List<DailyAnalyticsPoint> dailyGrowthSeries;
  final Map<String, int> xpBySource;
  final List<AnalyticsLifeAreaMetric> lifeAreas;
  final List<GoalHealthItem> goalHealth;
  final List<ProjectPerformanceItem> projectPerformance;
  final Map<int, int> tasksByPriority;
  final Map<String, int> tasksByLifeArea;
  final Map<int, int> activityByDayOfWeek; // 1 = Mon .. 7 = Sun
  final Map<String, int>
  activityByTimeOfDay; // 'Morning', 'Afternoon', 'Evening', 'Night'
  final List<MilestoneItem> milestones;
  final List<RecentActivityItem> recentActivity;
  final List<AnalyticsInsightItem> insights;

  const AnalyticsSnapshot({
    required this.range,
    required this.lifeAreaId,
    required this.totalXp,
    this.previousTotalXp = 0,
    required this.xpDelta,
    required this.positiveXp,
    required this.negativeXp,
    required this.xpVelocityDelta,
    required this.completionRateDelta,
    required this.consistencyDelta,
    required this.activeGoals,
    required this.completedGoals,
    this.createdGoals = 0,
    required this.activeProjects,
    required this.completedProjects,
    this.createdProjects = 0,
    required this.activeTasks,
    required this.completedTasks,
    this.createdTasks = 0,
    this.createdDecisions = 0,
    this.completedDecisions = 0,
    required this.activitiesStarted,
    required this.sessionsCompleted,
    required this.actualMinutes,
    required this.currentStreak,
    required this.longestStreak,
    this.activeDaysCount = 0,
    required this.xpOverTime,
    this.dailyGrowthSeries = const [],
    required this.xpBySource,
    required this.lifeAreas,
    this.goalHealth = const [],
    this.projectPerformance = const [],
    this.tasksByPriority = const {},
    this.tasksByLifeArea = const {},
    this.activityByDayOfWeek = const {},
    this.activityByTimeOfDay = const {},
    this.milestones = const [],
    this.recentActivity = const [],
    this.insights = const [],
  });

  int get totalTrackedItems => activeTasks + activeGoals + activeProjects;
  double get taskCompletionRate => (activeTasks + completedTasks) == 0
      ? 0.0
      : (completedTasks /
            (activeTasks + completedTasks > 0
                ? (activeTasks + completedTasks)
                : 1) *
            100.0);
}
