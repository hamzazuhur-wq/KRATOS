// Domain entity for Task — Wave 4
// Pure Dart, no Flutter / Drift / Supabase imports.

import '../ids.dart';
import '../hlc.dart';
import '../errors.dart';

/// Status values for a Task.
enum TaskStatus { pending, inProgress, completed, cancelled }

/// Role of a task's relationship to a goal.
enum TaskGoalRole {
  contributesTo,
  blocks,
  inspiredBy,
  tracks,
}

extension TaskGoalRoleJson on TaskGoalRole {
  String toJson() => switch (this) {
        TaskGoalRole.contributesTo => 'contributes_to',
        TaskGoalRole.blocks => 'blocks',
        TaskGoalRole.inspiredBy => 'inspired_by',
        TaskGoalRole.tracks => 'tracks',
      };

  static TaskGoalRole fromJson(String value) => switch (value) {
        'contributes_to' => TaskGoalRole.contributesTo,
        'blocks' => TaskGoalRole.blocks,
        'inspired_by' => TaskGoalRole.inspiredBy,
        'tracks' => TaskGoalRole.tracks,
        _ => throw ValidationError('Unknown TaskGoalRole: $value'),
      };
}

/// Immutable domain entity for a Task.
class Task {
  final Id id;
  final Id ownerId;
  final String title;
  final TaskStatus status;
  final int priority;
  final int sortOrder;
  final Id? projectId;
  final Id? primaryGoalId;
  final String? notes;
  final DateTime? dueDate;
  final int? xpReward;
  final String? recurringRule;
  final DateTime? completedAt;
  final DateTime? deletedAt;
  final Hlc versionHlc;
  final DateTime createdAt;

  const Task._({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.status,
    required this.priority,
    required this.sortOrder,
    required this.versionHlc,
    required this.createdAt,
    this.projectId,
    this.primaryGoalId,
    this.notes,
    this.dueDate,
    this.xpReward,
    this.recurringRule,
    this.completedAt,
    this.deletedAt,
  });

  /// Reconstruct a Task from persisted data (used by repositories).
  factory Task.fromData({
    required Id id,
    required Id ownerId,
    required String title,
    required TaskStatus status,
    required int priority,
    required int sortOrder,
    required Hlc versionHlc,
    required DateTime createdAt,
    Id? projectId,
    Id? primaryGoalId,
    String? notes,
    DateTime? dueDate,
    int? xpReward,
    String? recurringRule,
    DateTime? completedAt,
    DateTime? deletedAt,
  }) =>
      Task._(
        id: id,
        ownerId: ownerId,
        title: title,
        status: status,
        priority: priority,
        sortOrder: sortOrder,
        versionHlc: versionHlc,
        createdAt: createdAt,
        projectId: projectId,
        primaryGoalId: primaryGoalId,
        notes: notes,
        dueDate: dueDate,
        xpReward: xpReward,
        recurringRule: recurringRule,
        completedAt: completedAt,
        deletedAt: deletedAt,
      );


