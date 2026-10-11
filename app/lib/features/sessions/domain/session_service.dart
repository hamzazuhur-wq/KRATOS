// ignore_for_file: public_member_api_docs
// SessionService — the single authority for Focus Time session lifecycle.
//
//   UI -> controller -> SessionService -> Drift (Sessions) -> Outbox -> Supabase
//                                      -> existing XP engine (ActivityXpCalculator
//                                         + DriftXpLedgerWriter), idempotent per session
//
// Source of truth = persisted Sessions rows. A running session is persisted
// the moment it starts (status = 'running'); a UI timer only renders
// `now - startedAt`. Nothing is written per second.
//
// Policy: ONE active (running/paused) session per owner. Starting a different
// entity finalizes the previous one first, so overlapping time can never
// inflate analytics.
//
// Sync: only FINALIZED sessions are enqueued (op=upsert, entity=sessions,
// same canonical id), so the server never sees half-open intervals and
// repeated sync is idempotent via apply_sync_batch (HLC + ON CONFLICT(id)).

import 'dart:convert';

import 'package:drift/drift.dart' as drift;

import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../activities/domain/activity_xp_calculator.dart';
import '../../streaks/domain/streak_service.dart';
import '../../xp/data/xp_ledger_writer_impl.dart';
import '../../xp/domain/xp_allocation_math.dart';
import 'session_clock.dart';

class SessionStatus {
  SessionStatus._();
  static const running = 'running';
  static const paused = 'paused';
  static const completed = 'completed';
}

class SessionSource {
  SessionSource._();
  static const timer = 'timer';
  static const manual = 'manual';
}

/// Sessions shorter than this never earn XP (accidental taps).
const int kMinXpSessionMs = 5000;

class SessionStopResult {
  final String sessionId;
  final int durationMs;
  final int xpEarned;

  /// True when this call performed the finalization (false = already completed).
  final bool finalizedNow;
  const SessionStopResult({
    required this.sessionId,
    required this.durationMs,
    required this.xpEarned,
    required this.finalizedNow,
  });
}

class SessionService {
  final AppDatabase _db;
  final DateTime Function() _now;

  SessionService(this._db, {DateTime Function()? clock})
    : _now = clock ?? (() => DateTime.now().toUtc());

  static bool isActive(Session s) =>
      s.deletedAt == null &&
      (s.status == SessionStatus.running || s.status == SessionStatus.paused);

  drift.Selectable<Session> _activeQuery(String ownerId) =>
      _db.select(_db.sessions)
        ..where(
          (s) =>
              s.ownerId.equals(ownerId) &
              s.deletedAt.isNull() &
              s.status.isIn([SessionStatus.running, SessionStatus.paused]),
        )
        ..orderBy([(s) => drift.OrderingTerm.desc(s.startedAt)]);

