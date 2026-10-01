// ignore_for_file: public_member_api_docs
// Phase 2 — Activity Duration XP Engine.
//
// SINGLE SOURCE OF TRUTH for activity session XP calculation.
// Both the live-timer path (GlobalActiveSessionController) and the
// manual quick-log path (ActivityDashboardRepository.quickLogSession)
// call calculateActivityXp() — no other XP math for activities should exist.
//
// Formula (ADR-Phase2):
//   Ceiling XP  = ROUND(30 × difficulty / 10)          [max when difficulty=10 → 30 XP]
//   Duration %  = linear interpolation from anchor curve (diminishing returns)
//   Final XP    = ROUND(Ceiling XP × duration factor)  [always an integer]
//
// Anchor curve (minutes → factor):
//   0 → 0.00,  15 → 0.05,  30 → 0.10,  60 → 0.20,
//  120 → 0.35, 240 → 0.55, 360 → 0.70, 480 → 0.82,
//  600 → 0.92, 720 → 1.00
//
// Constraints:
//   - difficulty must be 1–10 (inclusive)
//   - duration must be >= 0 and <= 12 hours (43 200 seconds or 720 minutes)
//   - Final XP is always a non-negative integer

import '../../xp/domain/base_xp_config.dart';

/// Calculates XP earned for a single activity session based on difficulty
/// and actual session duration.
///
/// This is a pure-Dart, zero-dependency calculator — no database, no Flutter.
/// It is safe to call from any layer.
class ActivityXpCalculator {
  ActivityXpCalculator._();

  /// Maximum possible XP for any single activity session (difficulty 10, 12 h).
  static const int maxActivityXp = BaseXpConfig.maxActivityXp;

  /// Maximum allowed session duration in minutes.
  static const int maxSessionMinutes = 720; // 12 hours

  // Anchor points of the diminishing-returns curve.
  // Minutes → duration factor (0.0–1.0).
  // Linear interpolation is used for values between anchors.
  static const List<_Anchor> _curve = [
    _Anchor(minutes: 0, factor: 0.00),
    _Anchor(minutes: 15, factor: 0.05),
    _Anchor(minutes: 30, factor: 0.10),
    _Anchor(minutes: 60, factor: 0.20),
    _Anchor(minutes: 120, factor: 0.35),
    _Anchor(minutes: 240, factor: 0.55),
    _Anchor(minutes: 360, factor: 0.70),
    _Anchor(minutes: 480, factor: 0.82),
    _Anchor(minutes: 600, factor: 0.92),
    _Anchor(minutes: 720, factor: 1.00),
  ];

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the XP ceiling for the given [difficulty] (1–10).
  ///
  /// Ceiling XP = ROUND(30 × difficulty / 10)
  /// Delegated to [BaseXpConfig.forActivity].
  ///
  /// Throws [ArgumentError] if difficulty is outside 1–10.
  static int ceilingXp(int difficulty) => BaseXpConfig.forActivity(difficulty);

  /// Returns the duration factor (0.0–1.0) for [minutes] of session time.
  ///
  /// Uses linear interpolation between the anchor points of the diminishing-
  /// returns curve. [minutes] is clamped to [maxSessionMinutes] before lookup.
  ///
  /// Throws [ArgumentError] if [minutes] < 0.
  static double durationFactor(int minutes) {
    if (minutes < 0) {
      throw ArgumentError.value(
          minutes, 'minutes', 'Duration must be >= 0 minutes');
    }
    final clamped = minutes.clamp(0, maxSessionMinutes);
    return _interpolate(clamped.toDouble());
  }

  /// Calculates the final integer XP earned for a session.
  ///
  /// [difficulty] — activity difficulty (1–10 inclusive).
  /// [duration]   — actual elapsed session time (must be >= Duration.zero
  ///                and <= 12 hours).
  ///
  /// Returns ROUND(ceilingXp(difficulty) × durationFactor(minutes)).
  ///
  /// Throws [ArgumentError] for invalid inputs.
  static int calculateActivityXp(int difficulty, Duration duration) {
    _validateDifficulty(difficulty);
    _validateDuration(duration);

    final minutes = duration.inMinutes;
    final ceiling = ceilingXp(difficulty);
    final factor = durationFactor(minutes);
    return (ceiling * factor).round();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static void _validateDifficulty(int difficulty) =>
      BaseXpConfig.validateDifficulty(difficulty);

  static void _validateDuration(Duration duration) {
    if (duration.isNegative) {
      throw ArgumentError.value(
          duration, 'duration', 'Duration must be >= Duration.zero');
    }
    if (duration.inMinutes > maxSessionMinutes) {
      throw ArgumentError.value(
          duration,
          'duration',
          'Duration exceeds maximum session length of $maxSessionMinutes minutes (12 hours)');
    }
  }

  /// Linearly interpolates [minutes] through [_curve].
  static double _interpolate(double minutes) {
    // Below first anchor — return 0
    if (minutes <= _curve.first.minutes) return _curve.first.factor;
    // At or above last anchor — return 1.0
    if (minutes >= _curve.last.minutes) return _curve.last.factor;

    // Find the surrounding anchors
    for (var i = 0; i < _curve.length - 1; i++) {
      final lo = _curve[i];
      final hi = _curve[i + 1];
      if (minutes >= lo.minutes && minutes <= hi.minutes) {
        final t = (minutes - lo.minutes) / (hi.minutes - lo.minutes);
        return lo.factor + t * (hi.factor - lo.factor);
      }
    }
    // Unreachable — satisfies Dart flow analysis
    return _curve.last.factor;
  }
}

// ---------------------------------------------------------------------------
// Private data class — anchor point on the diminishing-returns curve
// ---------------------------------------------------------------------------

class _Anchor {
  final int minutes;
  final double factor;
  const _Anchor({required this.minutes, required this.factor});
}
