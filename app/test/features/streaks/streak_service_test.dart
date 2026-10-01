import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/domain/hlc.dart';
import 'package:kratos_app/domain/ids.dart';
import 'package:kratos_app/features/streaks/data/streaks_dao.dart';
import 'package:kratos_app/features/streaks/domain/streak_config.dart';
import 'package:kratos_app/features/streaks/domain/streak_service.dart';

void main() {
  group('Phase 3 streak reward configuration', () {
    test('integer daily rewards start on day 3 and scale by day', () {
      expect(StreakConfig.rewardForDay(1), 0);
      expect(StreakConfig.rewardForDay(2), 0);
      expect(StreakConfig.rewardForDay(3), 30);
      expect(StreakConfig.rewardForDay(4), 40);
      expect(StreakConfig.rewardForDay(7), 70);
      expect(StreakConfig.rewardForDay(10), 100);
      expect(StreakConfig.rewardForDay(30), 300);
      expect(StreakConfig.rewardForDay(100), 1000);
    });
  });

  group('app-wide qualifying calendar streak', () {
    late AppDatabase db;
    late StreaksDao dao;
    const owner = 'streak-test-user';

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = StreaksDao(db);
    });

    tearDown(() => db.close());

    Future<GlobalStreakDayResult> completeOn(int day) =>
        dao.recordGlobalCompletion(
          userId: owner,
          eventDate: DateTime(2026, 1, day, 12),
          versionHlc: Hlc.now(Id.uuidV7()).toString(),
        );

    test('multiple completions on one local date advance only once', () async {
      final first = await completeOn(1);
      final duplicateTask = await completeOn(1);
      final anotherEntity = await completeOn(1);

      expect(first.streakDay, 1);
      expect(first.advancedToday, isTrue);
      expect(duplicateTask.streakDay, 1);
      expect(duplicateTask.advancedToday, isFalse);
      expect(anotherEntity.streakDay, 1);
      expect(anotherEntity.advancedToday, isFalse);
    });

    test(
      'one missed day consumes one freeze and preserves elapsed day count',
      () async {
        await completeOn(1);
        await completeOn(2);
        await completeOn(3);

        final resumed = await completeOn(5); // day 4 is protected
        expect(resumed.streakDay, 5);
        expect(resumed.freezesConsumed, 1);
        expect(resumed.freezesAvailable, 2);
      },
    );

    test(
      'three missed calendar days consume all three freezes individually',
      () async {
        await completeOn(1);
        final afterThreeMisses = await completeOn(5); // missed days 2, 3, 4
        expect(afterThreeMisses.streakDay, 5);
        expect(afterThreeMisses.freezesConsumed, 3);
        expect(afterThreeMisses.freezesAvailable, 0);
      },
    );

    test(
      'a further missed day without an available freeze restarts at day 1',
      () async {
        await completeOn(1);
        await completeOn(5); // consumes the allowance on days 2-4
        final restarted = await completeOn(7); // day 6 cannot be protected

        expect(restarted.streakDay, 1);
        expect(restarted.freezesConsumed, 0);
        expect(restarted.freezesAvailable, 0);
        expect(restarted.longestStreak, 5);
      },
    );

    test('expired freezes replenish the rolling allowance', () async {
      await completeOn(1);
      await completeOn(5); // consumes 3 freezes on days 2-4
      final afterWindow = await completeOn(36); // old uses are outside 30 days

      expect(afterWindow.streakDay, 1);
      expect(afterWindow.freezesConsumed, 0);
      expect(afterWindow.freezesAvailable, 3);
    });
  });

  group('daily streak XP event', () {
    late AppDatabase db;
    late StreakService service;
    const owner = 'streak-reward-test-user';
    const area = 'streak-reward-test-area';

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = StreakService(db);
    });

    tearDown(() => db.close());

    Future<void> complete(int day, String sourceId) async {
      final stamp = DateTime(2026, 2, day, 12);
      await service.recordQualifyingCompletion(
        userId: const Id(owner),
        sourceId: Id(sourceId),
        lifeAreaId: const Id(area),
        completedAt: stamp,
        versionHlc: Hlc.now(Id.uuidV7()).toString(),
        deviceId: Id.uuidV7(),
      );
    }

    test('day 7 followed by a frozen day and day 9 awards 90 once', () async {
      for (var day = 1; day <= 7; day++) {
        await complete(day, 'completion-$day');
      }
      final ledgerBefore = await db.select(db.xpLedger).get();
      expect(
        ledgerBefore
            .where((row) => row.sourceType == 'streak')
            .map((row) => row.points)
            .toList(),
        [30, 40, 50, 60, 70],
      );

      await Future.wait([
        complete(9, 'completion-9'), // day 8 is automatically frozen
        complete(9, 'second-completion-9'),
      ]);

      final rewards = await (db.select(
        db.xpLedger,
      )..where((row) => row.sourceType.equals('streak'))).get();
      final dayNineRewards = rewards
          .where((row) => row.idempotencyKey.endsWith('20260209'))
          .toList();
      expect(dayNineRewards, hasLength(1));
      expect(dayNineRewards.single.action, 'daily_reward');
      expect(dayNineRewards.single.points, 90);
      expect(dayNineRewards.single.basePoints, 90);
      expect(dayNineRewards.single.streakBonus, 0);
      expect(dayNineRewards.single.idempotencyKey, 'streak_${owner}_20260209');
      expect(await db.xpAnalyticsDao.totalStreakBonusXp(owner), 340);
      expect(await db.select(db.syncOutbox).get(), isEmpty);

      final pauses = await (db.select(
        db.streakPauses,
      )..where((row) => row.userId.equals(owner))).get();
      expect(pauses, hasLength(1));
      expect(pauses.single.reason, 'phase3-freeze:2026-02-08');
    });
  });
}
