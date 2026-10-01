// ignore_for_file: public_member_api_docs
// Wave 25: BurnoutDetectionService — Predictive AI habit coaching.
//
// Invariant #11: AI never mutates state autonomously.
// Every coaching analysis generates an audit record in `ai_artifacts`.

import '../../../data/drift/app_database.dart';

import 'package:drift/drift.dart';

import '../../../domain/ids.dart';
import '../domain/coach_models.dart';

class BurnoutDetectionService {
  final AppDatabase _db;

  BurnoutDetectionService({required AppDatabase db}) : _db = db;

  /// Analyzes habit velocity and predicts burnout risk.
  Future<CoachRecommendation> analyzeHabitVelocity({
    required String userId,
    required HabitVelocityMetrics metrics,
  }) async {
    final fatigue = metrics.computeFatigueIndex();
    final now = DateTime.now().toUtc();

    final BurnoutRiskLevel risk;
    final CoachActionKind action;
    final String headline;
    final String explanation;
    final String actionLabel;

    if (fatigue >= 0.7) {
      risk = BurnoutRiskLevel.critical;
      action = CoachActionKind.enforceRestDay;
      headline = 'High Burnout Warning';
      explanation =
          'You have accumulated intense cognitive load with ${metrics.consecutiveActiveDays} consecutive active days and ${metrics.latePenaltiesPast7Days} slipping tasks. We strongly recommend taking a planned recovery day.';
      actionLabel = 'Activate Recovery Pause';
    } else if (fatigue >= 0.45) {
      risk = BurnoutRiskLevel.elevated;
      action = CoachActionKind.suggestStreakFreeze;
      headline = 'Elevated Fatigue Detected';
      explanation =
          'Your pace is aggressive (${metrics.sessionsPast7Days} sessions this week). Consider utilizing a streak freeze token to decompress without losing your streak progress.';
      actionLabel = 'Use Streak Freeze';
    } else if (fatigue >= 0.25) {
      risk = BurnoutRiskLevel.moderate;
      action = CoachActionKind.reduceDailyLoad;
      headline = 'Pacing Advisory';
      explanation = 'Great consistency, but session frequency is rising rapidly. Keep sessions under 45 minutes to maintain sustained focus.';
      actionLabel = 'Set Pacing Limit';
    } else {
      risk = BurnoutRiskLevel.low;
      action = CoachActionKind.maintainMomentum;
      headline = 'Optimal Flow State';
      explanation = 'Your velocity is well-balanced across your life areas with steady recovery intervals. Keep up the disciplined momentum!';
      actionLabel = 'Continue Schedule';
    }

    final recommendation = CoachRecommendation(
      riskLevel: risk,
      fatigueScore: fatigue,
      recommendedAction: action,
      headline: headline,
      explanation: explanation,
      suggestedActionLabel: actionLabel,
      analyzedAt: now,
    );

    // Audit in ai_artifacts (Invariant #11)
    await _db
        .into(_db.aiArtifacts)
        .insert(
          AiArtifactsCompanion(
            id: Value(Id.uuidV7().value),
            ownerId: Value(userId),
            kind: const Value('burnout_coaching_advisory'),
            prompt: Value('Analyze fatigue index: $fatigue'),
            response: Value('$headline: $explanation'),
            model: const Value('omniroute-predictive-coach-v1'),
            tokensIn: const Value(120),
            tokensOut: const Value(85),
            relatedEntityId: const Value(null),
            relatedEntityKind: const Value('habit_velocity'),
            createdAt: Value(now),
          ),
        );

    return recommendation;
  }
}
