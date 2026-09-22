// ignore_for_file: public_member_api_docs

import '../errors.dart';
import '../hlc.dart';
import '../ids.dart';
import '../invariants.dart';
import '../timestamps.dart';

/// Goal status enum.
enum GoalStatus {
  active,
  completed,
  abandoned;

  static GoalStatus fromString(String s) =>
      GoalStatus.values.firstWhere((v) => v.name == s);
}

/// Pure-Dart Goal entity with recursive tree semantics:
///   - depth(root) == 0
///   - depth(child) == depth(parent) + 1
///   - path = "/{rootId}/{parentId}/{nodeId}"
///   - rootId is the topmost ancestor's id (== self.id for a root)
class Goal {
  final Id id;
  final Id ownerId;
  final Id? parentId; // null only for root
  final Id rootId;
  final String path;
  final int depth;
  final String title;
  final String? description;
  final Id? lifeAreaId;
  final GoalStatus status;
  final int? xpTarget;
  final double progress;
  final Iso8601Timestamp? dueDate;
  final Iso8601Timestamp? completedAt;
  final Iso8601Timestamp? deletedAt;
  final Hlc versionHlc;
  final Hlc progressHlc;
  final Iso8601Timestamp createdAt;
  final Iso8601Timestamp updatedAt;

  Goal({
    required this.id,
    required this.ownerId,
    required this.rootId,
    required this.path,
    required this.depth,
    required this.title,
    required this.versionHlc,
    required this.progressHlc,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.description,
    this.lifeAreaId,
    this.status = GoalStatus.active,
    this.xpTarget,
    this.progress = 0.0,
    this.dueDate,
    this.completedAt,
    this.deletedAt,
  }) {
    GoalPath.validate(rootId.value, depth, path);
    if (progress < 0 || progress > 1) {
      throw ValidationError(
        'progress',
        'progress must be in [0,1]; got $progress',
      );
    }
  }

  bool get isRoot => parentId == null;
  bool get isDeleted => deletedAt != null;
  bool get isCompleted => status == GoalStatus.completed;

  /// Build the path for a child goal of [this].
  String childPath(Id childId) =>
      GoalPath.buildPath(rootId.value, path, childId.value);

  Goal rename(String newTitle, Hlc newHlc) {
    _requireActive();
    return Goal(
      id: id,
      ownerId: ownerId,
      parentId: parentId,
      rootId: rootId,
      path: path,
      depth: depth,
      title: newTitle,
      description: description,
      lifeAreaId: lifeAreaId,
      status: status,
      xpTarget: xpTarget,
      progress: progress,
      progressHlc: progressHlc,
      dueDate: dueDate,
      completedAt: completedAt,
      deletedAt: deletedAt,
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  Goal setProgress(double newProgress, Hlc newHlc) {
    _requireActive();
    if (newProgress < 0 || newProgress > 1) {
      throw ValidationError(
        'progress',
        'progress must be in [0,1]; got $newProgress',
      );
    }
    return Goal(
      id: id,
      ownerId: ownerId,
      parentId: parentId,
      rootId: rootId,
      path: path,
      depth: depth,
      title: title,
      description: description,
      lifeAreaId: lifeAreaId,
      status: status,
      xpTarget: xpTarget,
      progress: newProgress,
      progressHlc: newHlc,
      dueDate: dueDate,
      completedAt: completedAt,
      deletedAt: deletedAt,
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  Goal archive(Hlc newHlc) {
    if (isDeleted) {
      throw ConflictError('Cannot archive a deleted Goal');
    }
    return Goal(
      id: id,
      ownerId: ownerId,
      parentId: parentId,
      rootId: rootId,
      path: path,
      depth: depth,
      title: title,
      description: description,
      lifeAreaId: lifeAreaId,
      status: GoalStatus.abandoned,
      xpTarget: xpTarget,
      progress: progress,
      progressHlc: progressHlc,
      dueDate: dueDate,
      completedAt: completedAt,
      deletedAt: deletedAt,
      versionHlc: newHlc,
      createdAt: createdAt,
      updatedAt: Iso8601Timestamp.now(),
    );
  }

  int get xpEarned {
    if (xpTarget == null || xpTarget! <= 0) return 0;
    return (xpTarget! * progress).round();
  }

  void _requireActive() {
    if (isDeleted) {
      throw ConflictError('Cannot modify a deleted Goal');
    }
    if (isCompleted) {
      throw ConflictError('Cannot modify a completed Goal');
    }
  }
}
