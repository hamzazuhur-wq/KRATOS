// Wave 5: Drift implementation of XpLedgerWriter.
// Coordinates local append-only ledger writes, outbox queuing, and idempotency caching.

import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/errors.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../domain/xp_allocation_math.dart';
import '../domain/xp_ledger_event.dart';
import '../domain/xp_ledger_writer.dart';
import 'xp_ledger_dao.dart';

class DriftXpLedgerWriter implements XpLedgerWriter {
  final AppDatabase _db;
  final XpLedgerDao _dao;

  DriftXpLedgerWriter(this._db) : _dao = XpLedgerDao(_db);

  @override
  Future<bool> isIdempotencyKeyProcessed(Id idempotencyKey) async {
    final cached = await _dao.isKeyInCache(idempotencyKey.value);
    if (cached) return true;
    final row = await _dao.findByIdempotencyKey(idempotencyKey.value);
    return row != null;
  }

  @override
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
  }) async {
    // 1. Idempotency Check: if key already executed, return existing event
    final existingRow =
        await _dao.findByIdempotencyKey(idempotencyKey.value);
    if (existingRow != null) {
      final existingLines = await _dao.linesForLedger(existingRow.id);
      return _rowToDomain(existingRow, existingLines);
    }

    // 2. Compute Net Points
    final netPoints = basePoints + bonusPoints - latePenalty + streakBonus;
    if (netPoints == 0) {
      throw ValidationError('Net XP points cannot be zero');
    }

    // 3. Proportional apportionment via Hamilton-Hare method (Invariant #2)
    final allocatedResults = HamiltonHareAllocator.allocate(
      totalPoints: netPoints,
      ratios: allocationRatios,
    );

    final eventId = Id.uuidV7();
    final now = DateTime.now().toUtc();

    final lineEntities = allocatedResults.map((r) {
      return XpAllocationLineEntity(
        id: Id.uuidV7(),
        lifeAreaId: r.lifeAreaId,
        allocatedPoints: r.points,
        percentage: r.percentage,
        versionHlc: clock,
        createdAt: now,
      );
    }).toList();

    final event = XpLedgerEvent.create(
      id: eventId,
      ownerId: ownerId,
      idempotencyKey: idempotencyKey,
      sourceType: sourceType,
      sourceId: sourceId,
      action: action,
      basePoints: basePoints,
      bonusPoints: bonusPoints,
      latePenalty: latePenalty,
      streakBonus: streakBonus,
      categoryRuleVersionId: categoryRuleVersionId,
      versionHlc: clock,
      deviceId: deviceId,
      lines: lineEntities,
      createdAt: now,
    );

    // 4. Atomic Drift transaction for Ledger + Allocations + Outbox + Cache (Invariant #13)
    await _db.transaction(() async {
      // a. Insert parent xp_ledger row
      await _dao.insertLedgerRow(XpLedgerCompanion(
        id: Value(event.id.value),
        ownerId: Value(event.ownerId.value),
        idempotencyKey: Value(event.idempotencyKey.value),
        sourceType: Value(event.sourceType),
        sourceId: Value(event.sourceId.value),
        action: Value(event.action),
        points: Value(event.points),
        basePoints: Value(event.basePoints),
        bonusPoints: Value(event.bonusPoints),
        latePenalty: Value(event.latePenalty),
        streakBonus: Value(event.streakBonus),
        categoryRuleVersionId: Value(event.categoryRuleVersionId?.value),
        reversalEventId: Value(event.reversalEventId?.value),
        versionHlc: Value(event.versionHlc.toString()),
        deviceId: Value(event.deviceId.value),
        createdAt: Value(event.createdAt),
      ));

      // b. Insert child xp_allocation_lines
      final companions = event.lines.map((l) {
        return XpAllocationLinesCompanion(
          id: Value(l.id.value),
          ledgerId: Value(event.id.value),
          lifeAreaId: Value(l.lifeAreaId.value),
          allocatedPoints: Value(l.allocatedPoints),
          percentage: Value(l.percentage),
          versionHlc: Value(l.versionHlc.toString()),
          createdAt: Value(l.createdAt),
        );
      }).toList();
      await _dao.insertAllocationLines(companions);

      // c. Enqueue into sync_outbox (same transaction)
      await _db.into(_db.syncOutbox).insert(SyncOutboxCompanion(
        userId: Value(event.ownerId.value),
        op: const Value('INSERT'),
        entity: const Value('xp_ledger'),
        entityId: Value(event.id.value),
        payloadJson: Value(jsonEncode(event.toRpcPayload())),
        hlc: Value(event.versionHlc.toString()),
        deviceId: Value(event.deviceId.value),
        idempotencyKey: Value(event.idempotencyKey.value),
        status: const Value('pending'),
      ));

      // d. Record in local idempotency key fast lookup cache
      await _dao.markKeyProcessed(event.idempotencyKey.value, event.ownerId.value);
    });

    return event;
  }

  @override
  Future<XpLedgerEvent> reverse({
    required Id originalEventId,
    required String reason,
    required Hlc clock,
    required Id deviceId,
    required Id idempotencyKey,
  }) async {
    // 1. Fetch original event
    final originalRow = await _dao.findById(originalEventId.value);
    if (originalRow == null) {
      throw ValidationError(
          'Cannot reverse non-existent ledger event: ${originalEventId.value}');
    }

    if (originalRow.action == 'reversal') {
      throw ValidationError('Cannot reverse an existing reversal event');
    }

    // 2. Fetch original allocation lines
    final originalLines = await _dao.linesForLedger(originalEventId.value);
    if (originalLines.isEmpty) {
      throw InvariantViolation(
          'Original event ${originalEventId.value} has no allocation lines');
    }

    final reversalId = Id.uuidV7();
    final now = DateTime.now().toUtc();

    // 3. Create compensating inverted allocation lines
    final compensatingLines = originalLines.map((l) {
      return XpAllocationLineEntity(
        id: Id.uuidV7(),
        lifeAreaId: Id(l.lifeAreaId),
        allocatedPoints: -l.allocatedPoints,
        percentage: l.percentage,
        versionHlc: clock,
        createdAt: now,
      );
    }).toList();

    // 4. Construct compensating XpLedgerEvent (Invariant #1)
    final compensatingEvent = XpLedgerEvent.create(
      id: reversalId,
      ownerId: Id(originalRow.ownerId),
      idempotencyKey: idempotencyKey,
      sourceType: 'reversal',
      sourceId: originalEventId,
      action: 'reversal',
      basePoints: originalRow.basePoints != null ? -originalRow.basePoints! : null,
      bonusPoints: -originalRow.bonusPoints,
      latePenalty: -originalRow.latePenalty,
      streakBonus: -originalRow.streakBonus,
      categoryRuleVersionId: originalRow.categoryRuleVersionId != null
          ? Id(originalRow.categoryRuleVersionId!)
          : null,
      reversalEventId: originalEventId,
      versionHlc: clock,
      deviceId: deviceId,
      lines: compensatingLines,
      createdAt: now,
    );

    // 5. Atomic write
    await _db.transaction(() async {
      await _dao.insertLedgerRow(XpLedgerCompanion(
        id: Value(compensatingEvent.id.value),
        ownerId: Value(compensatingEvent.ownerId.value),
        idempotencyKey: Value(compensatingEvent.idempotencyKey.value),
        sourceType: Value(compensatingEvent.sourceType),
        sourceId: Value(compensatingEvent.sourceId.value),
        action: Value(compensatingEvent.action),
        points: Value(compensatingEvent.points),
        basePoints: Value(compensatingEvent.basePoints),
        bonusPoints: Value(compensatingEvent.bonusPoints),
        latePenalty: Value(compensatingEvent.latePenalty),
        streakBonus: Value(compensatingEvent.streakBonus),
        categoryRuleVersionId:
            Value(compensatingEvent.categoryRuleVersionId?.value),
        reversalEventId: Value(compensatingEvent.reversalEventId?.value),
        versionHlc: Value(compensatingEvent.versionHlc.toString()),
        deviceId: Value(compensatingEvent.deviceId.value),
        createdAt: Value(compensatingEvent.createdAt),
      ));

      final companions = compensatingEvent.lines.map((l) {
        return XpAllocationLinesCompanion(
          id: Value(l.id.value),
          ledgerId: Value(compensatingEvent.id.value),
          lifeAreaId: Value(l.lifeAreaId.value),
          allocatedPoints: Value(l.allocatedPoints),
          percentage: Value(l.percentage),
          versionHlc: Value(l.versionHlc.toString()),
          createdAt: Value(l.createdAt),
        );
      }).toList();
      await _dao.insertAllocationLines(companions);

      await _db.into(_db.syncOutbox).insert(SyncOutboxCompanion(
        userId: Value(compensatingEvent.ownerId.value),
        op: const Value('INSERT'),
        entity: const Value('xp_ledger'),
        entityId: Value(compensatingEvent.id.value),
        payloadJson: Value(jsonEncode(compensatingEvent.toRpcPayload())),
        hlc: Value(compensatingEvent.versionHlc.toString()),
        deviceId: Value(compensatingEvent.deviceId.value),
        idempotencyKey: Value(compensatingEvent.idempotencyKey.value),
        status: const Value('pending'),
      ));

      await _dao.markKeyProcessed(
        compensatingEvent.idempotencyKey.value,
        compensatingEvent.ownerId.value,
      );
    });

    return compensatingEvent;
  }

  XpLedgerEvent _rowToDomain(
    XpLedgerData row,
    List<XpAllocationLine> lines,
  ) {
    return XpLedgerEvent.create(
      id: Id(row.id),
      ownerId: Id(row.ownerId),
      idempotencyKey: Id(row.idempotencyKey),
      sourceType: row.sourceType,
      sourceId: Id(row.sourceId),
      action: row.action,
      basePoints: row.basePoints,
      bonusPoints: row.bonusPoints,
      latePenalty: row.latePenalty,
      streakBonus: row.streakBonus,
      categoryRuleVersionId: row.categoryRuleVersionId != null
          ? Id(row.categoryRuleVersionId!)
          : null,
      reversalEventId:
          row.reversalEventId != null ? Id(row.reversalEventId!) : null,
      versionHlc: Hlc.parse(row.versionHlc),
      deviceId: Id(row.deviceId),
      createdAt: row.createdAt,
      lines: lines.map((l) {
        return XpAllocationLineEntity(
          id: Id(l.id),
          lifeAreaId: Id(l.lifeAreaId),
          allocatedPoints: l.allocatedPoints,
          percentage: l.percentage,
          versionHlc: Hlc.parse(l.versionHlc),
          createdAt: l.createdAt,
        );
      }).toList(),
    );
  }
}
