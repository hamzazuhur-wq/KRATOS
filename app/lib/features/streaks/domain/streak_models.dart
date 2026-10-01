// Wave 7: Streak domain models.
// Pure Dart — represents streaks, freeze inventory, and milestone statuses.

import '../../../domain/ids.dart';

class StreakInfo {
  final Id userId;
  final Id lifeAreaId;
  final int currentStreak;
  final int longestStreak;
  final int freezeTokensAvailable;
  final DateTime? lastActiveDate;
  @Deprecated(
    'Phase 3 uses a separate daily streak XP event, not a multiplier.',
  )
  bool get isWeeklyBonusActive => false;

  const StreakInfo({
    required this.userId,
    required this.lifeAreaId,
    required this.currentStreak,
    required this.longestStreak,
    required this.freezeTokensAvailable,
    this.lastActiveDate,
  });

  /// Factory calculating derived milestone attributes.
  factory StreakInfo.create({
    required Id userId,
    required Id lifeAreaId,
    required int currentStreak,
    required int longestStreak,
    required int freezeTokensAvailable,
    DateTime? lastActiveDate,
  }) {
    return StreakInfo(
      userId: userId,
      lifeAreaId: lifeAreaId,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      freezeTokensAvailable: freezeTokensAvailable,
      lastActiveDate: lastActiveDate,
    );
  }
}
