// ignore_for_file: public_member_api_docs
// Wave 25: AI Habit Coach & Burnout Predictor Domain Models.
//
// Analyzes user session intensity, streak pressure, and late penalty trends
// to protect the user from exhaustion while sustaining long-term growth.
// Invariant #11: AI never mutates state autonomously; all coach actions require
// explicit user confirmation.

enum BurnoutRiskLevel {
  low,
  moderate,
  elevated,
  critical,
}

enum CoachActionKind {
  maintainMomentum,
  reduceDailyLoad,
  suggestStreakFreeze,
  enforceRestDay,
}

class HabitVelocityMetrics {
  final int consecutiveActiveDays;
  final int sessionsPast7Days;
  final int totalMinutesPast7Days;
  final int latePenaltiesPast7Days;
  final double averageDailyXp;

  const HabitVelocityMetrics({
    required this.consecutiveActiveDays,
    required this.sessionsPast7Days,
    required this.totalMinutesPast7Days,
    required this.latePenaltiesPast7Days,
    required this.averageDailyXp,
  });

  /// Computes a normalized fatigue index between 0.0 (fresh) and 1.0 (exhausted).
  double computeFatigueIndex() {
    double fatigue = 0.0;

    // Fatigue factors:
    // 1. Extreme consecutive days without rest (>14 days)
    if (consecutiveActiveDays > 21) {
      fatigue += 0.4;
    } else if (consecutiveActiveDays > 14) {
      fatigue += 0.25;
    } else if (consecutiveActiveDays > 7) {
      fatigue += 0.1;
    }

    // 2. High session volume (>20 sessions/week)
    if (sessionsPast7Days >= 25) {
      fatigue += 0.35;
    } else if (sessionsPast7Days >= 18) {
      fatigue += 0.2;
    }

    // 3. Spiking late penalties (slipping deadlines indicates cognitive overload)
    if (latePenaltiesPast7Days >= 3) {
      fatigue += 0.35;
    } else if (latePenaltiesPast7Days >= 1) {
      fatigue += 0.15;
    }

    return fatigue.clamp(0.0, 1.0);
  }
}

class CoachRecommendation {
  final BurnoutRiskLevel riskLevel;
  final double fatigueScore;
  final CoachActionKind recommendedAction;
  final String headline;
  final String explanation;
  final String suggestedActionLabel;
  final DateTime analyzedAt;

  const CoachRecommendation({
    required this.riskLevel,
    required this.fatigueScore,
    required this.recommendedAction,
    required this.headline,
    required this.explanation,
    required this.suggestedActionLabel,
    required this.analyzedAt,
  });
}
