// Repository interfaces for Wave 4 junction tables.
// Pure Dart — no Drift, no Supabase.

import '../entities/task.dart';
import '../hlc.dart';
import '../ids.dart';

/// CRUD for Tasks — stub DAO (full UX in Wave 9).
abstract class TaskRepository {
  Future<Task?> findById(Id taskId);
  Future<List<Task>> fetchAll(Id ownerId);
  Future<void> save(Task task);
  Future<void> delete(Id taskId);
}

/// Junction: Task ↔ Goal links with roles.
abstract class TaskGoalLinkRepository {
  /// Fetch all goals linked to a task.
  Future<List<TaskGoalLink>> fetchForTask(Id taskId);

  /// Fetch all tasks linked to a goal.
  Future<List<TaskGoalLink>> fetchForGoal(Id goalId);

  /// Add a link. Enforces UNIQUE (taskId, goalId) per role.
  Future<void> link({
    required Id taskId,
    required Id goalId,
    required TaskGoalRole role,
    required int sortOrder,
    required Hlc clock,
  });

  /// Remove a specific link.
  Future<void> unlink({required Id taskId, required Id goalId});
}

/// Junction: Skill ↔ Tool links.
abstract class SkillToolLinkRepository {
  Future<List<SkillToolLink>> fetchForSkill(Id skillId);
  Future<List<SkillToolLink>> fetchForTool(Id toolId);

  Future<void> link({
    required Id skillId,
    required Id toolId,
    required Hlc clock,
  });

  Future<void> unlink({required Id skillId, required Id toolId});
}

/// Polymorphic Attachment ↔ Entity links.
abstract class AttachmentLinkRepository {
  /// Fetch all attachment links for a given entity.
  Future<List<AttachmentLink>> fetchForEntity({
    required Id entityId,
    required String entityKind,
  });

  /// Add an attachment link (file or url) to an entity.
  Future<void> attach({
    required Id attachmentId,
    required String attachmentKind,
    required Id entityId,
    required String entityKind,
    required Hlc clock,
  });

  /// Remove an attachment link.
  Future<void> detach(Id attachmentLinkId);
}
