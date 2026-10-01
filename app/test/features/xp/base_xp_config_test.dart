// Phase 1 tests: KRATOS Base XP Economy & Difficulty System.
// Tests all 4 base sources, difficulty range 1..10, edge cases, and integer integrity.

import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/domain/errors.dart';
import 'package:kratos_app/features/xp/domain/base_xp_config.dart';

void main() {
  group('BaseXpSource enum specification', () {
    test('contains EXACTLY the 4 authorized base sources (Invariant)', () {
      expect(BaseXpSource.values, containsAll([
        BaseXpSource.activity,
        BaseXpSource.skill,
        BaseXpSource.task,
        BaseXpSource.subGoal,
      ]));
      expect(
        BaseXpSource.values.length,
        4,
        reason: 'Goals, Life Areas, and Projects must NOT be Base XP sources',
      );
    });

    test('has correct maximum XP caps per source specification', () {
      expect(BaseXpConfig.maxPointsFor(BaseXpSource.activity), 30);
      expect(BaseXpConfig.maxPointsFor(BaseXpSource.skill), 50);
      expect(BaseXpConfig.maxPointsFor(BaseXpSource.task), 75);
      expect(BaseXpConfig.maxPointsFor(BaseXpSource.subGoal), 300);

      expect(BaseXpSource.activity.maxPoints, 30);
      expect(BaseXpSource.skill.maxPoints, 50);
      expect(BaseXpSource.task.maxPoints, 75);
      expect(BaseXpSource.subGoal.maxPoints, 300);
    });

    test('provides human-readable labels and machine identifiers', () {
      expect(BaseXpSource.activity.displayName, 'Activity');
      expect(BaseXpSource.skill.displayName, 'Skill');
      expect(BaseXpSource.task.displayName, 'Task');
      expect(BaseXpSource.subGoal.displayName, 'Sub-Goal');

      expect(BaseXpSource.activity.identifier, 'activity');
      expect(BaseXpSource.skill.identifier, 'skill');
      expect(BaseXpSource.task.identifier, 'task');
      expect(BaseXpSource.subGoal.identifier, 'sub_goal');
    });
  });

  group('BaseXpConfig - Specific Required Test Values', () {
    test('Activity at Difficulty 5 = 15 XP (30 * 5 / 10 = 15)', () {
      final xp = BaseXpConfig.calculate(
        source: BaseXpSource.activity,
        difficulty: 5,
      );
      expect(xp, 15);
      expect(BaseXpConfig.forActivity(5), 15);
    });

    test('Skill at Difficulty 8 = 40 XP (50 * 8 / 10 = 40)', () {
      final xp = BaseXpConfig.calculate(
        source: BaseXpSource.skill,
        difficulty: 8,
      );
      expect(xp, 40);
      expect(BaseXpConfig.forSkill(8), 40);
    });

    test('Task at Difficulty 5 = 38 XP (75 * 5 / 10 = 37.5 -> 38)', () {
      final xp = BaseXpConfig.calculate(
        source: BaseXpSource.task,
        difficulty: 5,
      );
      expect(xp, 38);
      expect(BaseXpConfig.forTask(5), 38);
    });

    test('Sub-Goal at Difficulty 7 = 210 XP (300 * 7 / 10 = 210)', () {
      final xp = BaseXpConfig.calculate(
        source: BaseXpSource.subGoal,
        difficulty: 7,
      );
      expect(xp, 210);
      expect(BaseXpConfig.forSubGoal(7), 210);
    });

    test('Task at Difficulty 3 = 23 XP (75 * 3 / 10 = 22.5 -> 23)', () {
      final xp = BaseXpConfig.calculate(
        source: BaseXpSource.task,
        difficulty: 3,
      );
      expect(xp, 23);
      expect(BaseXpConfig.forTask(3), 23);
    });
  });

  group('BaseXpConfig - Full 1..10 Scale for All 4 Sources', () {
    test('Activity (Max 30) across difficulties 1 to 10', () {
      const expected = [3, 6, 9, 12, 15, 18, 21, 24, 27, 30];
      for (var d = 1; d <= 10; d++) {
        final xp = BaseXpConfig.forActivity(d);
        expect(xp, expected[d - 1], reason: 'Activity D$d');
        expect(xp, isA<int>());
        expect(xp, isPositive);
      }
    });

    test('Skill (Max 50) across difficulties 1 to 10', () {
      const expected = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50];
      for (var d = 1; d <= 10; d++) {
        final xp = BaseXpConfig.forSkill(d);
        expect(xp, expected[d - 1], reason: 'Skill D$d');
        expect(xp, isA<int>());
        expect(xp, isPositive);
      }
    });

    test('Task (Max 75) across difficulties 1 to 10', () {
      // 7.5->8, 15, 22.5->23, 30, 37.5->38, 45, 52.5->53, 60, 67.5->68, 75
      const expected = [8, 15, 23, 30, 38, 45, 53, 60, 68, 75];
      for (var d = 1; d <= 10; d++) {
        final xp = BaseXpConfig.forTask(d);
        expect(xp, expected[d - 1], reason: 'Task D$d');
        expect(xp, isA<int>());
        expect(xp, isPositive);
      }
    });

    test('Sub-Goal (Max 300) across difficulties 1 to 10', () {
      const expected = [30, 60, 90, 120, 150, 180, 210, 240, 270, 300];
      for (var d = 1; d <= 10; d++) {
        final xp = BaseXpConfig.forSubGoal(d);
        expect(xp, expected[d - 1], reason: 'Sub-Goal D$d');
        expect(xp, isA<int>());
        expect(xp, isPositive);
      }
    });
  });

  group('BaseXpConfig - Integer Integrity Verification', () {
    test('all 40 combinations produce exact non-negative integers', () {
      for (final source in BaseXpSource.values) {
        for (var d = 1; d <= 10; d++) {
          final xp = BaseXpConfig.calculate(source: source, difficulty: d);
          expect(xp, isA<int>());
          expect(xp >= 0, isTrue);
          expect(xp.toDouble(), equals(xp.toDouble().roundToDouble()));
        }
      }
    });
  });

  group('BaseXpConfig - Difficulty Validation & Edge Cases', () {
    test('throws ArgumentError when difficulty < 1 (e.g. 0, -1, -50)', () {
      for (final invalid in [0, -1, -10, -100]) {
        expect(
          () => BaseXpConfig.calculate(
            source: BaseXpSource.task,
            difficulty: invalid,
          ),
          throwsArgumentError,
          reason: 'Difficulty $invalid must be rejected',
        );
        expect(
          () => BaseXpConfig.forActivity(invalid),
          throwsArgumentError,
        );
        expect(
          () => BaseXpConfig.validateDifficulty(invalid),
          throwsArgumentError,
        );
      }
    });

    test('throws ArgumentError when difficulty > 10 (e.g. 11, 15, 100)', () {
      for (final invalid in [11, 12, 50, 100]) {
        expect(
          () => BaseXpConfig.calculate(
            source: BaseXpSource.task,
            difficulty: invalid,
          ),
          throwsArgumentError,
          reason: 'Difficulty $invalid must be rejected',
        );
        expect(
          () => BaseXpConfig.forSubGoal(invalid),
          throwsArgumentError,
        );
        expect(
          () => BaseXpConfig.validateDifficulty(invalid),
          throwsArgumentError,
        );
      }
    });

    test('throws ArgumentError when difficulty is null', () {
      expect(
        () => BaseXpConfig.calculate(
          source: BaseXpSource.task,
          difficulty: null,
        ),
        throwsArgumentError,
      );
      expect(
        () => BaseXpConfig.forSkill(null),
        throwsArgumentError,
      );
      expect(
        () => BaseXpConfig.validateDifficulty(null),
        throwsArgumentError,
      );
    });

    test('validateDifficultyDomain throws ValidationError for domain-layer usage', () {
      expect(
        () => BaseXpConfig.validateDifficultyDomain(null),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => BaseXpConfig.validateDifficultyDomain(0),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => BaseXpConfig.validateDifficultyDomain(11),
        throwsA(isA<ValidationError>()),
      );
      // Valid does not throw:
      expect(() => BaseXpConfig.validateDifficultyDomain(1), returnsNormally);
      expect(() => BaseXpConfig.validateDifficultyDomain(10), returnsNormally);
    });
  });

  group('XpEconomyConfig alias compatibility', () {
    test('XpEconomyConfig works identically as BaseXpConfig', () {
      expect(XpEconomyConfig.maxTaskXp, 75);
      expect(XpEconomyConfig.forTask(5), 38);
      expect(XpEconomyConfig.forActivity(5), 15);
      expect(XpEconomyConfig.forSkill(8), 40);
      expect(XpEconomyConfig.forSubGoal(7), 210);
    });
  });
}