  factory Task.create({
    required Id ownerId,
    required String title,
    required Hlc clock,
    Id? projectId,
    Id? primaryGoalId,
    String? notes,
    DateTime? dueDate,
    int? xpReward,
    int priority = 2,
    int sortOrder = 0,
  }) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ValidationError('Task title cannot be empty');
    if (priority < 1 || priority > 5) {
      throw ValidationError('Priority must be between 1 and 5');
    }
    return Task._(
      id: Id.uuidV7(),
      ownerId: ownerId,
      title: trimmed,
      status: TaskStatus.pending,
      priority: priority,
      sortOrder: sortOrder,
      versionHlc: clock,
      createdAt: DateTime.now().toUtc(),
      projectId: projectId,
      primaryGoalId: primaryGoalId,
      notes: notes,
      dueDate: dueDate,
      xpReward: xpReward,
    );
  }

  /// Rename a task (immutable — returns new instance).
  Task rename(String newTitle, {required Hlc clock}) {
    final trimmed = newTitle.trim();
    if (trimmed.isEmpty) throw ValidationError('Task title cannot be empty');
    return _copyWith(title: trimmed, versionHlc: clock);
  }

  /// Mark as complete. Cancelled tasks cannot be completed.
  Task complete({required Hlc clock}) {
    if (status == TaskStatus.cancelled) {
      throw ValidationError('Cannot complete a cancelled task');
    }
    if (status == TaskStatus.completed) return this;
    return _copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime.now().toUtc(),
      versionHlc: clock,
    );
  }

  /// Soft-delete the task.
  Task delete({required Hlc clock}) {
    if (deletedAt != null) return this;
    return _copyWith(
      deletedAt: DateTime.now().toUtc(),
      versionHlc: clock,
    );
  }

  /// Cancel a task. Completed tasks cannot be cancelled (Invariant #8).
  Task cancel({required Hlc clock}) {
    if (status == TaskStatus.completed) {
      throw ValidationError('Cannot cancel a completed task');
    }
    return _copyWith(status: TaskStatus.cancelled, versionHlc: clock);
  }

  Task _copyWith({
    String? title,
    TaskStatus? status,
    DateTime? completedAt,
    DateTime? deletedAt,
    Hlc? versionHlc,
  }) {
    return Task._(
      id: id,
      ownerId: ownerId,
      title: title ?? this.title,
      status: status ?? this.status,
      priority: priority,
      sortOrder: sortOrder,
      versionHlc: versionHlc ?? this.versionHlc,
      createdAt: createdAt,
      projectId: projectId,
      primaryGoalId: primaryGoalId,
      notes: notes,
      dueDate: dueDate,
      xpReward: xpReward,
      recurringRule: recurringRule,
      completedAt: completedAt ?? this.completedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Task && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// Junction: a Task linked to a Goal with a role.
class TaskGoalLink {
  final Id taskId;
  final Id goalId;
  final TaskGoalRole role;
  final int sortOrder;
  final Hlc versionHlc;
  final DateTime createdAt;

  const TaskGoalLink({
    required this.taskId,
    required this.goalId,
    required this.role,
    required this.sortOrder,
    required this.versionHlc,
    required this.createdAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskGoalLink &&
          other.taskId == taskId &&
          other.goalId == goalId);

  @override
  int get hashCode => Object.hash(taskId, goalId);
}

/// Junction: a Skill linked to a Tool.
class SkillToolLink {
  final Id skillId;
  final Id toolId;
  final Hlc versionHlc;
  final DateTime createdAt;

  const SkillToolLink({
    required this.skillId,
    required this.toolId,
    required this.versionHlc,
    required this.createdAt,
  });
}

/// Valid entity kinds for AttachmentLinks.
const Set<String> kValidEntityKinds = {
  'goal',
  'task',
  'project',
  'note',
  'session',
  'activity',
};

/// Valid attachment kinds.
const Set<String> kValidAttachmentKinds = {
  'file',
  'link',
};

/// Polymorphic junction: an Attachment (file or link) linked to any entity.
class AttachmentLink {
  final Id id;
  final Id attachmentId;
  final String attachmentKind; // 'file' | 'link'
  final Id entityId;
  final String entityKind; // from kValidEntityKinds
  final Hlc versionHlc;
  final DateTime createdAt;

  AttachmentLink({
    required this.id,
    required this.attachmentId,
    required this.attachmentKind,
    required this.entityId,
    required this.entityKind,
    required this.versionHlc,
    required this.createdAt,
  }) {
    if (!kValidAttachmentKinds.contains(attachmentKind)) {
      throw ValidationError('Unknown attachmentKind: $attachmentKind');
    }
    if (!kValidEntityKinds.contains(entityKind)) {
      throw ValidationError('Unknown entityKind: $entityKind');
    }
  }
}
