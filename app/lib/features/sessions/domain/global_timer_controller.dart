// ignore_for_file: public_member_api_docs
// Wave 9: Global Timer Controller & Session Capture Engine.
// Provides app-wide persistent timer state with live countdown, pause/resume,
// and real database session persistence linked to Task, Goal, and Life Area.

import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' as drift;

import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../xp/data/xp_ledger_writer_impl.dart';
import '../../xp/domain/xp_allocation_math.dart';
import '../data/live_focus_notification_bridge.dart';

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

  ActiveTimerState copyWith({
    int? elapsedSeconds,
    bool? isPaused,
  }) {
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
  static final GlobalTimerController _instance = GlobalTimerController._internal();
  factory GlobalTimerController() => _instance;
  GlobalTimerController._internal() {
    LiveFocusNotificationBridge.onNativePause = () {
      pauseTimer();
    };
    LiveFocusNotificationBridge.onNativeResume = () {
      resumeTimer();
    };
  }

  final _stateController = StreamController<ActiveTimerState?>.broadcast();
  Timer? _ticker;
  ActiveTimerState? _state;

  Stream<ActiveTimerState?> get stream => _stateController.stream;
  ActiveTimerState? get currentState => _state;
  bool get hasActiveTimer => _state != null;

  void startTimer({
    required String taskId,
    required String taskTitle,
    String? goalId,
    String? goalTitle,
    String? lifeAreaId,
    String? lifeAreaName,
  }) {
    _ticker?.cancel();

    _state = ActiveTimerState(
      taskId: taskId,
      taskTitle: taskTitle,
      goalId: goalId,
      goalTitle: goalTitle,
      lifeAreaId: lifeAreaId,
      lifeAreaName: lifeAreaName,
      startedAt: DateTime.now().toUtc(),
      elapsedSeconds: 0,
      isPaused: false,
    );

    _stateController.add(_state);

    LiveFocusNotificationBridge.start(
      sessionId: taskId,
      title: taskTitle,
      lifeAreaName: lifeAreaName,
    );

    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_state != null && !_state!.isPaused) {
        _state = _state!.copyWith(elapsedSeconds: _state!.elapsedSeconds + 1);
        _stateController.add(_state);
      }
    });
  }

  void pauseTimer() {
    if (_state != null && !_state!.isPaused) {
      _state = _state!.copyWith(isPaused: true);
      _stateController.add(_state);
      LiveFocusNotificationBridge.pause();
    }
  }

  void resumeTimer() {
    if (_state != null && _state!.isPaused) {
      _state = _state!.copyWith(isPaused: false);
      _stateController.add(_state);
      LiveFocusNotificationBridge.resume();
    }
  }

  /// Stops timer and saves the session to the database with outbox sync and XP reward.
  Future<String?> stopAndSaveSession({
    required AppDatabase database,
    required String ownerId,
    String? note,
  }) async {
    final state = _state;
    if (state == null) return null;

    LiveFocusNotificationBridge.stop();
    _ticker?.cancel();
    _ticker = null;
    _state = null;
    _stateController.add(null);

    final sessionId = Id.uuidV7().value;
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id.uuidV7());
    final durationMs = state.elapsedSeconds * 1000;

    await database.transaction(() async {
      // 1. Insert real Session row
      await database.sessionsDao.startSession(
        SessionsCompanion(
          id: drift.Value(sessionId),
          ownerId: drift.Value(ownerId),
          taskId: drift.Value(state.taskId),
          lifeAreaId: drift.Value(state.lifeAreaId),
          startedAt: drift.Value(state.startedAt),
          endedAt: drift.Value(now),
          durationMs: drift.Value(durationMs),
          note: drift.Value(note ?? 'Focus session on ${state.taskTitle}'),
          versionHlc: drift.Value(hlc.toString()),
          createdAt: drift.Value(now),
          updatedAt: drift.Value(now),
        ),
      );

      // 2. Enqueue to outbox
      await database.into(database.syncOutbox).insert(
        SyncOutboxCompanion.insert(
          userId: ownerId,
          op: 'upsert',
          entity: 'sessions',
          entityId: sessionId,
          payloadJson: jsonEncode({
            'id': sessionId,
            'owner_id': ownerId,
            'task_id': state.taskId,
            'life_area_id': state.lifeAreaId,
            'started_at': state.startedAt.toIso8601String(),
            'ended_at': now.toIso8601String(),
            'duration_ms': durationMs,
          }),
          hlc: hlc.toString(),
          deviceId: 'local_device',
        ),
      );

      // 3. Award XP if session was at least 60 seconds (1 XP per minute, min 5 XP)
      if (state.elapsedSeconds >= 60) {
        final xpPoints = (state.elapsedSeconds ~/ 60).clamp(5, 50);
        final writer = DriftXpLedgerWriter(database);
        final idempotencyKey = Id('xp_sess_$sessionId');

        String effectiveArea = state.lifeAreaId ?? '';
        if (effectiveArea.isEmpty) {
          final areas = await (database.select(database.lifeAreas)
                ..where((l) => l.ownerId.equals(ownerId) & l.deletedAt.isNull())
                ..limit(1))
              .get();
          effectiveArea = areas.isNotEmpty ? areas.first.id : 'la_default';
        }

        await writer.recordEvent(
          ownerId: Id(ownerId),
          idempotencyKey: idempotencyKey,
          sourceType: 'session',
          sourceId: Id(sessionId),
          action: 'focus_completed',
          basePoints: xpPoints,
          allocationRatios: [
            AllocationRatio(lifeAreaId: Id(effectiveArea), percentage: 100.0),
          ],
          clock: hlc,
          deviceId: Id('local_device'),
        );
      }
    });

    return sessionId;
  }

  void discard() {
    LiveFocusNotificationBridge.stop();
    _ticker?.cancel();
    _ticker = null;
    _state = null;
    _stateController.add(null);
  }
}
