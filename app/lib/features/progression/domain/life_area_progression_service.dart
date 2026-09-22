// Wave 6: LifeAreaProgressionService.
// Invariant #3: Progression belongs strictly to LifeArea (no global level).
// Aggregates XP from xp_allocation_lines and computes current Level, Tier, and Promotion status.

import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/ids.dart';
import 'progression_calculator.dart';
import 'progression_models.dart';

class LifeAreaProgressionService {
  final AppDatabase _db;

  LifeAreaProgressionService(this._db);

  /// Computes the real-time progression for a LifeArea.
  Future<ProgressionInfo> getProgressionForLifeArea({
    required Id lifeAreaId,
    Set<Id> completedObjectiveIds = const {},
    bool testOutBypass = false,
  }) async {
    // 1. Sum total allocated points for this lifeAreaId
    final query = _db.selectOnly(_db.xpAllocationLines)
      ..addColumns([_db.xpAllocationLines.allocatedPoints.sum()])
      ..where(_db.xpAllocationLines.lifeAreaId.equals(lifeAreaId.value));

    final row = await query.getSingle();
    final totalXp =
        row.read(_db.xpAllocationLines.allocatedPoints.sum()) ?? 0;

    // 2. Fetch any level objectives for evaluation
    final levelCurve = await _findCurrentLevel(totalXp);
    final rawObjectives = await (_db.select(_db.levelObjectives)
          ..where((o) => o.level.equals(levelCurve.level)))
        .get();

    final objectives = rawObjectives
        .map((o) => LevelObjectiveSnapshot(
              id: Id(o.id),
              level: o.level,
              title: o.title,
              description: o.description,
              isMandatory: o.isMandatory,
            ))
        .toList();

    // 3. Compute progression state
    return ProgressionCalculator.calculate(
      lifeAreaId: lifeAreaId,
      totalXp: totalXp,
      levelObjectives: objectives,
      completedObjectiveIds: completedObjectiveIds,
      testOutBypass: testOutBypass,
    );
  }

  Future<LevelCurveSnapshot> _findCurrentLevel(int totalXp) async {
    final curves = ProgressionCalculator.defaultCurves;
    var matched = curves.first;
    for (final c in curves) {
      if (c.cumulativeXpRequired <= totalXp) {
        matched = c;
      } else {
        break;
      }
    }
    return matched;
  }
}
