// Wave 5: Interface for XPLedgerWriter.
// The sole authorized mutation pathway for XP event generation.
// Invariant #15: No direct XP inserts; all mutations route through this writer.

import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import 'xp_allocation_math.dart';
import 'xp_ledger_event.dart';

abstract class XpLedgerWriter {
  /// Check if an idempotency key has already been executed.
  Future<bool> isIdempotencyKeyProcessed(Id idempotencyKey);

  /// Record an XP event with proportional allocation across LifeAreas.
  ///
  /// Automatically:
  /// 1. Checks idempotency.
  /// 2. Calculates proportional allocation using Hamilton-Hare method.
  /// 3. Writes to `xp_ledger` and `xp_allocation_lines`.
  /// 4. Writes to `sync_outbox` in the same transaction.
  /// 5. Caches in `processed_idempotency_keys`.
  Future<XpLedgerEvent> recordEvent({
    required Id ownerId,
    required Id idempotencyKey,
    required String sourceType,
    required Id sourceId,
    required String action,
    required int basePoints,
    required List<AllocationRatio> allocationRatios,
    required Hlc clock,
    required Id deviceId,
    int bonusPoints = 0,
    int latePenalty = 0,
    int streakBonus = 0,
    Id? categoryRuleVersionId,
    bool enqueueSync = true,
  });

  /// Create a compensating reversal event for an existing ledger event.
  ///
  /// Invariant #1: Ledger is append-only. Corrections write a new event
  /// with negative points and `reversal_event_id` set to the original event.
  Future<XpLedgerEvent> reverse({
    required Id originalEventId,
    required String reason,
    required Hlc clock,
    required Id deviceId,
    required Id idempotencyKey,
  });
}
