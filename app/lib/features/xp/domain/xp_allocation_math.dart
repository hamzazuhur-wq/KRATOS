// Wave 5: Hamilton-Hare Largest-Remainder Allocation & Late Penalty Math.
// Pure Dart — zero dependencies, mathematically exact, guarantees zero drift.

import '../../../domain/errors.dart';
import '../../../domain/ids.dart';

/// Requested allocation share for a LifeArea.
class AllocationRatio {
  final Id lifeAreaId;
  final double percentage; // e.g., 50.0 for 50%

  const AllocationRatio({
    required this.lifeAreaId,
    required this.percentage,
  });
}

/// Calculated allocation result with exact integer points.
class AllocatedResult {
  final Id lifeAreaId;
  final int points;
  final double percentage;

  const AllocatedResult({
    required this.lifeAreaId,
    required this.points,
    required this.percentage,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AllocatedResult &&
          other.lifeAreaId == lifeAreaId &&
          other.points == points &&
          other.percentage == percentage);

  @override
  int get hashCode => Object.hash(lifeAreaId, points, percentage);

  @override
  String toString() =>
      'AllocatedResult(lifeAreaId: $lifeAreaId, points: $points, percentage: $percentage%)';
}

/// Implements the Hamilton-Hare Largest Remainder Method for proportional apportionment.
/// Guarantees that SUM(allocated_points) == totalPoints under all inputs without roundoff loss.
class HamiltonHareAllocator {
  const HamiltonHareAllocator._();

  /// Proportionally allocates [totalPoints] across [ratios].
  ///
  /// Enforces:
  /// - `ratios` cannot be empty.
  /// - `totalPoints != 0`.
  /// - Resulting points sum to [totalPoints] exactly (Invariant #2).
  static List<AllocatedResult> allocate({
    required int totalPoints,
    required List<AllocationRatio> ratios,
  }) {
    if (ratios.isEmpty) {
      throw ValidationError('Allocation ratios cannot be empty');
    }
    if (totalPoints == 0) {
      throw ValidationError('Cannot allocate 0 total points');
    }

    final totalPercentage =
        ratios.fold<double>(0, (sum, r) => sum + r.percentage);
    if (totalPercentage <= 0) {
      throw ValidationError('Total allocation percentage must be positive');
    }

    if (totalPoints > 0) {
      return _allocatePositive(totalPoints, ratios, totalPercentage);
    } else {
      return _allocateNegative(totalPoints, ratios, totalPercentage);
    }
  }

  static List<AllocatedResult> _allocatePositive(
    int totalPoints,
    List<AllocationRatio> ratios,
    double totalPercentage,
  ) {
    final floors = <int>[];
    final fractions = <_ItemFraction>[];

    for (var i = 0; i < ratios.length; i++) {
      final normalizedRatio = ratios[i].percentage / totalPercentage;
      final exactQuota = totalPoints * normalizedRatio;
      final floorVal = exactQuota.floor();
      final fraction = exactQuota - floorVal;

      floors.add(floorVal);
      fractions.add(_ItemFraction(
        index: i,
        fraction: fraction,
        idValue: ratios[i].lifeAreaId.value,
      ));
    }

    var allocatedSum = floors.fold<int>(0, (sum, val) => sum + val);
    var remaining = totalPoints - allocatedSum;

    // Sort by largest fractional remainder descending.
    // Ties are broken deterministically by LifeArea ID lexicographical order.
    fractions.sort((a, b) {
      final cmp = b.fraction.compareTo(a.fraction);
      if (cmp != 0) return cmp;
      return a.idValue.compareTo(b.idValue);
    });

    for (var i = 0; i < remaining; i++) {
      final targetIdx = fractions[i % fractions.length].index;
      floors[targetIdx] += 1;
    }

    final results = <AllocatedResult>[];
    for (var i = 0; i < ratios.length; i++) {
      results.add(AllocatedResult(
        lifeAreaId: ratios[i].lifeAreaId,
        points: floors[i],
        percentage: ratios[i].percentage,
      ));
    }

    // Mathematical verification of Invariant #2
    final finalSum = results.fold<int>(0, (sum, r) => sum + r.points);
    if (finalSum != totalPoints) {
      throw InvariantViolation(
          'Hamilton-Hare sum $finalSum does not equal totalPoints $totalPoints');
    }

    return results;
  }

  static List<AllocatedResult> _allocateNegative(
    int totalPoints,
    List<AllocationRatio> ratios,
    double totalPercentage,
  ) {
    // For negative points (compensating reversal events), allocate absolute then invert
    final absAllocations = _allocatePositive(-totalPoints, ratios, totalPercentage);
    return absAllocations
        .map((r) => AllocatedResult(
              lifeAreaId: r.lifeAreaId,
              points: -r.points,
              percentage: r.percentage,
            ))
        .toList();
  }
}

class _ItemFraction {
  final int index;
  final double fraction;
  final String idValue;

  const _ItemFraction({
    required this.index,
    required this.fraction,
    required this.idValue,
  });
}

/// Calculates late penalties according to Invariant #7 and Invariant #8.
class LatePenaltyCalculator {
  const LatePenaltyCalculator._();

  /// Calculates penalty points to subtract.
  ///
  /// Invariants:
  /// - Cancelled items NEVER receive penalties or XP (Invariant #8).
  /// - Overdue items receive -30% penalty of basePoints (Invariant #7).
  static int calculate({
    required DateTime? dueDate,
    required String status,
    required int basePoints,
    DateTime? now,
  }) {
    if (status.toLowerCase() == 'cancelled') {
      return 0;
    }
    if (dueDate == null || basePoints <= 0) {
      return 0;
    }

    final currentTime = now ?? DateTime.now().toUtc();
    if (currentTime.isAfter(dueDate)) {
      // 30% late penalty modifier (ADR-005, Invariant #7)
      return (basePoints * 0.30).round();
    }

    return 0;
  }
}
