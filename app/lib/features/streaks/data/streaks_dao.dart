// ignore_for_file: public_member_api_docs
// Wave 7: Drift DAO for UserStreaks, StreakPauses, and StreakFreezeInventory.
// ADR-005 / ADR-012: Per-LifeArea streaks with Trophy.so/Duolingo auto-freeze retention.

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/drift/ledger_tables.dart';
import '../../../domain/ids.dart';
import '../domain/streak_config.dart';

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

class GlobalStreakDayResult {
  final int streakDay;
  final int longestStreak;
  final int freezesConsumed;
  final int freezesAvailable;
  final bool advancedToday;
  final bool rewardEligible;

  const GlobalStreakDayResult({
    required this.streakDay,
    required this.longestStreak,
    required this.freezesConsumed,
    required this.freezesAvailable,
    required this.advancedToday,
    required this.rewardEligible,
  });
}

@DriftAccessor(tables: [UserStreaks, StreakPauses, StreakFreezeInventory])
class StreaksDao extends DatabaseAccessor<AppDatabase> with _$StreaksDaoMixin {
  StreaksDao(super.db);

  static const globalStreakKey = '__kratos_global_streak__';
  static const _freezeReasonPrefix = 'phase3-freeze:';

  /// Applies a real completion to the one-per-user, app-wide calendar streak.
  /// Freeze uses are audit rows so the rolling allowance survives restarts.
  Future<GlobalStreakDayResult> recordGlobalCompletion({
    required String userId,
    required DateTime eventDate,
    required String versionHlc,
  }) => transaction(() async {
    final localDay = _localDay(eventDate);
    final todayUtc = localDay;
    final existing = await getStreak(userId, globalStreakKey);
    final freezeRows =
        await (select(db.streakPauses)..where(
              (p) =>
                  p.userId.equals(userId) &
                  p.reason.like('$_freezeReasonPrefix%'),
            ))
            .get();
    final recentFreezeDays = freezeRows
        .map((row) => _freezeDay(row.reason))
        .whereType<DateTime>()
        .where((day) {
          final age = localDay.difference(day).inDays;
          return age >= 0 && age < StreakConfig.freezeWindowDays;
        })
        .toSet();
    final available = (StreakConfig.maxFreezes - recentFreezeDays.length).clamp(
      0,
      StreakConfig.maxFreezes,
    );

    if (existing == null) {
      await into(db.userStreaks).insert(
        UserStreaksCompanion(
          userId: Value(userId),
          lifeAreaId: const Value(globalStreakKey),
          currentStreak: const Value(1),
          longestStreak: const Value(1),
          lastActiveDate: Value(todayUtc),
          lastActiveHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      await _ensureGlobalFreezeInventory(userId, available);
      return GlobalStreakDayResult(
        streakDay: 1,
        longestStreak: 1,
        freezesConsumed: 0,
        freezesAvailable: available,
        advancedToday: true,
        rewardEligible: true,
      );
    }

    final lastDay = existing.lastActiveDate == null
        ? null
        : _localDay(existing.lastActiveDate!);
    final dayDiff = lastDay == null ? 1 : localDay.difference(lastDay).inDays;
    if (dayDiff <= 0) {
      await _ensureGlobalFreezeInventory(userId, available);
      return GlobalStreakDayResult(
        streakDay: existing.currentStreak,
        longestStreak: existing.longestStreak,
        freezesConsumed: 0,
        freezesAvailable: available,
        advancedToday: false,
        rewardEligible: dayDiff == 0,
      );
    }

    var current = existing.currentStreak;
    var longest = existing.longestStreak;
    var freezesConsumed = 0;
    final missedDays = dayDiff - 1;
    var streakBroken = false;

    for (var offset = 1; offset <= missedDays; offset++) {
      final missedDay = localDay.subtract(Duration(days: dayDiff - offset));
      final missedKey = _dayKey(missedDay);
      final age = localDay.difference(missedDay).inDays;
      final inWindow = age >= 0 && age < StreakConfig.freezeWindowDays;
      final alreadyUsed = recentFreezeDays.contains(missedDay);
      final currentlyAvailable =
          StreakConfig.maxFreezes - recentFreezeDays.length;

      if (inWindow && !alreadyUsed && currentlyAvailable > 0 && !streakBroken) {
        final reason = '$_freezeReasonPrefix$missedKey';
        await into(db.streakPauses).insertOnConflictUpdate(
          StreakPausesCompanion(
            id: Value('freeze:$userId:$missedKey'),
            userId: Value(userId),
            lifeAreaId: const Value(null),
            reason: Value(reason),
            startedAt: Value(missedDay.toUtc()),
            endedAt: Value(todayUtc),
            versionHlc: Value(versionHlc),
            createdAt: Value(DateTime.now().toUtc()),
          ),
        );
        recentFreezeDays.add(missedDay);
        freezesConsumed++;
        current++;
      } else {
        streakBroken = true;
      }
    }

    if (streakBroken) {
      current = 1;
    } else {
      // Include protected missed calendar days in the preserved sequence.
      current++;
    }
    if (current > longest) longest = current;

    await (update(db.userStreaks)..where(
          (s) => s.userId.equals(userId) & s.lifeAreaId.equals(globalStreakKey),
        ))
        .write(
          UserStreaksCompanion(
            currentStreak: Value(current),
            longestStreak: Value(longest),
            lastActiveDate: Value(todayUtc),
            lastActiveHlc: Value(versionHlc),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    await _ensureGlobalFreezeInventory(
      userId,
      (StreakConfig.maxFreezes - recentFreezeDays.length).clamp(
        0,
        StreakConfig.maxFreezes,
      ),
      consumed: freezesConsumed,
    );

    return GlobalStreakDayResult(
      streakDay: current,
      longestStreak: longest,
      freezesConsumed: freezesConsumed,
      freezesAvailable: (StreakConfig.maxFreezes - recentFreezeDays.length)
          .clamp(0, StreakConfig.maxFreezes),
      advancedToday: true,
      rewardEligible: true,
    );
  });

  Future<void> _ensureGlobalFreezeInventory(
    String userId,
    int available, {
    int consumed = 0,
  }) async {
    final inventory = await getFreezeInventory(userId, globalStreakKey);
    if (inventory == null) {
      await into(db.streakFreezeInventory).insert(
        StreakFreezeInventoryCompanion(
          id: Value(Id.uuidV7().value),
          userId: Value(userId),
          lifeAreaId: const Value(globalStreakKey),
          tokensAvailable: Value(available),
          tokensUsed: Value(consumed),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      return;
    }
    await (update(db.streakFreezeInventory)..where(
          (row) =>
              row.userId.equals(userId) &
              row.lifeAreaId.equals(globalStreakKey),
        ))
        .write(
          StreakFreezeInventoryCompanion(
            tokensAvailable: Value(available),
            tokensUsed: Value(inventory.tokensUsed + consumed),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  static DateTime _localDay(DateTime value) {
    final local = value.toLocal();
    // Compare date-only values in UTC so a daylight-saving transition does
    // not turn a calendar day into a 23- or 25-hour interval.
    return DateTime.utc(local.year, local.month, local.day);
  }

  static String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  static DateTime? _freezeDay(String? reason) {
    if (reason == null || !reason.startsWith(_freezeReasonPrefix)) return null;
    final raw = reason.substring(_freezeReasonPrefix.length).split('-');
    if (raw.length != 3) return null;
    final parts = raw.map(int.tryParse).toList();
    if (parts.any((part) => part == null)) return null;
    return DateTime.utc(parts[0]!, parts[1]!, parts[2]!);
  }

  /// Fetch streak record for a specific user and life area.
  Future<UserStreak?> getStreak(String userId, String lifeAreaId) =>
      (select(db.userStreaks)..where(
            (s) => s.userId.equals(userId) & s.lifeAreaId.equals(lifeAreaId),
          ))
          .getSingleOrNull();

  /// All streaks across life areas for a user.
  Future<List<UserStreak>> allStreaksForUser(String userId) =>
      (select(db.userStreaks)..where((s) => s.userId.equals(userId))).get();

  /// Fetch freeze inventory for a user and life area.
  Future<StreakFreezeInventoryData?> getFreezeInventory(
    String userId,
    String lifeAreaId,
  ) =>
      (select(db.streakFreezeInventory)..where(
            (f) => f.userId.equals(userId) & f.lifeAreaId.equals(lifeAreaId),
          ))
          .getSingleOrNull();

  /// Read the current rolling allowance without mutating streak state.
  Future<int> globalFreezesAvailable(String userId, {DateTime? atDate}) async {
    final localDay = _localDay(atDate ?? DateTime.now());
    final rows =
        await (select(db.streakPauses)..where(
              (p) =>
                  p.userId.equals(userId) &
                  p.reason.like('$_freezeReasonPrefix%'),
            ))
            .get();
    final recentDays = rows
        .map((row) => _freezeDay(row.reason))
        .whereType<DateTime>()
        .where((day) {
          final age = localDay.difference(day).inDays;
          return age >= 0 && age < StreakConfig.freezeWindowDays;
        })
        .toSet();
    return (StreakConfig.maxFreezes - recentDays.length).clamp(
      0,
      StreakConfig.maxFreezes,
    );
  }

  /// Process streak update upon activity in a LifeArea.
  /// Runs inside a transaction; mimics server-side process_streak_activity RPC.
  Future<StreakActivityResult> processActivity({
    required String userId,
    required String lifeAreaId,
    required DateTime activityDate,
    required String versionHlc,
  }) => transaction(() async {
    final existingStreak = await getStreak(userId, lifeAreaId);
    final normalizedDate = DateTime.utc(
      activityDate.year,
      activityDate.month,
      activityDate.day,
    );

    if (existingStreak == null) {
      // Initialize streak record
      await into(db.userStreaks).insert(
        UserStreaksCompanion(
          userId: Value(userId),
          lifeAreaId: Value(lifeAreaId),
          currentStreak: const Value(1),
          longestStreak: const Value(1),
          lastActiveDate: Value(normalizedDate),
          lastActiveHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

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

    final dayDiff = lastDate != null
        ? normalizedDate.difference(lastDate).inDays
        : 1;

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
        await (update(db.streakFreezeInventory)..where(
              (f) => f.userId.equals(userId) & f.lifeAreaId.equals(lifeAreaId),
            ))
            .write(
              StreakFreezeInventoryCompanion(
                tokensAvailable: Value(inventory.tokensAvailable - 1),
                tokensUsed: Value(inventory.tokensUsed + 1),
                lastUsedDate: Value(
                  normalizedDate.subtract(const Duration(days: 1)),
                ),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );

        // Record pause log
        await into(db.streakPauses).insert(
          StreakPausesCompanion(
            id: Value(Id.uuidV7().value),
            userId: Value(userId),
            lifeAreaId: Value(lifeAreaId),
            reason: const Value('Auto freeze token consumed'),
            startedAt: Value(normalizedDate.subtract(const Duration(days: 1))),
            endedAt: Value(normalizedDate),
            versionHlc: Value(versionHlc),
            createdAt: Value(DateTime.now().toUtc()),
          ),
        );

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
    await (update(db.userStreaks)..where(
          (s) => s.userId.equals(userId) & s.lifeAreaId.equals(lifeAreaId),
        ))
        .write(
          UserStreaksCompanion(
            currentStreak: Value(newCurrent),
            longestStreak: Value(newLongest),
            lastActiveDate: Value(normalizedDate),
            lastActiveHlc: Value(versionHlc),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );

    return StreakActivityResult(
      currentStreak: newCurrent,
      longestStreak: newLongest,
      freezeConsumed: freezeConsumed,
      isWeeklyBonusActive: newCurrent >= 7,
    );
  });
}
