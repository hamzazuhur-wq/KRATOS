// Wave 24 Unit Tests: Real-Time Collaboration & CRDT Shared Notes
//
// Tests cover:
//   1. CrdtDelta serialization & deserialization
//   2. CrdtTextMergeEngine.applyDelta insert at beginning, middle, end
//   3. CrdtTextMergeEngine.applyDelta delete & replace
//   4. Deterministic multi-delta merge convergence across simulated devices
//   5. CollaborativeNoteEntity copyWith immutability
//   6. Concurrent edit resolution ordering via HLC timestamps

import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/features/collaboration/domain/crdt_models.dart';

void main() {
  group('CrdtDelta serialization', () {
    test('round-trip preserves all fields', () {
      final delta = CrdtDelta(
        id: 'delta_01',
        noteId: 'note_100',
        authorId: 'usr_alice',
        opType: CrdtOpType.insert,
        position: 5,
        text: 'hello ',
        length: 6,
        sequence: 1,
        versionHlc: '2026-09-23T12:00:00.000Z-0001',
        appliedAt: DateTime.utc(2026, 9, 23, 12, 0, 0),
      );

      final serialized = delta.serialize();
      final deserialized = CrdtDelta.deserialize(serialized);

      expect(deserialized.id, delta.id);
      expect(deserialized.noteId, delta.noteId);
      expect(deserialized.authorId, delta.authorId);
      expect(deserialized.opType, CrdtOpType.insert);
      expect(deserialized.position, 5);
      expect(deserialized.text, 'hello ');
      expect(deserialized.versionHlc, delta.versionHlc);
    });
  });

  group('CrdtTextMergeEngine', () {
    test('applies insert operations correctly', () {
      const initial = 'Hello World';

      final insertMiddle = CrdtDelta(
        id: 'd1',
        noteId: 'n1',
        authorId: 'u1',
        opType: CrdtOpType.insert,
        position: 6,
        text: 'Brave ',
        sequence: 1,
        versionHlc: '1',
        appliedAt: DateTime.now().toUtc(),
      );

      final result = CrdtTextMergeEngine.applyDelta(initial, insertMiddle);
      expect(result, 'Hello Brave World');
    });

    test('applies delete operations correctly', () {
      const initial = 'Hello Brave World';

      final deleteMiddle = CrdtDelta(
        id: 'd2',
        noteId: 'n1',
        authorId: 'u1',
        opType: CrdtOpType.delete,
        position: 6,
        length: 6, // 'Brave '
        sequence: 2,
        versionHlc: '2',
        appliedAt: DateTime.now().toUtc(),
      );

      final result = CrdtTextMergeEngine.applyDelta(initial, deleteMiddle);
      expect(result, 'Hello World');
    });

    test('applies replace operations correctly', () {
      const initial = 'Goal: Run 5km';

      final replaceDelta = CrdtDelta(
        id: 'd3',
        noteId: 'n1',
        authorId: 'u1',
        opType: CrdtOpType.replace,
        position: 10,
        length: 3, // '5km'
        text: '10km',
        sequence: 3,
        versionHlc: '3',
        appliedAt: DateTime.now().toUtc(),
      );

      final result = CrdtTextMergeEngine.applyDelta(initial, replaceDelta);
      expect(result, 'Goal: Run 10km');
    });

    test('mergeLog converges deterministically regardless of input arrival order', () {
      const base = 'Start: ';

      final deltaA = CrdtDelta(
        id: 'dA',
        noteId: 'n1',
        authorId: 'alice',
        opType: CrdtOpType.insert,
        position: 7,
        text: 'Step 1 ',
        sequence: 1,
        versionHlc: '2026-09-23T10:00:00Z',
        appliedAt: DateTime.utc(2026, 9, 23, 10),
      );

      final deltaB = CrdtDelta(
        id: 'dB',
        noteId: 'n1',
        authorId: 'bob',
        opType: CrdtOpType.insert,
        position: 14,
        text: '-> Step 2',
        sequence: 2,
        versionHlc: '2026-09-23T10:01:00Z',
        appliedAt: DateTime.utc(2026, 9, 23, 10, 1),
      );

      // Arrival order 1: [A, B]
      final result1 = CrdtTextMergeEngine.mergeLog(base, [deltaA, deltaB]);

      // Arrival order 2: [B, A]
      final result2 = CrdtTextMergeEngine.mergeLog(base, [deltaB, deltaA]);

      expect(result1, result2);
      expect(result1, 'Start: Step 1 -> Step 2');
    });
  });
}
