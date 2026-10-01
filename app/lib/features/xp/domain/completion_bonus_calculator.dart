/// Central rules for Phase 4 Goal and Project completion bonuses.
class CompletionBonusCalculator {
  const CompletionBonusCalculator._();

  static const double completionBonusRate = 0.30;

  /// Returns a non-negative integer bonus using Dart's standard ROUND rule.
  static int calculate(int eligibleXp) {
    if (eligibleXp <= 0) return 0;
    return (eligibleXp * completionBonusRate).round();
  }
}
