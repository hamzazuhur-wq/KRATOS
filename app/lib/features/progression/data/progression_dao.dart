// ignore_for_file: public_member_api_docs
// Wave 6: Drift DAO for LevelCurves, TierDefinitions, and LevelObjectives.

import 'dart:math' as math;
import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';
import '../../../data/drift/progression_tables.dart';

part 'progression_dao.g.dart';

@DriftAccessor(tables: [LevelCurves, TierDefinitions, LevelObjectives])
class ProgressionDao extends DatabaseAccessor<AppDatabase>
    with _$ProgressionDaoMixin {
  ProgressionDao(super.db);

  /// Ensure initial curves and tiers are populated in the local SQLite database.
  Future<void> ensureSeeded() async {
    final curveCount = await (select(db.levelCurves)..limit(1)).get();
    if (curveCount.isEmpty) {
      await _seedCurves();
    }

    final tierCount = await (select(db.tierDefinitions)..limit(1)).get();
    if (tierCount.isEmpty) {
      await _seedTiers();
    }
  }

  Future<void> _seedCurves() async {
    final list = <LevelCurvesCompanion>[];
    var cumul = 0;

    // Level 1 starts at 0 cumulative XP
    list.add(const LevelCurvesCompanion(
      level: Value(1),
      deltaXp: Value(100),
      cumulativeXpRequired: Value(0),
    ));

    for (var lvl = 2; lvl <= 100; lvl++) {
      final delta = (100 * math.pow(1.085, lvl)).floor();
      cumul += delta;
      if (cumul > 14000000) cumul = 14000000;

      list.add(LevelCurvesCompanion(
        level: Value(lvl),
        deltaXp: Value(delta),
        cumulativeXpRequired: Value(cumul),
      ));
    }

    await batch((b) {
      b.insertAll(db.levelCurves, list, mode: InsertMode.insertOrReplace);
    });
  }

  Future<void> _seedTiers() async {
    final tiers = [
      const TierDefinitionsCompanion(
        name: Value('Bronze'),
        entryXp: Value(1000),
        ordinal: Value(1),
        icon: Value('shield_bronze'),
        color: Value('#CD7F32'),
      ),
      const TierDefinitionsCompanion(
        name: Value('Silver'),
        entryXp: Value(3000),
        ordinal: Value(2),
        icon: Value('shield_silver'),
        color: Value('#C0C0C0'),
      ),
      const TierDefinitionsCompanion(
        name: Value('Gold'),
        entryXp: Value(7000),
        ordinal: Value(3),
        icon: Value('shield_gold'),
        color: Value('#FFD700'),
      ),
      const TierDefinitionsCompanion(
        name: Value('Crystal'),
        entryXp: Value(15000),
        ordinal: Value(4),
        icon: Value('gem_crystal'),
        color: Value('#00FFFF'),
      ),
      const TierDefinitionsCompanion(
        name: Value('Diamond'),
        entryXp: Value(30000),
        ordinal: Value(5),
        icon: Value('gem_diamond'),
        color: Value('#B9F2FF'),
      ),
      const TierDefinitionsCompanion(
        name: Value('Mythic'),
        entryXp: Value(60000),
        ordinal: Value(6),
        icon: Value('crown_mythic'),
        color: Value('#C6F135'),
      ),
    ];

    await batch((b) {
      b.insertAll(db.tierDefinitions, tiers, mode: InsertMode.insertOrReplace);
    });
  }

  /// All level curves ordered by level.
  Future<List<LevelCurve>> allCurves() =>
      (select(db.levelCurves)..orderBy([(c) => OrderingTerm.asc(c.level)]))
          .get();

  /// All tier definitions ordered by ordinal.
  Future<List<TierDefinition>> allTiers() =>
      (select(db.tierDefinitions)..orderBy([(t) => OrderingTerm.asc(t.ordinal)]))
          .get();

  /// Find matching level curve for given total XP.
  Future<LevelCurve> findLevelForXp(int totalXp) async {
    final row = await (select(db.levelCurves)
          ..where((c) => c.cumulativeXpRequired.isSmallerOrEqualValue(totalXp))
          ..orderBy([(c) => OrderingTerm.desc(c.level)])
          ..limit(1))
        .getSingleOrNull();

    if (row != null) return row;

    return (select(db.levelCurves)
          ..orderBy([(c) => OrderingTerm.asc(c.level)])
          ..limit(1))
        .getSingle();
  }

  /// Find matching tier definition for given total XP.
  Future<TierDefinition> findTierForXp(int totalXp) async {
    final row = await (select(db.tierDefinitions)
          ..where((t) => t.entryXp.isSmallerOrEqualValue(totalXp))
          ..orderBy([(t) => OrderingTerm.desc(t.ordinal)])
          ..limit(1))
        .getSingleOrNull();

    if (row != null) return row;

    return (select(db.tierDefinitions)
          ..orderBy([(t) => OrderingTerm.asc(t.ordinal)])
          ..limit(1))
        .getSingle();
  }

  /// Objectives for a given level.
  Future<List<LevelObjective>> objectivesForLevel(int level) =>
      (select(db.levelObjectives)..where((o) => o.level.equals(level))).get();
}
