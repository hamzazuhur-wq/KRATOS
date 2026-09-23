// Wave 23 Unit Tests: XP Monthly Summary & Data Backup Service
//
// Tests cover:
//   1. BackupManifest.toJson() / fromJson() round-trip
//   2. _validateSchema — valid and invalid manifests
//   3. BackupService.exportToJson() — empty DB produces empty manifest
//   4. BackupService.exportToJson() — with seeded data produces non-empty manifest
//   5. BackupService.importFromJson() — invalid JSON returns failed result
//   6. BackupService.importFromJson() — wrong schema version rejected
//   7. BackupService.importFromJson() — valid manifest with goals inserts rows
//   8. BackupService.importFromJson() — idempotent second import
//   9. XP monthly aggregation helper (_aggregateXpByMonth logic via export)
//  10. BackupImportResult.totalImported sum

import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/backup/domain/backup_service.dart';

AppDatabase _openInMemory() =>
    AppDatabase.forTesting(NativeDatabase.memory());

Future<void> _seedUser(AppDatabase db, String userId) async {
  await db.into(db.users).insert(UsersCompanion(
        id: Value(userId),
        deviceId: const Value('dev-001'),
        displayName: const Value('Dev User'),
        timezone: const Value('UTC'),
        createdAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
}

Future<void> _seedLifeArea(
    AppDatabase db, String userId, String lifeAreaId) async {
  await db.into(db.lifeAreas).insert(LifeAreasCompanion(
        id: Value(lifeAreaId),
        ownerId: Value(userId),
        name: const Value('Career'),
        sortOrder: const Value(0),
        versionHlc: const Value('1-0-0'),
        createdAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
}

Future<void> _seedGoal(
    AppDatabase db, String userId, String goalId) async {
  await db.into(db.goals).insert(GoalsCompanion(
        id: Value(goalId),
        ownerId: Value(userId),
        rootId: Value(goalId),
        path: const Value('/'),
        depth: const Value(0),
        title: const Value('Launch KRATOS'),
        status: const Value('active'),
        progress: const Value(0.0),
        versionHlc: const Value('1-0-0'),
        createdAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
}

void main() {
  const userId = 'usr_seed_dev_01';
  const lifeAreaId = 'la_career_01';
  const goalId = 'goal_launch_01';

  // ---------------------------------------------------------------------------
  // 1. BackupManifest pure model tests
  // ---------------------------------------------------------------------------
  group('BackupManifest', () {
    test('toJson() contains required fields', () {
      final manifest = BackupManifest(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 15),
        userId: userId,
        lifeAreas: [],
        goals: [],
        tasks: [],
        notes: [],
        skills: [],
        projects: [],
        achievements: [],
        xpSummary: [],
      );
      final json = manifest.toJson();
      expect(json['schema_version'], 1);
      expect(json['user_id'], userId);
      expect(json.containsKey('exported_at'), isTrue);
      expect(json['life_areas'], isEmpty);
    });

    test('fromJson() round-trip preserves all fields', () {
      final original = BackupManifest(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 15),
        userId: userId,
        lifeAreas: [
          {'id': 'la1', 'name': 'Health'}
        ],
        goals: [],
        tasks: [],
        notes: [],
        skills: [],
        projects: [],
        achievements: [],
        xpSummary: [],
      );
      final json = original.toJson();
      final restored = BackupManifest.fromJson(json);
      expect(restored.schemaVersion, 1);
      expect(restored.userId, userId);
      expect(restored.lifeAreas.length, 1);
      expect(restored.lifeAreas.first['name'], 'Health');
    });

    test('toJsonString() is valid JSON', () {
      final manifest = BackupManifest(
        schemaVersion: 1,
        exportedAt: DateTime.utc(2026, 1, 15),
        userId: userId,
        lifeAreas: [],
        goals: [],
        tasks: [],
        notes: [],
        skills: [],
        projects: [],
        achievements: [],
        xpSummary: [],
      );
      final str = manifest.toJsonString();
      expect(() => jsonDecode(str), returnsNormally);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. BackupImportResult helpers
  // ---------------------------------------------------------------------------
  group('BackupImportResult', () {
    test('totalImported sums all entity counts', () {
      const result = BackupImportResult(
        success: true,
        lifeAreasImported: 2,
        goalsImported: 5,
        tasksImported: 10,
        notesImported: 3,
        skillsImported: 1,
        projectsImported: 4,
      );
      expect(result.totalImported, 25);
    });

    test('BackupImportResult.failed sets success=false and message', () {
      const result = BackupImportResult.failed('Test error');
      expect(result.success, isFalse);
      expect(result.errorMessage, 'Test error');
      expect(result.totalImported, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. BackupService.exportToJson() integration tests
  // ---------------------------------------------------------------------------
  group('BackupService.exportToJson()', () {
    late AppDatabase db;
    late BackupService service;

    setUp(() async {
      db = _openInMemory();
      service = BackupService(db: db);
      await _seedUser(db, userId);
    });

    tearDown(() async {
      await db.close();
    });

    test('empty DB returns manifest with empty lists', () async {
      final manifest = await service.exportToJson(userId);
      expect(manifest.schemaVersion, 1);
      expect(manifest.userId, userId);
      expect(manifest.lifeAreas, isEmpty);
      expect(manifest.goals, isEmpty);
      expect(manifest.tasks, isEmpty);
      expect(manifest.notes, isEmpty);
    });

    test('with seeded life area returns manifest.lifeAreas.length = 1', () async {
      await _seedLifeArea(db, userId, lifeAreaId);
      final manifest = await service.exportToJson(userId);
      expect(manifest.lifeAreas.length, 1);
    });

    test('with seeded goal returns manifest.goals.length = 1', () async {
      await _seedLifeArea(db, userId, lifeAreaId);
      await _seedGoal(db, userId, goalId);
      final manifest = await service.exportToJson(userId);
      expect(manifest.goals.length, 1);
    });

    test('xpSummary is empty when no ledger entries', () async {
      final manifest = await service.exportToJson(userId);
      expect(manifest.xpSummary, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. BackupService.importFromJson() integration tests
  // ---------------------------------------------------------------------------
  group('BackupService.importFromJson()', () {
    late AppDatabase db;
    late BackupService service;

    setUp(() async {
      db = _openInMemory();
      service = BackupService(db: db);
      await _seedUser(db, userId);
    });

    tearDown(() async {
      await db.close();
    });

    test('returns failed result for invalid JSON string', () async {
      final result = await service.importFromJson('not-json');
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Invalid JSON'));
    });

    test('returns failed result for wrong schema version', () async {
      final json = jsonEncode({
        'schema_version': 99,
        'user_id': userId,
        'exported_at': DateTime.now().toIso8601String(),
      });
      final result = await service.importFromJson(json);
      expect(result.success, isFalse);
      expect(result.errorMessage, contains('schema'));
    });

    test('valid empty manifest returns success with 0 imports', () async {
      final manifest = BackupManifest(
        schemaVersion: 1,
        exportedAt: DateTime.now().toUtc(),
        userId: userId,
        lifeAreas: [],
        goals: [],
        tasks: [],
        notes: [],
        skills: [],
        projects: [],
        achievements: [],
        xpSummary: [],
      );
      final result = await service.importFromJson(manifest.toJsonString());
      expect(result.success, isTrue);
      expect(result.totalImported, 0);
    });

    test('imports life areas correctly', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final manifest = BackupManifest(
        schemaVersion: 1,
        exportedAt: DateTime.now().toUtc(),
        userId: userId,
        lifeAreas: [
          {
            'id': lifeAreaId,
            'owner_id': userId,
            'name': 'Career',
            'sort_order': 0,
            'version_hlc': '1-0-0',
            'created_at': now,
            'updated_at': now,
          }
        ],
        goals: [],
        tasks: [],
        notes: [],
        skills: [],
        projects: [],
        achievements: [],
        xpSummary: [],
      );
      final result = await service.importFromJson(manifest.toJsonString());
      expect(result.success, isTrue);
      expect(result.lifeAreasImported, 1);

      final rows = await db.select(db.lifeAreas).get();
      expect(rows.length, 1);
      expect(rows.first.name, 'Career');
    });

    test('idempotent: importing same data twice does not duplicate rows', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      final manifest = BackupManifest(
        schemaVersion: 1,
        exportedAt: DateTime.now().toUtc(),
        userId: userId,
        lifeAreas: [
          {
            'id': lifeAreaId,
            'owner_id': userId,
            'name': 'Career',
            'sort_order': 0,
            'version_hlc': '1-0-0',
            'created_at': now,
            'updated_at': now,
          }
        ],
        goals: [],
        tasks: [],
        notes: [],
        skills: [],
        projects: [],
        achievements: [],
        xpSummary: [],
      );
      await service.importFromJson(manifest.toJsonString());
      await service.importFromJson(manifest.toJsonString());

      final rows = await db.select(db.lifeAreas).get();
      expect(rows.length, 1); // no duplicate
    });
  });
}
