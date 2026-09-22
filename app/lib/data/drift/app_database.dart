import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'aux_tables.dart';
import 'core_tables.dart';
import 'ledger_tables.dart';

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
    // XP Ledger (0002)
    XpLedger,
    XpAllocationLines,
    UserStreaks,
    StreakPauses,
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
