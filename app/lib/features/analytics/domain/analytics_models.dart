import 'package:flutter/foundation.dart';

import 'focus_time_models.dart';
export 'focus_time_models.dart';
import 'positive_trend_models.dart';
export 'positive_trend_models.dart';

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

  String get comparisonLabel => switch (this) {
    AnalyticsPeriod.sevenDays => 'vs previous 7 days',
    AnalyticsPeriod.thirtyDays => 'vs previous 30 days',
    AnalyticsPeriod.ninetyDays => 'vs previous 90 days',
    AnalyticsPeriod.year => 'vs previous year',
    AnalyticsPeriod.oneYear => 'vs previous period',
    AnalyticsPeriod.today => 'vs yesterday',
    AnalyticsPeriod.week => 'vs previous week',
    AnalyticsPeriod.month => 'vs previous month',
    AnalyticsPeriod.custom => 'vs previous period',
  };
}

@immutable
class AnalyticsDateRange {
  final DateTime start;
  final DateTime end;
  final AnalyticsPeriod? period;

  const AnalyticsDateRange({
    required this.start,
    required this.end,
    this.period,
  });

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
          period: period,
        );
      case AnalyticsPeriod.thirtyDays:
        final start = today.subtract(const Duration(days: 29));
        return AnalyticsDateRange(
          start: start,
          end: today.add(const Duration(days: 1)),
          period: period,
        );
      case AnalyticsPeriod.ninetyDays:
        final start = today.subtract(const Duration(days: 89));
        return AnalyticsDateRange(
          start: start,
          end: today.add(const Duration(days: 1)),
          period: period,
        );
      case AnalyticsPeriod.oneYear:
        final start = today.subtract(const Duration(days: 364));
        return AnalyticsDateRange(
          start: start,
          end: today.add(const Duration(days: 1)),
          period: period,
        );
      case AnalyticsPeriod.today:
        return AnalyticsDateRange(
          start: today,
          end: today.add(const Duration(days: 1)),
          period: period,
        );
      case AnalyticsPeriod.week:
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return AnalyticsDateRange(
          start: monday,
          end: monday.add(const Duration(days: 7)),
          period: period,
        );
      case AnalyticsPeriod.month:
        final start = DateTime(today.year, today.month);
        return AnalyticsDateRange(
          start: start,
          end: DateTime(today.year, today.month + 1),
          period: period,
        );
      case AnalyticsPeriod.year:
        final start = DateTime(today.year);
        return AnalyticsDateRange(
          start: start,
          end: DateTime(today.year + 1),
          period: period,
        );
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
        return AnalyticsDateRange(start: start, end: end, period: period);
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

  bool get isNegative => !isPositive && !isNeutral;
  String get formattedPercent =>
      '${changePct >= 0 ? '+' : ''}${changePct.toStringAsFixed(1)}%';
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
  final String? sourceType;
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
  final int periodCompletedTasks;
  final int previousCompletedTasks;
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
  final List<AnalyticsPoint> previousXpOverTime;
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
  final List<AnalyticsSkillMetric> topSkills;
  final FocusTimeSnapshot? focusTime;
  final List<PositiveTrendInsight>? positiveTrends;

  const AnalyticsSnapshot({
    required this.range,
    required this.lifeAreaId,
    this.sourceType,
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
    this.periodCompletedTasks = 0,
    this.previousCompletedTasks = 0,
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
    this.previousXpOverTime = const [],
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
    this.topSkills = const [],
    this.focusTime,
    this.positiveTrends,
  });

  FocusTimeSnapshot get safeFocusTime => focusTime ?? FocusTimeSnapshot.empty(range);

  List<PositiveTrendInsight> get safePositiveTrends =>
      positiveTrends ?? PositiveTrendDetector.detect(this);

  List<PositiveTrendInsight> get previewPositiveTrends =>
      safePositiveTrends.take(3).toList();

  int get periodTasksCount =>
      periodCompletedTasks > 0
          ? periodCompletedTasks
          : dailyGrowthSeries.fold<int>(0, (sum, p) => sum + p.tasksCompleted);

  MetricDelta get tasksDelta => MetricDelta.compute(
    current: periodTasksCount.toDouble(),
    previous: previousCompletedTasks.toDouble(),
  );

  int get totalTrackedItems => activeTasks + activeGoals + activeProjects;
  double get taskCompletionRate => (activeTasks + completedTasks) == 0
      ? 0.0
      : (completedTasks /
            (activeTasks + completedTasks > 0
                ? (activeTasks + completedTasks)
                : 1) *
            100.0);
}

