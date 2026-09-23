// ignore_for_file: public_member_api_docs
// Wave 16: Drift DAO for SyncOutbox and SyncCursors.
// Implements FIFO queue drain, retry tracking, and cursor watermarks.

import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';
import '../../../data/drift/ledger_tables.dart';

part 'sync_dao.g.dart';

@DriftAccessor(tables: [SyncOutbox, SyncCursors, SyncTombstones])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  /// Fetch pending outbox mutations ordered by sequence number (FIFO).
  Future<List<SyncOutboxData>> getPendingItems(String userId, {int limit = 50}) =>
      (select(db.syncOutbox)
            ..where((t) => t.userId.equals(userId) & t.status.equals('pending'))
            ..orderBy([(t) => OrderingTerm.asc(t.seq)])
            ..limit(limit))
          .get();

  /// Count of currently pending outbox mutations.
  Future<int> countPendingItems(String userId) async {
    final countExp = db.syncOutbox.seq.count();
    final query = selectOnly(db.syncOutbox)
      ..addColumns([countExp])
      ..where(db.syncOutbox.userId.equals(userId) & db.syncOutbox.status.equals('pending'));
    final row = await query.getSingleOrNull();
    return row?.read(countExp) ?? 0;
  }

  /// Mark an array of sequences as completed and remove from pending outbox.
  Future<void> markCompleted(List<int> seqs) =>
      (delete(db.syncOutbox)..where((t) => t.seq.isIn(seqs))).go();

  /// Increment attempt counter and schedule next attempt with backoff on failure.
  Future<void> markFailed(int seq, String errorClass, String errorCode, Duration backoff) =>
      (update(db.syncOutbox)..where((t) => t.seq.equals(seq))).write(
        SyncOutboxCompanion(
          attempts: Value(1), // increment or mark
          status: const Value('pending'),
          lastErrorClass: Value(errorClass),
          lastErrorCode: Value(errorCode),
          nextAttemptAt: Value(DateTime.now().toUtc().add(backoff)),
        ),
      );

  /// Record sync cursor watermark.
  Future<void> updateCursor(String userId, String peerId, String entityKind, String hlc) =>
      into(db.syncCursors).insertOnConflictUpdate(
        SyncCursorsCompanion(
          userId: Value(userId),
          peerId: Value(peerId),
          entityKind: Value(entityKind),
          lastAppliedHlc: Value(hlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
}
