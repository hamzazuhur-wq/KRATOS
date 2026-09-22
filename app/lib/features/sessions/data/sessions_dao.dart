// ignore_for_file: public_member_api_docs
// Wave 9: Drift DAO for Sessions — time-block logging with XP linkage.
// Sessions belong to Tasks or Activities and optionally reference a LifeArea.
// After a session ends, XP is awarded via XpLedgerWriter.

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/drift/core_tables.dart';
import '../../../domain/ids.dart';

part 'sessions_dao.g.dart';

@DriftAccessor(tables: [Sessions])
class SessionsDao extends DatabaseAccessor<AppDatabase>
    with _$SessionsDaoMixin {
  SessionsDao(super.db);

  /// All active (non-deleted) sessions for owner, newest first.
  Future<List<Session>> allSessions(String ownerId) =>
      (select(db.sessions)
            ..where((s) => s.ownerId.equals(ownerId) & s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
          .get();

  /// Sessions for a specific task.
  Future<List<Session>> sessionsForTask(String taskId) =>
      (select(db.sessions)
            ..where((s) => s.taskId.equals(taskId) & s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
          .get();

  /// Sessions for a specific activity.
  Future<List<Session>> sessionsForActivity(String activityId) =>
      (select(db.sessions)
            ..where(
                (s) => s.activityId.equals(activityId) & s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
          .get();

  /// Sessions for a specific life area.
  Future<List<Session>> sessionsForLifeArea(String lifeAreaId) =>
      (select(db.sessions)
            ..where(
                (s) => s.lifeAreaId.equals(lifeAreaId) & s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
          .get();

  /// Find a single session by id.
  Future<Session?> findById(String id) =>
      (select(db.sessions)..where((s) => s.id.equals(id))).getSingleOrNull();

  /// Start a new session — creates the record with startedAt = now.
  Future<String> startSession(SessionsCompanion companion) async {
    await into(db.sessions).insert(companion);
    return companion.id.value;
  }

  /// End a session — set endedAt and compute durationMs.
  Future<void> endSession(String sessionId, DateTime endedAt) async {
    final session = await findById(sessionId);
    if (session == null) return;
    final durationMs = endedAt.difference(session.startedAt).inMilliseconds;
    await (update(db.sessions)..where((s) => s.id.equals(sessionId))).write(
      SessionsCompanion(
        endedAt: Value(endedAt.toUtc()),
        durationMs: Value(durationMs),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Upsert a session (for sync replay).
  Future<void> upsert(SessionsCompanion companion) =>
      into(db.sessions).insertOnConflictUpdate(companion);

  /// Soft-delete a session.
  Future<void> softDelete(String sessionId, String deletedBy, String versionHlc) =>
      (update(db.sessions)..where((s) => s.id.equals(sessionId))).write(
        SessionsCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          deletedBy: Value(deletedBy),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Total duration in ms for a task's non-deleted sessions.
  Future<int> totalDurationMsForTask(String taskId) async {
    final rows = await sessionsForTask(taskId);
    return rows.fold<int>(0, (sum, s) => sum + (s.durationMs ?? 0));
  }

  /// Total duration in ms for a life area (analytics input).
  Future<int> totalDurationMsForLifeArea(String lifeAreaId) async {
    final rows = await sessionsForLifeArea(lifeAreaId);
    return rows.fold<int>(0, (sum, s) => sum + (s.durationMs ?? 0));
  }
}
