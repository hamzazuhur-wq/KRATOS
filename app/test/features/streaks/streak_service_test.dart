// Wave 7 tests: Streak models, freeze token consumption, and weekly bonus calculations.

import 'package:flutter_test/flutter_test.dart';
import 'package:kratos/domain/ids.dart';
import 'package:kratos/features/streaks/domain/streak_models.dart';

void main() {
  final userId = Id.uuidV7();
  final lifeAreaId = Id.uuidV7();

  group('StreakInfo model & milestones', () {
    test('initial streak has 2 freeze tokens and inactive bonus', () {
      final streak = StreakInfo.create(
        userId: userId,
        lifeAreaId: lifeAreaId,
        currentStreak: 1,
        longestStreak: 1,
        freezeTokensAvailable: 2,
      );

      expect(streak.currentStreak, 1);
      expect(streak.longestStreak, 1);
      expect(streak.freezeTokensAvailable, 2);
      expect(streak.isWeeklyBonusActive, false);
      expect(streak.isStreakSociety, false);
      expect(streak.calculateStreakBonus(100), 0);
    });

    test('reaches 7-day streak and activates +20% weekly streak bonus (ADR-005)', () {
      final streak = StreakInfo.create(
        userId: userId,
        lifeAreaId: lifeAreaId,
        currentStreak: 7,
        longestStreak: 7,
        freezeTokensAvailable: 2,
      );

      expect(streak.isWeeklyBonusActive, true);
      expect(streak.calculateStreakBonus(100), 20); // +20% of 100 = 20
      expect(streak.calculateStreakBonus(50), 10);
    });

    test('reaches 100-day streak and activates Streak Society milestone', () {
      final streak = StreakInfo.create(
        userId: userId,
        lifeAreaId: lifeAreaId,
        currentStreak: 100,
        longestStreak: 100,
        freezeTokensAvailable: 3,
      );

      expect(streak.isWeeklyBonusActive, true);
      expect(streak.isStreakSociety, true);
    });
  });
}
