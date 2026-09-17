// ignore_for_file: public_member_api_docs

import 'package:drift/drift.dart';

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get deviceId => text()();
  TextColumn get displayName => text()();
  TextColumn get timezone => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class LifeAreas extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  TextColumn get color => text()();
  TextColumn get icon => text()();
  IntColumn get sortOrder => integer()();
  DateTimeColumn get archivedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime()();
  TextColumn get deletedBy => text()();
  TextColumn get deletedReason => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text()();
  IntColumn get baseXp => integer()();
  BoolColumn get isImmutable => boolean()();
  DateTimeColumn get archivedAt => dateTime()();
  IntColumn get sortOrder => integer()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class CategoryActions extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  TextColumn get actionName => text()();
  RealColumn get modifierPercent => real()();
  DateTimeColumn get effectiveFrom => dateTime()();
  DateTimeColumn get effectiveUntil => dateTime()();
  IntColumn get version => integer()();
}

class CategoryXpRuleVersions extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId => text()();
  TextColumn get snapshot => text()();
  DateTimeColumn get effectiveFrom => dateTime()();
  DateTimeColumn get effectiveUntil => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
}

class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get parentId => text()();
  TextColumn get rootId => text()();
  TextColumn get path => text()();
  IntColumn get depth => integer()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get lifeAreaId => text()();
  TextColumn get status => text()();
  IntColumn get xpTarget => integer()();
  RealColumn get progress => real()();
  TextColumn get progressHlc => text()();
  DateTimeColumn get dueDate => dateTime()();
  DateTimeColumn get completedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime()();
  TextColumn get deletedBy => text()();
  TextColumn get deletedReason => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get goalId => text()();
  TextColumn get lifeAreaId => text()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get status => text()();
  DateTimeColumn get dueDate => dateTime()();
  TextColumn get memberIds => text()();
  DateTimeColumn get deletedAt => dateTime()();
  TextColumn get deletedBy => text()();
  TextColumn get deletedReason => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get projectId => text()();
  TextColumn get primaryGoalId => text()();
  TextColumn get title => text()();
  TextColumn get notes => text()();
  DateTimeColumn get dueDate => dateTime()();
  IntColumn get priority => integer()();
  TextColumn get status => text()();
  IntColumn get sortOrder => integer()();
  IntColumn get xpReward => integer()();
  TextColumn get recurringRule => text()();
  DateTimeColumn get completedAt => dateTime()();
  TextColumn get completedHlc => text()();
  DateTimeColumn get deletedAt => dateTime()();
  TextColumn get deletedBy => text()();
  TextColumn get deletedReason => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
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
  TextColumn get lifeAreaId => text()();
  TextColumn get name => text()();
  TextColumn get description => text()();
  TextColumn get xpRule => text()();
  DateTimeColumn get archivedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime()();
  TextColumn get deletedBy => text()();
  TextColumn get deletedReason => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get taskId => text()();
  TextColumn get activityId => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
  IntColumn get durationMs => integer()();
  TextColumn get note => text()();
  TextColumn get lifeAreaId => text()();
  DateTimeColumn get deletedAt => dateTime()();
  TextColumn get deletedBy => text()();
  TextColumn get deletedReason => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}