  /// Active (running/paused) session for [ownerId], restored from Drift.
  Future<Session?> activeSession(String ownerId) async {
    final rows = await _activeQuery(ownerId).get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<Session?> find(String id) =>
      (_db.select(_db.sessions)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// Persists a new running session immediately.
  ///
  /// If an active session already exists for the SAME entity it is returned
  /// (resumed if paused). If it is for a DIFFERENT entity it is finalized first.
  Future<Session> start({
    required String ownerId,
    required String entityType, // 'activity' | 'task'
    required String entityId,
    String? lifeAreaId,
    String? sessionId,
    DateTime? startedAt,
    String? note,
  }) {
    return _db.transaction(() async {
      final active = await activeSession(ownerId);
      if (active != null) {
        final sameEntity = entityType == 'task'
            ? active.taskId == entityId
            : active.activityId == entityId;
        if (sameEntity) {
          if (active.status == SessionStatus.paused) {
            return (await resume(active.id)) ?? active;
          }
          return active;
        }
        await stop(active.id);
      }

      final now = _now();
      final id = sessionId ?? Id.uuidV7().value;
      final resolvedArea =
          lifeAreaId ?? await _resolveLifeArea(ownerId, entityType, entityId);
      final hlc = Hlc.now(Id(ownerId)).toString();
      await _db
          .into(_db.sessions)
          .insert(
            SessionsCompanion.insert(
              id: id,
              ownerId: ownerId,
              taskId: drift.Value(entityType == 'task' ? entityId : null),
              activityId: drift.Value(
                entityType == 'activity' ? entityId : null,
              ),
              lifeAreaId: drift.Value(resolvedArea),
              startedAt: (startedAt ?? now).toUtc(),
              note: drift.Value(note),
              status: const drift.Value(SessionStatus.running),
              source: const drift.Value(SessionSource.timer),
              versionHlc: hlc,
              createdAt: now,
              updatedAt: now,
            ),
          );
      return (await find(id))!;
    });
  }

  Future<Session?> pause(String sessionId) async {
    final s = await find(sessionId);
    if (s == null || s.status != SessionStatus.running) return s;
    final now = _now();
    await (_db.update(_db.sessions)..where((r) => r.id.equals(sessionId))).write(
      SessionsCompanion(
        status: const drift.Value(SessionStatus.paused),
        pausedAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    return find(sessionId);
  }

  Future<Session?> resume(String sessionId) async {
    final s = await find(sessionId);
    if (s == null || s.status != SessionStatus.paused) return s;
    final now = _now();
    final pausedAt = s.pausedAt ?? now;
    final delta = now.difference(pausedAt).inMilliseconds;
    await (_db.update(_db.sessions)..where((r) => r.id.equals(sessionId))).write(
      SessionsCompanion(
        status: const drift.Value(SessionStatus.running),
        pausedAt: const drift.Value(null),
        pausedTotalMs: drift.Value(s.pausedTotalMs + (delta < 0 ? 0 : delta)),
        updatedAt: drift.Value(now),
      ),
    );
    return find(sessionId);
  }

  /// Finalizes the session: persists endedAt + durationMs, queues the Outbox
  /// upsert and awards XP exactly once. Safe to call repeatedly.
  Future<SessionStopResult?> stop(String sessionId, {String? note}) {
    return _db.transaction(() async {
      final s = await find(sessionId);
      if (s == null) return null;
      if (!isActive(s)) {
        return SessionStopResult(
          sessionId: s.id,
          durationMs: s.durationMs ?? 0,
          xpEarned: 0,
          finalizedNow: false,
        );
      }
      final now = _now();
      final durationMs = SessionClock.focusedMs(
        startedAt: s.startedAt,
        now: now,
        pausedTotalMs: s.pausedTotalMs,
        pausedAt: s.pausedAt,
      );
      var pausedTotal = s.pausedTotalMs;
      if (s.pausedAt != null) {
        final d = now.difference(s.pausedAt!).inMilliseconds;
        pausedTotal += d < 0 ? 0 : d;
      }
      final hlc = Hlc.now(Id(s.ownerId));
      await (_db.update(_db.sessions)..where((r) => r.id.equals(sessionId))).write(
        SessionsCompanion(
          status: const drift.Value(SessionStatus.completed),
          endedAt: drift.Value(now),
          durationMs: drift.Value(durationMs),
          pausedAt: const drift.Value(null),
          pausedTotalMs: drift.Value(pausedTotal),
          note: note == null ? const drift.Value.absent() : drift.Value(note),
          versionHlc: drift.Value(hlc.toString()),
          updatedAt: drift.Value(now),
        ),
      );
      final done = (await find(sessionId))!;
      await _enqueueUpsert(done, hlc);
      final xp = await _awardXp(done, hlc, now);
      return SessionStopResult(
        sessionId: done.id,
        durationMs: durationMs,
        xpEarned: xp,
        finalizedNow: true,
      );
    });
  }

  /// Manual time entry on the SAME canonical model (source = manual).
  Future<SessionStopResult> logManual({
    required String ownerId,
    required String entityType,
    required String entityId,
    required DateTime startedAt,
    DateTime? endedAt,
    int? durationMs,
    String? note,
    String? sessionId,
  }) {
    assert(endedAt != null || durationMs != null);
    return _db.transaction(() async {
      final start = startedAt.toUtc();
      final end = (endedAt ?? start.add(Duration(milliseconds: durationMs!)))
          .toUtc();
      var dur = durationMs ?? SessionClock.wallMs(start, end);
      if (dur > kMaxSessionDurationMs) dur = kMaxSessionDurationMs;
      final now = _now();
      final id = sessionId ?? Id.uuidV7().value;
      final area = await _resolveLifeArea(ownerId, entityType, entityId);
      final hlc = Hlc.now(Id(ownerId));
      await _db
          .into(_db.sessions)
          .insert(
            SessionsCompanion.insert(
              id: id,
              ownerId: ownerId,
              taskId: drift.Value(entityType == 'task' ? entityId : null),
              activityId: drift.Value(
                entityType == 'activity' ? entityId : null,
              ),
              lifeAreaId: drift.Value(area),
              startedAt: start,
              endedAt: drift.Value(end),
              durationMs: drift.Value(dur),
              note: drift.Value(note),
              status: const drift.Value(SessionStatus.completed),
              source: const drift.Value(SessionSource.manual),
              versionHlc: hlc.toString(),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final row = (await find(id))!;
      await _enqueueUpsert(row, hlc);
      final xp = await _awardXp(row, hlc, now);
      return SessionStopResult(
        sessionId: id,
        durationMs: dur,
        xpEarned: xp,
        finalizedNow: true,
      );
    });
  }

  /// Discards an unfinished session (never synced, so hard-deleted locally).
  Future<void> discard(String sessionId) async {
    final s = await find(sessionId);
    if (s == null || !isActive(s)) return;
    await (_db.delete(_db.sessions)..where((r) => r.id.equals(sessionId))).go();
  }

  // ── internals ────────────────────────────────────────────────────────────

  Future<void> _enqueueUpsert(Session s, Hlc hlc) async {
    await _db
        .into(_db.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            userId: s.ownerId,
            op: 'upsert',
            entity: 'sessions',
            entityId: s.id,
            payloadJson: jsonEncode({
              'id': s.id,
              'owner_id': s.ownerId,
              'task_id': s.taskId,
              'activity_id': s.activityId,
              'life_area_id': s.lifeAreaId,
              'started_at': s.startedAt.toUtc().toIso8601String(),
              'ended_at': s.endedAt?.toUtc().toIso8601String(),
              'duration_ms': s.durationMs,
              'note': s.note,
              'status': s.status,
              'source': s.source,
              'paused_total_ms': s.pausedTotalMs,
            }),
            hlc: hlc.toString(),
            deviceId: 'local_device',
            idempotencyKey: drift.Value('session_upsert_${s.id}'),
          ),
        );
  }

  Future<String?> _resolveLifeArea(
    String ownerId,
    String entityType,
    String entityId,
  ) async {
    if (entityType == 'activity') {
      final a = await (_db.select(
        _db.activities,
      )..where((r) => r.id.equals(entityId))).getSingleOrNull();
      return a?.lifeAreaId;
    }
    final t = await (_db.select(
      _db.tasks,
    )..where((r) => r.id.equals(entityId))).getSingleOrNull();
    return t?.lifeAreaId;
  }

  /// The ONLY place a session turns into XP. Uses the existing engine:
  ///  - activity: ActivityXpCalculator(difficulty, duration)
  ///  - task: task.xpReward or 25 (pre-existing semantics)
  /// Idempotent: ledger key `xp_sess_<sessionId>`.
  Future<int> _awardXp(Session s, Hlc hlc, DateTime now) async {
    final dur = s.durationMs ?? 0;
    if (dur < kMinXpSessionMs) return 0;

    int xp;
    if (s.activityId != null) {
      final a = await (_db.select(
        _db.activities,
      )..where((r) => r.id.equals(s.activityId!))).getSingleOrNull();
      final capped = Duration(
        milliseconds: dur > const Duration(hours: 12).inMilliseconds
            ? const Duration(hours: 12).inMilliseconds
            : dur,
      );
      xp = ActivityXpCalculator.calculateActivityXp(
        (a?.difficulty ?? 5).clamp(1, 10),
        capped,
      );
      if (xp < 1) xp = 1;
    } else if (s.taskId != null) {
      final t = await (_db.select(
        _db.tasks,
      )..where((r) => r.id.equals(s.taskId!))).getSingleOrNull();
      xp = (t?.xpReward != null && t!.xpReward! > 0) ? t.xpReward! : 25;
    } else {
      xp = 25;
    }

    var area = s.lifeAreaId ?? '';
    if (area.isEmpty) {
      final areas =
          await (_db.select(_db.lifeAreas)
                ..where(
                  (l) => l.ownerId.equals(s.ownerId) & l.deletedAt.isNull(),
                )
                ..limit(1))
              .get();
      if (areas.isNotEmpty) area = areas.first.id;
    }
    if (area.isEmpty) return 0;

    final key = Id('xp_sess_${s.id}');
    final writer = DriftXpLedgerWriter(_db);
    final alreadyAwarded = await writer.isIdempotencyKeyProcessed(key);
    await writer.recordEvent(
      ownerId: Id(s.ownerId),
      idempotencyKey: key,
      sourceType: 'session',
      sourceId: Id(s.id),
      action: 'focus_completed',
      basePoints: xp,
      allocationRatios: [AllocationRatio(lifeAreaId: Id(area), percentage: 100.0)],
      clock: hlc,
      deviceId: Id('local_device'),
    );
    if (alreadyAwarded) return 0;

    if (s.activityId != null) {
      await StreakService(_db).recordQualifyingCompletion(
        userId: Id(s.ownerId),
        sourceId: Id(s.id),
        lifeAreaId: Id(area),
        completedAt: now,
        versionHlc: hlc.toString(),
        deviceId: Id('local_device'),
      );
    }
    return xp;
  }
}
