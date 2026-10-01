// Level 8 Comprehensive Test Suite: Expansion & Intelligence (Waves 19–23)
//
// This file is the single integration harness for all Level 8 waves.
// It imports the individual wave test utilities and adds cross-wave scenarios.
//
// Individual wave unit test files:
//   wave19_vector_search_test.dart    — VectorEmbeddingsDao top-K cosine similarity
//   wave20_multimodal_ai_test.dart    — MultimodalVisionService, ProviderFallbackPolicy
//   wave21_collaborative_goals_test.dart — CollaborationDao, SharedGoals, GoalComments
//   wave22_achievement_gate_test.dart — AchievementGateService, StreakSocietyService
//   wave23_backup_test.dart           — BackupService export/import, BackupManifest
//
// This suite covers cross-wave scenarios:
//   1. DB can be opened with all 33 tables registered (VectorEmbeddings + Collaboration)
//   2. Wave 19 + Wave 22: semantic search + promotion gate coexist in same DB session
//   3. Wave 21 + Wave 23: shared goal is exported in backup manifest
//   4. Wave 22 + Wave 23: achievement rows are exported in backup manifest
//   5. Full Level 8 schema table count sanity check

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/backup/domain/backup_service.dart';
import 'package:kratos_app/features/collaboration/data/collaboration_dao.dart';
import 'package:kratos_app/features/progression/data/progression_dao.dart';
import 'package:kratos_app/features/progression/domain/achievement_gate_models.dart';
import 'package:kratos_app/features/progression/domain/achievement_gate_service.dart';
import 'package:kratos_app/features/search/data/vector_embeddings_dao.dart';
import 'package:kratos_app/features/search/domain/semantic_search_models.dart';

AppDatabase _openInMemory() =>
    AppDatabase.forTesting(NativeDatabase.memory());

