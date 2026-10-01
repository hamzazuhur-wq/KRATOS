/// Single source of truth for the Phase 3 streak and freeze rules.
abstract final class StreakConfig {
  static const minimumStreakDaysForReward = 3;
  static const streakXpPerDay = 10;
  static const maxFreezes = 3;
  static const freezeWindowDays = 30;

  static int rewardForDay(int streakDay) =>
      streakDay < minimumStreakDaysForReward ? 0 : streakDay * streakXpPerDay;
}
