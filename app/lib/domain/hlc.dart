// ignore_for_file: public_member_api_docs
//
// Pure-Dart Hybrid Logical Clock value object.
//
// The Drift-side implementation lives in app/lib/core/hlc.dart and
// stores 16-byte binary. This domain copy is string-typed so the domain
// layer stays free of dart:typed_data / drift dependencies.

import 'ids.dart';

class Hlc {
  final int wallMs;
  final int counter;
  final Id nodeId;

  const Hlc({
    required this.wallMs,
    required this.counter,
    required this.nodeId,
  });

  /// "Now" with a stable Id from this device.
  factory Hlc.now(Id nodeId) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    return Hlc(wallMs: now, counter: 0, nodeId: nodeId);
  }

  /// Parse from stored string format `Hlc(wall=..., c=..., node=...)`.
  /// Falls back to a zero clock if the format is unrecognized (graceful degradation).
  factory Hlc.parse(String s) {
    try {
      final wallMatch = RegExp(r'wall=(\d+)').firstMatch(s);
      final counterMatch = RegExp(r'c=(\d+)').firstMatch(s);
      final nodeMatch = RegExp(r'node=([0-9a-fA-F-]+)').firstMatch(s);
      if (wallMatch == null || counterMatch == null || nodeMatch == null) {
        throw const FormatException('bad hlc format');
      }
      return Hlc(
        wallMs: int.parse(wallMatch.group(1)!),
        counter: int.parse(counterMatch.group(1)!),
        nodeId: Id(nodeMatch.group(1)!),
      );
    } catch (_) {
      // Graceful fallback — treat as epoch zero
      return Hlc(
        wallMs: 0,
        counter: 0,
        nodeId: const Id('00000000-0000-7000-8000-000000000000'),
      );
    }
  }

  static Hlc merge(Hlc a, Hlc b, {int? nowMs, Id? nodeId}) {
    final now = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final maxWall = [a.wallMs, b.wallMs, now].reduce((x, y) => x > y ? x : y);

    int counter;
    if (maxWall == a.wallMs && maxWall == b.wallMs) {
      counter = a.counter > b.counter ? a.counter : b.counter;
      counter += 1;
    } else if (maxWall == a.wallMs) {
      counter = a.counter + 1;
    } else if (maxWall == b.wallMs) {
      counter = b.counter + 1;
    } else {
      counter = 0;
    }
    // Tiebreak by nodeId for deterministic order when wallMs+counter equal.
    final winner = (maxWall == a.wallMs && maxWall == b.wallMs)
        ? (a.counter >= b.counter ? a : b)
        : (maxWall == a.wallMs ? a : b);
    return Hlc(
      wallMs: maxWall,
      counter: counter,
      nodeId: nodeId ?? winner.nodeId,
    );
  }

  /// Lexicographic total order: by wallMs, then counter, then nodeId.
  int compareTo(Hlc other) {
    if (wallMs != other.wallMs) return wallMs.compareTo(other.wallMs);
    if (counter != other.counter) return counter.compareTo(other.counter);
    return nodeId.value.compareTo(other.nodeId.value);
  }

  @override
  bool operator ==(Object other) =>
      other is Hlc &&
      other.wallMs == wallMs &&
      other.counter == counter &&
      other.nodeId == nodeId;

  @override
  int get hashCode => Object.hash(wallMs, counter, nodeId.value);

  @override
  String toString() => 'Hlc(wall=$wallMs, c=$counter, node=${nodeId.value})';
}
