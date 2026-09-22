// ignore_for_file: public_member_api_docs
// Wave 7: Drift DAO for UserStreaks, StreakPauses, and StreakFreezeInventory.
// ADR-005 / ADR-012: Per-LifeArea streaks with Trophy.so/Duolingo auto-freeze retention.

import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';
import '../../../data/drift/ledger_tables.dart';
import '../../../domain/ids.dart';

part 'streaks_dao.g.dart';

class StreakActivityResult {
  final int currentStreak;
  final int longestStreak;
  final bool freezeConsumed;
  final bool isWeeklyBonusActive;

  const StreakActivityResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.freezeConsumed,
    required this.isWeeklyBonusActive,
  });
}

@DriftAccessor(tables: [UserStreaks, StreakPauses, StreakFreezeInventory])
class StreaksDao extends DatabaseAccessor<AppDatabase>
    with _$StreaksDaoMixin {
  StreaksDao(super.db);

  /// Fetch streak record for a specific user and life area.
  Future<UserStreak?> getStreak(String userId, String lifeAreaId) =>
      (select(db.userStreaks)
            ..where((s) =>
                s.userId.equals(userId) & s.lifeAreaId.equals(lifeAreaId)))
          .getSingleOrNull();

  /// All streaks across life areas for a user.
  Future<List<UserStreak>> allStreaksForUser(String userId) =>
      (select(db.userStreaks)..where((s) => s.userId.equals(userId))).get();

  /// Fetch freeze inventory for a user and life area.
  Future<StreakFreezeInventoryData?> getFreezeInventory(
          String userId, String lifeAreaId) =>
      (select(db.streakFreezeInventory)
            ..where((f) =>
                f.userId.equals(userId) & f.lifeAreaId.equals(lifeAreaId)))
          .getSingleOrNull();

  /// Process streak update upon activity in a LifeArea.
  /// Runs inside a transaction; mimics server-side process_streak_activity RPC.
  Future<StreakActivityResult> processActivity({
    required String userId,
    required String lifeAreaId,
    required DateTime activityDate,
    required String versionHlc,
  }) =>
      transaction(() async {
        final existingStreak = await getStreak(userId, lifeAreaId);
        final normalizedDate =
            DateTime.utc(activityDate.year, activityDate.month, activityDate.day);

        if (existingStreak == null) {
          // Initialize streak record
          await into(db.userStreaks).insert(UserStreaksCompanion(
            userId: Value(userId),
            lifeAreaId: Value(lifeAreaId),
            currentStreak: const Value(1),
            longestStreak: const Value(1),
            lastActiveDate: Value(normalizedDate),
            lastActiveHlc: Value(versionHlc),
            updatedAt: Value(DateTime.now().toUtc()),
          ));

          // Initialize 2 free freeze tokens
          await into(db.streakFreezeInventory).insertOnConflictUpdate(
            StreakFreezeInventoryCompanion(
              id: Value(Id.uuidV7().value),
              userId: Value(userId),
              lifeAreaId: Value(lifeAreaId),
              tokensAvailable: const Value(2),
              tokensUsed: const Value(0),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );

          return const StreakActivityResult(
            currentStreak: 1,
            longestStreak: 1,
            freezeConsumed: false,
            isWeeklyBonusActive: false,
          );
        }

        final lastDate = existingStreak.lastActiveDate != null
            ? DateTime.utc(
                existingStreak.lastActiveDate!.year,
                existingStreak.lastActiveDate!.month,
                existingStreak.lastActiveDate!.day,
              )
            : null;

        final dayDiff =
            lastDate != null ? normalizedDate.difference(lastDate).inDays : 1;

        var newCurrent = 1;
        var newLongest = existingStreak.longestStreak;
        var freezeConsumed = false;

        if (dayDiff == 0) {
          // Same day activity: streak unchanged
          newCurrent = existingStreak.currentStreak;
        } else if (dayDiff == 1) {
          // Consecutive day: increment streak
          newCurrent = existingStreak.currentStreak + 1;
          if (newCurrent > newLongest) newLongest = newCurrent;
        } else if (dayDiff == 2) {
          // Missed 1 day: check freeze tokens
          final inventory = await getFreezeInventory(userId, lifeAreaId);
          if (inventory != null && inventory.tokensAvailable > 0) {
            // Consume 1 freeze token
            await (update(db.streakFreezeInventory)
                  ..where((f) =>
                      f.userId.equals(userId) & f.lifeAreaId.equals(lifeAreaId)))
                .write(StreakFreezeInventoryCompanion(
              tokensAvailable: Value(inventory.tokensAvailable - 1),
              tokensUsed: Value(inventory.tokensUsed + 1),
              lastUsedDate: Value(normalizedDate.subtract(const Duration(days: 1))),
              updatedAt: Value(DateTime.now().toUtc()),
            ));

            // Record pause log
            await into(db.streakPauses).insert(StreakPausesCompanion(
              id: Value(Id.uuidV7().value),
              userId: Value(userId),
              lifeAreaId: Value(lifeAreaId),
              reason: const Value('Auto freeze token consumed'),
              startedAt: Value(normalizedDate.subtract(const Duration(days: 1))),
              endedAt: Value(normalizedDate),
              versionHlc: Value(versionHlc),
              createdAt: Value(DateTime.now().toUtc()),
            ));

            freezeConsumed = true;
            newCurrent = existingStreak.currentStreak + 1;
            if (newCurrent > newLongest) newLongest = newCurrent;
          } else {
            // No freezes available: reset
            newCurrent = 1;
          }
        } else {
          // Missed > 1 day: reset
          newCurrent = 1;
        }

        // Update streak projection
        await (update(db.userStreaks)
              ..where((s) =>
                  s.userId.equals(userId) & s.lifeAreaId.equals(lifeAreaId)))
            .write(UserStreaksCompanion(
          currentStreak: Value(newCurrent),
          longestStreak: Value(newLongest),
          lastActiveDate: Value(normalizedDate),
          lastActiveHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ));

        return StreakActivityResult(
          currentStreak: newCurrent,
          longestStreak: newLongest,
          freezeConsumed: freezeConsumed,
          isWeeklyBonusActive: newCurrent >= 7,
        );
      });
}
