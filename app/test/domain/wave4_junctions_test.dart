// Wave 4: Junction table + domain entity tests.
// Tests: Task invariants, TaskGoalRole parsing, AttachmentLink guard, junction uniqueness.

import 'package:flutter_test/flutter_test.dart';
import 'package:kratos/domain/entities/task.dart';
import 'package:kratos/domain/hlc.dart';
import 'package:kratos/domain/ids.dart';
import 'package:kratos/domain/errors.dart';

void main() {
  final ownerId = Id.uuidV7();
  final clock = Hlc.now(Id.uuidV7());

  group('Task entity', () {
    test('create validates non-empty title', () {
      expect(
        () => Task.create(ownerId: ownerId, title: '', clock: clock),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => Task.create(ownerId: ownerId, title: '   ', clock: clock),
        throwsA(isA<ValidationError>()),
      );
    });

    test('create validates priority 1–5', () {
      expect(
        () => Task.create(ownerId: ownerId, title: 'T', clock: clock, priority: 0),
        throwsA(isA<ValidationError>()),
      );
      expect(
        () => Task.create(ownerId: ownerId, title: 'T', clock: clock, priority: 6),
        throwsA(isA<ValidationError>()),
      );
    });

    test('create with valid args returns pending task', () {
      final task = Task.create(
        ownerId: ownerId,
        title: 'Write tests',
        clock: clock,
        priority: 3,
      );
      expect(task.title, 'Write tests');
      expect(task.status, TaskStatus.pending);
      expect(task.completedAt, isNull);
      expect(task.deletedAt, isNull);
    });

    test('rename trims and validates', () {
      final task = Task.create(ownerId: ownerId, title: 'Old', clock: clock);
      final renamed = task.rename('  New Title  ', clock: clock);
      expect(renamed.title, 'New Title');
      expect(renamed.id, task.id); // same entity
    });

    test('rename with empty title throws ValidationError', () {
      final task = Task.create(ownerId: ownerId, title: 'Old', clock: clock);
      expect(
        () => task.rename('', clock: clock),
        throwsA(isA<ValidationError>()),
      );
    });

    test('complete transitions to completed', () {
      final task = Task.create(ownerId: ownerId, title: 'T', clock: clock);
      final done = task.complete(clock: clock);
      expect(done.status, TaskStatus.completed);
      expect(done.completedAt, isNotNull);
    });

    test('complete on cancelled throws ValidationError', () {
      final task = Task.create(ownerId: ownerId, title: 'T', clock: clock);
      final cancelled = task.cancel(clock: clock);
      expect(
        () => cancelled.complete(clock: clock),
        throwsA(isA<ValidationError>()),
      );
    });

    test('cancel on completed throws ValidationError (Invariant #8)', () {
      final task = Task.create(ownerId: ownerId, title: 'T', clock: clock);
      final done = task.complete(clock: clock);
      expect(
        () => done.cancel(clock: clock),
        throwsA(isA<ValidationError>()),
      );
    });

    test('soft-delete sets deletedAt', () {
      final task = Task.create(ownerId: ownerId, title: 'T', clock: clock);
      final deleted = task.delete(clock: clock);
      expect(deleted.deletedAt, isNotNull);
    });

    test('double-delete is idempotent', () {
      final task = Task.create(ownerId: ownerId, title: 'T', clock: clock);
      final d1 = task.delete(clock: clock);
      final d2 = d1.delete(clock: clock);
      expect(d2.deletedAt, d1.deletedAt); // same timestamp
    });
  });

  group('TaskGoalRole serialization', () {
    test('round-trips all known roles', () {
      for (final role in TaskGoalRole.values) {
        final json = role.toJson();
        final parsed = TaskGoalRoleJson.fromJson(json);
        expect(parsed, role);
      }
    });

    test('unknown role throws ValidationError', () {
      expect(
        () => TaskGoalRoleJson.fromJson('unknown_role'),
        throwsA(isA<ValidationError>()),
      );
    });
  });

  group('AttachmentLink invariants', () {
    test('valid file link to task is created', () {
      final link = AttachmentLink(
        id: Id.uuidV7(),
        attachmentId: Id.uuidV7(),
        attachmentKind: 'file',
        entityId: Id.uuidV7(),
        entityKind: 'task',
        versionHlc: clock,
        createdAt: DateTime.now().toUtc(),
      );
      expect(link.attachmentKind, 'file');
      expect(link.entityKind, 'task');
    });

    test('unknown attachmentKind throws ValidationError', () {
      expect(
        () => AttachmentLink(
          id: Id.uuidV7(),
          attachmentId: Id.uuidV7(),
          attachmentKind: 'image', // not in kValidAttachmentKinds
          entityId: Id.uuidV7(),
          entityKind: 'task',
          versionHlc: clock,
          createdAt: DateTime.now().toUtc(),
        ),
        throwsA(isA<ValidationError>()),
      );
    });

    test('unknown entityKind throws ValidationError', () {
      expect(
        () => AttachmentLink(
          id: Id.uuidV7(),
          attachmentId: Id.uuidV7(),
          attachmentKind: 'file',
          entityId: Id.uuidV7(),
          entityKind: 'invoice', // not in kValidEntityKinds
          versionHlc: clock,
          createdAt: DateTime.now().toUtc(),
        ),
        throwsA(isA<ValidationError>()),
      );
    });

    test('all valid entityKinds are accepted', () {
      for (final kind in kValidEntityKinds) {
        expect(
          () => AttachmentLink(
            id: Id.uuidV7(),
            attachmentId: Id.uuidV7(),
            attachmentKind: 'link',
            entityId: Id.uuidV7(),
            entityKind: kind,
            versionHlc: clock,
            createdAt: DateTime.now().toUtc(),
          ),
          returnsNormally,
        );
      }
    });
  });

  group('TaskGoalLink equality', () {
    test('same taskId + goalId are equal', () {
      final taskId = Id.uuidV7();
      final goalId = Id.uuidV7();
      final link1 = TaskGoalLink(
        taskId: taskId,
        goalId: goalId,
        role: TaskGoalRole.contributesTo,
        sortOrder: 0,
        versionHlc: clock,
        createdAt: DateTime.now().toUtc(),
      );
      final link2 = TaskGoalLink(
        taskId: taskId,
        goalId: goalId,
        role: TaskGoalRole.blocks, // different role, same PK
        sortOrder: 1,
        versionHlc: clock,
        createdAt: DateTime.now().toUtc(),
      );
      expect(link1, equals(link2)); // PK equality
    });
  });
}
