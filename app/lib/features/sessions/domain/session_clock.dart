// ignore_for_file: public_member_api_docs
// Pure timestamp math for sessions. The persisted timestamps are the source
// of truth; any UI timer is just a rendering of these functions.

/// Hard sanity cap for a single session (forgotten timers). XP is separately
/// capped by ActivityXpCalculator (12 h).
const int kMaxSessionDurationMs = 7 * 24 * 60 * 60 * 1000;

class SessionClock {
  SessionClock._();

  /// Milliseconds of ACTUAL focused time at [now].
  ///
  /// focused = (now - startedAt) - pausedTotalMs - (currently paused ? now - pausedAt : 0)
  /// A paused interval never counts. Result is clamped to [0, kMaxSessionDurationMs].
  static int focusedMs({
    required DateTime startedAt,
    required DateTime now,
    int pausedTotalMs = 0,
    DateTime? pausedAt,
  }) {
    var paused = pausedTotalMs;
    if (pausedAt != null && now.isAfter(pausedAt)) {
      paused += now.difference(pausedAt).inMilliseconds;
    }
    final raw = now.difference(startedAt).inMilliseconds - paused;
    if (raw < 0) return 0;
    if (raw > kMaxSessionDurationMs) return kMaxSessionDurationMs;
    return raw;
  }

  /// Wall-clock interval length (start -> end), used for hour distribution.
  static int wallMs(DateTime startedAt, DateTime endedAt) {
    final v = endedAt.difference(startedAt).inMilliseconds;
    return v < 0 ? 0 : v;
  }
}
