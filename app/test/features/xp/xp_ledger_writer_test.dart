// Wave 5 tests: XpLedgerEvent entity invariants and RPC payload validation.

import 'package:flutter_test/flutter_test.dart';
import 'package:kratos/domain/errors.dart';
import 'package:kratos/domain/hlc.dart';
import 'package:kratos/domain/ids.dart';
import 'package:kratos/features/xp/domain/xp_ledger_event.dart';

void main() {
  final ownerId = Id.uuidV7();
  final deviceId = Id.uuidV7();
  final clock = Hlc.now(deviceId);
  final lifeAreaId = Id.uuidV7();

  group('XpLedgerEvent domain entity', () {
    test('enforces allocation lines sum equals total points (Invariant #2)', () {
      final line1 = XpAllocationLineEntity(
        id: Id.uuidV7(),
        lifeAreaId: lifeAreaId,
        allocatedPoints: 30, // Sum = 30, but total points = 100
        percentage: 100.0,
        versionHlc: clock,
        createdAt: DateTime.now().toUtc(),
      );

      expect(
        () => XpLedgerEvent.create(
          id: Id.uuidV7(),
          ownerId: ownerId,
          idempotencyKey: Id.uuidV7(),
          sourceType: 'task',
          sourceId: Id.uuidV7(),
          action: 'complete',
          basePoints: 100,
          bonusPoints: 0,
          latePenalty: 0,
          streakBonus: 0,
          versionHlc: clock,
          deviceId: deviceId,
          lines: [line1],
        ),
        throwsA(isA<InvariantViolation>()),
      );
    });

    test('creates valid event when allocation sum matches points', () {
      final line1 = XpAllocationLineEntity(
        id: Id.uuidV7(),
        lifeAreaId: lifeAreaId,
        allocatedPoints: 100,
        percentage: 100.0,
        versionHlc: clock,
        createdAt: DateTime.now().toUtc(),
      );

      final event = XpLedgerEvent.create(
        id: Id.uuidV7(),
        ownerId: ownerId,
        idempotencyKey: Id.uuidV7(),
        sourceType: 'task',
        sourceId: Id.uuidV7(),
        action: 'complete',
        basePoints: 100,
        bonusPoints: 0,
        latePenalty: 0,
        streakBonus: 0,
        versionHlc: clock,
        deviceId: deviceId,
        lines: [line1],
      );

      expect(event.points, 100);
      expect(event.lines.length, 1);
      expect(event.lines.first.allocatedPoints, 100);
    });

    test('validates net arithmetic with bonuses and penalties', () {
      final line = XpAllocationLineEntity(
        id: Id.uuidV7(),
        lifeAreaId: lifeAreaId,
        allocatedPoints: 85, // 100 base + 15 streak - 30 late = 85
        percentage: 100.0,
        versionHlc: clock,
        createdAt: DateTime.now().toUtc(),
      );

      final event = XpLedgerEvent.create(
        id: Id.uuidV7(),
        ownerId: ownerId,
        idempotencyKey: Id.uuidV7(),
        sourceType: 'task',
        sourceId: Id.uuidV7(),
        action: 'complete',
        basePoints: 100,
        bonusPoints: 0,
        latePenalty: 30,
        streakBonus: 15,
        versionHlc: clock,
        deviceId: deviceId,
        lines: [line],
      );

      expect(event.points, 85);
    });

    test('throws ValidationError when total points is zero', () {
      final line = XpAllocationLineEntity(
        id: Id.uuidV7(),
        lifeAreaId: lifeAreaId,
        allocatedPoints: 0,
        percentage: 100.0,
        versionHlc: clock,
        createdAt: DateTime.now().toUtc(),
      );

      expect(
        () => XpLedgerEvent.create(
          id: Id.uuidV7(),
          ownerId: ownerId,
          idempotencyKey: Id.uuidV7(),
          sourceType: 'task',
          sourceId: Id.uuidV7(),
          action: 'complete',
          basePoints: 0,
          bonusPoints: 0,
          latePenalty: 0,
          streakBonus: 0,
          versionHlc: clock,
          deviceId: deviceId,
          lines: [line],
        ),
        throwsA(isA<ValidationError>()),
      );
    });

    test('serializes to valid RPC payload', () {
      final line = XpAllocationLineEntity(
        id: Id.uuidV7(),
        lifeAreaId: lifeAreaId,
        allocatedPoints: 50,
        percentage: 100.0,
        versionHlc: clock,
        createdAt: DateTime.now().toUtc(),
      );

      final event = XpLedgerEvent.create(
        id: Id.uuidV7(),
        ownerId: ownerId,
        idempotencyKey: Id.uuidV7(),
        sourceType: 'goal',
        sourceId: Id.uuidV7(),
        action: 'milestone',
        basePoints: 50,
        bonusPoints: 0,
        latePenalty: 0,
        streakBonus: 0,
        versionHlc: clock,
        deviceId: deviceId,
        lines: [line],
      );

      final payload = event.toRpcPayload();
      expect(payload['id'], event.id.value);
      expect(payload['owner_id'], ownerId.value);
      expect(payload['points'], 50);
      expect(payload['allocation_lines'], isA<List>());
      expect((payload['allocation_lines'] as List).length, 1);
    });
  });
}
