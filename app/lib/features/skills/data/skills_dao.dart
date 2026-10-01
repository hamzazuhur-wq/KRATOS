// ignore_for_file: public_member_api_docs
// Wave 8: Drift DAO for Skills & SkillTools.
// Invariant #4: Skills are pure attribution; not XP owners.
// Invariant #10: Historical XP auditable after skill soft-delete.

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/drift/aux_tables.dart';

part 'skills_dao.g.dart';

@DriftAccessor(
  tables: [Skills, SkillGroups, SkillLifeAreaLinks, SkillTools, Tools],
)
class SkillsDao extends DatabaseAccessor<AppDatabase> with _$SkillsDaoMixin {
  SkillsDao(super.db);

  Future<List<Skill>> allSkills(String ownerId) => listSkills(ownerId);

  Future<List<Skill>> listSkills(
    String ownerId, {
    String? query,
    String? groupId,
    int? masteryLevel,
    String? lifeAreaId,
    bool includeArchived = false,
  }) {
    final skillQuery =
        select(db.skills).join([
            if (lifeAreaId != null)
              innerJoin(
                db.skillLifeAreaLinks,
                db.skillLifeAreaLinks.skillId.equalsExp(db.skills.id),
              ),
          ])
          ..where(
            db.skills.ownerId.equals(ownerId) &
                db.skills.deletedAt.isNull() &
                (includeArchived
                    ? const Constant(true)
                    : db.skills.archivedAt.isNull()) &
                (query == null || query.trim().isEmpty
                    ? const Constant(true)
                    : db.skills.name.like('%${query.trim()}%') |
                          db.skills.description.like('%${query.trim()}%')) &
                (groupId == null
                    ? const Constant(true)
                    : db.skills.groupId.equals(groupId)) &
                (masteryLevel == null
                    ? const Constant(true)
                    : db.skills.masteryLevel.equals(masteryLevel)) &
                (lifeAreaId == null
                    ? const Constant(true)
                    : db.skillLifeAreaLinks.lifeAreaId.equals(lifeAreaId)),
          )
          ..orderBy([OrderingTerm.desc(db.skills.updatedAt)]);
    return skillQuery.map((row) => row.readTable(db.skills)).get();
  }

  Future<List<Skill>> skillsForLifeArea(String ownerId, String lifeAreaId) =>
      listSkills(ownerId, lifeAreaId: lifeAreaId);

  Future<Skill?> findById(String id) =>
      (select(db.skills)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<void> upsert(SkillsCompanion companion) =>
      into(db.skills).insertOnConflictUpdate(companion);

  Future<List<SkillGroup>> listGroups(
    String ownerId, {
    bool includeArchived = false,
  }) =>
      (select(db.skillGroups)
            ..where(
              (g) =>
                  g.ownerId.equals(ownerId) &
                  g.deletedAt.isNull() &
                  (includeArchived
                      ? const Constant(true)
                      : g.archivedAt.isNull()),
            )
            ..orderBy([(g) => OrderingTerm.asc(g.name)]))
          .get();

  Future<void> upsertGroup(SkillGroupsCompanion companion) =>
      into(db.skillGroups).insertOnConflictUpdate(companion);

  Future<void> archiveGroup(String groupId, String versionHlc) =>
      (update(db.skillGroups)..where((g) => g.id.equals(groupId))).write(
        SkillGroupsCompanion(
          archivedAt: Value(DateTime.now().toUtc()),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> restoreGroup(String groupId, String versionHlc) =>
      (update(db.skillGroups)..where((g) => g.id.equals(groupId))).write(
        SkillGroupsCompanion(
          archivedAt: const Value(null),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> attachToLifeArea({
    required String ownerId,
    required String skillId,
    required String lifeAreaId,
    required String versionHlc,
  }) => into(db.skillLifeAreaLinks).insertOnConflictUpdate(
    SkillLifeAreaLinksCompanion.insert(
      ownerId: ownerId,
      skillId: skillId,
      lifeAreaId: lifeAreaId,
      versionHlc: versionHlc,
      createdAt: DateTime.now().toUtc(),
    ),
  );

  Future<int> removeFromLifeArea(String skillId, String lifeAreaId) =>
      (delete(db.skillLifeAreaLinks)..where(
            (link) =>
                link.skillId.equals(skillId) &
                link.lifeAreaId.equals(lifeAreaId),
          ))
          .go();

  Future<List<SkillLifeAreaLink>> lifeAreasForSkill(String skillId) => (select(
    db.skillLifeAreaLinks,
  )..where((link) => link.skillId.equals(skillId))).get();

  Future<void> softDelete(
    String skillId,
    String deletedBy,
    String versionHlc,
  ) => (update(db.skills)..where((s) => s.id.equals(skillId))).write(
    SkillsCompanion(
      deletedAt: Value(DateTime.now().toUtc()),
      deletedBy: Value(deletedBy),
      versionHlc: Value(versionHlc),
      updatedAt: Value(DateTime.now().toUtc()),
    ),
  );

  /// Fetch tools linked to a skill.
  Future<List<Tool>> toolsForSkill(String skillId) {
    final query = select(db.tools).join([
      innerJoin(db.skillTools, db.skillTools.toolId.equalsExp(db.tools.id)),
    ])..where(db.skillTools.skillId.equals(skillId));

    return query.map((row) => row.readTable(db.tools)).get();
  }
}
