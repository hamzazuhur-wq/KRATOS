import 'dart:typed_data';
import 'package:kratos_app/core/hlc.dart';
import 'package:test/test.dart';

void main() {
  const nodeId = 0x0001020304050607;

  group('HLC', () {
    test('construct from parameters', () {
      final hlc = HLC(wallMs: 1000, counter: 5, nodeId: nodeId);
      expect(hlc.wallMs, equals(1000));
      expect(hlc.counter, equals(5));
      expect(hlc.nodeId, equals(nodeId));
    });

    test('now() uses current wall clock', () {
      final before = DateTime.now().toUtc().millisecondsSinceEpoch;
      final hlc = HLC.now(nodeId: nodeId);
      final after = DateTime.now().toUtc().millisecondsSinceEpoch;
      expect(hlc.wallMs, greaterThanOrEqualTo(before));
      expect(hlc.wallMs, lessThanOrEqualTo(after));
      expect(hlc.counter, equals(0));
    });

    group('toBytes / fromBytes round-trip', () {
      test('preserves all fields', () {
        final original = HLC(wallMs: 1725500000000, counter: 42, nodeId: nodeId);
        final bytes = original.toBytes();
        expect(bytes.length, equals(16));
        final decoded = HLC.fromBytes(bytes);
        expect(decoded, equals(original));
      });

      test('throws on wrong length', () {
        expect(() => HLC.fromBytes(Uint8List(10)), throwsArgumentError);
      });

      test('handles max values', () {
        final maxWall = (1 << 48) - 1; // 2^48 - 1
        final maxCounter = (1 << 16) - 1; // 2^16 - 1
        final maxNode = (1 << 64) - 1; // 2^64 - 1
        final hlc = HLC(wallMs: maxWall, counter: maxCounter, nodeId: maxNode);
        final decoded = HLC.fromBytes(hlc.toBytes());
        expect(decoded, equals(hlc));
        expect(decoded.wallMs, equals(maxWall));
        expect(decoded.counter, equals(maxCounter));
        expect(decoded.nodeId, equals(maxNode));
      });

      test('handles zero values', () {
        final hlc = HLC(wallMs: 0, counter: 0, nodeId: 0);
        final decoded = HLC.fromBytes(hlc.toBytes());
        expect(decoded, equals(hlc));
      });
    });

    group('toHex / fromHex round-trip', () {
      test('preserves all fields', () {
        final original = HLC(wallMs: 1725500000000, counter: 99, nodeId: nodeId);
        final hex = original.toHex();
        expect(hex.length, equals(32)); // 16 bytes * 2
        final decoded = HLC.fromHex(hex);
        expect(decoded, equals(original));
      });

      test('throws on wrong length', () {
        expect(() => HLC.fromHex('abcd'), throwsArgumentError);
      });
    });

    group('merge', () {
      test('advances wall clock when other is ahead', () {
        final local = HLC(wallMs: 1000, counter: 0, nodeId: nodeId);
        final remote = HLC(wallMs: 2000, counter: 0, nodeId: 0xABCD);
        final merged = local.merge(remote, nowMs: 0);
        expect(merged.wallMs, equals(2000));
        expect(merged.counter, equals(1)); // wall advanced → counter+1 from other
        expect(merged.nodeId, equals(nodeId)); // keeps local nodeId
      });

      test('increments counter when wall clocks are equal', () {
        final local = HLC(wallMs: 1500, counter: 3, nodeId: nodeId);
        final remote = HLC(wallMs: 1500, counter: 5, nodeId: 0xABCD);
        final merged = local.merge(remote, nowMs: 0);
        expect(merged.wallMs, equals(1500));
        expect(merged.counter, equals(6)); // max(3,5) + 1
        expect(merged.nodeId, equals(nodeId));
      });

      test('advances counter when local wall is ahead', () {
        final local = HLC(wallMs: 3000, counter: 2, nodeId: nodeId);
        final remote = HLC(wallMs: 1000, counter: 10, nodeId: 0xABCD);
        final merged = local.merge(remote, nowMs: 0);
        expect(merged.wallMs, equals(3000));
        expect(merged.counter, equals(3)); // local counter + 1
      });

      test('is commutative on wallMs and counter (nodeId stays local)', () {
        final a = HLC(wallMs: 1000, counter: 1, nodeId: nodeId);
        final b = HLC(wallMs: 2000, counter: 2, nodeId: 0xABCD);
        final ab = a.merge(b, nowMs: 0);
        final ba = b.merge(a, nowMs: 0);
        expect(ab.wallMs, equals(ba.wallMs));
        expect(ab.counter, equals(ba.counter));
      });

      test('merge with now() advances past current time', () {
        final past = HLC(wallMs: 1, counter: 0, nodeId: nodeId);
        final hlcNow = HLC.now(nodeId: nodeId);
        final merged = past.merge(hlcNow);
        expect(merged.wallMs, greaterThanOrEqualTo(hlcNow.wallMs));
      });
    });

    group('compareTo', () {
      test('orders by wallMs first', () {
        final a = HLC(wallMs: 100, counter: 5, nodeId: 1);
        final b = HLC(wallMs: 200, counter: 1, nodeId: 1);
        expect(a.compareTo(b), lessThan(0));
        expect(b.compareTo(a), greaterThan(0));
      });

      test('orders by counter when wallMs equal', () {
        final a = HLC(wallMs: 100, counter: 1, nodeId: 1);
        final b = HLC(wallMs: 100, counter: 2, nodeId: 1);
        expect(a.compareTo(b), lessThan(0));
      });

      test('orders by nodeId when wallMs and counter equal', () {
        final a = HLC(wallMs: 100, counter: 1, nodeId: 1);
        final b = HLC(wallMs: 100, counter: 1, nodeId: 2);
        expect(a.compareTo(b), lessThan(0));
      });
    });

    group('equality', () {
      test('equal HLCs are == and have same hashCode', () {
        final a = HLC(wallMs: 100, counter: 5, nodeId: nodeId);
        final b = HLC(wallMs: 100, counter: 5, nodeId: nodeId);
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different HLCs are not ==', () {
        final a = HLC(wallMs: 100, counter: 5, nodeId: nodeId);
        final b = HLC(wallMs: 100, counter: 6, nodeId: nodeId);
        expect(a, isNot(equals(b)));
      });
    });

    test('toString is human-readable', () {
      final hlc = HLC(wallMs: 1000, counter: 5, nodeId: nodeId);
      expect(hlc.toString(), contains('wallMs=1000'));
      expect(hlc.toString(), contains('counter=5'));
    });
  });
}
