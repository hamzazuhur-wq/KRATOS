// ignore_for_file: avoid_redundant_argument_values
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/features/activities/domain/activity_xp_calculator.dart';

void main() {
  group('Phase 2 — ActivityXpCalculator', () {
    group('Ceiling XP Calculation', () {
      test('computes exact ceiling XP for all difficulty levels 1..10', () {
        expect(ActivityXpCalculator.ceilingXp(1), equals(3));
        expect(ActivityXpCalculator.ceilingXp(2), equals(6));
        expect(ActivityXpCalculator.ceilingXp(3), equals(9));
        expect(ActivityXpCalculator.ceilingXp(4), equals(12));
        expect(ActivityXpCalculator.ceilingXp(5), equals(15));
        expect(ActivityXpCalculator.ceilingXp(6), equals(18));
        expect(ActivityXpCalculator.ceilingXp(7), equals(21));
        expect(ActivityXpCalculator.ceilingXp(8), equals(24));
        expect(ActivityXpCalculator.ceilingXp(9), equals(27));
        expect(ActivityXpCalculator.ceilingXp(10), equals(30));
      });

      test('rejects difficulty < 1', () {
        expect(() => ActivityXpCalculator.ceilingXp(0), throwsArgumentError);
        expect(() => ActivityXpCalculator.ceilingXp(-1), throwsArgumentError);
      });

      test('rejects difficulty > 10', () {
        expect(() => ActivityXpCalculator.ceilingXp(11), throwsArgumentError);
        expect(() => ActivityXpCalculator.ceilingXp(99), throwsArgumentError);
      });
    });

    group('Anchor Points & Diminishing Returns Curve', () {
      test('matches all anchor points exactly', () {
        expect(ActivityXpCalculator.durationFactor(0), closeTo(0.00, 1e-6));
        expect(ActivityXpCalculator.durationFactor(15), closeTo(0.05, 1e-6));
        expect(ActivityXpCalculator.durationFactor(30), closeTo(0.10, 1e-6));
        expect(ActivityXpCalculator.durationFactor(60), closeTo(0.20, 1e-6));
        expect(ActivityXpCalculator.durationFactor(120), closeTo(0.35, 1e-6));
        expect(ActivityXpCalculator.durationFactor(240), closeTo(0.55, 1e-6));
        expect(ActivityXpCalculator.durationFactor(360), closeTo(0.70, 1e-6));
        expect(ActivityXpCalculator.durationFactor(480), closeTo(0.82, 1e-6));
        expect(ActivityXpCalculator.durationFactor(600), closeTo(0.92, 1e-6));
        expect(ActivityXpCalculator.durationFactor(720), closeTo(1.00, 1e-6));
      });

      test('linearly interpolates between anchor points', () {
        // Midway between 30m (0.10) and 60m (0.20) -> 45m = 0.15
        expect(ActivityXpCalculator.durationFactor(45), closeTo(0.15, 1e-6));

        // Midway between 60m (0.20) and 120m (0.35) -> 90m = 0.275
        expect(ActivityXpCalculator.durationFactor(90), closeTo(0.275, 1e-6));

        // Midway between 120m (0.35) and 240m (0.55) -> 180m = 0.45
        expect(ActivityXpCalculator.durationFactor(180), closeTo(0.45, 1e-6));

        // Midway between 360m (0.70) and 480m (0.82) -> 420m = 0.76
        expect(ActivityXpCalculator.durationFactor(420), closeTo(0.76, 1e-6));
      });

      test('rejects negative duration', () {
        expect(() => ActivityXpCalculator.durationFactor(-1), throwsArgumentError);
      });
    });

    group('Final calculateActivityXp Formula & Edge Cases', () {
      test('Difficulty 5 anchor points match expected rounded integers', () {
        // Ceiling = 15
        expect(ActivityXpCalculator.calculateActivityXp(5, Duration.zero), equals(0));
        // 15 * 0.05 = 0.75 -> 1
        expect(ActivityXpCalculator.calculateActivityXp(5, const Duration(minutes: 15)), equals(1));
        // 15 * 0.10 = 1.5 -> 2
        expect(ActivityXpCalculator.calculateActivityXp(5, const Duration(minutes: 30)), equals(2));
        // 15 * 0.20 = 3.0 -> 3
        expect(ActivityXpCalculator.calculateActivityXp(5, const Duration(minutes: 60)), equals(3));
        // 15 * 0.35 = 5.25 -> 5
        expect(ActivityXpCalculator.calculateActivityXp(5, const Duration(minutes: 120)), equals(5));
        // 15 * 0.55 = 8.25 -> 8 (4 hours)
        expect(ActivityXpCalculator.calculateActivityXp(5, const Duration(hours: 4)), equals(8));
        // 15 * 0.70 = 10.5 -> 11
        expect(ActivityXpCalculator.calculateActivityXp(5, const Duration(hours: 6)), equals(11));
        // 15 * 0.82 = 12.3 -> 12
        expect(ActivityXpCalculator.calculateActivityXp(5, const Duration(hours: 8)), equals(12));
        // 15 * 0.92 = 13.8 -> 14
        expect(ActivityXpCalculator.calculateActivityXp(5, const Duration(hours: 10)), equals(14));
        // 15 * 1.00 = 15.0 -> 15 (12 hours)
        expect(ActivityXpCalculator.calculateActivityXp(5, const Duration(hours: 12)), equals(15));
      });

      test('Difficulty 10 at maximum 12 hours yields exact 30 XP', () {
        // Ceiling = 30, Factor = 1.0 -> 30 XP
        final xp = ActivityXpCalculator.calculateActivityXp(10, const Duration(hours: 12));
        expect(xp, equals(30));
        expect(xp, equals(ActivityXpCalculator.maxActivityXp));
      });

      test('Difficulty 1 at maximum 12 hours yields exact 3 XP', () {
        // Ceiling = 3, Factor = 1.0 -> 3 XP
        final xp = ActivityXpCalculator.calculateActivityXp(1, const Duration(hours: 12));
        expect(xp, equals(3));
      });

      test('Zero duration yields 0 XP regardless of difficulty', () {
        for (var d = 1; d <= 10; d++) {
          expect(ActivityXpCalculator.calculateActivityXp(d, Duration.zero), equals(0));
        }
      });

      test('rejects negative duration in calculateActivityXp', () {
        expect(
          () => ActivityXpCalculator.calculateActivityXp(5, const Duration(minutes: -10)),
          throwsArgumentError,
        );
      });

      test('rejects duration exceeding 12 hours (720 minutes)', () {
        expect(
          () => ActivityXpCalculator.calculateActivityXp(5, const Duration(minutes: 721)),
          throwsArgumentError,
        );
        expect(
          () => ActivityXpCalculator.calculateActivityXp(5, const Duration(hours: 13)),
          throwsArgumentError,
        );
      });

      test('rejects out-of-range difficulty in calculateActivityXp', () {
        expect(
          () => ActivityXpCalculator.calculateActivityXp(0, const Duration(hours: 1)),
          throwsArgumentError,
        );
        expect(
          () => ActivityXpCalculator.calculateActivityXp(11, const Duration(hours: 1)),
          throwsArgumentError,
        );
      });
    });
  });
}
