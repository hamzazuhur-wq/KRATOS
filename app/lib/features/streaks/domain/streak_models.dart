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
  final bool isWeeklyBonusActive; // currentStreak >= 7 (+20% bonus ADR-005)
  final bool isStreakSociety; // currentStreak >= 100

  const StreakInfo({
    required this.userId,
    required this.lifeAreaId,
    required this.currentStreak,
    required this.longestStreak,
    required this.freezeTokensAvailable,
    this.lastActiveDate,
    required this.isWeeklyBonusActive,
    required this.isStreakSociety,
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
      isWeeklyBonusActive: currentStreak >= 7,
      isStreakSociety: currentStreak >= 100,
    );
  }

  /// Calculates the +20% streak modifier in points for positive XP (ADR-005).
  int calculateStreakBonus(int basePoints) {
    if (!isWeeklyBonusActive || basePoints <= 0) return 0;
    return (basePoints * 0.20).round();
  }
}
