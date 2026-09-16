/// Hybrid Logical Clock (HLC) for KRATOS.
///
/// Combines wall-clock time with a logical counter and node identifier
/// to produce a total order consistent with causality.
/// Storage: 16-byte binary (6B ms + 2B counter + 8B node-id).
/// Dialect-agnostic: works with Drift/SQLite (BLOB) and Supabase/Postgres (BYTEA).
library;

import 'dart:typed_data';

/// Encoding: [wall_ms (6 bytes, big-endian)] [counter (2 bytes, BE)] [node_id (8 bytes)]
const int _kTimestampBytes = 6;
const int _kCounterBytes = 2;
const int _kNodeIdBytes = 8;
const int _kTotalBytes = _kTimestampBytes + _kCounterBytes + _kNodeIdBytes; // 16

/// An immutable Hybrid Logical Clock value.
final class HLC implements Comparable<HLC> {
  /// Wall-clock milliseconds since Unix epoch (stored as 48-bit big-endian).
  final int wallMs;

  /// Logical counter for events within the same millisecond (16-bit).
  final int counter;

  /// Node identifier — 64-bit (e.g. ULID prefix) ensuring global uniqueness.
  final int nodeId;

  const HLC({
    required this.wallMs,
    required this.counter,
    required this.nodeId,
  });

  /// Create an [HLC] from the current wall clock and the given [nodeId].
  /// The counter starts at 0.
  factory HLC.now({required int nodeId}) {
    final ms = DateTime.now().toUtc().millisecondsSinceEpoch;
    return HLC(wallMs: ms, counter: 0, nodeId: nodeId);
  }

  /// Decode a 16-byte binary representation.
  factory HLC.fromBytes(Uint8List bytes) {
    if (bytes.length != _kTotalBytes) {
      throw ArgumentError(
        'HLC requires exactly $_kTotalBytes bytes, got ${bytes.length}',
      );
    }
    final data = ByteData.sublistView(bytes);
    final wallMs = _readUint48(data, 0);
    final counter = data.getUint16(_kTimestampBytes);
    final nodeId = data.getUint64(_kTimestampBytes + _kCounterBytes);
    return HLC(wallMs: wallMs, counter: counter, nodeId: nodeId);
  }

  /// Decode from a hex string (e.g. stored in SQLite TEXT columns).
  factory HLC.fromHex(String hex) {
    if (hex.length != _kTotalBytes * 2) {
      throw ArgumentError(
        'HLC hex must be ${_kTotalBytes * 2} chars, got ${hex.length}',
      );
    }
    final bytes = Uint8List(_kTotalBytes);
    for (var i = 0; i < _kTotalBytes; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return HLC.fromBytes(bytes);
  }

  /// Encode to 16-byte binary representation.
  Uint8List toBytes() {
    final bytes = Uint8List(_kTotalBytes);
    final data = ByteData.sublistView(bytes);
    _writeUint48(data, 0, wallMs);
    data.setUint16(_kTimestampBytes, counter);
    data.setUint64(_kTimestampBytes + _kCounterBytes, nodeId);
    return bytes;
  }

  /// Encode to hex string.
  String toHex() => toBytes().map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Merge with an incoming HLC [other] — the core HLC update rule.
  ///
  /// Returns a new [HLC] with:
  /// - wallMs = max(this.wallMs, other.wallMs, now)
  /// - counter = 0 if wallMs advanced, else max(this.counter, other.counter) + 1
  /// - nodeId = this.nodeId (local node owns the merged clock)
  ///
  /// [nowMs] is the current wall clock in ms; injectable for deterministic
  /// tests. Defaults to `DateTime.now()`.
  HLC merge(HLC other, {int? nowMs}) {
    final current = nowMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
    final maxWall = [wallMs, other.wallMs, current]
        .reduce((a, b) => a > b ? a : b);

    int newCounter;
    if (maxWall > wallMs && maxWall > other.wallMs) {
      // Wall clock advanced beyond both — reset counter.
      newCounter = 0;
    } else if (maxWall == wallMs && maxWall == other.wallMs) {
      // Same millisecond — increment the logical counter.
      newCounter = [counter, other.counter].reduce((a, b) => a > b ? a : b) + 1;
    } else {
      // One side advanced, other didn't — increment from the advancing side.
      newCounter = (maxWall == wallMs ? counter : other.counter) + 1;
    }

    return HLC(wallMs: maxWall, counter: newCounter, nodeId: nodeId);
  }

  /// Compare two HLCs by wallMs, then counter, then nodeId.
  @override
  int compareTo(HLC other) {
    final wallCmp = wallMs.compareTo(other.wallMs);
    if (wallCmp != 0) return wallCmp;
    final counterCmp = counter.compareTo(other.counter);
    if (counterCmp != 0) return counterCmp;
    return nodeId.compareTo(other.nodeId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HLC &&
          runtimeType == other.runtimeType &&
          wallMs == other.wallMs &&
          counter == other.counter &&
          nodeId == other.nodeId;

  @override
  int get hashCode => Object.hash(wallMs, counter, nodeId);

  @override
  String toString() =>
      'HLC(wallMs=$wallMs, counter=$counter, nodeId=$nodeId)';
}

/// Read a 48-bit unsigned integer from [data] at [byteOffset] (big-endian).
int _readUint48(ByteData data, int byteOffset) {
  // Dart's ByteData maxes at getUint32; split into high 16 + low 32.
  final high = data.getUint16(byteOffset); // bytes 0-1
  final low = data.getUint32(byteOffset + 2); // bytes 2-5
  return (high << 32) | low;
}

/// Write a 48-bit unsigned integer to [data] at [byteOffset] (big-endian).
void _writeUint48(ByteData data, int byteOffset, int value) {
  data.setUint16(byteOffset, (value >> 32) & 0xFFFF);
  data.setUint32(byteOffset + 2, value & 0xFFFFFFFF);
}
