// Phase 1: KRATOS Base XP Economy & Difficulty System.
// Pure Dart — zero dependencies, mathematically exact.

import '../../../domain/errors.dart';

/// The four authoritative Base XP source types in KRATOS (Phase 1).
///
/// Invariants:
/// - Goal, Life Area, and Project are explicitly EXCLUDED as Base XP sources.
/// - Goal is a structural container / progress entity.
/// - Life Area is XP ownership / attribution.
/// - Project has separate progression/difficulty logic.
/// - Skill does NOT own a persistent XP balance; difficulty determines the XP
///   value of qualifying actions attributed to Life Areas.
enum BaseXpSource {
  activity,
  skill,
  task,
  subGoal,
}

/// Extension providing metadata for [BaseXpSource].
extension BaseXpSourceDetails on BaseXpSource {
  /// Maximum XP achievable for this source at difficulty 10.
  int get maxPoints => BaseXpConfig.maxPointsFor(this);

  /// Human-readable label for UI and reporting.
  String get displayName => switch (this) {
    BaseXpSource.activity => 'Activity',
    BaseXpSource.skill => 'Skill',
    BaseXpSource.task => 'Task',
    BaseXpSource.subGoal => 'Sub-Goal',
  };

  /// Machine-readable identifier matching KRATOS conventions.
  String get identifier => switch (this) {
    BaseXpSource.activity => 'activity',
    BaseXpSource.skill => 'skill',
    BaseXpSource.task => 'task',
    BaseXpSource.subGoal => 'sub_goal',
  };
}

/// Central authority for KRATOS Base XP calculations and difficulty validation.
///
/// Invariants:
/// 1. Only 4 base sources exist: Activity (30), Skill (50), Task (75), Sub-Goal (300).
/// 2. Difficulty is strictly an integer in [1, 10].
/// 3. Formula: XP = ROUND(MaxXP * Difficulty / 10).
/// 4. Centralized integer rounding guarantees zero floating-point drift.
class BaseXpConfig {
  const BaseXpConfig._();

  /// Minimum selectable difficulty.
  static const int minDifficulty = 1;

  /// Maximum selectable difficulty.
  static const int maxDifficulty = 10;

  /// Source Max XP caps:
  static const int maxActivityXp = 30;
  static const int maxSkillXp = 50;
  static const int maxTaskXp = 75;
  static const int maxSubGoalXp = 300;

  /// Returns the maximum XP for [source] (at difficulty 10).
  static int maxPointsFor(BaseXpSource source) {
    switch (source) {
      case BaseXpSource.activity:
        return maxActivityXp;
      case BaseXpSource.skill:
        return maxSkillXp;
      case BaseXpSource.task:
        return maxTaskXp;
      case BaseXpSource.subGoal:
        return maxSubGoalXp;
    }
  }

  /// Validates that [difficulty] is non-null and within [1, 10].
  ///
  /// Throws [ArgumentError] if null or outside range.
  static void validateDifficulty(int? difficulty) {
    if (difficulty == null) {
      throw ArgumentError.notNull('difficulty');
    }
    if (difficulty < minDifficulty || difficulty > maxDifficulty) {
      throw ArgumentError.value(
        difficulty,
        'difficulty',
        'Difficulty must be between $minDifficulty and $maxDifficulty inclusive.',
      );
    }
  }

  /// Validates difficulty and returns domain [ValidationError] on failure.
  static void validateDifficultyDomain(int? difficulty) {
    if (difficulty == null) {
      throw const ValidationError('difficulty', 'Difficulty must not be null');
    }
    if (difficulty < minDifficulty || difficulty > maxDifficulty) {
      throw ValidationError(
        'difficulty',
        'Difficulty ($difficulty) must be between $minDifficulty and $maxDifficulty inclusive',
      );
    }
  }

  /// Calculates Base XP for [source] and [difficulty].
  ///
  /// Formula: `ROUND(MaxXP * Difficulty / 10)`
  /// Always returns a non-negative integer.
  /// Throws [ArgumentError] if [difficulty] is null or not in [1, 10].
  static int calculate({
    required BaseXpSource source,
    required int? difficulty,
  }) {
    validateDifficulty(difficulty);
    final maxPoints = maxPointsFor(source);
    return (maxPoints * difficulty! / 10).round();
  }

  /// Convenience calculation for [BaseXpSource.activity] (Max 30).
  static int forActivity(int? difficulty) =>
      calculate(source: BaseXpSource.activity, difficulty: difficulty);

  /// Convenience calculation for [BaseXpSource.skill] (Max 50).
  static int forSkill(int? difficulty) =>
      calculate(source: BaseXpSource.skill, difficulty: difficulty);

  /// Convenience calculation for [BaseXpSource.task] (Max 75).
  static int forTask(int? difficulty) =>
      calculate(source: BaseXpSource.task, difficulty: difficulty);

  /// Convenience calculation for [BaseXpSource.subGoal] (Max 300).
  static int forSubGoal(int? difficulty) =>
      calculate(source: BaseXpSource.subGoal, difficulty: difficulty);
}

/// Alias for [BaseXpConfig] supporting alternate nomenclature.
typedef XpEconomyConfig = BaseXpConfig;
