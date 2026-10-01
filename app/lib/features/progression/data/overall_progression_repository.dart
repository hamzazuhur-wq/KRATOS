import '../../../data/drift/app_database.dart';
import '../../levels/data/levels_dashboard_repository.dart';
import '../domain/global_progression.dart';
import '../domain/progression_models.dart';

/// Read-only aggregate progression snapshot for identity/status surfaces.
///
/// XP remains owned by Life Areas. This adapter only sums the already-computed
/// Life Area progression rows and feeds that total into the existing engine so
/// the Main Bar and Levels surfaces share one presentation source.
class OverallProgressionSnapshot {
  final int totalXp;
  final ProgressionInfo progression;
  final GlobalProgressionState global;

  const OverallProgressionSnapshot({
    required this.totalXp,
    required this.progression,
    required this.global,
  });

  factory OverallProgressionSnapshot.empty() {
    final global = GlobalProgressionDefinitions.resolve(0);
    return OverallProgressionSnapshot(
      totalXp: 0,
      progression: global.toProgressionInfo(),
      global: global,
    );
  }
}

class OverallProgressionRepository {
  final AppDatabase database;
  late final LevelsDashboardRepository _levelsRepository =
      LevelsDashboardRepository(database);

  OverallProgressionRepository(this.database);

  Future<OverallProgressionSnapshot> getSnapshot(String ownerId) async {
    final entries = await _levelsRepository.getProgressions(ownerId);
    final totalXp = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.progression.totalXp,
    );

    final global = GlobalProgressionDefinitions.resolve(totalXp);

    return OverallProgressionSnapshot(
      totalXp: totalXp,
      progression: global.toProgressionInfo(),
      global: global,
    );
  }

  Stream<OverallProgressionSnapshot> watch(String ownerId) async* {
    final triggerStream = database
        .customSelect(
          'SELECT 1',
          readsFrom: {
            database.lifeAreas,
            database.xpLedger,
            database.xpAllocationLines,
            database.levelCurves,
            database.tierDefinitions,
          },
        )
        .watch();

    yield await getSnapshot(ownerId);
    yield* triggerStream.asyncMap((_) => getSnapshot(ownerId));
  }
}
