// ignore_for_file: public_member_api_docs
// Wave 10: XP Analytics DAO — aggregation queries for the dashboard.
// Reads from xp_ledger + xp_allocation_lines (append-only, no writes here).
// All XP writes go through XpLedgerWriter — never direct INSERT.

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/drift/ledger_tables.dart';

part 'xp_analytics_dao.g.dart';

/// Read-only DAO for XP analytics queries.
///
/// Aggregates data from [XpLedger] and [XpAllocationLines] for the
/// dashboard. No writes — XP is always written via [XpLedgerWriter].
@DriftAccessor(tables: [XpLedger, XpAllocationLines])
class XpAnalyticsDao extends DatabaseAccessor<AppDatabase>
    with _$XpAnalyticsDaoMixin {
  XpAnalyticsDao(super.db);

  // ─── Total XP per LifeArea ─────────────────────────────────────────────

  /// Total allocated XP for a single life area.
  Future<int> totalXpForLifeArea(String lifeAreaId) async {
    final query = selectOnly(db.xpAllocationLines)
      ..addColumns([db.xpAllocationLines.allocatedPoints.sum()])
      ..where(db.xpAllocationLines.lifeAreaId.equals(lifeAreaId));
    final row = await query.getSingleOrNull();
    return row?.read(db.xpAllocationLines.allocatedPoints.sum()) ?? 0;
  }

  /// Total XP for all life areas of an owner, as a map {lifeAreaId: xp}.
  Future<Map<String, int>> xpByLifeArea(String ownerId) async {
    // Join xp_ledger (for owner filter) with xp_allocation_lines.
    final query = select(db.xpAllocationLines).join([
      innerJoin(
        db.xpLedger,
        db.xpLedger.id.equalsExp(db.xpAllocationLines.ledgerId),
      ),
    ])
      ..where(db.xpLedger.ownerId.equals(ownerId));
    final rows = await query
        .map((row) => (
              lifeAreaId: row.readTable(db.xpAllocationLines).lifeAreaId,
              points: row.readTable(db.xpAllocationLines).allocatedPoints,
            ))
        .get();
    final result = <String, int>{};
    for (final r in rows) {
      result[r.lifeAreaId] = (result[r.lifeAreaId] ?? 0) + r.points;
    }
    return result;
  }

  // ─── XP Over Time ─────────────────────────────────────────────────────

  /// XP events in the last [days] days for an owner, ordered newest first.
  ///
  /// NOTE: Includes BOTH original positive rows AND compensating negative
  /// reversal rows so that [dailyXpTotals] computes correct net XP.
  /// Filtering out reversal rows (reversalEventId.isNull()) would inflate
  /// totals because the compensating deduction would be invisible.
  Future<List<XpLedgerData>> recentXpEvents(String ownerId, int days) {
    final since =
        DateTime.now().toUtc().subtract(Duration(days: days));
    return (select(db.xpLedger)
          ..where((e) =>
              e.ownerId.equals(ownerId) &
              e.createdAt.isBiggerThanValue(since))
          ..orderBy([(e) => OrderingTerm.desc(e.createdAt)]))
        .get();
  }

  // ─── XP by Source Type ────────────────────────────────────────────────

  /// Total XP grouped by sourceType (e.g. 'task', 'session', 'goal').
  ///
  /// NOTE: All rows (original + reversal) are included so the SUM nets
  /// correctly. Excluding reversals would inflate XP per source type.
  Future<Map<String, int>> xpBySourceType(String ownerId) async {
    final rows = await (select(db.xpLedger)
          ..where((e) => e.ownerId.equals(ownerId)))
        .get();
    final result = <String, int>{};
    for (final r in rows) {
      result[r.sourceType] = (result[r.sourceType] ?? 0) + r.points;
    }
    return result;
  }

  // ─── Streak Bonus Earned ──────────────────────────────────────────────

  /// Total streak bonus XP earned for an owner.
  Future<int> totalStreakBonusXp(String ownerId) async {
    final query = selectOnly(db.xpLedger)
      ..addColumns([db.xpLedger.streakBonus.sum()])
      ..where(db.xpLedger.ownerId.equals(ownerId));
    final row = await query.getSingleOrNull();
    return row?.read(db.xpLedger.streakBonus.sum()) ?? 0;
  }

  // ─── Daily XP Totals (last 7 days) ────────────────────────────────────

  /// Returns a list of (date, xp) pairs for the last [days] days.
  /// Used for the sparkline / bar chart on the dashboard.
  Future<List<({DateTime date, int xp})>> dailyXpTotals(
      String ownerId, int days) async {
    final rows = await recentXpEvents(ownerId, days);
    final map = <String, int>{};
    for (final r in rows) {
      final dayKey =
          '${r.createdAt.year}-${r.createdAt.month.toString().padLeft(2, '0')}-${r.createdAt.day.toString().padLeft(2, '0')}';
      map[dayKey] = (map[dayKey] ?? 0) + r.points;
    }
    return map.entries
        .map((e) => (date: DateTime.parse(e.key), xp: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Fetch complete dashboard metrics bundle in one coordinated pass.
  Future<XpDashboardMetrics> getDashboardMetrics(String ownerId) async {
    final areaXp = await xpByLifeArea(ownerId);
    final sources = await xpBySourceType(ownerId);
    final streakBonus = await totalStreakBonusXp(ownerId);
    final daily = await dailyXpTotals(ownerId, 7);

    final totalXp = areaXp.values.fold<int>(0, (sum, xp) => sum + xp);

    return XpDashboardMetrics(
      totalXp: totalXp,
      streakBonusXp: streakBonus,
      lifeAreaXp: areaXp,
      sourceTypeXp: sources,
      dailyXp: daily.map((d) => d.xp).toList(),
    );
  }
}

class XpDashboardMetrics {
  final int totalXp;
  final int streakBonusXp;
  final Map<String, int> lifeAreaXp;
  final Map<String, int> sourceTypeXp;
  final List<int> dailyXp;

  const XpDashboardMetrics({
    required this.totalXp,
    required this.streakBonusXp,
    required this.lifeAreaXp,
    required this.sourceTypeXp,
    required this.dailyXp,
  });

  factory XpDashboardMetrics.empty() {
    return const XpDashboardMetrics(
      totalXp: 0,
      streakBonusXp: 0,
      lifeAreaXp: {},
      sourceTypeXp: {},
      dailyXp: [0, 0, 0, 0, 0, 0, 0],
    );
  }
}

