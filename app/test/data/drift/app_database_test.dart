import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';

void main() {
  group('AppDatabase', () {
    late AppDatabase db;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
    });

    test('opens and creates all tables', () async {
      const id = 'usr_test_01';
      await db.into(db.users).insert(UsersCompanion.insert(
        id: id,
        deviceId: 'device_01',
        displayName: const Value('Test User'),
        timezone: 'UTC',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ));
      final rows = await db.select(db.users).get();
      expect(rows.length, equals(1));
      expect(rows.first.displayName, equals('Test User'));
    });

    test('goals table supports root goals with null parentId and optional fields', () async {
      await db.into(db.users).insert(UsersCompanion.insert(
        id: 'usr_test_02',
        deviceId: 'device_02',
        timezone: 'UTC',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ));
      const id = 'goal_root_01';
      // Root goal has null parentId, no dueDate, no completedAt, no deletedAt
      await db.into(db.goals).insert(GoalsCompanion.insert(
        id: id,
        ownerId: 'usr_test_02',
        rootId: id,
        path: 'goal_root_01',
        depth: 0,
        title: 'Root Goal',
        status: 'active',
        progress: 0.0,
        versionHlc: '0:0:1',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ));
      final rows = await db.select(db.goals).get();
      expect(rows.length, equals(1));
      expect(rows.first.parentId, isNull);
      expect(rows.first.description, isNull);
      expect(rows.first.completedAt, isNull);
      expect(rows.first.depth, equals(0));
    });

    test('user_streaks supports independent streaks per life area', () async {
      await db.into(db.users).insert(UsersCompanion.insert(
        id: 'usr_test_03',
        deviceId: 'device_03',
        timezone: 'UTC',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ));

      // 2 independent streaks for 2 life areas for the same user
      await db.into(db.userStreaks).insert(UserStreaksCompanion.insert(
        userId: 'usr_test_03',
        lifeAreaId: 'la_sport',
        currentStreak: const Value(5),
        longestStreak: const Value(10),
      ));

      await db.into(db.userStreaks).insert(UserStreaksCompanion.insert(
        userId: 'usr_test_03',
        lifeAreaId: 'la_learning',
        currentStreak: const Value(2),
        longestStreak: const Value(3),
      ));

      final streaks = await db.select(db.userStreaks).get();
      expect(streaks.length, equals(2));
      final sport = streaks.firstWhere((s) => s.lifeAreaId == 'la_sport');
      expect(sport.currentStreak, equals(5));
      final learning = streaks.firstWhere((s) => s.lifeAreaId == 'la_learning');
      expect(learning.currentStreak, equals(2));
    });
  });
}
