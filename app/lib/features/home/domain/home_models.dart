import '../../levels/data/levels_dashboard_repository.dart';
import '../../profile/domain/profile_models.dart';
import '../../streaks/domain/streak_models.dart';

class HomeWorkSummary {
  final int activeTasks;
  final int completedTasks;
  final int dueTodayTasks;
  final int overdueTasks;
  final int activeGoals;
  final int completedGoals;
  final int activeProjects;
  final int completedProjects;

  const HomeWorkSummary({
    required this.activeTasks,
    required this.completedTasks,
    required this.dueTodayTasks,
    required this.overdueTasks,
    required this.activeGoals,
    required this.completedGoals,
    required this.activeProjects,
    required this.completedProjects,
  });

  const HomeWorkSummary.empty()
      : activeTasks = 0,
        completedTasks = 0,
        dueTodayTasks = 0,
        overdueTasks = 0,
        activeGoals = 0,
        completedGoals = 0,
        activeProjects = 0,
        completedProjects = 0;
}

/// Supported actionable entity types for "Ending Today".
enum EndingTodayType { task, goal, project }

/// Represents an item that genuinely has a due date ending today.
class HomeEndingTodayItem {
  final String id;
  final String title;
  final EndingTodayType type;
  final String typeLabel;
  final String? lifeAreaName;
  final DateTime dueDate;

  const HomeEndingTodayItem({
    required this.id,
    required this.title,
    required this.type,
    required this.typeLabel,
    this.lifeAreaName,
    required this.dueDate,
  });
}

/// Supported entity types for the "Recent" section.
enum HomeRecentType { task, goal, project, session, activityEvent }

/// Represents an item recently modified, completed, or recorded.
class HomeRecentItem {
  final String id;
  final String title;
  final String subtitle;
  final HomeRecentType type;
  final DateTime timestamp;
  final bool isCompleted;

  const HomeRecentItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.timestamp,
    this.isCompleted = false,
  });
}

/// Represents the overall aggregate XP and progression range across active Life Areas.
class HomeAggregateProgression {
  final int totalXp;
  final int minRangeXp;
  final int maxRangeXp;
  final double progressPct;

  const HomeAggregateProgression({
    required this.totalXp,
    required this.minRangeXp,
    required this.maxRangeXp,
    required this.progressPct,
  });

  factory HomeAggregateProgression.empty() {
    return const HomeAggregateProgression(
      totalXp: 0,
      minRangeXp: 0,
      maxRangeXp: 100,
      progressPct: 0.0,
    );
  }
}

/// Consolidated state model for the KRATOS Home Dashboard.
class HomeDashboardData {
  final UserProfileData profile;
  final HomeAggregateProgression aggregateProgression;
  final List<LevelsDashboardEntry> lifeAreaEntries;
  final List<HomeEndingTodayItem> endingTodayItems;
  final List<HomeRecentItem> recentItems;
  final StreakInfo streakInfo;
  final HomeWorkSummary workSummary;

  const HomeDashboardData({
    required this.profile,
    required this.aggregateProgression,
    required this.lifeAreaEntries,
    required this.endingTodayItems,
    required this.recentItems,
    required this.streakInfo,
    this.workSummary = const HomeWorkSummary.empty(),
  });
}
