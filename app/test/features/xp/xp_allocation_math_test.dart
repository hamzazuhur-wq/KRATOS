// Wave 5 tests: Hamilton-Hare Largest-Remainder math & Late penalty calculation.

import 'package:flutter_test/flutter_test.dart';
import 'package:kratos/domain/errors.dart';
import 'package:kratos/domain/ids.dart';
import 'package:kratos/features/xp/domain/xp_allocation_math.dart';

void main() {
  final areaA = Id.uuidV7();
  final areaB = Id.uuidV7();
  final areaC = Id.uuidV7();

  group('HamiltonHareAllocator', () {
    test('allocates 100 points equally across 3 shares with exact sum', () {
      final ratios = [
        AllocationRatio(lifeAreaId: areaA, percentage: 33.33),
        AllocationRatio(lifeAreaId: areaB, percentage: 33.33),
        AllocationRatio(lifeAreaId: areaC, percentage: 33.33),
      ];

      final results = HamiltonHareAllocator.allocate(
        totalPoints: 100,
        ratios: ratios,
      );

      expect(results.length, 3);
      final sum = results.fold<int>(0, (s, r) => s + r.points);
      expect(sum, 100, reason: 'Invariant #2: sum must exactly equal totalPoints');
    });

    test('allocates 10 points across 3 equal shares', () {
      final ratios = [
        AllocationRatio(lifeAreaId: areaA, percentage: 10),
        AllocationRatio(lifeAreaId: areaB, percentage: 10),
        AllocationRatio(lifeAreaId: areaC, percentage: 10),
      ];

      final results = HamiltonHareAllocator.allocate(
        totalPoints: 10,
        ratios: ratios,
      );

      final sum = results.fold<int>(0, (s, r) => s + r.points);
      expect(sum, 10);
      // Floor is 3 for each; 1 remainder distributed
      expect(results.map((r) => r.points).toList(), containsAll([4, 3, 3]));
    });

    test('allocates 100% to single share correctly', () {
      final ratios = [
        AllocationRatio(lifeAreaId: areaA, percentage: 100),
      ];

      final results = HamiltonHareAllocator.allocate(
        totalPoints: 75,
        ratios: ratios,
      );

      expect(results.length, 1);
      expect(results.first.points, 75);
    });

    test('allocates negative points (compensating reversal) correctly', () {
      final ratios = [
        AllocationRatio(lifeAreaId: areaA, percentage: 60),
        AllocationRatio(lifeAreaId: areaB, percentage: 40),
      ];

      final results = HamiltonHareAllocator.allocate(
        totalPoints: -50,
        ratios: ratios,
      );

      final sum = results.fold<int>(0, (s, r) => s + r.points);
      expect(sum, -50);
      expect(results.first.points, -30);
      expect(results.last.points, -20);
    });

    test('throws ValidationError when totalPoints is zero', () {
      final ratios = [AllocationRatio(lifeAreaId: areaA, percentage: 100)];
      expect(
        () => HamiltonHareAllocator.allocate(totalPoints: 0, ratios: ratios),
        throwsA(isA<ValidationError>()),
      );
    });

    test('throws ValidationError when ratios list is empty', () {
      expect(
        () => HamiltonHareAllocator.allocate(totalPoints: 50, ratios: []),
        throwsA(isA<ValidationError>()),
      );
    });
  });

  group('LatePenaltyCalculator', () {
    final now = DateTime.utc(2026, 9, 23, 12, 0);

    test('returns 30% penalty when item is overdue', () {
      final overdue = DateTime.utc(2026, 9, 20); // 3 days ago
      final penalty = LatePenaltyCalculator.calculate(
        dueDate: overdue,
        status: 'pending',
        basePoints: 100,
        now: now,
      );
      expect(penalty, 30);
    });

    test('returns 0 penalty when item is not overdue', () {
      final futureDue = DateTime.utc(2026, 9, 25);
      final penalty = LatePenaltyCalculator.calculate(
        dueDate: futureDue,
        status: 'pending',
        basePoints: 100,
        now: now,
      );
      expect(penalty, 0);
    });

    test('returns 0 penalty for cancelled items even if overdue (Invariant #8)', () {
      final overdue = DateTime.utc(2026, 9, 20);
      final penalty = LatePenaltyCalculator.calculate(
        dueDate: overdue,
        status: 'cancelled',
        basePoints: 100,
        now: now,
      );
      expect(penalty, 0);
    });

    test('returns 0 penalty when dueDate is null', () {
      final penalty = LatePenaltyCalculator.calculate(
        dueDate: null,
        status: 'pending',
        basePoints: 100,
        now: now,
      );
      expect(penalty, 0);
    });
  });
}