/// Documented KRATOS Skill ranks: D, C, B, A, S.
/// Distinct from Life Area tiers (Foundation, Momentum, Bronze, Silver, Gold, Crystal, etc.).
enum SkillRank {
  d('D', 1),
  c('C', 2),
  b('B', 3),
  a('A', 4),
  s('S', 5);

  final String label;
  final int level;
  int get masteryLevel => level;

  const SkillRank(this.label, this.level);

  static SkillRank fromMasteryLevel(int masteryLevel) {
    if (masteryLevel >= 5) return SkillRank.s;
    if (masteryLevel == 4) return SkillRank.a;
    if (masteryLevel == 3) return SkillRank.b;
    if (masteryLevel == 2) return SkillRank.c;
    return SkillRank.d;
  }
}

/// Production model for Top Skills in KRATOS Analytics.
/// Captures authoritative period metric, historical XP, comparison deltas,
/// real activity/completion counts, and daily time-series points.
@immutable
class AnalyticsSkillMetric {
  final String id;
  final String name;
  final String? description;
  final String? icon;
  final String? groupId;
  final String? groupName;
  final SkillRank rank;
  final int masteryLevel;
  final int level;
  final int xp; // Authoritative period XP (or all-time XP if all-time period is selected)
  final int totalXp; // All-time XP
  final int previousXp; // XP in previous comparison period
  final MetricDelta delta; // Growth/change delta
  final double contributionPct; // % of total skill XP across the active dataset
  final int activityCount; // Associated activities, tasks, sessions
  final int completedTasksCount; // Completed tasks linked to this skill
  final int sessionMinutes; // Minutes spent in sessions linked to this skill
  final List<AnalyticsPoint> xpOverTime; // Daily XP time series in period
  final List<AnalyticsPoint> previousXpOverTime; // Daily XP time series in previous period
  final List<String> lifeAreaIds;
  final List<String> lifeAreaNames;

  AnalyticsSkillMetric({
    required this.id,
    required this.name,
    this.description,
    this.icon,
    this.groupId,
    this.groupName,
    required this.rank,
    int? masteryLevel,
    int? level,
    int? xp,
    int? periodXp,
    int? totalXp,
    int? allTimeXp,
    int? previousXp,
    int? previousPeriodXp,
    MetricDelta? delta,
    MetricDelta? xpDelta,
    this.contributionPct = 0.0,
    this.activityCount = 0,
    this.completedTasksCount = 0,
    int? sessionMinutes,
    int? focusMinutes,
    int? sessionsCount,
    this.xpOverTime = const [],
    this.previousXpOverTime = const [],
    this.lifeAreaIds = const [],
    this.lifeAreaNames = const [],
    String? lifeAreaId,
    String? lifeAreaName,
  })  : masteryLevel = masteryLevel ?? rank.level,
        level = level ?? rank.level,
        xp = xp ?? periodXp ?? 0,
        totalXp = totalXp ?? allTimeXp ?? 0,
        previousXp = previousXp ?? previousPeriodXp ?? 0,
        delta = delta ??
            xpDelta ??
            const MetricDelta(
              current: 0,
              previous: 0,
              changePct: 0,
              isPositive: true,
              isNeutral: true,
            ),
        sessionMinutes = sessionMinutes ??
            focusMinutes ??
            (sessionsCount != null ? sessionsCount * 30 : 0);

  int get periodXp => xp;
  int get allTimeXp => totalXp;
  MetricDelta get xpDelta => delta;
  int get focusMinutes => sessionMinutes;
  int get sessionsCount => sessionMinutes > 0 ? (sessionMinutes ~/ 30) : 0;
  String? get lifeAreaName =>
      lifeAreaNames.isNotEmpty ? lifeAreaNames.first : null;
  String? get lifeAreaId =>
      lifeAreaIds.isNotEmpty ? lifeAreaIds.first : null;
}
