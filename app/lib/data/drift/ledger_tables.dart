// ignore_for_file: public_member_api_docs
import 'package:drift/drift.dart';

/// XP ledger — append-only mirror of server xp_ledger (migration 0002).
class XpLedger extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get idempotencyKey => text()();
  TextColumn get sourceType => text()();
  TextColumn get sourceId => text()();
  TextColumn get action => text()();
  IntColumn get points => integer()();
  IntColumn get basePoints => integer().nullable()();
  IntColumn get bonusPoints => integer().withDefault(const Constant(0))();
  IntColumn get latePenalty => integer().withDefault(const Constant(0))();
  IntColumn get streakBonus => integer().withDefault(const Constant(0))();
  TextColumn get categoryRuleVersionId => text().nullable()();
  TextColumn get reversalEventId => text().nullable()();
  TextColumn get versionHlc => text()();
  TextColumn get deviceId => text()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Allocation lines mirror of server xp_allocation_lines (migration 0002).
class XpAllocationLines extends Table {
  TextColumn get id => text()();
  TextColumn get ledgerId => text()();
  TextColumn get lifeAreaId => text()();
  IntColumn get allocatedPoints => integer()();
  RealColumn get percentage => real()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Streak projection mirror of server user_streaks (migration 0002).
class UserStreaks extends Table {
  TextColumn get userId => text()();
  TextColumn get lifeAreaId => text()();
  IntColumn get currentStreak => integer().withDefault(const Constant(0))();
  IntColumn get longestStreak => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastActiveDate => dateTime().nullable()();
  TextColumn get lastActiveHlc => text().nullable()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column> get primaryKey => {userId, lifeAreaId};
}

/// Streak pauses mirror of server streak_pauses (migration 0002).
class StreakPauses extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get lifeAreaId => text().nullable()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column> get primaryKey => {id};
}

/// Transactional outbox mirror of server sync_outbox (migration 0003).
class SyncOutbox extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get userId => text()();
  TextColumn get op => text()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  TextColumn get payloadJson => text()();
  TextColumn get hlc => text()();
  TextColumn get deviceId => text()();
  TextColumn get idempotencyKey => text().nullable()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastErrorClass => text().nullable()();
  TextColumn get lastErrorCode => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
}

/// Sync cursor watermark mirror of server sync_cursors (migration 0003).
class SyncCursors extends Table {
  TextColumn get userId => text()();
  TextColumn get peerId => text()();
  TextColumn get entityKind => text()();
  TextColumn get lastAppliedHlc => text()();
  DateTimeColumn get updatedAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column> get primaryKey => {userId, peerId, entityKind};
}

/// Tombstone mirror of server sync_tombstones (migration 0003).
class SyncTombstones extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  TextColumn get entity => text()();
  TextColumn get entityId => text()();
  DateTimeColumn get deletedAt => dateTime()();
  TextColumn get deletedHlc => text()();
  TextColumn get deletedBy => text().nullable()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().clientDefault(() => DateTime.now().toUtc())();

  @override
  Set<Column> get primaryKey => {id};
}