// ignore_for_file: public_member_api_docs
// Wave 22: Domain models for Achievement-Gated Level Promotions (ADR-010).
//
// A Life Area level promotion requires BOTH:
//   1. Cumulative XP ≥ level_curves.cumulative_xp_required for the next level.
//   2. ALL mandatory level_objectives for the current level are completed
//      (tracked as achievements with category = 'level_objective').

/// Status of a single mandatory level objective toward promotion.
enum ObjectiveStatus {
  /// Not yet started.
  notStarted,

  /// Partially complete (some sub-tasks done).
  inProgress,

  /// Completed — achievement record exists.
  completed,
}

/// A single mandatory objective that must be completed before promotion.
class PromotionObjective {
  final String objectiveId;
  final String title;
  final String description;
  final int level;
  final ObjectiveStatus status;

  const PromotionObjective({
    required this.objectiveId,
    required this.title,
    required this.description,
    required this.level,
    required this.status,
  });

  bool get isCompleted => status == ObjectiveStatus.completed;

  PromotionObjective copyWith({ObjectiveStatus? status}) => PromotionObjective(
        objectiveId: objectiveId,
        title: title,
        description: description,
        level: level,
        status: status ?? this.status,
      );
}

/// The compound gate result for a Life Area promotion evaluation.
///
/// Promotion is allowed only when [xpGatePassed] AND [allObjectivesPassed].
/// Matches the PostgreSQL `evaluate_level_promotion_gate` RPC logic.
sealed class PromotionGateResult {
  const PromotionGateResult();
}

/// XP threshold not yet reached.
class PromotionGateLocked extends PromotionGateResult {
  final int currentXp;
  final int requiredXp;
  final int currentLevel;
  final List<PromotionObjective> objectives;

  const PromotionGateLocked({
    required this.currentXp,
    required this.requiredXp,
    required this.currentLevel,
    required this.objectives,
  });

  int get xpDeficit => requiredXp - currentXp;
  double get xpProgress =>
      requiredXp > 0 ? (currentXp / requiredXp).clamp(0.0, 1.0) : 0.0;
}

/// XP threshold passed but one or more mandatory objectives incomplete.
class PromotionGatePendingObjectives extends PromotionGateResult {
  final int currentXp;
  final int requiredXp;
  final int currentLevel;
  final List<PromotionObjective> objectives;

  const PromotionGatePendingObjectives({
    required this.currentXp,
    required this.requiredXp,
    required this.currentLevel,
    required this.objectives,
  });

  List<PromotionObjective> get incomplete =>
      objectives.where((o) => !o.isCompleted).toList();

  int get completedCount => objectives.where((o) => o.isCompleted).length;
  int get totalCount => objectives.length;
  double get objectivesProgress =>
      totalCount > 0 ? completedCount / totalCount : 1.0;
}

/// All gates passed — promotion is ready to execute.
class PromotionGateReady extends PromotionGateResult {
  final int currentXp;
  final int currentLevel;
  final int nextLevel;
  final List<PromotionObjective> objectives;

  const PromotionGateReady({
    required this.currentXp,
    required this.currentLevel,
    required this.nextLevel,
    required this.objectives,
  });
}

/// Promotion was already executed; user is now at [newLevel].
class PromotionGatePromoted extends PromotionGateResult {
  final int newLevel;
  final String achievementId;
  final DateTime promotedAt;

  const PromotionGatePromoted({
    required this.newLevel,
    required this.achievementId,
    required this.promotedAt,
  });
}

// ---------------------------------------------------------------------------
// Streak Society
// ---------------------------------------------------------------------------

/// Milestone category for the Streak Society bonus.
enum StreakSocietyTier {
  /// 100 consecutive active days in a Life Area.
  centurion(days: 100, bonusFreezeTokens: 5, badge: 'centurion_100'),

  /// 200 consecutive active days.
  legend(days: 200, bonusFreezeTokens: 10, badge: 'legend_200'),

  /// 365 consecutive active days.
  immortal(days: 365, bonusFreezeTokens: 20, badge: 'immortal_365');

  const StreakSocietyTier({
    required this.days,
    required this.bonusFreezeTokens,
    required this.badge,
  });

  final int days;
  final int bonusFreezeTokens;
  final String badge;
}

/// Result of checking whether a streak qualifies for a Streak Society milestone.
class StreakSocietyMilestone {
  /// The tier that was just reached (null if no milestone reached).
  final StreakSocietyTier? tier;

  /// Number of bonus freeze tokens awarded (0 if no milestone).
  final int bonusTokensAwarded;

  /// Whether this is a new milestone (first time reaching this tier).
  final bool isNew;

  const StreakSocietyMilestone({
    required this.tier,
    required this.bonusTokensAwarded,
    required this.isNew,
  });

  /// No milestone was reached.
  const StreakSocietyMilestone.none()
      : tier = null,
        bonusTokensAwarded = 0,
        isNew = false;

  bool get hasMilestone => tier != null && isNew;
}
