// ignore_for_file: public_member_api_docs
import 'package:drift/drift.dart';

/// Local Drift mirror of `notes` (migration 0004).
class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get bodyText => text()();
  TextColumn get bodyMarkdown => text()();
  BoolColumn get pinned => boolean()();
  DateTimeColumn get archivedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime()();
  TextColumn get deletedBy => text()();
  TextColumn get deletedReason => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Local Drift mirror of `audios` (migration 0004).
class Audios extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get sessionId => text()();
  TextColumn get taskId => text()();
  IntColumn get durationMs => integer()();
  TextColumn get mime => text()();
  TextColumn get transcriptionText => text()();
  TextColumn get transcriptionStatus => text()();
  DateTimeColumn get capturedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime()();
  TextColumn get deletedBy => text()();
  TextColumn get deletedReason => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Local Drift mirror of `achievements` (migration 0004).
class Achievements extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get kind => text()();
  IntColumn get level => integer()();
  DateTimeColumn get awardedAt => dateTime()();
  TextColumn get xpLedgerEventId => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Local Drift mirror of `evidence` (migration 0004).
class Evidence extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get claimKind => text()();
  TextColumn get payload => text()();
  DateTimeColumn get capturedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime()();
  TextColumn get deletedBy => text()();
  TextColumn get deletedReason => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Local Drift mirror of `ai_artifacts` (migration 0004).
class AiArtifacts extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get kind => text()();
  TextColumn get prompt => text()();
  TextColumn get response => text()();
  TextColumn get model => text()();
  IntColumn get tokensIn => integer()();
  IntColumn get tokensOut => integer()();
  TextColumn get relatedEntityId => text()();
  TextColumn get relatedEntityKind => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Local Drift mirror of `files` (migration 0004).
class Files extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get storageKey => text()();
  TextColumn get mime => text()();
  IntColumn get sizeBytes => integer()();
  TextColumn get sha256 => text()();
  DateTimeColumn get deletedAt => dateTime()();
  TextColumn get deletedBy => text()();
  TextColumn get deletedReason => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Local Drift mirror of `links` (migration 0004).
class Links extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get url => text()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get faviconUrl => text()();
  DateTimeColumn get deletedAt => dateTime()();
  TextColumn get deletedBy => text()();
  TextColumn get deletedReason => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
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
}

/// Local Drift mirror of `skills` (migration 0004).
class Skills extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  IntColumn get xpTotal => integer()();
  IntColumn get level => integer()();
  TextColumn get icon => text()();
  DateTimeColumn get archivedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime()();
  TextColumn get deletedBy => text()();
  TextColumn get deletedReason => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Local Drift mirror of `tools` (migration 0004).
class Tools extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  TextColumn get toolType => text()();
  DateTimeColumn get archivedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime()();
  TextColumn get deletedBy => text()();
  TextColumn get deletedReason => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
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