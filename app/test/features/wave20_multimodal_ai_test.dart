// Wave 20: Unit tests for Multimodal Vision & Provider Fallback Policy.

import 'package:drift/native.dart';
import 'package:test/test.dart';
import '../../lib/data/drift/app_database.dart';
import '../../lib/features/ai/data/multimodal_vision_service.dart';
import '../../lib/features/ai/domain/multimodal_models.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('ProviderFallbackPolicy threshold math', () {
    test('does not trigger fallback under minimum request count', () {
      final policy = ProviderFallbackPolicy(failureThreshold: 0.30);
      policy.recordFailure();
      policy.recordFailure();

      expect(policy.totalRequests, equals(2));
      expect(policy.failureRate, equals(1.0));
      // Less than 5 requests -> no fallback yet
      expect(policy.shouldFallbackToCloud, isFalse);
    });

    test('triggers fallback to cloud when failures >= 30% over 5+ requests', () {
      final policy = ProviderFallbackPolicy(failureThreshold: 0.30);
      policy.recordSuccess();
      policy.recordSuccess();
      policy.recordSuccess();
      policy.recordFailure();
      policy.recordFailure(); // 2 / 5 = 40% failure

      expect(policy.totalRequests, equals(5));
      expect(policy.failureRate, equals(0.40));
      expect(policy.shouldFallbackToCloud, isTrue);
    });
  });

  group('MultimodalVisionService analysis & audit', () {
    test('analyzeImageEvidence proposes health XP and records ai_artifacts row', () async {
      final service = MultimodalVisionService(db, ownerId: 'usr_multimodal_01');

      const input = MultimodalInput(
        imagePath: '/evidence/run_5k.png',
        userPrompt: 'Strava workout screenshot for 5k morning run',
      );

      final result = await service.analyzeImageEvidence(input);
      expect(result.detectedActivity, contains('Running'));
      expect(result.proposedXp, equals(180));
      expect(result.lifeAreaId, equals('la_health'));

      // Check ai_artifacts table
      final artifacts = await db.select(db.aiArtifacts).get();
      expect(artifacts.length, equals(1));
      expect(artifacts.first.kind, equals('multimodalVision'));
      expect(artifacts.first.prompt, contains('/evidence/run_5k.png'));
    });

    test('streamPlanDecomposition emits chunks in order', () async {
      final service = MultimodalVisionService(db, ownerId: 'usr_multimodal_01');
      final chunks = await service.streamPlanDecomposition('Master Dart').toList();

      expect(chunks.length, equals(5));
      expect(chunks.last.isComplete, isTrue);
    });
  });
}
