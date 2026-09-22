// ignore_for_file: public_member_api_docs
// Wave 9: Drift DAO for Activities — named recurring activity templates.
// Activities are reusable labels for sessions (e.g. "Morning jog", "Read book").
// They carry an xpRule JSON blob describing per-minute or flat XP awards.

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/drift/core_tables.dart';

part 'activities_dao.g.dart';

@DriftAccessor(tables: [Activities])
class ActivitiesDao extends DatabaseAccessor<AppDatabase>
    with _$ActivitiesDaoMixin {
  ActivitiesDao(super.db);

  /// All active activities for owner.
  Future<List<Activity>> allActivities(String ownerId) =>
      (select(db.activities)
            ..where(
                (a) => a.ownerId.equals(ownerId) & a.deletedAt.isNull() & a.archivedAt.isNull())
            ..orderBy([(a) => OrderingTerm.asc(a.name)]))
          .get();

  /// Activities for a life area.
  Future<List<Activity>> activitiesForLifeArea(String lifeAreaId) =>
      (select(db.activities)
            ..where((a) =>
                a.lifeAreaId.equals(lifeAreaId) &
                a.deletedAt.isNull() &
                a.archivedAt.isNull())
            ..orderBy([(a) => OrderingTerm.asc(a.name)]))
          .get();

  Future<Activity?> findById(String id) =>
      (select(db.activities)..where((a) => a.id.equals(id))).getSingleOrNull();

  Future<void> upsert(ActivitiesCompanion companion) =>
      into(db.activities).insertOnConflictUpdate(companion);

  Future<void> archive(String activityId, String versionHlc) =>
      (update(db.activities)..where((a) => a.id.equals(activityId))).write(
        ActivitiesCompanion(
          archivedAt: Value(DateTime.now().toUtc()),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> softDelete(
          String activityId, String deletedBy, String versionHlc) =>
      (update(db.activities)..where((a) => a.id.equals(activityId))).write(
        ActivitiesCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          deletedBy: Value(deletedBy),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
}
