// ignore_for_file: public_member_api_docs
// Wave 21: Collaborative Goals Drift Tables & DAO.

import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';

part 'collaboration_dao.g.dart';

@DataClassName('SharedGoalData')
class SharedGoals extends Table {
  TextColumn get id => text()();
  TextColumn get goalId => text()();
  TextColumn get ownerId => text()();
  TextColumn get partnerId => text()();
  TextColumn get role => text()();
  BoolColumn get canComment => boolean().withDefault(const Constant(true))();
  BoolColumn get canVerify => boolean().withDefault(const Constant(false))();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('GoalCommentData')
class GoalComments extends Table {
  TextColumn get id => text()();
  TextColumn get goalId => text()();
  TextColumn get authorId => text()();
  TextColumn get bodyText => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftAccessor(tables: [SharedGoals, GoalComments])
class CollaborationDao extends DatabaseAccessor<AppDatabase>
    with _$CollaborationDaoMixin {
  CollaborationDao(super.db);

  /// Share a goal with a partner.
  Future<void> shareGoal(SharedGoalsCompanion companion) =>
      into(db.sharedGoals).insertOnConflictUpdate(companion);

  /// Get all partners for a goal.
  Future<List<SharedGoalData>> getPartnersForGoal(String goalId) =>
      (select(db.sharedGoals)..where((t) => t.goalId.equals(goalId))).get();

  /// Post an accountability comment.
  Future<void> addComment(GoalCommentsCompanion companion) =>
      into(db.goalComments).insert(companion);

  /// Fetch all comments for a goal ordered chronologically.
  Future<List<GoalCommentData>> getCommentsForGoal(String goalId) =>
      (select(db.goalComments)
            ..where((t) => t.goalId.equals(goalId))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
          .get();
}