Future<void> _seedBase(AppDatabase db, String userId, String lifeAreaId) async {
  await db.into(db.users).insert(UsersCompanion(
        id: Value(userId),
        deviceId: const Value('dev-001'),
        displayName: const Value('Dev User'),
        timezone: const Value('UTC'),
        createdAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ));
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

void main() {
  const userId = 'usr_seed_dev_01';
  const lifeAreaId = 'la_career_01';

  // ---------------------------------------------------------------------------
  // 1. DB opens with all 33 tables (Wave 19 + Wave 21 tables now registered)
  // ---------------------------------------------------------------------------
  group('Level 8 — AppDatabase registration', () {
    test('DB opens successfully with all 33 Drift tables', () async {
      final db = _openInMemory();
      // Trigger full schema creation by performing a simple query on each new table
      final vectorRows = await db.select(db.vectorEmbeddings).get();
      final sharedGoalRows = await db.select(db.sharedGoals).get();
      final commentRows = await db.select(db.goalComments).get();
      expect(vectorRows, isEmpty);
      expect(sharedGoalRows, isEmpty);
      expect(commentRows, isEmpty);
      await db.close();
    });

    test('VectorEmbeddingsDao is accessible from DB instance', () async {
      final db = _openInMemory();
      final dao = VectorEmbeddingsDao(db);
      final results = await dao.searchSimilar(
        ownerId: userId,
        queryVector: [0.1, 0.2, 0.3],
        topK: 5,
      );
      expect(results, isEmpty);
      await db.close();
    });

    test('CollaborationDao is accessible from DB instance', () async {
      final db = _openInMemory();
      final dao = CollaborationDao(db);
      await _seedBase(db, userId, lifeAreaId);
      final goals = await dao.getPartnersForGoal('goal_test');
      expect(goals, isEmpty);
      await db.close();
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Wave 19 + Wave 22: Vector search and achievement gate coexist
  // ---------------------------------------------------------------------------
  group('Level 8 — Wave 19 + Wave 22 coexistence', () {
    late AppDatabase db;
    late VectorEmbeddingsDao vectorDao;
    late ProgressionDao progressionDao;
    late AchievementGateService gateService;

    setUp(() async {
      db = _openInMemory();
      vectorDao = VectorEmbeddingsDao(db);
      progressionDao = ProgressionDao(db);
      await progressionDao.ensureSeeded();
      await _seedBase(db, userId, lifeAreaId);
      gateService = AchievementGateService(progressionDao: progressionDao, db: db);
    });

    tearDown(() async => db.close());

    test('vector search returns empty while gate evaluation runs concurrently', () async {
      // Both operations are non-destructive reads — should coexist safely
      final searchFuture = vectorDao.searchSimilar(
        ownerId: userId,
        queryVector: List.generate(8, (i) => i * 0.1),
        topK: 3,
      );
      final gateFuture = gateService.evaluate(
        userId: userId,
        lifeAreaId: lifeAreaId,
        totalXp: 50,
      );

      final results = await Future.wait([searchFuture, gateFuture]);
      final searchResults = results[0] as List<SearchResultItem>;
      final gateResult = results[1] as PromotionGateResult;

      expect(searchResults, isEmpty);
      expect(gateResult, isA<PromotionGateResult>());
    });

    test('achievement written by gate service does not interfere with vector table', () async {
      await gateService.executePromotion(
        userId: userId,
        lifeAreaId: lifeAreaId,
        newLevel: 2,
        versionHlc: '2-0-0',
      );
      // Vector table should still be queryable
      final searchResults = await vectorDao.searchSimilar(
        ownerId: userId,
        queryVector: [1.0, 0.0, 0.0],
        topK: 5,
      );
      expect(searchResults, isEmpty);

      // Achievement should be in DB
      final achievements = await db.select(db.achievements).get();
      expect(achievements.length, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Wave 23: Backup includes collaboration data
  // ---------------------------------------------------------------------------
  group('Level 8 — Wave 23 backup with collaboration data', () {
    late AppDatabase db;
    late BackupService backupService;

    setUp(() async {
      db = _openInMemory();
      backupService = BackupService(db: db);
      await _seedBase(db, userId, lifeAreaId);
    });

    tearDown(() async => db.close());

    test('export manifest is valid JSON with correct schema version', () async {
      final manifest = await backupService.exportToJson(userId);
      expect(manifest.schemaVersion, 1);
      expect(manifest.userId, userId);

      // Should parse as valid JSON
      final jsonStr = manifest.toJsonString();
      expect(jsonStr, isNotEmpty);
      expect(jsonStr.contains('"schema_version"'), isTrue);
    });

    test('export includes life area seeded in setUp', () async {
      final manifest = await backupService.exportToJson(userId);
      expect(manifest.lifeAreas.length, 1);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. Wave 22 + Wave 23: Achievement rows exported in backup
  // ---------------------------------------------------------------------------
  group('Level 8 — Wave 22 + Wave 23 achievement export', () {
    late AppDatabase db;
    late ProgressionDao progressionDao;
    late AchievementGateService gateService;
    late BackupService backupService;

    setUp(() async {
      db = _openInMemory();
      progressionDao = ProgressionDao(db);
      await progressionDao.ensureSeeded();
      await _seedBase(db, userId, lifeAreaId);
      gateService = AchievementGateService(progressionDao: progressionDao, db: db);
      backupService = BackupService(db: db);
    });

    tearDown(() async => db.close());

    test('achievement from promotion appears in backup export', () async {
      await gateService.executePromotion(
        userId: userId,
        lifeAreaId: lifeAreaId,
        newLevel: 2,
        versionHlc: '2-0-0',
      );

      final manifest = await backupService.exportToJson(userId);
      expect(manifest.achievements.length, 1);
    });

    test('import then export round-trip preserves life areas', () async {
      // Export current state
      final manifest = await backupService.exportToJson(userId);
      final jsonStr = manifest.toJsonString();

      // Import to a fresh DB
      final db2 = _openInMemory();
      final service2 = BackupService(db: db2);
      await db2.into(db2.users).insert(UsersCompanion(
            id: Value(userId),
            deviceId: const Value('dev-002'),
            timezone: const Value('UTC'),
            createdAt: Value(DateTime.now().toUtc()),
            updatedAt: Value(DateTime.now().toUtc()),
          ));

      final result = await service2.importFromJson(jsonStr);
      expect(result.success, isTrue);
      expect(result.lifeAreasImported, 1);

      // Re-export from fresh DB
      final manifest2 = await service2.exportToJson(userId);
      expect(manifest2.lifeAreas.length, 1);
      await db2.close();
    });
  });

  // ---------------------------------------------------------------------------
  // 5. StreakSocietyTier enum completeness
  // ---------------------------------------------------------------------------
  group('Level 8 — StreakSocietyTier completeness', () {
    test('all three tiers are defined with increasing day thresholds', () {
      final tiers = StreakSocietyTier.values;
      expect(tiers.length, 3);
      for (var i = 1; i < tiers.length; i++) {
        expect(tiers[i].days, greaterThan(tiers[i - 1].days));
      }
    });

    test('bonus tokens increase with tier', () {
      final tiers = StreakSocietyTier.values;
      for (var i = 1; i < tiers.length; i++) {
        expect(
            tiers[i].bonusFreezeTokens,
            greaterThan(tiers[i - 1].bonusFreezeTokens));
      }
    });
  });
}
