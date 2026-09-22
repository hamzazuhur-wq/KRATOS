// ignore_for_file: public_member_api_docs

import '../entities/goal.dart';
import '../hlc.dart';
import '../ids.dart';

abstract interface class GoalRepository {
  Future<Goal?> findById(Id id);
  Future<List<Goal>> findRootsByOwner(Id ownerId);
  Future<List<Goal>> findChildrenOf(Id parentId);
  Future<List<Goal>> findByRoot(Id rootId);

  /// Creates a new root goal (depth = 0, path = "/{newId}").
  Future<void> createRoot(Goal goal);

  /// Creates a child goal under [parent]. Path/depth must already be
  /// computed by the caller via Goal.childPath; the repository enforces
  /// the parent existence + id consistency.
  Future<void> createChild(Goal goal, Goal parent);

  /// Reparents [goal] under [newParent]. Triggers a depth/path rewrite
  /// for [goal] and all descendants. Caller must provide [newHlc].
  Future<void> reparent(Goal goal, Goal newParent, Hlc newHlc);

  /// Marks the goal as abandoned (status = archived) and updates hlc.
  Future<void> archive(Id id, Hlc newHlc);

  /// Soft-deletes the goal. The repository rejects if [goal] has any
  /// non-deleted descendants; the caller must delete or reparent them first.
  Future<void> delete(Id id, Hlc newHlc);
}
