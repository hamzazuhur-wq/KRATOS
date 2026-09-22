// ignore_for_file: public_member_api_docs
// Wave 5: XP Ledger Drift DAO.
// Accessor for xp_ledger, xp_allocation_lines, and processed_idempotency_keys.

import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';
import '../../../data/drift/ledger_tables.dart';

part 'xp_ledger_dao.g.dart';

@DriftAccessor(tables: [XpLedger, XpAllocationLines, ProcessedIdempotencyKeys])
class XpLedgerDao extends DatabaseAccessor<AppDatabase>
    with _$XpLedgerDaoMixin {
  XpLedgerDao(super.db);

  /// Fetch a single ledger entry by ID.
  Future<XpLedgerData?> findById(String id) =>
      (select(db.xpLedger)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  /// Check if an idempotency key was already recorded in the ledger.
  Future<XpLedgerData?> findByIdempotencyKey(String key) =>
      (select(db.xpLedger)..where((tbl) => tbl.idempotencyKey.equals(key)))
          .getSingleOrNull();

  /// Check if key is in the local 7-day fast lookup table.
  Future<bool> isKeyInCache(String key) async {
    final row = await (select(db.processedIdempotencyKeys)
          ..where((tbl) => tbl.idempotencyKey.equals(key)))
        .getSingleOrNull();
    return row != null;
  }

  /// Mark key as processed in the local fast lookup table.
  Future<void> markKeyProcessed(String key, String userId) =>
      into(db.processedIdempotencyKeys).insertOnConflictUpdate(
        ProcessedIdempotencyKeysCompanion(
          idempotencyKey: Value(key),
          userId: Value(userId),
          createdAt: Value(DateTime.now().toUtc()),
        ),
      );

  /// Remove keys older than 7 days from the cache.
  Future<int> purgeExpiredKeys(DateTime olderThan) =>
      (delete(db.processedIdempotencyKeys)
            ..where((tbl) => tbl.createdAt.isSmallerThanValue(olderThan)))
          .go();

  /// Insert parent ledger event row.
  Future<void> insertLedgerRow(XpLedgerCompanion entry) =>
      into(db.xpLedger).insert(entry);

  /// Batch insert child allocation lines.
  Future<void> insertAllocationLines(List<XpAllocationLinesCompanion> lines) =>
      batch((b) {
        b.insertAll(db.xpAllocationLines, lines);
      });

  /// Fetch child allocation lines for a specific ledger ID.
  Future<List<XpAllocationLine>> linesForLedger(String ledgerId) =>
      (select(db.xpAllocationLines)..where((l) => l.ledgerId.equals(ledgerId)))
          .get();

  /// Fetch chronological XP history for an owner.
  Future<List<XpLedgerData>> historyForOwner(String ownerId, {int limit = 50}) =>
      (select(db.xpLedger)
            ..where((tbl) => tbl.ownerId.equals(ownerId))
            ..orderBy([(tbl) => OrderingTerm.desc(tbl.createdAt)])
            ..limit(limit))
          .get();
}
