// ignore_for_file: public_member_api_docs
import 'package:drift/drift.dart';

/// Local Drift mirror of `notes` (migration 0004).
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get bodyText => text()();
  TextColumn get bodyMarkdown => text().nullable()();
  BoolColumn get pinned => boolean()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
  TextColumn get deletedReason => text().nullable()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local Drift mirror of `audios` (migration 0004).
class Audios extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get sessionId => text().nullable()();
  TextColumn get taskId => text().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get mime => text().nullable()();
  TextColumn get transcriptionText => text().nullable()();
  TextColumn get transcriptionStatus => text().nullable()();
  DateTimeColumn get capturedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
  TextColumn get deletedReason => text().nullable()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local Drift mirror of `achievements` (migration 0004).
class Achievements extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get kind => text()();
  IntColumn get level => integer().nullable()();
  DateTimeColumn get awardedAt => dateTime()();
  TextColumn get xpLedgerEventId => text().nullable()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local Drift mirror of `evidence` (migration 0004).
class Evidence extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get claimKind => text()();
  TextColumn get payload => text()();
  DateTimeColumn get capturedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
  TextColumn get deletedReason => text().nullable()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local Drift mirror of `ai_artifacts` (migration 0004).
class AiArtifacts extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get kind => text()();
  TextColumn get prompt => text().nullable()();
  TextColumn get response => text().nullable()();
  TextColumn get model => text().nullable()();
  IntColumn get tokensIn => integer().nullable()();
  IntColumn get tokensOut => integer().nullable()();
  TextColumn get relatedEntityId => text().nullable()();
  TextColumn get relatedEntityKind => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local Drift mirror of `files` (migration 0004).
class Files extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get storageKey => text()();
  TextColumn get mime => text().nullable()();
  IntColumn get sizeBytes => integer()();
  TextColumn get sha256 => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
  TextColumn get deletedReason => text().nullable()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local Drift mirror of `links` (migration 0004).
class Links extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get url => text()();
  TextColumn get title => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get faviconUrl => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
  TextColumn get deletedReason => text().nullable()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local Drift mirror of `attachment_links` (migration 0004).
class AttachmentLinks extends Table {
  TextColumn get id => text()();
  TextColumn get attachmentId => text()();
  TextColumn get attachmentKind => text()();
  TextColumn get entityId => text()();
  TextColumn get entityKind => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local Drift mirror of `skills` (migration 0004).
class Skills extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  IntColumn get xpTotal => integer()();
  IntColumn get level => integer()();
  TextColumn get icon => text().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
  TextColumn get deletedReason => text().nullable()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local Drift mirror of `tools` (migration 0004).
class Tools extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get toolType => text()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
  TextColumn get deletedReason => text().nullable()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local Drift mirror of `skill_tools` (migration 0004).
class SkillTools extends Table {
  TextColumn get skillId => text()();
  TextColumn get toolId => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {skillId, toolId};
}

/// Local Drift mirror of `task_tool_links` (migration 0004).
class TaskToolLinks extends Table {
  TextColumn get taskId => text()();
  TextColumn get toolId => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {taskId, toolId};
}