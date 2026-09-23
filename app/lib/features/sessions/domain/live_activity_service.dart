// ignore_for_file: public_member_api_docs
// Wave 27: LiveActivityService — Lock Screen & Dynamic Island session state manager.
//
// Coordinates real-time timer broadcasting for focus sessions to power
// interactive widgets, system tiles, and Live Activities.

import 'dart:async';

class LiveSessionState {
  final String sessionId;
  final String title;
  final String? lifeAreaName;
  final DateTime startedAt;
  final int plannedDurationSeconds;
  final int elapsedSeconds;
  final bool isPaused;

  const LiveSessionState({
    required this.sessionId,
    required this.title,
    this.lifeAreaName,
    required this.startedAt,
    required this.plannedDurationSeconds,
    required this.elapsedSeconds,
    required this.isPaused,
  });

  int get remainingSeconds =>
      (plannedDurationSeconds - elapsedSeconds).clamp(0, plannedDurationSeconds);

  double get progressPct => plannedDurationSeconds > 0
      ? (elapsedSeconds / plannedDurationSeconds).clamp(0.0, 1.0)
      : 0.0;

  bool get isCompleted => remainingSeconds == 0;

  LiveSessionState copyWith({
    int? elapsedSeconds,
    bool? isPaused,
  }) =>
      LiveSessionState(
        sessionId: sessionId,
        title: title,
        lifeAreaName: lifeAreaName,
        startedAt: startedAt,
        plannedDurationSeconds: plannedDurationSeconds,
        elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
        isPaused: isPaused ?? this.isPaused,
      );
}

class LiveActivityService {
  final _stateController = StreamController<LiveSessionState?>.broadcast();
  Timer? _ticker;
  LiveSessionState? _currentState;

  Stream<LiveSessionState?> get stateStream => _stateController.stream;
  LiveSessionState? get currentState => _currentState;

  /// Starts broadcasting a live focus session activity.
  void start({
    required String sessionId,
    required String title,
    String? lifeAreaName,
    required int durationSeconds,
  }) {
    _ticker?.cancel();

    _currentState = LiveSessionState(
      sessionId: sessionId,
      title: title,
      lifeAreaName: lifeAreaName,
      startedAt: DateTime.now().toUtc(),
      plannedDurationSeconds: durationSeconds,
      elapsedSeconds: 0,
      isPaused: false,
    );

    _stateController.add(_currentState);

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentState == null) {
        timer.cancel();
        return;
      }

      if (!_currentState!.isPaused) {
        final newElapsed = _currentState!.elapsedSeconds + 1;
        _currentState = _currentState!.copyWith(elapsedSeconds: newElapsed);
        _stateController.add(_currentState);

        if (_currentState!.isCompleted) {
          timer.cancel();
        }
      }
    });
  }

  /// Pauses the live timer.
  void pause() {
    if (_currentState != null && !_currentState!.isPaused) {
      _currentState = _currentState!.copyWith(isPaused: true);
      _stateController.add(_currentState);
    }
  }

  /// Resumes the live timer.
  void resume() {
    if (_currentState != null && _currentState!.isPaused) {
      _currentState = _currentState!.copyWith(isPaused: false);
      _stateController.add(_currentState);
    }
  }

  /// Stops and dismisses the live session activity.
  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _currentState = null;
    _stateController.add(null);
  }

  void dispose() {
    _ticker?.cancel();
    _stateController.close();
  }
}
