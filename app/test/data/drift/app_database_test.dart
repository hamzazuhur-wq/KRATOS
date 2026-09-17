
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
      final id = 'usr_test_01';
      await db.into(db.users).insert(UsersCompanion.insert(
        id: id,
        deviceId: 'device_01',
        displayName: 'Test User',
        timezone: 'UTC',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ));
      final rows = await db.select(db.users).get();
      expect(rows.length, equals(1));
      expect(rows.first.displayName, equals('Test User'));
    });
    test('goals table supports recursive columns', () async {
      await db.into(db.users).insert(UsersCompanion.insert(
        id: 'usr_test_02',
        deviceId: 'device_02',
        displayName: 'Recursive',
        timezone: 'UTC',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ));
      final id = 'goal_root_01';
      await db.into(db.goals).insert(GoalsCompanion.insert(
        id: id,
        ownerId: 'usr_test_02',
        parentId: id,
        rootId: id,
        path: 'goal_root_01',
        depth: 0,
        title: 'Root Goal',
        description: '',
        lifeAreaId: 'la_1',
        status: 'active',
        xpTarget: 0,
        progress: 0.0,
        progressHlc: '0:0:1',
        dueDate: DateTime.now().toUtc(),
        completedAt: DateTime.now().toUtc(),
        deletedAt: DateTime.now().toUtc(),
        deletedBy: '',
        deletedReason: '',
        versionHlc: '0:0:1',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ));
      final rows = await db.select(db.goals).get();
      expect(rows.length, equals(1));
      expect(rows.first.depth, equals(0));
    });
  });
}
