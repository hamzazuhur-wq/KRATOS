import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Decisions & ActivityEvents Foundation Tests', () {
    test('Can create, query, and resolve a Decision', () async {
      final now = DateTime.now().toUtc();
      await db.into(db.users).insert(
        UsersCompanion.insert(
          id: 'user_1',
          deviceId: 'dev_1',
          timezone: 'UTC',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.into(db.lifeAreas).insert(
        LifeAreasCompanion.insert(
          id: 'la_1',
          ownerId: 'user_1',
          name: 'Professional',
          sortOrder: 1,
          versionHlc: '0',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.into(db.decisions).insert(
        DecisionsCompanion.insert(
          id: 'dec_1',
          ownerId: 'user_1',
          title: 'Switch cloud architecture',
          content: const Value('Evaluated latency and cost; switching to Supabase Postgres'),
          lifeAreaId: const Value('la_1'),
          versionHlc: '0',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final decision = await (db.select(db.decisions)..where((d) => d.id.equals('dec_1'))).getSingle();
      expect(decision.title, 'Switch cloud architecture');
      expect(decision.status, 'pending');
      expect(decision.lifeAreaId, 'la_1');

      // Resolve decision
      final resolvedTime = DateTime.now().toUtc();
      await (db.update(db.decisions)..where((d) => d.id.equals('dec_1'))).write(
        DecisionsCompanion(
          status: const Value('resolved'),
          resolvedAt: Value(resolvedTime),
          updatedAt: Value(resolvedTime),
        ),
      );

      final resolved = await (db.select(db.decisions)..where((d) => d.id.equals('dec_1'))).getSingle();
      expect(resolved.status, 'resolved');
      expect(resolved.resolvedAt, isNotNull);
    });

    test('Can record and query ActivityEvents', () async {
      final now = DateTime.now().toUtc();
      await db.into(db.users).insert(
        UsersCompanion.insert(
          id: 'user_2',
          deviceId: 'dev_2',
          timezone: 'UTC',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await db.into(db.activityEvents).insert(
        ActivityEventsCompanion.insert(
          id: 'evt_1',
          ownerId: 'user_2',
          eventType: 'task_completed',
          entityType: 'task',
          entityId: const Value('task_101'),
          metadata: const Value('{"xp": 50, "priority": 1}'),
          occurredAt: now,
          versionHlc: '0',
          createdAt: now,
        ),
      );

      final events = await (db.select(db.activityEvents)..where((e) => e.ownerId.equals('user_2'))).get();
      expect(events.length, 1);
      expect(events.first.eventType, 'task_completed');
      expect(events.first.entityType, 'task');
      expect(events.first.entityId, 'task_101');
    });
  });
}
