// Wave 5: Domain entity for XP Ledger events and allocation lines.
// Pure Dart — enforces append-only, sum invariant, and arithmetic integrity.

import '../../../domain/errors.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';

/// Single allocation breakdown line.
class XpAllocationLineEntity {
  final Id id;
  final Id lifeAreaId;
  final int allocatedPoints;
  final double percentage;
  final Hlc versionHlc;
  final DateTime createdAt;

  const XpAllocationLineEntity({
    required this.id,
    required this.lifeAreaId,
    required this.allocatedPoints,
    required this.percentage,
    required this.versionHlc,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id.value,
        'life_area_id': lifeAreaId.value,
        'allocated_points': allocatedPoints,
        'percentage': percentage,
      };
}

/// Immutable domain entity representing an append-only row in `xp_ledger`.
class XpLedgerEvent {
  final Id id;
  final Id ownerId;
  final Id idempotencyKey;
  final String sourceType;
  final Id sourceId;
  final String action;
  final int points;
  final int? basePoints;
  final int bonusPoints;
  final int latePenalty;
  final int streakBonus;
  final Id? categoryRuleVersionId;
  final Id? reversalEventId;
  final Hlc versionHlc;
  final Id deviceId;
  final DateTime createdAt;
  final List<XpAllocationLineEntity> lines;

  XpLedgerEvent._({
    required this.id,
    required this.ownerId,
    required this.idempotencyKey,
    required this.sourceType,
    required this.sourceId,
    required this.action,
    required this.points,
    required this.basePoints,
    required this.bonusPoints,
    required this.latePenalty,
    required this.streakBonus,
    required this.categoryRuleVersionId,
    required this.reversalEventId,
    required this.versionHlc,
    required this.deviceId,
    required this.createdAt,
    required this.lines,
  });

  /// Factory validating all core invariants upon creation.
  factory XpLedgerEvent.create({
    required Id id,
    required Id ownerId,
    required Id idempotencyKey,
    required String sourceType,
    required Id sourceId,
    required String action,
    required int? basePoints,
    required int bonusPoints,
    required int latePenalty,
    required int streakBonus,
    required Hlc versionHlc,
    required Id deviceId,
    required List<XpAllocationLineEntity> lines,
    Id? categoryRuleVersionId,
    Id? reversalEventId,
    DateTime? createdAt,
  }) {
    final computedPoints =
        (basePoints ?? 0) + bonusPoints - latePenalty + streakBonus;

    if (computedPoints == 0) {
      throw ValidationError('points', 'Total XP points cannot be zero');
    }

    if (lines.isEmpty) {
      throw ValidationError('lines', 'At least one allocation line is required');
    }

    final sumAllocated =
        lines.fold<int>(0, (sum, line) => sum + line.allocatedPoints);
    if (sumAllocated != computedPoints) {
      throw InvariantViolation(
        'allocation_sum', 'Allocation lines sum ($sumAllocated) does not match total points ($computedPoints) (Invariant #2)',
      );
    }

    return XpLedgerEvent._(
      id: id,
      ownerId: ownerId,
      idempotencyKey: idempotencyKey,
      sourceType: sourceType,
      sourceId: sourceId,
      action: action,
      points: computedPoints,
      basePoints: basePoints,
      bonusPoints: bonusPoints,
      latePenalty: latePenalty,
      streakBonus: streakBonus,
      categoryRuleVersionId: categoryRuleVersionId,
      reversalEventId: reversalEventId,
      versionHlc: versionHlc,
      deviceId: deviceId,
      createdAt: createdAt ?? DateTime.now().toUtc(),
      lines: List.unmodifiable(lines),
    );
  }

  /// Exports payload formatted for the server `record_xp_event` RPC.
  Map<String, dynamic> toRpcPayload() => {
        'id': id.value,
        'owner_id': ownerId.value,
        'idempotency_key': idempotencyKey.value,
        'source_type': sourceType,
        'source_id': sourceId.value,
        'action': action,
        'points': points,
        'base_points': basePoints,
        'bonus_points': bonusPoints,
        'late_penalty': latePenalty,
        'streak_bonus': streakBonus,
        'category_rule_version_id': categoryRuleVersionId?.value,
        'reversal_event_id': reversalEventId?.value,
        'version_hlc': versionHlc.toString(),
        'device_id': deviceId.value,
        'allocation_lines': lines.map((l) => l.toJson()).toList(),
      };
}
