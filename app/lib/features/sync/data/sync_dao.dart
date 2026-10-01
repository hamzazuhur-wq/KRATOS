// ignore_for_file: public_member_api_docs
// Wave 16: Drift DAO for SyncOutbox and SyncCursors.
// Implements FIFO queue drain, retry tracking, and cursor watermarks.

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/drift/ledger_tables.dart';
import '../domain/sync_models.dart';

part 'sync_dao.g.dart';

@DriftAccessor(tables: [SyncOutbox, SyncCursors, SyncTombstones])
class SyncDao extends DatabaseAccessor<AppDatabase>
    with _$SyncDaoMixin
    implements SyncOutboxStore {
  SyncDao(super.db);

  /// Fetch pending outbox mutations ordered by sequence number (FIFO).
  Future<List<SyncOutboxData>> getPendingItems(
    String userId, {
    int limit = 50,
  }) =>
      (select(db.syncOutbox)
            ..where(
              (t) =>
                  t.userId.equals(userId) &
                  t.status.equals('pending') &
                  (t.nextAttemptAt.isNull() |
                      t.nextAttemptAt.isSmallerOrEqualValue(
                        DateTime.now().toUtc(),
                      )),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.seq)])
            ..limit(limit))
          .get();

  @override
  Future<List<SyncItem>> loadPending(String userId, {int limit = 50}) async =>
      (await getPendingItems(userId, limit: limit))
          .map(
            (row) => SyncItem(
              seq: row.seq,
              userId: row.userId,
              op: row.op.toLowerCase(),
              entity: row.entity,
              entityId: row.entityId,
              payloadJson: row.payloadJson,
              hlc: row.hlc,
              deviceId: row.deviceId,
              idempotencyKey: row.idempotencyKey,
              attempts: row.attempts,
              status: SyncStatus.pending,
              createdAt: row.createdAt,
            ),
          )
          .toList(growable: false);

  /// Count of currently pending outbox mutations.
  Future<int> countPendingItems(String userId) async {
    final countExp = db.syncOutbox.seq.count();
    final query = selectOnly(db.syncOutbox)
      ..addColumns([countExp])
      ..where(
        db.syncOutbox.userId.equals(userId) &
            db.syncOutbox.status.equals('pending'),
      );
    final row = await query.getSingleOrNull();
    return row?.read(countExp) ?? 0;
  }

  @override
  Future<int> countPending(String userId) => countPendingItems(userId);

  /// Preserve acknowledged operations for diagnosis; acknowledgement requires a server response.
  @override
  Future<void> markAcknowledged(List<int> seqs) =>
      (update(db.syncOutbox)..where((t) => t.seq.isIn(seqs))).write(
        const SyncOutboxCompanion(
          status: Value('done'),
          lastErrorClass: Value(null),
          lastErrorCode: Value(null),
          nextAttemptAt: Value(null),
        ),
      );

  /// Increment attempt counter and schedule next attempt with backoff on failure.
  @override
  Future<void> recordFailure({
    required int seq,
    required String errorClass,
    required String errorCode,
    required Duration backoff,
    required bool retryable,
    int maxAttempts = 3,
  }) async {
    final row = await (select(
      db.syncOutbox,
    )..where((t) => t.seq.equals(seq))).getSingleOrNull();
    if (row == null || row.status == 'done') return;
    final attempts = row.attempts + 1;
    final parked = !retryable || attempts >= maxAttempts;
    await (update(db.syncOutbox)..where((t) => t.seq.equals(seq))).write(
      SyncOutboxCompanion(
        attempts: Value(attempts),
        status: Value(parked ? 'failed' : 'pending'),
        lastErrorClass: Value(errorClass),
        lastErrorCode: Value(errorCode),
        nextAttemptAt: Value(
          parked ? null : DateTime.now().toUtc().add(backoff),
        ),
      ),
    );
  }

  Future<void> retryFailed(int seq) =>
      (update(
        db.syncOutbox,
      )..where((t) => t.seq.equals(seq) & t.status.equals('failed'))).write(
        const SyncOutboxCompanion(
          attempts: Value(0),
          status: Value('pending'),
          lastErrorClass: Value(null),
          lastErrorCode: Value(null),
          nextAttemptAt: Value(null),
        ),
      );

  /// Record sync cursor watermark.
  Future<void> updateCursor(
    String userId,
    String peerId,
    String entityKind,
    String hlc,
  ) => into(db.syncCursors).insertOnConflictUpdate(
    SyncCursorsCompanion(
      userId: Value(userId),
      peerId: Value(peerId),
      entityKind: Value(entityKind),
      lastAppliedHlc: Value(hlc),
      updatedAt: Value(DateTime.now().toUtc()),
    ),
  );

  /// Fetch sync cursor watermark.
  Future<String?> getCursor(
    String userId,
    String peerId,
    String entityKind,
  ) async {
    final row = await (select(db.syncCursors)
      ..where(
        (t) =>
            t.userId.equals(userId) &
            t.peerId.equals(peerId) &
            t.entityKind.equals(entityKind),
      )).getSingleOrNull();
    return row?.lastAppliedHlc;
  }
}
