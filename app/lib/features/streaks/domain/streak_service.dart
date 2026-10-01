// Wave 7: StreakService.
// Connects domain layer with StreaksDao and computes StreakInfo.

import 'dart:convert';
import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../data/streaks_dao.dart';
import '../../xp/data/xp_ledger_writer_impl.dart';
import '../../xp/domain/xp_allocation_math.dart';
import 'streak_config.dart';
import 'streak_models.dart';

class StreakService {
  final StreaksDao _dao;
  final AppDatabase _database;

  StreakService(AppDatabase db) : _database = db, _dao = StreaksDao(db);

  /// Applies a real completion to the app-wide calendar streak and records
  /// at most one standalone streak XP event for the user's local calendar day.
  Future<StreakCompletionResult> recordQualifyingCompletion({
    required Id userId,
    required Id sourceId,
    required Id lifeAreaId,
    required DateTime completedAt,
    required String versionHlc,
    required Id deviceId,
  }) async {
    final result = await _dao.recordGlobalCompletion(
      userId: userId.value,
      eventDate: completedAt,
      versionHlc: versionHlc,
    );
    final reward = StreakConfig.rewardForDay(result.streakDay);
    if (reward > 0 && result.rewardEligible) {
      final localDay = completedAt.toLocal();
      final dayKey =
          '${localDay.year.toString().padLeft(4, '0')}'
          '${localDay.month.toString().padLeft(2, '0')}'
          '${localDay.day.toString().padLeft(2, '0')}';
      final rewardKey = Id('streak_${userId.value}_$dayKey');
      await _database.transaction(() async {
        // Serialize the lookup and append so simultaneous completions cannot
        // create multiple daily rewards even though the local mirror has no
        // dedicated SQL unique index for this key yet.
        final existing = await _database.xpLedgerDao.findByIdempotencyKey(
          rewardKey.value,
        );
        if (existing != null) return;
        await DriftXpLedgerWriter(_database).recordEvent(
          ownerId: userId,
          idempotencyKey: rewardKey,
          sourceType: 'streak',
          sourceId: sourceId,
          action: 'daily_reward',
          basePoints: reward,
          allocationRatios: [
            AllocationRatio(lifeAreaId: lifeAreaId, percentage: 100),
          ],
          clock: Hlc.parse(versionHlc),
          deviceId: deviceId,
          enqueueSync: false,
        );
      });
    }

    if (result.advancedToday) {
      final streakEventId = Id.uuidV7().value;
      await _database.into(_database.activityEvents).insert(
        ActivityEventsCompanion.insert(
          id: streakEventId,
          ownerId: userId.value,
          eventType: 'streak_extended',
          entityType: 'streak',
          entityId: Value(lifeAreaId.value),
          lifeAreaId: Value(lifeAreaId.value),
          metadata: Value(
            jsonEncode({
              'current_streak': result.streakDay,
              'longest_streak': result.longestStreak,
              'freezes_consumed': result.freezesConsumed,
              'freezes_available': result.freezesAvailable,
            }),
          ),
          occurredAt: completedAt,
          versionHlc: versionHlc,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }

    return StreakCompletionResult(
      streakDay: result.streakDay,
      longestStreak: result.longestStreak,
      rewardXp: reward,
      freezesConsumed: result.freezesConsumed,
      freezesAvailable: result.freezesAvailable,
      advancedToday: result.advancedToday,
    );
  }

  /// Fetch the current streak and freeze inventory for a LifeArea.
  Future<StreakInfo> getStreakForLifeArea({
    required Id userId,
    required Id lifeAreaId,
  }) async {
    final streak = await _dao.getStreak(userId.value, lifeAreaId.value);
    final freeze = await _dao.getFreezeInventory(
      userId.value,
      lifeAreaId.value,
    );

    return StreakInfo.create(
      userId: userId,
      lifeAreaId: lifeAreaId,
      currentStreak: streak?.currentStreak ?? 0,
      longestStreak: streak?.longestStreak ?? 0,
      freezeTokensAvailable: freeze?.tokensAvailable ?? 2,
      lastActiveDate: streak?.lastActiveDate,
    );
  }
}

class StreakCompletionResult {
  final int streakDay;
  final int longestStreak;
  final int rewardXp;
  final int freezesConsumed;
  final int freezesAvailable;
  final bool advancedToday;

  const StreakCompletionResult({
    required this.streakDay,
    required this.longestStreak,
    required this.rewardXp,
    required this.freezesConsumed,
    required this.freezesAvailable,
    required this.advancedToday,
  });
}
