// ignore_for_file: public_member_api_docs
//
// Pure invariant checks. Enforces §6 cross-doc invariants from
// 04-architecture-synthesis.md. Throw on violation; return normally otherwise.

import 'errors.dart';

/// Goal tree consistency:
///   - depth(root) == 0
///   - depth(child) == depth(parent) + 1
///   - ancestor's id appears as a prefix of child's path (in order)
///   - rootId matches the topmost ancestor's id
///   - path is non-empty and starts with rootId
class GoalPath {
  static const String separator = '/';

  static String buildPath(String rootId, String parentPath, String nodeId) {
    if (parentPath.isEmpty || parentPath == rootId) {
      if (nodeId == rootId) return rootId;
      return '$rootId$separator$nodeId';
    }
    return '$parentPath$separator$nodeId';
  }

  static int depthOf(String path) {
    final clean = path.trim();
    if (clean.isEmpty) {
      throw const InvariantViolation('goal.path.depth', 'empty path');
    }
    final segments = clean.split(separator).where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      throw const InvariantViolation('goal.path.depth', 'empty path segments');
    }
    return segments.length - 1;
  }

  static String rootIdOf(String path) {
    final segments = path.split(separator).where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      throw const InvariantViolation('goal.path.root', 'path has no root');
    }
    return segments.first;
  }

  static void validate(String rootId, int depth, String path) {
    if (depth < 0) {
      throw InvariantViolation(
        'goal.path.depth',
        'depth must be >= 0; got $depth',
      );
    }
    if (path.startsWith(separator) || path.endsWith(separator)) {
      throw InvariantViolation(
        'goal.path.wellformed',
        'path must not have leading or trailing slashes: $path',
      );
    }
    final computedDepth = depthOf(path);
    if (computedDepth != depth) {
      throw InvariantViolation(
        'goal.path.depth_mismatch',
        'path "$path" implies depth $computedDepth but row says $depth',
      );
    }
    if (rootIdOf(path) != rootId) {
      throw InvariantViolation(
        'goal.path.root_mismatch',
        'path root does not match rootId',
      );
    }
  }
}

/// For every xp_ledger row, the sum of xp_allocation_lines must equal points.
/// Forward-declared for Wave 5+ implementation. The check itself is in Wave 5.
class AllocationSum {
  static int computeSum(Iterable<int> lines) =>
      lines.fold(0, (a, b) => a + b);

  static void validate(int points, Iterable<int> lines) {
    final sum = computeSum(lines);
    if (sum != points) {
      throw InvariantViolation(
        'xp.allocation_sum',
        'SUM(allocated_points)=$sum != ledger.points=$points',
      );
    }
  }
}
