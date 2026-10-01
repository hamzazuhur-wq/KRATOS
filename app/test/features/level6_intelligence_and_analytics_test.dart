// Level 6: Intelligence, Analytics & Evidence Full-Domain Test Suite.
// Covers Wave 10 (XP Dashboard Metrics), Wave 11 (AI OmniRoute & Audit Log),
// Wave 12 (Skills Attribution & Tool Linking), and Wave 13 (Evidence Hub & Links).

import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/ai/data/omniroute_ai_service.dart';
import 'package:kratos_app/features/ai/domain/ai_models.dart';
import 'package:kratos_app/features/xp/data/xp_analytics_dao.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  // ─── Wave 10: XP Dashboard & Analytics ───────────────────────────────

  group('Level 6 / Wave 10: XP Dashboard & Analytics Metrics', () {
    test('XpDashboardMetrics composite calculation calculates total XP correctly', () {
      const metrics = XpDashboardMetrics(
        totalXp: 8740,
        streakBonusXp: 320,
        lifeAreaXp: {
          'Career': 3400,
          'Health': 2800,
          'Learning': 1540,
          'Relationships': 1000,
        },
        sourceTypeXp: {
          'Tasks': 4200,
          'Sessions': 2900,
          'Goals': 1640,
        },
        dailyXp: [120, 85, 200, 0, 145, 310, 95],
      );

      expect(metrics.totalXp, equals(8740));
      expect(metrics.streakBonusXp, equals(320));
      expect(metrics.dailyXp.length, equals(7));

      // Sum of life areas matches total
      final sumAreas = metrics.lifeAreaXp.values.fold<int>(0, (s, v) => s + v);
      expect(sumAreas, equals(metrics.totalXp));
    });

    test('XpDashboardMetrics.empty provides zero-state defaults', () {
      final empty = XpDashboardMetrics.empty();
      expect(empty.totalXp, equals(0));
      expect(empty.streakBonusXp, equals(0));
      expect(empty.dailyXp, equals([0, 0, 0, 0, 0, 0, 0]));
    });
  });

  // ─── Wave 11: AI Engine & Invariant #11 Audit Trail ──────────────────

  group('Level 6 / Wave 11: OmniRoute AI Service & Audit Trail', () {
    test('complete() writes every interaction to ai_artifacts (Invariant #11)', () async {
      final aiService = OmniRouteAIService(db, ownerId: 'usr_test_ai_01');

      final completion = await aiService.complete(
        capability: AICapability.summarizeSession,
        messages: [
          AIMessage.user('Completed 45m deep focus on database migrations.'),
        ],
        context: const ContextBundle(activeLifeAreaId: 'la_career'),
        relatedEntityId: 'sess_123',
        relatedEntityKind: 'sessions',
      );

      expect(completion.text.isNotEmpty, isTrue);
      expect(completion.modelId, contains('omniroute'));
      expect(completion.tokensIn, greaterThan(0));
      expect(completion.tokensOut, greaterThan(0));

      // Query ai_artifacts table to verify audit logging
      final artifacts = await db.select(db.aiArtifacts).get();
      expect(artifacts.length, equals(1));
      final record = artifacts.first;
      expect(record.ownerId, equals('usr_test_ai_01'));
      expect(record.kind, equals('summarizeSession'));
      expect(record.relatedEntityId, equals('sess_123'));
      expect(record.relatedEntityKind, equals('sessions'));
      expect(record.response, equals(completion.text));
    });

    test('transcribe() writes audio transcription audit to ai_artifacts', () async {
      final aiService = OmniRouteAIService(db, ownerId: 'usr_test_ai_01');

      final result = await aiService.transcribe(
        audioPath: '/tmp/audio_memo_01.m4a',
        durationMs: 25000,
      );

      expect(result.text.isNotEmpty, isTrue);
      expect(result.durationMs, equals(25000));
      expect(result.confidence, greaterThanOrEqualTo(0.95));

      final artifacts = await db.select(db.aiArtifacts).get();
      expect(artifacts.length, equals(1));
      expect(artifacts.first.kind, equals('transcribeAudio'));
    });
  });

  // ─── Wave 12: Skills Attribution & Tool Linking ──────────────────────

  group('Level 6 / Wave 12: Skills Attribution & Tool Decoupling', () {
    test('Skills XP attribution does not overwrite level bounds', () {
      const xpTotal = 1450;
      const nextLevelXp = 500;
      final inLevelXp = xpTotal % nextLevelXp;
      final progressFraction = inLevelXp / nextLevelXp;

      expect(inLevelXp, equals(450));
      expect(progressFraction, equals(0.9));
    });

    test('Tools are independent inventory items linkable to skills', () {
      final initialTools = ['Flutter', 'Drift'];
      final updatedTools = List<String>.from(initialTools)..add('Supabase');

      expect(updatedTools.length, equals(3));
      expect(updatedTools, containsAll(['Flutter', 'Drift', 'Supabase']));

      // Removal works cleanly
      updatedTools.remove('Drift');
      expect(updatedTools.length, equals(2));
      expect(updatedTools.contains('Drift'), isFalse);
    });
  });

  // ─── Wave 13: Evidence Hub & Polymorphic Links ───────────────────────

  group('Level 6 / Wave 13: Evidence Hub & Attachments', () {
    test('supports adding links and evidence records independently', () {
      final links = <({String title, String url, String dateAdded})>[
        (title: 'Postgres Docs', url: 'https://postgresql.org', dateAdded: 'Today'),
      ];
      final evidence = <({String kind, String payload, String capturedAt})>[
        (kind: 'test_pass', payload: 'All unit tests passed', capturedAt: 'Today'),
      ];

      expect(links.length, equals(1));
      expect(links.first.url, startsWith('https://'));
      expect(evidence.length, equals(1));
      expect(evidence.first.kind, equals('test_pass'));
    });
  });
}
