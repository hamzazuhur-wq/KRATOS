// ignore_for_file: public_member_api_docs

import 'package:drift/drift.dart';

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get deviceId => text()();
  TextColumn get displayName => text().nullable()();
  TextColumn get timezone => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class LifeAreas extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get color => text().nullable()();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder => integer()();
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

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text()();
  IntColumn get baseXp => integer()();
  BoolColumn get isImmutable => boolean()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  IntColumn get sortOrder => integer()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class CategoryActions extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  TextColumn get actionName => text()();
  RealColumn get modifierPercent => real()();
  DateTimeColumn get effectiveFrom => dateTime()();
  DateTimeColumn get effectiveUntil => dateTime().nullable()();
  IntColumn get version => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class CategoryXpRuleVersions extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  TextColumn get snapshot => text()();
  DateTimeColumn get effectiveFrom => dateTime()();
  DateTimeColumn get effectiveUntil => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get parentId => text().nullable()();
  TextColumn get rootId => text()();
  TextColumn get path => text()();
  IntColumn get depth => integer()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get lifeAreaId => text().nullable()();
  TextColumn get status => text()();
  IntColumn get xpTarget => integer().nullable()();
  RealColumn get progress => real()();
  TextColumn get progressHlc => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
  TextColumn get deletedReason => text().nullable()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get goalId => text().nullable()();
  TextColumn get lifeAreaId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  TextColumn get memberIds => text()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
  TextColumn get deletedReason => text().nullable()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get projectId => text().nullable()();
  TextColumn get primaryGoalId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();
  IntColumn get priority => integer()();
  TextColumn get status => text()();
  IntColumn get sortOrder => integer()();
  IntColumn get xpReward => integer().nullable()();
  TextColumn get recurringRule => text().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();
  TextColumn get completedHlc => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
  TextColumn get deletedReason => text().nullable()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class TaskGoalLinks extends Table {
  TextColumn get taskId => text()();
  TextColumn get goalId => text()();
  TextColumn get role => text()();
  IntColumn get sortOrder => integer()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {taskId, goalId};
}

class Activities extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get lifeAreaId => text().nullable()();
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  TextColumn get xpRule => text().nullable()();
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

class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get taskId => text().nullable()();
  TextColumn get activityId => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get lifeAreaId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
  TextColumn get deletedReason => text().nullable()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}