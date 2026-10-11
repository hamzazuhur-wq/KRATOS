// ignore_for_file: public_member_api_docs
// GlobalActiveSessionController — UI/state adapter over SessionService.
//
// The persisted Sessions row is the source of truth. This class only:
//   * mirrors the active row into an in-memory ActiveSessionState for widgets,
//   * renders elapsed time as a pure function of persisted timestamps
//     (never `elapsedSeconds++`), so background/sleep/restart are exact,
//   * restores an unfinished session from Drift on bind / app resume,
//   * serializes all DB writes so start -> pause -> stop can never race.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../data/drift/app_database.dart';
import 'session_clock.dart';
import 'session_service.dart';
import '../../../domain/ids.dart';

enum ActiveSessionStatus { running, paused, completed, stopped }

class ActiveSessionState {
  final String sessionId;
  final String entityType; // 'activity' | 'task'
  final String entityId;
  final String title;
  final String? lifeAreaId;
  final String? lifeAreaName;
  final String? categoryName;
  final int targetDurationSeconds;
  final DateTime startedAt;
  final DateTime? pausedAt;
  final int totalPausedMs;
  final bool isPaused;
  final int elapsedSeconds;

  const ActiveSessionState({
    required this.sessionId,
    required this.entityType,
    required this.entityId,
    required this.title,
    this.lifeAreaId,
    this.lifeAreaName,
    this.categoryName,
    this.targetDurationSeconds = 0,
    required this.startedAt,
    this.pausedAt,
    this.totalPausedMs = 0,
    this.isPaused = false,
    this.elapsedSeconds = 0,
  });

  /// Focused milliseconds at [now], derived purely from persisted timestamps.
  int elapsedMsAt(DateTime now) => SessionClock.focusedMs(
    startedAt: startedAt,
    now: now,
    pausedTotalMs: totalPausedMs,
    pausedAt: isPaused ? pausedAt : null,
  );

