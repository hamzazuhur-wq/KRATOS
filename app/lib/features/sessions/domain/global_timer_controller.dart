// ignore_for_file: public_member_api_docs
// GlobalTimerController — task/goal timer facade.
//
// There is ONE time-capture pipeline (SessionService via
// GlobalActiveSessionController). This class used to keep its own in-memory
// `elapsedSeconds++` counter and its own XP formula; it now only adapts the
// persisted session into the legacy ActiveTimerState shape used by the banner.

import 'dart:async';

import '../../../data/drift/app_database.dart';
import 'global_active_session_controller.dart';

class ActiveTimerState {
  final String taskId;
  final String taskTitle;
  final String? goalId;
  final String? goalTitle;
  final String? lifeAreaId;
  final String? lifeAreaName;
  final DateTime startedAt;
  final int elapsedSeconds;
  final bool isPaused;

  const ActiveTimerState({
    required this.taskId,
    required this.taskTitle,
    this.goalId,
    this.goalTitle,
    this.lifeAreaId,
    this.lifeAreaName,
    required this.startedAt,
    this.elapsedSeconds = 0,
    this.isPaused = false,
  });

  String get formattedTime {
    final m = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  ActiveTimerState copyWith({int? elapsedSeconds, bool? isPaused}) {
    return ActiveTimerState(
      taskId: taskId,
      taskTitle: taskTitle,
      goalId: goalId,
      goalTitle: goalTitle,
      lifeAreaId: lifeAreaId,
      lifeAreaName: lifeAreaName,
      startedAt: startedAt,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}

class GlobalTimerController {
  static final GlobalTimerController _instance =
      GlobalTimerController._internal();
  factory GlobalTimerController() => _instance;
  GlobalTimerController._internal();

  final GlobalActiveSessionController _core = GlobalActiveSessionController();

  // Presentation-only metadata (goal context) for the session this facade started.
  String? _ownedSessionId;
  String? _goalId;
  String? _goalTitle;

  /// True when the task banner (not the mini player) presents [sessionId].
  bool owns(String sessionId) => _ownedSessionId == sessionId;

  ActiveTimerState? _map(ActiveSessionState? s) {
    if (s == null || s.sessionId != _ownedSessionId) return null;
    return ActiveTimerState(
      taskId: s.entityId,
      taskTitle: s.title,
      goalId: _goalId,
      goalTitle: _goalTitle,
      lifeAreaId: s.lifeAreaId,
      lifeAreaName: s.lifeAreaName,
      startedAt: s.startedAt,
      elapsedSeconds: s.elapsedSeconds,
      isPaused: s.isPaused,
    );
  }

  Stream<ActiveTimerState?> get stream => _core.stream.map(_map);
  ActiveTimerState? get currentState => _map(_core.currentState);
  bool get hasActiveTimer => currentState != null;

  void startTimer({
    required String taskId,
    required String taskTitle,
    String? goalId,
    String? goalTitle,
    String? lifeAreaId,
    String? lifeAreaName,
  }) {
    _core.startSession(
      entityType: 'task',
      entityId: taskId,
      title: taskTitle,
      lifeAreaId: lifeAreaId,
      lifeAreaName: lifeAreaName,
    );
    final s = _core.currentState;
    if (s != null && s.entityId == taskId) {
      _ownedSessionId = s.sessionId;
      _goalId = goalId;
      _goalTitle = goalTitle;
    }
  }

  void pauseTimer() => _core.pauseSession();

  void resumeTimer() => _core.resumeSession();

  /// Finalizes the session through SessionService (duration from persisted
  /// timestamps, Outbox upsert, single idempotent XP award).
  Future<String?> stopAndSaveSession({
    required AppDatabase database,
    required String ownerId,
    String? note,
  }) async {
    final result = await _core.completeSession(
      database: database,
      ownerId: ownerId,
      note: note,
    );
    _ownedSessionId = null;
    return result?['sessionId'] as String?;
  }

  void discard() {
    _ownedSessionId = null;
    _core.discard();
  }
}
