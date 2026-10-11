import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' hide Category;

import '../../../data/drift/app_database.dart';
import '../../../domain/ids.dart';
import '../../progression/domain/progression_calculator.dart';
import '../../progression/domain/progression_models.dart';

/// Read model for one independent Life Area progression on the Levels page.
class LevelsDashboardEntry {
  final LifeArea area;
  final Category? category;
  final ProgressionInfo progression;

  const LevelsDashboardEntry({
    required this.area,
    required this.category,
    required this.progression,
  });
}

/// Reads the Levels dashboard through the existing Drift relationships.
///
/// XP is scoped through the owning ledger row, while the category is resolved
/// through LifeAreas.categoryId and the existing life_area category type.
class LevelsDashboardRepository {
  final AppDatabase _database;

  LevelsDashboardRepository(this._database);

  Future<List<TierDefinition>> tiers() async {
    await _database.progressionDao.ensureSeeded();
    return _database.progressionDao.allTiers();
  }

  Future<List<LevelCurve>> curves() async {
    await _database.progressionDao.ensureSeeded();
    return _database.progressionDao.allCurves();
  }

  JoinedSelectStatement _buildQuery(String ownerId) {
    return _database.select(_database.lifeAreas).join([
      leftOuterJoin(
        _database.categories,
        _database.categories.id.equalsExp(_database.lifeAreas.categoryId) &
            _database.categories.ownerId.equalsExp(_database.lifeAreas.ownerId) &
            _database.categories.categoryType.equals('life_area'),
      ),
      leftOuterJoin(
        _database.xpAllocationLines,
        _database.xpAllocationLines.lifeAreaId.equalsExp(_database.lifeAreas.id),
      ),
      leftOuterJoin(
        _database.xpLedger,
        // Join on ledger id and owner only. Do NOT filter out reversal rows
        // here — compensating negative rows must be included so that
        // SUM(allocatedPoints) nets to the correct value. Excluding reversals
        // (reversalEventId.isNull()) inflates every life-area's XP total.
        _database.xpLedger.id.equalsExp(_database.xpAllocationLines.ledgerId) &
            _database.xpLedger.ownerId.equalsExp(_database.lifeAreas.ownerId),
      ),
    ])
      ..where(
        _database.lifeAreas.ownerId.equals(ownerId) &
            _database.lifeAreas.archivedAt.isNull() &
            _database.lifeAreas.deletedAt.isNull(),
      )
      ..orderBy([
        OrderingTerm.asc(_database.lifeAreas.sortOrder),
        OrderingTerm.asc(_database.lifeAreas.name),
      ]);
  }

  static final Map<String, Future<List<LevelsDashboardEntry>>> _inFlight = {};

  Future<List<LevelsDashboardEntry>> getProgressions(String ownerId) {
    final existing = _inFlight[ownerId];
    if (existing != null) return existing;

    final future = _fetchProgressions(ownerId);
    _inFlight[ownerId] = future;
    return future.whenComplete(() => _inFlight.remove(ownerId));
  }

  Future<List<LevelsDashboardEntry>> _fetchProgressions(String ownerId) async {
    await _database.progressionDao.ensureSeeded();
    final tiers = await _database.progressionDao.allTiers();
    final curves = await _database.progressionDao.allCurves();
    final rows = await _buildQuery(ownerId).get();
    return _mapRows(rows, tiers, curves);
  }

  Stream<List<LevelsDashboardEntry>> watchProgressions(String ownerId) async* {
    debugPrint('[LevelsRepo] watchProgressions started for $ownerId');
    await _database.progressionDao.ensureSeeded();
    final tiers = await _database.progressionDao.allTiers();
    final curves = await _database.progressionDao.allCurves();
    final rows = await _buildQuery(ownerId).get();
    debugPrint('[LevelsRepo] watchProgressions rows: ${rows.length}, tiers: ${tiers.length}, curves: ${curves.length}');

    // customSelect().watch() does not guarantee an initial emission on web.
    final initial = _mapRows(rows, tiers, curves);
    debugPrint('[LevelsRepo] watchProgressions yielding initial: ${initial.length} entries');
    yield initial;

    yield* _database
        .customSelect(
          'SELECT 1',
          readsFrom: {
            _database.lifeAreas,
            _database.categories,
            _database.xpLedger,
            _database.xpAllocationLines,
          },
        )
        .watch()
        .asyncMap((_) async {
          final rows = await _buildQuery(ownerId).get();
          return _mapRows(rows, tiers, curves);
        });
  }

  List<LevelsDashboardEntry> _mapRows(
    List<TypedResult> rows,
    List<TierDefinition> tiers,
    List<LevelCurve> curves,
  ) {
    final grouped = <String, _DashboardAccumulator>{};
    for (final row in rows) {
      final area = row.readTable(_database.lifeAreas);
      final accumulator = grouped.putIfAbsent(
        area.id,
        () => _DashboardAccumulator(
          area: area,
          category: row.readTableOrNull(_database.categories),
        ),
      );

      final allocation = row.readTableOrNull(_database.xpAllocationLines);
      final ledger = row.readTableOrNull(_database.xpLedger);
      if (allocation != null && ledger != null) {
        accumulator.totalXp += allocation.allocatedPoints;
      }
    }

    final curveSnapshots = curves
        .map(
          (curve) => LevelCurveSnapshot(
            level: curve.level,
            deltaXp: curve.deltaXp,
            cumulativeXpRequired: curve.cumulativeXpRequired,
          ),
        )
        .toList();
    final tierSnapshots = tiers
        .map(
          (tier) => TierDefinitionSnapshot(
            name: tier.name,
            entryXp: tier.entryXp,
            ordinal: tier.ordinal,
            icon: tier.icon ?? '',
            color: tier.color ?? '#C6F135',
          ),
        )
        .toList();

    return grouped.values.map((item) {
      final progression = ProgressionCalculator.calculate(
        lifeAreaId: Id(item.area.id),
        totalXp: item.totalXp,
        customCurves: curveSnapshots,
        customTiers: tierSnapshots,
      );
      return LevelsDashboardEntry(
        area: item.area,
        category: item.category,
        progression: progression,
      );
    }).toList();
  }
}

class _DashboardAccumulator {
  final LifeArea area;
  final Category? category;
  int totalXp = 0;

  _DashboardAccumulator({required this.area, required this.category});
}
