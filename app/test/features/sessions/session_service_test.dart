import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/sessions/domain/session_clock.dart';
import 'package:kratos_app/features/sessions/domain/session_service.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late SessionService svc;
  const owner = 'user_focus_001';
  const area = 'la_focus_001';
  const actA = 'act_a';
  const actB = 'act_b';

  DateTime t(int h, int m, [int s = 0]) =>
      DateTime.utc(2026, 10, 8, h, m, s);

  Future<void> seedActivity(String id, {int difficulty = 5}) => db
      .into(db.activities)
      .insert(
        ActivitiesCompanion.insert(
          id: id,
          ownerId: owner,
          name: 'Activity $id',
          lifeAreaId: const drift.Value(area),
          difficulty: drift.Value(difficulty),
          versionHlc: '0:0:0',
          createdAt: t(0, 0),
          updatedAt: t(0, 0),
        ),
      );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    now = t(10, 0);
    svc = SessionService(db, clock: () => now);
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: owner,
            deviceId: 'dev',
            timezone: 'UTC',
            createdAt: t(0, 0),
            updatedAt: t(0, 0),
          ),
        );
    await db
        .into(db.lifeAreas)
        .insert(
          LifeAreasCompanion.insert(
            id: area,
            ownerId: owner,
            name: 'Design',
            sortOrder: 1,
            versionHlc: '0:0:0',
            createdAt: t(0, 0),
            updatedAt: t(0, 0),
          ),
        );
    await seedActivity(actA);
    await seedActivity(actB);
  });

  tearDown(() => db.close());

  Future<List<SyncOutboxData>> outbox() =>
      (db.select(db.syncOutbox)..where((o) => o.entity.equals('sessions'))).get();
  Future<List<XpLedgerData>> ledger() => db.select(db.xpLedger).get();

  group('SessionClock', () {
    test('excludes paused time', () {
      expect(
        SessionClock.focusedMs(
          startedAt: t(10, 0),
          now: t(11, 0),
          pausedTotalMs: 10 * 60000,
        ),
        50 * 60000,
      );
    });
    test('currently-paused interval is excluded', () {
      expect(
        SessionClock.focusedMs(
          startedAt: t(10, 0),
          now: t(11, 0),
          pausedAt: t(10, 30),
        ),
        30 * 60000,
      );
    });
    test('never negative', () {
      expect(
        SessionClock.focusedMs(startedAt: t(11, 0), now: t(10, 0)),
        0,
      );
    });
  });

  group('start / stop', () {
    test('start persists a running row immediately with exact startedAt', () async {
      final s = await svc.start(
        ownerId: owner,
        entityType: 'activity',
        entityId: actA,
      );
      final row = await svc.find(s.id);
      expect(row, isNotNull);
      expect(row!.status, SessionStatus.running);
      expect(row.startedAt.toUtc(), t(10, 0));
      expect(row.endedAt, isNull);
      expect(row.activityId, actA);
      expect(row.lifeAreaId, area, reason: 'context resolved from activity');
      expect(await outbox(), isEmpty, reason: 'only finalized sessions sync');
    });

    test('stop finalizes endedAt/duration, queues outbox, awards XP once', () async {
      final s = await svc.start(
        ownerId: owner,
        entityType: 'activity',
        entityId: actA,
      );
      now = t(10, 45);
      final r = (await svc.stop(s.id))!;
      expect(r.finalizedNow, isTrue);
      expect(r.durationMs, 45 * 60000);
      expect(r.xpEarned, greaterThan(0));

      final row = (await svc.find(s.id))!;
      expect(row.status, SessionStatus.completed);
      expect(row.endedAt!.toUtc(), t(10, 45));
      expect(row.durationMs, 45 * 60000);

      final ob = await outbox();
      expect(ob, hasLength(1));
      final payload = jsonDecode(ob.single.payloadJson) as Map;
      expect(payload['id'], s.id, reason: 'same canonical id offline->server');
      expect(payload['duration_ms'], 45 * 60000);
      expect(payload['status'], 'completed');
      expect(payload['source'], 'timer');

      expect(await ledger(), hasLength(1));
    });

    test('stopping twice never duplicates outbox or XP', () async {
      final s = await svc.start(
        ownerId: owner,
        entityType: 'activity',
        entityId: actA,
      );
      now = t(10, 30);
      await svc.stop(s.id);
      now = t(10, 40);
      final again = (await svc.stop(s.id))!;
      expect(again.finalizedNow, isFalse);
      expect(again.xpEarned, 0);
      expect(again.durationMs, 30 * 60000, reason: 'duration is frozen');
      expect(await outbox(), hasLength(1));
      expect(await ledger(), hasLength(1));
    });

    test('sessions under 5s earn no XP but are still recorded', () async {
      final s = await svc.start(
        ownerId: owner,
        entityType: 'activity',
        entityId: actA,
      );
      now = t(10, 0, 3);
      final r = (await svc.stop(s.id))!;
      expect(r.durationMs, 3000);
      expect(r.xpEarned, 0);
      expect(await ledger(), isEmpty);
    });
  });

  group('pause / resume', () {
    test('paused interval is excluded; multiple segments sum correctly', () async {
      final s = await svc.start(
        ownerId: owner,
        entityType: 'activity',
        entityId: actA,
      );
      now = t(10, 20);
      await svc.pause(s.id); // 20 focused
      now = t(10, 30);
      await svc.resume(s.id); // 10 paused
      now = t(10, 50);
      await svc.pause(s.id); // +20 focused (40)
      now = t(11, 0);
      await svc.resume(s.id); // +10 paused
      now = t(11, 10);
      final r = (await svc.stop(s.id))!; // +10 focused (50)
      expect(r.durationMs, 50 * 60000);
      final row = (await svc.find(s.id))!;
      expect(row.pausedTotalMs, 20 * 60000);
    });

    test('stop while paused excludes the trailing pause', () async {
      final s = await svc.start(
        ownerId: owner,
        entityType: 'activity',
        entityId: actA,
      );
      now = t(10, 30);
      await svc.pause(s.id);
      now = t(12, 0);
      final r = (await svc.stop(s.id))!;
      expect(r.durationMs, 30 * 60000);
    });
  });

  group('restart / background restore', () {
    test('active session is restored from Drift with correct elapsed', () async {
      final s = await svc.start(
        ownerId: owner,
        entityType: 'activity',
        entityId: actA,
      );
      // Simulate: app backgrounded at 10:30, process killed, returns 11:15.
      final svc2 = SessionService(db, clock: () => t(11, 15));
      final restored = (await svc2.activeSession(owner))!;
      expect(restored.id, s.id, reason: 'never reset on restart');
      expect(restored.startedAt.toUtc(), t(10, 0));
      expect(
        SessionClock.focusedMs(
          startedAt: restored.startedAt,
          now: t(11, 15),
          pausedTotalMs: restored.pausedTotalMs,
          pausedAt: restored.pausedAt,
        ),
        75 * 60000,
      );
    });

    test('paused state survives restart', () async {
      final s = await svc.start(
        ownerId: owner,
        entityType: 'activity',
        entityId: actA,
      );
      now = t(10, 30);
      await svc.pause(s.id);
      final restored = (await SessionService(db).activeSession(owner))!;
      expect(restored.status, SessionStatus.paused);
      expect(restored.pausedAt!.toUtc(), t(10, 30));
    });
  });

  group('overlap policy', () {
    test('starting the same entity returns the existing session', () async {
      final a = await svc.start(
        ownerId: owner,
        entityType: 'activity',
        entityId: actA,
      );
      now = t(10, 5);
      final b = await svc.start(
        ownerId: owner,
        entityType: 'activity',
        entityId: actA,
      );
      expect(b.id, a.id);
      expect(await db.select(db.sessions).get(), hasLength(1));
    });

    test('starting another entity finalizes the previous (no overlap)', () async {
      final a = await svc.start(
        ownerId: owner,
        entityType: 'activity',
        entityId: actA,
      );
      now = t(10, 30);
      final b = await svc.start(
        ownerId: owner,
        entityType: 'activity',
        entityId: actB,
      );
      final first = (await svc.find(a.id))!;
      expect(first.status, SessionStatus.completed);
      expect(first.endedAt!.toUtc(), t(10, 30));
      expect(b.startedAt.toUtc(), t(10, 30));
      final active = await (db.select(db.sessions)
            ..where((s) => s.status.isIn(['running', 'paused'])))
          .get();
      expect(active, hasLength(1));
      expect(active.single.id, b.id);
    });
  });

  group('manual entry', () {
    test('uses the same model with source=manual, queues outbox, awards XP', () async {
      final r = await svc.logManual(
        ownerId: owner,
        entityType: 'activity',
        entityId: actA,
        startedAt: t(8, 0),
        endedAt: t(9, 30),
      );
      final row = (await svc.find(r.sessionId))!;
      expect(row.source, SessionSource.manual);
      expect(row.status, SessionStatus.completed);
      expect(row.durationMs, 90 * 60000);
      expect(await outbox(), hasLength(1));
      expect(r.xpEarned, greaterThan(0));
      expect(await ledger(), hasLength(1));
    });
  });

  group('discard', () {
    test('discarding an unfinished session leaves no row, outbox, or XP', () async {
      final s = await svc.start(
        ownerId: owner,
        entityType: 'activity',
        entityId: actA,
      );
      await svc.discard(s.id);
      expect(await svc.find(s.id), isNull);
      expect(await outbox(), isEmpty);
      expect(await ledger(), isEmpty);
    });
  });
}
