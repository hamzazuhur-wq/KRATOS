// ignore_for_file: public_member_api_docs
import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/services.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../streaks/domain/streak_service.dart';
import '../../xp/data/xp_ledger_writer_impl.dart';
import '../../xp/domain/xp_allocation_math.dart';

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

  String get formattedElapsed {
    final h = elapsedSeconds ~/ 3600;
    final m = (elapsedSeconds % 3600) ~/ 60;
    final s = elapsedSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedTarget {
    if (targetDurationSeconds <= 0) return '';
    final h = targetDurationSeconds ~/ 3600;
    final m = (targetDurationSeconds % 3600) ~/ 60;
    final s = targetDurationSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  ActiveSessionState copyWith({
    DateTime? pausedAt,
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
      pausedAt: pausedAt ?? this.pausedAt,
      totalPausedMs: totalPausedMs ?? this.totalPausedMs,
      isPaused: isPaused ?? this.isPaused,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    );
  }
}

class GlobalActiveSessionController {
  static final GlobalActiveSessionController _instance = GlobalActiveSessionController._internal();
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

  Stream<ActiveSessionState?> get stream => _stateController.stream;
  ActiveSessionState? get currentState => _state;
  bool get hasActiveSession => _state != null;

  void bindDatabase(AppDatabase db, String ownerId) {
    _activeDb = db;
    _activeOwnerId = ownerId;
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
            await completeSession(database: _activeDb!, ownerId: _activeOwnerId!);
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
    // Only one active session at a time
    if (_state != null) {
      if (_state!.entityId == entityId) {
        if (_state!.isPaused) resumeSession();
        return;
      }
    }

    _ticker?.cancel();

    final sessionId = Id.uuidV7().value;
    final now = startedAt ?? DateTime.now().toUtc();
    final targetSec = targetDurationMinutes * 60;

    _state = ActiveSessionState(
      sessionId: sessionId,
      entityType: entityType,
      entityId: entityId,
      title: title,
      lifeAreaId: lifeAreaId,
      lifeAreaName: lifeAreaName,
      categoryName: categoryName,
      targetDurationSeconds: targetSec,
      startedAt: now,
      pausedAt: null,
      totalPausedMs: 0,
      isPaused: false,
      elapsedSeconds: (DateTime.now().toUtc().difference(now).inSeconds).clamp(0, 86400 * 7),
    );

    _stateController.add(_state);

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());

    _notifyNativeStart();
  }

  void _tick() {
    final s = _state;
    if (s == null) return;
    if (!s.isPaused) {
      final now = DateTime.now().toUtc();
      final elapsedMs = now.difference(s.startedAt).inMilliseconds - s.totalPausedMs;
      final elapsedSec = (elapsedMs ~/ 1000).clamp(0, 86400 * 7);
      _state = s.copyWith(elapsedSeconds: elapsedSec);
      _stateController.add(_state);
      _notifyNativeUpdate();
    }
  }

  void pauseSession() {
    final s = _state;
    if (s != null && !s.isPaused) {
      _state = s.copyWith(
        isPaused: true,
        pausedAt: DateTime.now().toUtc(),
      );
      _stateController.add(_state);
      _notifyNativePause();
    }
  }

  void resumeSession() {
    final s = _state;
    if (s != null && s.isPaused) {
      final pausedAt = s.pausedAt ?? DateTime.now().toUtc();
      final pauseDelta = DateTime.now().toUtc().difference(pausedAt).inMilliseconds;
      _state = s.copyWith(
        isPaused: false,
        pausedAt: null,
        totalPausedMs: s.totalPausedMs + pauseDelta,
      );
      _stateController.add(_state);
      _notifyNativeResume();
    }
  }

  Future<Map<String, dynamic>?> completeSession({
    required AppDatabase database,
    required String ownerId,
    String? note,
  }) async {
    final s = _state;
    if (s == null) return null;

    _ticker?.cancel();
    _ticker = null;
    _state = null;
    _stateController.add(null);
    _notifyNativeStop();

    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id(ownerId));
    int finalPaused = s.totalPausedMs;
    if (s.isPaused && s.pausedAt != null) {
      finalPaused += now.difference(s.pausedAt!).inMilliseconds;
    }
    final actualDurationMs = (now.difference(s.startedAt).inMilliseconds - finalPaused).clamp(0, 86400 * 7 * 1000);

    await database.transaction(() async {
      // 1. Insert Session row
      await database.into(database.sessions).insert(
        SessionsCompanion.insert(
          id: s.sessionId,
          ownerId: ownerId,
          taskId: drift.Value(s.entityType == 'task' ? s.entityId : null),
          activityId: drift.Value(s.entityType == 'activity' ? s.entityId : null),
          lifeAreaId: drift.Value(s.lifeAreaId),
          startedAt: s.startedAt,
          endedAt: drift.Value(now),
          durationMs: drift.Value(actualDurationMs),
          note: drift.Value(note ?? 'Completed focus session on ${s.title}'),
          versionHlc: hlc.toString(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 2. Enqueue to sync outbox
      await database.into(database.syncOutbox).insert(
        SyncOutboxCompanion.insert(
          userId: ownerId,
          op: 'upsert',
          entity: 'sessions',
          entityId: s.sessionId,
          payloadJson: jsonEncode({
            'id': s.sessionId,
            'owner_id': ownerId,
            'task_id': s.entityType == 'task' ? s.entityId : null,
            'activity_id': s.entityType == 'activity' ? s.entityId : null,
            'life_area_id': s.lifeAreaId,
            'started_at': s.startedAt.toIso8601String(),
            'ended_at': now.toIso8601String(),
            'duration_ms': actualDurationMs,
            'note': note,
          }),
          hlc: hlc.toString(),
          deviceId: 'local_device',
        ),
      );

      // 3. Award XP through Point Ledger
      final actualMinutes = (actualDurationMs / 60000);
      int xpPoints = actualMinutes.round();
      if (xpPoints < 1 && actualDurationMs >= 10000) xpPoints = 1;
      if (xpPoints > 0) {
        final writer = DriftXpLedgerWriter(database);
        final idempotencyKey = Id('xp_sess_${s.sessionId}');

        String effectiveArea = s.lifeAreaId ?? '';
        if (effectiveArea.isEmpty) {
          final areas = await (database.select(database.lifeAreas)
                ..where((l) => l.ownerId.equals(ownerId) & l.deletedAt.isNull())
                ..limit(1))
              .get();
          effectiveArea = areas.isNotEmpty ? areas.first.id : 'la_default';
        }

        final streakService = StreakService(database);
        final streakInfo = await streakService.getStreakForLifeArea(
          userId: Id(ownerId),
          lifeAreaId: Id(effectiveArea),
        );
        final streakBonus = streakInfo.calculateStreakBonus(xpPoints);

        await writer.recordEvent(
          ownerId: Id(ownerId),
          idempotencyKey: idempotencyKey,
          sourceType: 'session',
          sourceId: Id(s.sessionId),
          action: 'focus_completed',
          basePoints: xpPoints,
          streakBonus: streakBonus,
          allocationRatios: [
            AllocationRatio(lifeAreaId: Id(effectiveArea), percentage: 100.0),
          ],
          clock: hlc,
          deviceId: Id('local_device'),
        );
      }

      // 4. Update Streak if life area is present
      if (s.lifeAreaId != null && s.lifeAreaId!.isNotEmpty) {
        try {
          final streakService = StreakService(database);
          await streakService.logActivity(
            userId: Id(ownerId),
            lifeAreaId: Id(s.lifeAreaId!),
            activityDate: now,
            versionHlc: hlc.toString(),
          );
        } catch (_) {}
      }
    });

    return {
      'sessionId': s.sessionId,
      'durationMs': actualDurationMs,
      'xpEarned': (actualDurationMs ~/ 60000).clamp(1, 1000),
    };
  }

  Future<void> stopSession({
    required AppDatabase database,
    required String ownerId,
    String? note,
  }) async {
    final s = _state;
    if (s == null) return;

    _ticker?.cancel();
    _ticker = null;
    _state = null;
    _stateController.add(null);
    _notifyNativeStop();

    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id(ownerId));
    int finalPaused = s.totalPausedMs;
    if (s.isPaused && s.pausedAt != null) {
      finalPaused += now.difference(s.pausedAt!).inMilliseconds;
    }
    final actualDurationMs = (now.difference(s.startedAt).inMilliseconds - finalPaused).clamp(0, 86400 * 7 * 1000);

    await database.transaction(() async {
      await database.into(database.sessions).insert(
        SessionsCompanion.insert(
          id: s.sessionId,
          ownerId: ownerId,
          taskId: drift.Value(s.entityType == 'task' ? s.entityId : null),
          activityId: drift.Value(s.entityType == 'activity' ? s.entityId : null),
          lifeAreaId: drift.Value(s.lifeAreaId),
          startedAt: s.startedAt,
          endedAt: drift.Value(now),
          durationMs: drift.Value(actualDurationMs),
          note: drift.Value(note ?? 'Stopped focus session on ${s.title}'),
          versionHlc: hlc.toString(),
          createdAt: now,
          updatedAt: now,
        ),
      );

      await database.into(database.syncOutbox).insert(
        SyncOutboxCompanion.insert(
          userId: ownerId,
          op: 'upsert',
          entity: 'sessions',
          entityId: s.sessionId,
          payloadJson: jsonEncode({
            'id': s.sessionId,
            'owner_id': ownerId,
            'task_id': s.entityType == 'task' ? s.entityId : null,
            'activity_id': s.entityType == 'activity' ? s.entityId : null,
            'life_area_id': s.lifeAreaId,
            'started_at': s.startedAt.toIso8601String(),
            'ended_at': now.toIso8601String(),
            'duration_ms': actualDurationMs,
            'status': 'stopped',
          }),
          hlc: hlc.toString(),
          deviceId: 'local_device',
        ),
      );
    });
  }

  void discard() {
    _ticker?.cancel();
    _ticker = null;
    _state = null;
    _stateController.add(null);
    _notifyNativeStop();
  }

  // --- Native Platform Notification & Service Hooks ---
  void _notifyNativeStart() {
    final s = _state;
    if (s == null) return;
    _channel.invokeMethod('startFocusSession', {
      'sessionId': s.sessionId,
      'title': s.title,
      'lifeAreaName': s.lifeAreaName ?? '',
      'targetSeconds': s.targetDurationSeconds,
      'startedAtMs': s.startedAt.millisecondsSinceEpoch,
    }).catchError((_) {});
  }

  void _notifyNativeUpdate() {
    final s = _state;
    if (s == null) return;
    _channel.invokeMethod('updateFocusSession', {
      'elapsedSeconds': s.elapsedSeconds,
      'isPaused': s.isPaused,
      'formattedElapsed': s.formattedElapsed,
    }).catchError((_) {});
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
