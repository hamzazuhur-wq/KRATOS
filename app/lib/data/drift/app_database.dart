import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'aux_tables.dart';
import 'core_tables.dart';
import 'ledger_tables.dart';
import 'progression_tables.dart';
import '../../features/tasks/data/tasks_dao.dart';
import '../../features/tasks/data/junctions_dao.dart';
import '../../features/xp/data/xp_ledger_dao.dart';
import '../../features/xp/data/xp_analytics_dao.dart';
import '../../features/progression/data/progression_dao.dart';
import '../../features/streaks/data/streaks_dao.dart';
import '../../features/categories/data/categories_dao.dart';
import '../../features/skills/data/skills_dao.dart';
import '../../features/tools/data/tools_dao.dart';
import '../../features/sessions/data/sessions_dao.dart';
import '../../features/activities/data/activities_dao.dart';
import '../../features/projects/data/projects_dao.dart';

part 'app_database.g.dart';

/// KRATOS local offline-first database.
///
/// Mirrors the 30-table PostgreSQL schema from server/migrations/0001-0004.
/// Platform-aware: uses Native SQLite on Android/iOS/Desktop and Wasm/IndexedDB on Web.
@DriftDatabase(
  tables: [
    // Core (0001)
    Users,
    LifeAreas,
    Categories,
    CategoryActions,
    CategoryXpRuleVersions,
    Goals,
    Projects,
    Tasks,
    TaskGoalLinks,
    Activities,
    Sessions,
    // XP Ledger (0002 + Wave 5 + Wave 7)
    XpLedger,
    XpAllocationLines,
    UserStreaks,
    StreakPauses,
    StreakFreezeInventory,
    ProcessedIdempotencyKeys,
    // Sync (0003)
    SyncOutbox,
    SyncCursors,
    SyncTombstones,
    // Notes / AI / Skills / Attachments (0004)
    Notes,
    Audios,
    Achievements,
    Evidence,
    AiArtifacts,
    Files,
    Links,
    AttachmentLinks,
    Skills,
    Tools,
    SkillTools,
    TaskToolLinks,
    // Progression (0007 + Wave 6)
    LevelCurves,
    TierDefinitions,
    LevelObjectives,
  ],
  daos: [
    TasksDao,
    TaskGoalLinksDao,
    SkillToolsDao,
    TaskToolLinksDao,
    AttachmentLinksDao,
    XpLedgerDao,
    XpAnalyticsDao,
    ProgressionDao,
    StreaksDao,
    CategoriesDao,
    SkillsDao,
    ToolsDao,
    SessionsDao,
    ActivitiesDao,
    ProjectsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          // Single-version migration; future upgrades add columns/tables here.
        },
      );
}

QueryExecutor _openConnection() {
  // Uses drift_flutter: Native SQLite on Mobile/Desktop, WASM/IndexedDB on Web
  return driftDatabase(name: 'kratos_db');
}
