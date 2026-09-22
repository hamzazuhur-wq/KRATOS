// Wave 6 tests: Progression calculator, level curves, tier thresholds, and compound gates.

import 'package:flutter_test/flutter_test.dart';
import 'package:kratos/domain/ids.dart';
import 'package:kratos/features/progression/domain/progression_calculator.dart';
import 'package:kratos/features/progression/domain/progression_models.dart';

void main() {
  group('ProgressionCalculator — Curves and Tiers', () {
    test('0 XP starts at Level 1, Bronze tier, 0% progress', () {
      final info = ProgressionCalculator.calculate(totalXp: 0);
      expect(info.level, 1);
      expect(info.tier, 'Bronze');
      expect(info.xpInLevel, 0);
      expect(info.progressPct, 0.0);
      expect(info.canPromote, true);
    });

    test('1,000 XP reaches Bronze threshold', () {
      final info = ProgressionCalculator.calculate(totalXp: 1000);
      expect(info.tier, 'Bronze');
      expect(info.level, greaterThan(1));
    });

    test('3,000 XP advances to Silver tier', () {
      final info = ProgressionCalculator.calculate(totalXp: 3000);
      expect(info.tier, 'Silver');
    });

    test('7,000 XP advances to Gold tier', () {
      final info = ProgressionCalculator.calculate(totalXp: 7000);
      expect(info.tier, 'Gold');
    });

    test('15,000 XP advances to Crystal tier', () {
      final info = ProgressionCalculator.calculate(totalXp: 15000);
      expect(info.tier, 'Crystal');
    });

    test('30,000 XP advances to Diamond tier', () {
      final info = ProgressionCalculator.calculate(totalXp: 30000);
      expect(info.tier, 'Diamond');
    });

    test('60,000+ XP reaches pinnacle Mythic tier', () {
      final info = ProgressionCalculator.calculate(totalXp: 65000);
      expect(info.tier, 'Mythic');
    });

    test('level curves contain 100 levels with exponential progression', () {
      final curves = ProgressionCalculator.defaultCurves;
      expect(curves.length, 100);
      expect(curves.first.level, 1);
      expect(curves.last.level, 100);
      expect(curves.last.cumulativeXpRequired, lessThanOrEqualTo(14000000));
    });
  });

  group('ProgressionCalculator — Compound Gate (ADR-010)', () {
    final obj1 = LevelObjectiveSnapshot(
      id: Id.uuidV7(),
      level: 5,
      title: 'Complete 10 tasks in this LifeArea',
      isMandatory: true,
    );
    final obj2 = LevelObjectiveSnapshot(
      id: Id.uuidV7(),
      level: 5,
      title: 'Optional streak bonus',
      isMandatory: false,
    );

    test('blocks promotion when mandatory objective is incomplete', () {
      final info = ProgressionCalculator.calculate(
        totalXp: 5000,
        levelObjectives: [obj1, obj2],
        completedObjectiveIds: {}, // obj1 not completed
      );

      expect(info.canPromote, false);
    });

    test('allows promotion when mandatory objective is completed', () {
      final info = ProgressionCalculator.calculate(
        totalXp: 5000,
        levelObjectives: [obj1, obj2],
        completedObjectiveIds: {obj1.id}, // obj1 completed, obj2 optional
      );

      expect(info.canPromote, true);
    });

    test('allows promotion when testOutBypass is true regardless of objectives', () {
      final info = ProgressionCalculator.calculate(
        totalXp: 5000,
        levelObjectives: [obj1, obj2],
        completedObjectiveIds: {},
        testOutBypass: true,
      );

      expect(info.canPromote, true);
    });
  });
}
