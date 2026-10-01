import 'package:drift/drift.dart';

/// Local Drift mirror of `idea_spaces` (migration 0020).
@DataClassName('DriftIdeaSpace')
class IdeaSpaces extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
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

/// Local Drift mirror of `ideas` (migration 0020).
@DataClassName('DriftIdea')
class Ideas extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get title => text()();
  TextColumn get contentJson => text().withDefault(const Constant('[]'))();
  TextColumn get excerpt => text().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
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

/// Local Drift mirror of `idea_space_links` (migration 0020).
@DataClassName('DriftIdeaSpaceLink')
class IdeaSpaceLinks extends Table {
  TextColumn get id => text()();
  TextColumn get ideaId => text()();
  TextColumn get ideaSpaceId => text()();
  TextColumn get ownerId => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local Drift mirror of `idea_blocks` (migration 0020).
@DataClassName('DriftIdeaBlock')
class IdeaBlocks extends Table {
  TextColumn get id => text()();
  TextColumn get ideaId => text()();
  TextColumn get ownerId => text()();
  TextColumn get blockType => text()();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get payloadJson => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local Drift mirror of `idea_links` (migration 0020).
@DataClassName('DriftIdeaLink')
class IdeaLinks extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get sourceIdeaId => text()();
  TextColumn get sourceBlockId => text().nullable()();
  TextColumn get targetIdeaId => text()();
  TextColumn get targetBlockId => text().nullable()();
  TextColumn get displayText => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local Drift mirror of `tags` (migration 0020).
@DataClassName('DriftTag')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local Drift mirror of `idea_tags` (migration 0020).
@DataClassName('DriftIdeaTag')
class IdeaTags extends Table {
  TextColumn get id => text()();
  TextColumn get ideaId => text()();
  TextColumn get tagId => text()();
  TextColumn get ownerId => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local Drift mirror of `idea_attachments` (migration 0020).
@DataClassName('DriftIdeaAttachment')
class IdeaAttachments extends Table {
  TextColumn get id => text()();
  TextColumn get ideaId => text()();
  TextColumn get blockId => text().nullable()();
  TextColumn get ownerId => text()();
  TextColumn get storagePath => text()();
  TextColumn get fileName => text()();
  TextColumn get mimeType => text()();
  IntColumn get fileSize => integer().withDefault(const Constant(0))();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
