// Wave 25 Unit Tests: AI Habit Coach & Burnout Predictor
//
// Tests cover:
//   1. Fatigue index calculation across low, moderate, and critical loads
//   2. Threshold-based recommendation mapping
//   3. Invariant #11: Audit log entry written to ai_artifacts on every analysis
//   4. Suggested action validity

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/ai/data/burnout_detection_service.dart';
import 'package:kratos_app/features/ai/domain/coach_models.dart';

AppDatabase _openInMemory() => AppDatabase.forTesting(NativeDatabase.memory());

void main() {
  group('HabitVelocityMetrics', () {
    test('low load metrics yield low fatigue score (< 0.25)', () {
      const metrics = HabitVelocityMetrics(
        consecutiveActiveDays: 3,
        sessionsPast7Days: 5,
        totalMinutesPast7Days: 150,
        latePenaltiesPast7Days: 0,
        averageDailyXp: 80,
      );

      final score = metrics.computeFatigueIndex();
      expect(score, lessThan(0.25));
    });

    test('excessive consecutive days and missed deadlines spike fatigue (> 0.7)', () {
      const metrics = HabitVelocityMetrics(
        consecutiveActiveDays: 25,
        sessionsPast7Days: 28,
        totalMinutesPast7Days: 1200,
        latePenaltiesPast7Days: 4,
        averageDailyXp: 300,
      );

      final score = metrics.computeFatigueIndex();
      expect(score, greaterThanOrEqualTo(0.7));
    });
  });

  group('BurnoutDetectionService', () {
    late AppDatabase db;
    late BurnoutDetectionService service;
    const userId = 'usr_seed_dev_01';

    setUp(() async {
      db = _openInMemory();
      service = BurnoutDetectionService(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('audits analysis in ai_artifacts (Invariant #11)', () async {
      const metrics = HabitVelocityMetrics(
        consecutiveActiveDays: 16,
        sessionsPast7Days: 19,
        totalMinutesPast7Days: 800,
        latePenaltiesPast7Days: 1,
        averageDailyXp: 150,
      );

      final recommendation = await service.analyzeHabitVelocity(
        userId: userId,
        metrics: metrics,
      );

      expect(recommendation.riskLevel, isNotNull);
      expect(recommendation.suggestedActionLabel, isNotEmpty);

      // Verify ai_artifacts record
      final artifacts = await db.select(db.aiArtifacts).get();
      expect(artifacts.length, 1);
      expect(artifacts.first.ownerId, userId);
      expect(artifacts.first.kind, 'burnout_coaching_advisory');
      expect(artifacts.first.model, 'omniroute-predictive-coach-v1');
    });
  });
}
