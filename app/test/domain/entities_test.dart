import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/domain/entities/user.dart';
import 'package:kratos_app/domain/entities/life_area.dart';
import 'package:kratos_app/domain/entities/goal.dart';
import 'package:kratos_app/domain/ids.dart';
import 'package:kratos_app/domain/hlc.dart';
import 'package:kratos_app/domain/timestamps.dart';
import 'package:kratos_app/domain/errors.dart';

void main() {
  final nodeId = Id.uuidV7();
  
  group('User', () {
    test('creation + rename', () {
      var user = User(
        id: const Id('018e5e9a-7c00-7000-8000-000000000000'),
        deviceId: 'dev123',
        displayName: 'Old Name',
        syncVersion: '0',
        versionHlc: Hlc.now(nodeId),
        createdAt: Iso8601Timestamp.now(),
        updatedAt: Iso8601Timestamp.now(),
      );
      expect(user.displayName, 'Old Name');
      
      final h2 = Hlc.now(nodeId);
      user = user.rename('New Name', h2);
      expect(user.displayName, 'New Name');
      expect(user.versionHlc, h2);
    });
  });

  group('LifeArea', () {
    test('creation + rename + archive', () {
      var area = LifeArea(
        id: Id.uuidV7(),
        name: 'Area 1',
        description: null,
        ownerId: Id.uuidV7(),
        versionHlc: Hlc.now(nodeId),
        createdAt: Iso8601Timestamp.now(),
        updatedAt: Iso8601Timestamp.now(),
      );
      expect(area.isActive, isTrue);
      
      final h2 = Hlc.now(nodeId);
      area = area.rename('Area 2', h2);
      expect(area.name, 'Area 2');
      
      final h3 = Hlc.now(nodeId);
      area = area.archive(h3);
      expect(area.isActive, isFalse);
      expect(area.archivedAt, isNotNull);
    });
  });

  group('Goal', () {
    test('creation + rename + progress + xpEarned + archive', () {
      final rootId = Id.uuidV7();
      var goal = Goal(
        id: rootId,
        ownerId: Id.uuidV7(),
        parentId: null,
        rootId: rootId,
        path: rootId.value,
        depth: 0,
        title: 'G1',
        description: null,
        lifeAreaId: Id.uuidV7(),
        status: GoalStatus.active,
        xpTarget: 100,
        progress: 0.0,
        progressHlc: Hlc.now(nodeId),
        versionHlc: Hlc.now(nodeId),
        createdAt: Iso8601Timestamp.now(),
        updatedAt: Iso8601Timestamp.now(),
      );
      
      expect(goal.isRoot, isTrue);
      expect(goal.depth, 0);

      // child creation
      final childId = Id.uuidV7();
      final childPath = goal.childPath(childId);
      expect(childPath, '${rootId.value}/${childId.value}');

      final childGoal = Goal(
        id: childId,
        ownerId: goal.ownerId,
        parentId: rootId,
        rootId: rootId,
        path: childPath,
        depth: 1,
        title: 'Child Goal',
        versionHlc: Hlc.now(nodeId),
        progressHlc: Hlc.now(nodeId),
        createdAt: Iso8601Timestamp.now(),
        updatedAt: Iso8601Timestamp.now(),
      );
      expect(childGoal.isRoot, isFalse);
      expect(childGoal.depth, 1);

      // rename
      final h2 = Hlc.now(nodeId);
      goal = goal.rename('G2', h2);
      expect(goal.title, 'G2');
      
      // progress validation + clamp
      final ph = Hlc.now(nodeId);
      expect(() => goal.setProgress(-0.5, ph, h2), throwsA(isA<ValidationError>()));
      expect(() => goal.setProgress(1.5, ph, h2), throwsA(isA<ValidationError>()));
      
      goal = goal.setProgress(0.8, ph, h2);
      expect(goal.progress, 0.8);
      expect(goal.xpEarned, 80);
      
      // archive
      final h3 = Hlc.now(nodeId);
      goal = goal.archive(h3);
      expect(goal.status, GoalStatus.abandoned);
      expect(() => goal.rename('G3', h3), throwsA(isA<ConflictError>()));
    });
  });
}
