// ignore_for_file: public_member_api_docs
// Wave 8: Drift DAO for Skills & SkillTools.
// Invariant #4: Skills are pure attribution; not XP owners.
// Invariant #10: Historical XP auditable after skill soft-delete.

import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';
import '../../../data/drift/aux_tables.dart';

part 'skills_dao.g.dart';

@DriftAccessor(tables: [Skills, SkillTools, Tools])
class SkillsDao extends DatabaseAccessor<AppDatabase> with _$SkillsDaoMixin {
  SkillsDao(super.db);

  Future<List<Skill>> allSkills(String ownerId) => (select(db.skills)
        ..where((s) => s.ownerId.equals(ownerId) & s.deletedAt.isNull())
        ..orderBy([(s) => OrderingTerm.desc(s.xpTotal)]))
      .get();

  Future<Skill?> findById(String id) =>
      (select(db.skills)..where((s) => s.id.equals(id))).getSingleOrNull();

  Future<void> upsert(SkillsCompanion companion) =>
      into(db.skills).insertOnConflictUpdate(companion);

  Future<void> softDelete(String skillId, String deletedBy, String versionHlc) =>
      (update(db.skills)..where((s) => s.id.equals(skillId))).write(
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
