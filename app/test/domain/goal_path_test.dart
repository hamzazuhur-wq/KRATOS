import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/domain/invariants.dart';

void main() {
  group('GoalPath', () {
    test('root: depth 0 + path {rootId}', () {
      GoalPath.validate('g_root', 0, 'g_root');
      expect(GoalPath.buildPath('g_root', '', 'g_root'), 'g_root');
    });

    test('child: depth 1 + path {root}/{child}', () {
      const root = 'g_root';
      const child = 'g_child';
      final p = GoalPath.buildPath(root, root, child);
      expect(p, '$root/$child');
      GoalPath.validate(root, 1, p);
    });

    test('grandchild: depth 2 + path {root}/{child}/{grandchild}', () {
      const root = 'g_root';
      const child = 'g_child';
      const grandChild = 'g_grandchild';
      final p1 = GoalPath.buildPath(root, root, child);
      final p2 = GoalPath.buildPath(root, p1, grandChild);
      expect(p2, '$root/$child/$grandChild');
      GoalPath.validate(root, 2, p2);
    });

    test('validate rejects inconsistent depth', () {
      expect(
        () => GoalPath.validate('g_root', 2, 'g_root/x'),
        throwsA(isA<Exception>()),
      );
    });

    test('validate rejects leading or trailing slash', () {
      expect(
        () => GoalPath.validate('g_root', 0, '/g_root'),
        throwsA(isA<Exception>()),
      );
      expect(
        () => GoalPath.validate('g_root', 0, 'g_root/'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
