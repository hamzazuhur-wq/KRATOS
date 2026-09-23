// ignore_for_file: public_member_api_docs
// Wave 22: AchievementGateService — evaluates the compound promotion gate locally
// and StreakSocietyService — awards bonus freeze tokens at milestone streaks.
//
// Matches logic in server/migrations/0014_achievement_gated_promotion.sql
// `evaluate_level_promotion_gate` RPC (ADR-010).
//
// Invariant #15: All data reads are per-user; no cross-user data access.

import '../../../data/drift/app_database.dart';
import '../../../domain/ids.dart';
import '../../streaks/data/streaks_dao.dart';
import '../data/progression_dao.dart';
import '../domain/achievement_gate_models.dart';
import '../domain/progression_calculator.dart';
import '../domain/progression_models.dart';

/// Evaluates whether a Life Area is eligible for level promotion.
///
/// Gate logic (ADR-010):
///   1. totalXp ≥ level_curves.cumulative_xp_required for (currentLevel + 1)
///   2. ALL mandatory level_objectives for currentLevel are completed
///      (evidence: matching rows in achievements table)
///
/// This service operates on local Drift data for instant responsiveness;
/// the authoritative decision is confirmed server-side by the PostgreSQL RPC.
class AchievementGateService {
  final ProgressionDao _progressionDao;
  final AppDatabase _db;

  AchievementGateService({
    required ProgressionDao progressionDao,
    required AppDatabase db,
  })  : _progressionDao = progressionDao,
        _db = db;

  /// Evaluate the promotion gate for [userId] in [lifeAreaId].
  ///
  /// Returns a [PromotionGateResult] subtype describing the current state.
  Future<PromotionGateResult> evaluate({
    required String userId,
    required String lifeAreaId,
    required int totalXp,
    bool testOutBypass = false,
  }) async {
    // 1. Determine current level from XP
    final currentCurve = await _progressionDao.findLevelForXp(totalXp);
    final currentLevel = currentCurve.level;

    // 2. Look up XP required for next level
    final allCurves = await _progressionDao.allCurves();
    final nextCurveIdx =
        allCurves.indexWhere((c) => c.level == currentLevel) + 1;
    final int requiredXp = nextCurveIdx < allCurves.length
        ? allCurves[nextCurveIdx].cumulativeXpRequired
        : totalXp; // Already at max level

    final xpGatePassed = totalXp >= requiredXp;

    // 3. Load mandatory level objectives for currentLevel
    final rawObjectives =
        await _progressionDao.objectivesForLevel(currentLevel);
    final mandatoryObjectives =
        rawObjectives.where((o) => o.isMandatory).toList();

    // 4. Load completed achievements for this user (kind prefix = 'level_objective_')
    final completedAchievements = await (_db.select(_db.achievements)
          ..where((a) =>
              a.ownerId.equals(userId) &
              a.kind.like('level_objective_%')))
        .get();

    // kind format: 'level_objective_<objectiveId>'
    final completedIds = completedAchievements
        .map((a) => a.kind.replaceFirst('level_objective_', ''))
        .toSet();

    // 5. Map objectives to PromotionObjective with status
    final objectives = mandatoryObjectives.map((o) {
      final isCompleted = completedIds.contains(o.id) || testOutBypass;
      return PromotionObjective(
        objectiveId: o.id,
        title: o.title,
        description: o.description ?? '',
        level: o.level,
        status: isCompleted
            ? ObjectiveStatus.completed
            : ObjectiveStatus.notStarted,
      );
    }).toList();

    final allObjectivesPassed =
        testOutBypass || objectives.every((o) => o.isCompleted);

    // 6. Return appropriate sealed result
    if (!xpGatePassed) {
      return PromotionGateLocked(
        currentXp: totalXp,
        requiredXp: requiredXp,
        currentLevel: currentLevel,
        objectives: objectives,
      );
    }

    if (!allObjectivesPassed) {
      return PromotionGatePendingObjectives(
        currentXp: totalXp,
        requiredXp: requiredXp,
        currentLevel: currentLevel,
        objectives: objectives,
      );
    }

    return PromotionGateReady(
      currentXp: totalXp,
      currentLevel: currentLevel,
      nextLevel: currentLevel + 1,
      objectives: objectives,
    );
  }

