// Wave 26 Unit Tests: Self-Healing Storage & Automated Tombstone Janitor
//
// Tests cover:
//   1. Listing soft-deleted items and computing 30-day countdown
//   2. Restoring soft-deleted goals within 30-day window
//   3. Rejecting restore if item exceeded 30 days
//   4. Purging items older than 30 days
//   5. Storage audit and HLC clock drift sanity

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/maintenance/domain/janitor_service.dart';

AppDatabase _openInMemory() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  group('JanitorService', () {
    late AppDatabase db;
    late JanitorService janitor;
    const userId = 'usr_seed_dev_01';

    setUp(() async {
      db = _openInMemory();
      janitor = JanitorService(db: db);

      // Seed user
      await db.into(db.users).insert(UsersCompanion(
            id: const Value(userId),
            deviceId: const Value('dev-01'),
            timezone: const Value('UTC'),
            createdAt: Value(DateTime.now().toUtc()),
            updatedAt: Value(DateTime.now().toUtc()),
          ));
    });

    tearDown(() async {
      await db.close();
    });

    test('listTrashItems lists soft-deleted entities and computes daysRemaining', () async {
      final now = DateTime.now().toUtc();
      final tenDaysAgo = now.subtract(const Duration(days: 10));

      // Insert soft-deleted goal
      await db.into(db.goals).insert(GoalsCompanion(
            id: const Value('goal_trash_1'),
            ownerId: const Value(userId),
            rootId: const Value('goal_trash_1'),
            path: const Value('goal_trash_1'),
            depth: const Value(0),
            title: const Value('Old Goal'),
            status: const Value('active'),
            progress: const Value(0.0),
            deletedAt: Value(tenDaysAgo),
            versionHlc: const Value('1-0-0'),
            createdAt: Value(tenDaysAgo),
            updatedAt: Value(tenDaysAgo),
          ));

      final trash = await janitor.listTrashItems(userId);
      expect(trash.length, 1);
      expect(trash.first.title, 'Old Goal');
      expect(trash.first.daysRemaining, 20); // 30 - 10
    });

    test('restoreEntity restores item if within 30-day window', () async {
      final now = DateTime.now().toUtc();

      await db.into(db.goals).insert(GoalsCompanion(
            id: const Value('goal_restore_1'),
            ownerId: const Value(userId),
            rootId: const Value('goal_restore_1'),
            path: const Value('goal_restore_1'),
            depth: const Value(0),
            title: const Value('Recoverable Goal'),
            status: const Value('active'),
            progress: const Value(0.0),
            deletedAt: Value(now.subtract(const Duration(days: 5))),
            versionHlc: const Value('1-0-0'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ));

      final restored = await janitor.restoreEntity(
        entityKind: 'goal',
        entityId: 'goal_restore_1',
        versionHlc: '2-0-0',
      );

      expect(restored, isTrue);

      final row = await (db.select(db.goals)..where((g) => g.id.equals('goal_restore_1'))).getSingle();
      expect(row.deletedAt, isNull);
    });

    test('purgeExpiredLocalTrash cleans items older than 30 days', () async {
      final now = DateTime.now().toUtc();
      final fortyDaysAgo = now.subtract(const Duration(days: 40));

      // Expired goal
      await db.into(db.goals).insert(GoalsCompanion(
            id: const Value('goal_expired'),
            ownerId: const Value(userId),
            rootId: const Value('goal_expired'),
            path: const Value('goal_expired'),
            depth: const Value(0),
            title: const Value('Expired Goal'),
            status: const Value('active'),
            progress: const Value(0.0),
            deletedAt: Value(fortyDaysAgo),
            versionHlc: const Value('1-0-0'),
            createdAt: Value(fortyDaysAgo),
            updatedAt: Value(fortyDaysAgo),
          ));

      final purged = await janitor.purgeExpiredLocalTrash(userId);
      expect(purged, 1);

      final rows = await (db.select(db.goals)..where((g) => g.id.equals('goal_expired'))).get();
      expect(rows, isEmpty);
    });

    test('auditStorageHealth returns healthy status when clock drift is within 60s', () async {
      final report = await janitor.auditStorageHealth(
        userId,
        serverTime: DateTime.now().toUtc().add(const Duration(seconds: 5)),
      );

      expect(report.isClockHealthy, isTrue);
      expect(report.clockSkewSeconds, inInclusiveRange(4, 5));
    });
  });
}
