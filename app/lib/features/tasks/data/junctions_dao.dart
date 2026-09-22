// ignore_for_file: public_member_api_docs
// Wave 4: TaskGoalLinks, SkillTools, TaskToolLinks, AttachmentLinks DAOs.

import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';
import '../../../data/drift/core_tables.dart';
import '../../../data/drift/aux_tables.dart';

part 'junctions_dao.g.dart';

/// DAO for task ↔ goal junction table.
@DriftAccessor(tables: [TaskGoalLinks])
class TaskGoalLinksDao extends DatabaseAccessor<AppDatabase>
    with _$TaskGoalLinksDaoMixin {
  TaskGoalLinksDao(super.db);

  /// All goals linked to a given task.
  Future<List<TaskGoalLink>> forTask(String taskId) =>
      (select(db.taskGoalLinks)
            ..where((l) => l.taskId.equals(taskId))
            ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
          .get();

  /// All tasks linked to a given goal.
  Future<List<TaskGoalLink>> forGoal(String goalId) =>
      (select(db.taskGoalLinks)
            ..where((l) => l.goalId.equals(goalId)))
          .get();

  /// Insert or replace a link. PK is (taskId, goalId) — enforces uniqueness.
  Future<void> upsert(TaskGoalLinksCompanion companion) =>
      into(db.taskGoalLinks).insertOnConflictUpdate(companion);

  /// Remove a link between a task and goal.
  Future<int> remove(String taskId, String goalId) =>
      (delete(db.taskGoalLinks)
            ..where((l) => l.taskId.equals(taskId) & l.goalId.equals(goalId)))
          .go();
}

/// DAO for skill ↔ tool junction table.
@DriftAccessor(tables: [SkillTools])
class SkillToolsDao extends DatabaseAccessor<AppDatabase>
    with _$SkillToolsDaoMixin {
  SkillToolsDao(super.db);

  Future<List<SkillTool>> forSkill(String skillId) =>
      (select(db.skillTools)..where((s) => s.skillId.equals(skillId))).get();

  Future<List<SkillTool>> forTool(String toolId) =>
      (select(db.skillTools)..where((s) => s.toolId.equals(toolId))).get();

  Future<void> upsert(SkillToolsCompanion companion) =>
      into(db.skillTools).insertOnConflictUpdate(companion);

  Future<int> remove(String skillId, String toolId) =>
      (delete(db.skillTools)
            ..where((s) => s.skillId.equals(skillId) & s.toolId.equals(toolId)))
          .go();
}

/// DAO for task ↔ tool junction table.
@DriftAccessor(tables: [TaskToolLinks])
class TaskToolLinksDao extends DatabaseAccessor<AppDatabase>
    with _$TaskToolLinksDaoMixin {
  TaskToolLinksDao(super.db);

  Future<List<TaskToolLink>> forTask(String taskId) =>
      (select(db.taskToolLinks)..where((t) => t.taskId.equals(taskId))).get();

  Future<void> upsert(TaskToolLinksCompanion companion) =>
      into(db.taskToolLinks).insertOnConflictUpdate(companion);

  Future<int> remove(String taskId, String toolId) =>
      (delete(db.taskToolLinks)
            ..where((t) => t.taskId.equals(taskId) & t.toolId.equals(toolId)))
          .go();
}

/// DAO for attachment_links — polymorphic entity attachment.
@DriftAccessor(tables: [AttachmentLinks])
class AttachmentLinksDao extends DatabaseAccessor<AppDatabase>
    with _$AttachmentLinksDaoMixin {
  AttachmentLinksDao(super.db);

  /// All attachments for a specific entity.
  Future<List<AttachmentLink>> forEntity(
          String entityId, String entityKind) =>
      (select(db.attachmentLinks)
            ..where((a) =>
                a.entityId.equals(entityId) & a.entityKind.equals(entityKind)))
          .get();

  Future<void> upsert(AttachmentLinksCompanion companion) =>
      into(db.attachmentLinks).insertOnConflictUpdate(companion);

  Future<int> remove(String attachmentLinkId) =>
      (delete(db.attachmentLinks)
            ..where((a) => a.id.equals(attachmentLinkId)))
          .go();
}