  /// Execute promotion for [userId] in [lifeAreaId].
  ///
  /// Writes an achievement record for the level-up event.
  /// Server RPC `evaluate_level_promotion_gate` is the authoritative executor;
  /// this local write is queued via SyncOutbox (Invariant #13).
  Future<PromotionGatePromoted> executePromotion({
    required String userId,
    required String lifeAreaId,
    required int newLevel,
    required String versionHlc,
  }) async {
    final achievementId = Id.uuidV7().value;
    final now = DateTime.now().toUtc();

    await _db.into(_db.achievements).insert(
          AchievementsCompanion(
            id: Value(achievementId),
            ownerId: Value(userId),
            kind: Value('level_promotion_$newLevel'),
            level: Value(newLevel),
            awardedAt: Value(now),
            versionHlc: Value(versionHlc),
            createdAt: Value(now),
          ),
        );

    return PromotionGatePromoted(
      newLevel: newLevel,
      achievementId: achievementId,
      promotedAt: now,
    );
  }
}

/// Awards bonus freeze tokens when a streak reaches a Streak Society milestone.
///
/// Milestones (ADR-005 extension):
///   • 100 days → Centurion badge + 5 bonus freeze tokens
///   • 200 days → Legend badge  + 10 bonus freeze tokens
///   • 365 days → Immortal badge + 20 bonus freeze tokens
///
/// Idempotent: achievements table is checked before awarding to avoid duplication.
class StreakSocietyService {
  final StreaksDao _streaksDao;
  final AppDatabase _db;

  StreakSocietyService({
    required StreaksDao streaksDao,
    required AppDatabase db,
  })  : _streaksDao = streaksDao,
        _db = db;

  /// Check and award Streak Society milestone for [currentStreak] days.
  ///
  /// Returns a [StreakSocietyMilestone] describing what was awarded (if anything).
  Future<StreakSocietyMilestone> checkAndAward({
    required String userId,
    required String lifeAreaId,
    required int currentStreak,
    required String versionHlc,
  }) async {
    // Find the highest milestone tier reached at currentStreak
    StreakSocietyTier? reachedTier;
    for (final tier in StreakSocietyTier.values.reversed) {
      if (currentStreak >= tier.days) {
        reachedTier = tier;
        break;
      }
    }

    if (reachedTier == null) return const StreakSocietyMilestone.none();

    // Check if this milestone was already awarded (idempotency)
    final kindKey = 'streak_society_${reachedTier.badge}_$lifeAreaId';
    final existingAchievement = await (_db.select(_db.achievements)
          ..where((a) =>
              a.ownerId.equals(userId) &
              a.kind.equals(kindKey)))
        .getSingleOrNull();

    if (existingAchievement != null) {
      // Already awarded — not new
      return StreakSocietyMilestone(
        tier: reachedTier,
        bonusTokensAwarded: 0,
        isNew: false,
      );
    }

    // Award: write achievement + bonus freeze tokens in single transaction
    await _db.transaction(() async {
      final achievementId = Id.uuidV7().value;
      final now = DateTime.now().toUtc();

      await _db.into(_db.achievements).insert(
            AchievementsCompanion(
              id: Value(achievementId),
              ownerId: Value(userId),
              kind: Value(kindKey),
              level: const Value(null),
              awardedAt: Value(now),
              versionHlc: Value(versionHlc),
              createdAt: Value(now),
            ),
          );

      // Add bonus freeze tokens to inventory
      final inventory =
          await _streaksDao.getFreezeInventory(userId, lifeAreaId);
      if (inventory != null) {
        await (_db.update(_db.streakFreezeInventory)
              ..where((f) =>
                  f.userId.equals(userId) & f.lifeAreaId.equals(lifeAreaId)))
            .write(StreakFreezeInventoryCompanion(
          tokensAvailable:
              Value(inventory.tokensAvailable + reachedTier!.bonusFreezeTokens),
          updatedAt: Value(now),
        ));
      }
    });

    return StreakSocietyMilestone(
      tier: reachedTier,
      bonusTokensAwarded: reachedTier.bonusFreezeTokens,
      isNew: true,
    );
  }
}
