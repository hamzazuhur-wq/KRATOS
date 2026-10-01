// ignore_for_file: public_member_api_docs

enum ActivityDashboardTime { today, week, month, custom }

class ActivityDashboardItem {
  final String id;
  final String name;
  final String? description;
  final String? lifeAreaId;
  final String? lifeAreaName;
  final String? categoryId;
  final String? categoryName;
  final int? targetDurationMinutes;
  final int difficulty;
  final String? xpRule;
  final int periodSessionCount;
  final int periodTrackedDurationMs;
  final int periodXpEarned;
  final int totalSessionCount;
  final int totalTrackedDurationMs;
  final int totalXpEarned;
  final DateTime? lastSessionAt;
  final List<String> skillNames;

  const ActivityDashboardItem({
    required this.id,
    required this.name,
    this.description,
    this.lifeAreaId,
    this.lifeAreaName,
    this.categoryId,
    this.categoryName,
    this.targetDurationMinutes,
    this.difficulty = 5,
    this.xpRule,
    this.periodSessionCount = 0,
    this.periodTrackedDurationMs = 0,
    this.periodXpEarned = 0,
    this.totalSessionCount = 0,
    this.totalTrackedDurationMs = 0,
    this.totalXpEarned = 0,
    this.lastSessionAt,
    this.skillNames = const [],
  });

  String get formattedPeriodDuration {
    final minutes = (periodTrackedDurationMs ~/ 60000) % 60;
    final hours = periodTrackedDurationMs ~/ 3600000;
    if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    return '${minutes}m';
  }

  String get formattedTotalDuration {
    final minutes = (totalTrackedDurationMs ~/ 60000) % 60;
    final hours = totalTrackedDurationMs ~/ 3600000;
    if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    return '${minutes}m';
  }

  String get formattedTargetDuration {
    if (targetDurationMinutes == null || targetDurationMinutes == 0) return '';
    final h = targetDurationMinutes! ~/ 60;
    final m = targetDurationMinutes! % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }
}

class ActivityDetailData {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? lifeAreaId;
  final String? lifeAreaName;
  final String? categoryId;
  final String? categoryName;
  final int? targetDurationMinutes;
  final int difficulty;
  final String? xpRule;
  final int totalSessions;
  final int totalDurationMs;
  final int averageDurationMs;
  final int totalXpEarned;
  final DateTime? lastSessionAt;
  final List<String> skillNames;

  const ActivityDetailData({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.lifeAreaId,
    this.lifeAreaName,
    this.categoryId,
    this.categoryName,
    this.targetDurationMinutes,
    this.difficulty = 5,
    this.xpRule,
    this.totalSessions = 0,
    this.totalDurationMs = 0,
    this.averageDurationMs = 0,
    this.totalXpEarned = 0,
    this.lastSessionAt,
    this.skillNames = const [],
  });

  String get formattedTotalDuration {
    final minutes = (totalDurationMs ~/ 60000) % 60;
    final hours = totalDurationMs ~/ 3600000;
    if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    return '${minutes}m';
  }

  String get formattedAverageDuration {
    final minutes = (averageDurationMs ~/ 60000) % 60;
    final hours = averageDurationMs ~/ 3600000;
    if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    return '${minutes}m';
  }

  String get formattedTargetDuration {
    if (targetDurationMinutes == null || targetDurationMinutes == 0) return 'None';
    final h = targetDurationMinutes! ~/ 60;
    final m = targetDurationMinutes! % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }
}

class ActivitySessionLogItem {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int durationMs;
  final String? note;
  final int xpEarned;

  const ActivitySessionLogItem({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.durationMs,
    this.note,
    this.xpEarned = 0,
  });

  String get formattedDuration {
    final minutes = (durationMs ~/ 60000) % 60;
    final hours = durationMs ~/ 3600000;
    if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    return '${minutes}m';
  }
}
