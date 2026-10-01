// ignore_for_file: public_member_api_docs
// Wave 4: TaskGoalLinks, SkillTools, TaskToolLinks, AttachmentLinks DAOs.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/drift/core_tables.dart';
import '../../../data/drift/aux_tables.dart';
import '../../../domain/ids.dart';

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
      (select(db.taskGoalLinks)..where((l) => l.goalId.equals(goalId))).get();

  /// Insert or replace a link. PK is (taskId, goalId) — enforces uniqueness.
  Future<void> upsert(TaskGoalLinksCompanion companion) =>
      into(db.taskGoalLinks).insertOnConflictUpdate(companion);

  /// Remove a link between a task and goal.
  Future<int> remove(String taskId, String goalId) => (delete(
    db.taskGoalLinks,
  )..where((l) => l.taskId.equals(taskId) & l.goalId.equals(goalId))).go();
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

  Future<int> remove(String skillId, String toolId) => (delete(
    db.skillTools,
  )..where((s) => s.skillId.equals(skillId) & s.toolId.equals(toolId))).go();
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

  Future<int> remove(String taskId, String toolId) => (delete(
    db.taskToolLinks,
  )..where((t) => t.taskId.equals(taskId) & t.toolId.equals(toolId))).go();
}

/// DAO for attachment_links — polymorphic entity attachment.
@DriftAccessor(tables: [AttachmentLinks])
class AttachmentLinksDao extends DatabaseAccessor<AppDatabase>
    with _$AttachmentLinksDaoMixin {
  AttachmentLinksDao(super.db);

  /// All attachments for a specific entity.
  Future<List<AttachmentLink>> forEntity(String entityId, String entityKind) =>
      (select(db.attachmentLinks)..where(
            (a) =>
                a.entityId.equals(entityId) & a.entityKind.equals(entityKind),
          ))
          .get();

  /// All entities linked to a given attachment, used by Skill detail to
  /// aggregate real Goals/Projects/Tasks/Activities/Sessions usage.
  Future<List<AttachmentLink>> forAttachment(
    String attachmentId,
    String attachmentKind,
  ) =>
      (select(db.attachmentLinks)..where(
            (a) =>
                a.attachmentId.equals(attachmentId) &
                a.attachmentKind.equals(attachmentKind),
          ))
          .get();

  Future<void> upsert(AttachmentLinksCompanion companion) =>
      into(db.attachmentLinks).insertOnConflictUpdate(companion);

  Future<int> remove(String attachmentLinkId) => (delete(
    db.attachmentLinks,
  )..where((a) => a.id.equals(attachmentLinkId))).go();

  /// Persist a Skill edge and its offline mutation as one application-level
  /// operation. Skill edges use the established attachment_links contract.
  Future<void> upsertSkillLink({
    required String ownerId,
    required String entityId,
    required String entityKind,
    required String skillId,
    required String versionHlc,
  }) async {
    final linkId = Id.uuidV7().value;
    await upsert(
      AttachmentLinksCompanion.insert(
        id: linkId,
        attachmentId: skillId,
        attachmentKind: 'skill',
        entityId: entityId,
        entityKind: entityKind,
        versionHlc: versionHlc,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    await attachedDatabase
        .into(attachedDatabase.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            userId: ownerId,
            op: 'upsert',
            entity: 'attachment_links',
            entityId: linkId,
            payloadJson: jsonEncode({
              'id': linkId,
              'attachment_id': skillId,
              'attachment_kind': 'skill',
              'entity_id': entityId,
              'entity_kind': entityKind,
            }),
            hlc: versionHlc,
            deviceId: 'local_device',
          ),
        );
  }

  Future<void> removeSkillLinksForEntity({
    required String ownerId,
    required String entityId,
    required String entityKind,
    required String versionHlc,
  }) async {
    final links = await forEntity(entityId, entityKind);
    for (final link in links.where((item) => item.attachmentKind == 'skill')) {
      await remove(link.id);
      await attachedDatabase
          .into(attachedDatabase.syncOutbox)
          .insert(
            SyncOutboxCompanion.insert(
              userId: ownerId,
              op: 'delete',
              entity: 'attachment_links',
              entityId: link.id,
              payloadJson: jsonEncode({
                'id': link.id,
                'attachment_id': link.attachmentId,
                'attachment_kind': link.attachmentKind,
                'entity_id': link.entityId,
                'entity_kind': link.entityKind,
              }),
              hlc: versionHlc,
              deviceId: 'local_device',
            ),
          );
    }
  }
}
