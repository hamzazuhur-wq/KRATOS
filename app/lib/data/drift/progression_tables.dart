// ignore_for_file: public_member_api_docs
// Wave 6: Local Drift mirror of progression tables (migration 0007).
// Supports offline-first level curve lookups, tier ladders, and objectives.

import 'package:drift/drift.dart';

/// Local Drift mirror of `level_curves` (migration 0007).
class LevelCurves extends Table {
  IntColumn get level => integer()();
  IntColumn get deltaXp => integer()();
  IntColumn get cumulativeXpRequired => integer()();

  @override
  Set<Column> get primaryKey => {level};
}

/// Local Drift mirror of `tier_definitions` (migration 0007).
class TierDefinitions extends Table {
  TextColumn get name => text()();
  IntColumn get entryXp => integer()();
  IntColumn get ordinal => integer()();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();

  @override
  Set<Column> get primaryKey => {name};
}

/// Local Drift mirror of `level_objectives` (migration 0007).
class LevelObjectives extends Table {
  TextColumn get id => text()();
  IntColumn get level => integer()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isMandatory => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column> get primaryKey => {id};
}