  static String _fmt(int total) {
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedElapsed => _fmt(elapsedSeconds);

  String get formattedTarget =>
      targetDurationSeconds <= 0 ? '' : _fmt(targetDurationSeconds);

  ActiveSessionState copyWith({
    DateTime? pausedAt,
    bool clearPausedAt = false,
    int? totalPausedMs,
    bool? isPaused,
    int? elapsedSeconds,
  }) {
    return ActiveSessionState(
      sessionId: sessionId,
      entityType: entityType,
      entityId: entityId,
      title: title,
      lifeAreaId: lifeAreaId,
      lifeAreaName: lifeAreaName,
      categoryName: categoryName,
      targetDurationSeconds: targetDurationSeconds,
      startedAt: startedAt,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      totalPausedMs: totalPausedMs ?? this.totalPausedMs,
      isPaused: isPaused ?? this.isPaused,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }
}

class GlobalActiveSessionController with WidgetsBindingObserver {
  static final GlobalActiveSessionController _instance =
      GlobalActiveSessionController._internal();
  factory GlobalActiveSessionController() => _instance;
  GlobalActiveSessionController._internal() {
    _initMethodChannel();
  }

  static const _channel = MethodChannel('com.hamza.kratos/focus_session');

  final _stateController = StreamController<ActiveSessionState?>.broadcast();
  Timer? _ticker;
  ActiveSessionState? _state;
  AppDatabase? _activeDb;
  String? _activeOwnerId;
  bool _observing = false;
  Future<void> _chain = Future<void>.value();

  Stream<ActiveSessionState?> get stream => _stateController.stream;
  ActiveSessionState? get currentState => _state;
  bool get hasActiveSession => _state != null;
  AppDatabase? get activeDb => _activeDb;
  String? get activeOwnerId => _activeOwnerId;

  /// Clock indirection for deterministic tests.
  @visibleForTesting
  DateTime Function() nowProvider = () => DateTime.now().toUtc();

  void bindDatabase(AppDatabase db, String ownerId) {
    final changed = !identical(_activeDb, db) || _activeOwnerId != ownerId;
    _activeDb = db;
    _activeOwnerId = ownerId;
    if (changed) {
      _chain = Future<void>.value();
    }
    _ensureObserver();
    if (changed) unawaited(restore());
  }

  void _ensureObserver() {
    if (_observing) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    } catch (_) {
      // Binding not initialised (pure unit tests) — restore() still works.
    }
  }

  /// Foreground return: re-derive elapsed from timestamps and reconcile with
  /// the persisted row (covers sleep, browser tab restore, multi-tab edits).
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      _tick();
      unawaited(restore(reconcile: true));
    }
  }

  void _initMethodChannel() {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onNativePause':
          pauseSession();
          break;
        case 'onNativeResume':
          resumeSession();
          break;
        case 'onNativeComplete':
          if (_activeDb != null && _activeOwnerId != null) {
            await completeSession(
              database: _activeDb!,
              ownerId: _activeOwnerId!,
            );
          }
          break;
        case 'onNativeStop':
          if (_activeDb != null && _activeOwnerId != null) {
            await stopSession(database: _activeDb!, ownerId: _activeOwnerId!);
          }
          break;
      }
    });
  }

  bool isEntityActive(String entityId) {
    return _state != null && _state!.entityId == entityId;
  }

  Future<T?> _enqueue<T>(Future<T?> Function() op) {
    final completer = Completer<T?>();
    _chain = _chain.catchError((_) {}).then((_) async {
      try {
        final res = await op();
        completer.complete(res);
      } catch (e, st) {
        debugPrint('GlobalActiveSessionController op failed: $e\n$st');
        completer.complete(null);
      }
    });
    return completer.future;
  }

  // ── Restore ────────────────────────────────────────────────────────────

  /// Rebuilds [ActiveSessionState] from the persisted active session (if any).
  /// Never resets or restarts a session — only reads it.
  Future<void> restore({bool reconcile = false}) {
    final db = _activeDb;
    final owner = _activeOwnerId;
    if (db == null || owner == null) return Future.value();
    return _enqueue<void>(() async {
      final svc = SessionService(db, clock: nowProvider);
      final row = await svc.activeSession(owner);
      if (row == null) {
        // Persisted truth says nothing is active (finished elsewhere).
        if (_state != null && reconcile) _clearLocal(notifyNative: true);
        return;
      }
      if (_state != null && _state!.sessionId == row.id && !reconcile) return;

      final entityType = row.taskId != null ? 'task' : 'activity';
      final entityId = (row.taskId ?? row.activityId) ?? '';
      final prev = _state?.sessionId == row.id ? _state : null;
      final meta = prev == null
          ? await _lookupMeta(db, entityType, entityId, row.lifeAreaId)
          : (
              title: prev.title,
              lifeAreaName: prev.lifeAreaName,
              categoryName: prev.categoryName,
              targetSec: prev.targetDurationSeconds,
            );

      final paused = row.status == SessionStatus.paused;
      var s = ActiveSessionState(
        sessionId: row.id,
        entityType: entityType,
        entityId: entityId,
        title: meta.title,
        lifeAreaId: row.lifeAreaId,
        lifeAreaName: meta.lifeAreaName,
        categoryName: meta.categoryName,
        targetDurationSeconds: meta.targetSec,
        startedAt: row.startedAt.toUtc(),
        pausedAt: paused ? row.pausedAt?.toUtc() : null,
        totalPausedMs: row.pausedTotalMs,
        isPaused: paused,
      );
      s = s.copyWith(elapsedSeconds: s.elapsedMsAt(nowProvider()) ~/ 1000);
      final firstRestore = prev == null;
      _state = s;
      _stateController.add(_state);
      _startTicker();
      if (firstRestore) _notifyNativeStart();
      if (paused) _notifyNativePause();
    });
  }

  Future<({String title, String? lifeAreaName, String? categoryName, int targetSec})>
  _lookupMeta(
    AppDatabase db,
    String entityType,
    String entityId,
    String? lifeAreaId,
  ) async {
    var title = 'Focus session';
    String? categoryName;
    var targetSec = 0;
    String? lifeAreaName;
    if (entityType == 'activity') {
      final a = await (db.select(
        db.activities,
      )..where((r) => r.id.equals(entityId))).getSingleOrNull();
      if (a != null) {
        title = a.name;
        targetSec = (a.targetDurationMinutes ?? 0) * 60;
      }
    } else {
      final t = await (db.select(
        db.tasks,
      )..where((r) => r.id.equals(entityId))).getSingleOrNull();
      if (t != null) title = t.title;
    }
    if (lifeAreaId != null) {
      final la = await (db.select(
        db.lifeAreas,
      )..where((r) => r.id.equals(lifeAreaId))).getSingleOrNull();
      lifeAreaName = la?.name;
    }
    return (
      title: title,
      lifeAreaName: lifeAreaName,
      categoryName: categoryName,
      targetSec: targetSec,
    );
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────

  void startSession({
    required String entityType,
    required String entityId,
    required String title,
    String? lifeAreaId,
    String? lifeAreaName,
    String? categoryName,
    int targetDurationMinutes = 0,
    DateTime? startedAt,
  }) {
    // One active session at a time (same policy enforced in SessionService).
    if (_state != null && _state!.entityId == entityId) {
      if (_state!.isPaused) resumeSession();
      return;
    }

    _ticker?.cancel();

    final sessionId = Id.uuidV7().value;
    final now = (startedAt ?? nowProvider()).toUtc();

    _state = ActiveSessionState(
      sessionId: sessionId,
      entityType: entityType,
      entityId: entityId,
      title: title,
      lifeAreaId: lifeAreaId,
      lifeAreaName: lifeAreaName,
      categoryName: categoryName,
      targetDurationSeconds: targetDurationMinutes * 60,
      startedAt: now,
    );
    _state = _state!.copyWith(
      elapsedSeconds: _state!.elapsedMsAt(nowProvider()) ~/ 1000,
    );
    _stateController.add(_state);
    _startTicker();
    _notifyNativeStart();

    final db = _activeDb;
    final owner = _activeOwnerId;
    if (db != null && owner != null) {
      // Persist immediately (Drift first). SessionService finalizes any
      // different active session so time can never overlap.
      unawaited(
        _enqueue<void>(() async {
          await SessionService(db, clock: nowProvider).start(
            ownerId: owner,
            entityType: entityType,
            entityId: entityId,
            lifeAreaId: lifeAreaId,
            sessionId: sessionId,
            startedAt: now,
          );
        }),
      );
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final s = _state;
    if (s == null) return;
    final sec = s.elapsedMsAt(nowProvider()) ~/ 1000;
    if (sec == s.elapsedSeconds) return;
    _state = s.copyWith(elapsedSeconds: sec);
    _stateController.add(_state);
    if (!s.isPaused) _notifyNativeUpdate();
  }

  void pauseSession() {
    final s = _state;
    if (s == null || s.isPaused) return;
    final now = nowProvider();
    _state = s.copyWith(isPaused: true, pausedAt: now);
    _stateController.add(_state);
    _notifyNativePause();
    final db = _activeDb;
    if (db != null) {
      unawaited(
        _enqueue<void>(() async {
          await SessionService(db, clock: nowProvider).pause(s.sessionId);
        }),
      );
    }
  }

  void resumeSession() {
    final s = _state;
    if (s == null || !s.isPaused) return;
    final now = nowProvider();
    final pausedAt = s.pausedAt ?? now;
    final delta = now.difference(pausedAt).inMilliseconds;
    _state = s.copyWith(
      isPaused: false,
      clearPausedAt: true,
      totalPausedMs: s.totalPausedMs + (delta < 0 ? 0 : delta),
    );
    _stateController.add(_state);
    _notifyNativeResume();
    final db = _activeDb;
    if (db != null) {
      unawaited(
        _enqueue<void>(() async {
          await SessionService(db, clock: nowProvider).resume(s.sessionId);
        }),
      );
    }
  }

  /// Finalizes the active session (duration, Outbox, XP — all in SessionService).
  Future<Map<String, dynamic>?> completeSession({
    AppDatabase? database,
    String? ownerId,
    String? note,
  }) {
    final db = database ?? _activeDb;
    final oId = ownerId ?? _activeOwnerId ?? 'usr_local';
    if (db == null) {
      _clearLocal(notifyNative: true);
      return Future.value(null);
    }
    return _finish(database: db, ownerId: oId, note: note);
  }

  Future<void> stopSession({
    AppDatabase? database,
    String? ownerId,
    String? note,
  }) async {
    await completeSession(database: database, ownerId: ownerId, note: note);
  }

  Future<Map<String, dynamic>?> _finish({
    required AppDatabase database,
    required String ownerId,
    String? note,
  }) async {
    final s = _state;
    if (s == null) return null;
    _clearLocal(notifyNative: true);
    final result = await _enqueue<SessionStopResult>(() async {
      // Ensure the row exists even if the start write was never bound.
      final svc = SessionService(database, clock: nowProvider);
      if (await svc.find(s.sessionId) == null) {
        await svc.start(
          ownerId: ownerId,
          entityType: s.entityType,
          entityId: s.entityId,
          lifeAreaId: s.lifeAreaId,
          sessionId: s.sessionId,
          startedAt: s.startedAt,
        );
      }
      return svc.stop(s.sessionId, note: note);
    });
    if (result == null) return null;
    return {
      'sessionId': result.sessionId,
      'durationMs': result.durationMs,
      'xpEarned': result.xpEarned,
    };
  }

  void discard() {
    final s = _state;
    _clearLocal(notifyNative: true);
    final db = _activeDb;
    if (s != null && db != null) {
      unawaited(
        _enqueue<void>(() async {
          await SessionService(db, clock: nowProvider).discard(s.sessionId);
        }),
      );
    }
  }

  void _clearLocal({required bool notifyNative}) {
    _ticker?.cancel();
    _ticker = null;
    _state = null;
    _stateController.add(null);
    if (notifyNative) _notifyNativeStop();
  }

  /// Test helper: drop in-memory state without touching persistence
  /// (simulates an app process restart).
  @visibleForTesting
  void debugSimulateProcessRestart() {
    _ticker?.cancel();
    _ticker = null;
    _state = null;
    _stateController.add(null);
  }

  /// Test helper: fully reset controller between tests.
  @visibleForTesting
  void debugReset() {
    _ticker?.cancel();
    _ticker = null;
    _state = null;
    _activeDb = null;
    _activeOwnerId = null;
    _chain = Future<void>.value();
    _stateController.add(null);
  }

  /// Test helper: wait for queued persistence.
  @visibleForTesting
  Future<void> debugFlush() => _chain;

  // --- Native Platform Notification & Service Hooks ---
  void _notifyNativeStart() {
    final s = _state;
    if (s == null) return;
    _channel
        .invokeMethod('startFocusSession', {
          'sessionId': s.sessionId,
          'title': s.title,
          'lifeAreaName': s.lifeAreaName ?? '',
          'targetSeconds': s.targetDurationSeconds,
          'startedAtMs': s.startedAt.millisecondsSinceEpoch,
        })
        .catchError((_) {});
  }

  void _notifyNativeUpdate() {
    final s = _state;
    if (s == null) return;
    _channel
        .invokeMethod('updateFocusSession', {
          'elapsedSeconds': s.elapsedSeconds,
          'isPaused': s.isPaused,
          'formattedElapsed': s.formattedElapsed,
        })
        .catchError((_) {});
  }

  void _notifyNativePause() {
    _channel.invokeMethod('pauseFocusSession').catchError((_) {});
  }

  void _notifyNativeResume() {
    _channel.invokeMethod('resumeFocusSession').catchError((_) {});
  }

  void _notifyNativeStop() {
    _channel.invokeMethod('stopFocusSession').catchError((_) {});
  }
}
