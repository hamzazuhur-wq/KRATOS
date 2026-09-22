// ignore_for_file: public_member_api_docs
//
// Pure-Dart value object wrapping a UUID v7 string.
//
// Why UUID v7: see 03-id-and-database-architecture.md §1.3
//   - native Postgres uuid type
//   - lexicographic-sort property (time-ordered)
//   - Drift UuidValue maps cleanly to BLOB (16 bytes)
//   - PostgREST first-class
//
// This file has NO Flutter/Drift/Supabase imports.

import 'dart:math';
import 'dart:typed_data';

class Id {
  final String value;
  const Id(this.value);

  factory Id.fromString(String raw) {
    if (!Id(raw).isUuidV7) throw FormatException('Not a UUID v7: $raw');
    return Id(raw);
  }

  factory Id.uuidV7() {
    final ts = DateTime.now().toUtc().millisecondsSinceEpoch;
    final rnd = Random.secure();
    final b = Uint8List(16);

    // 48-bit big-endian timestamp
    b[0] = (ts >> 40) & 0xFF;
    b[1] = (ts >> 32) & 0xFF;
    b[2] = (ts >> 24) & 0xFF;
    b[3] = (ts >> 16) & 0xFF;
    b[4] = (ts >> 8) & 0xFF;
    b[5] = ts & 0xFF;

    // version nibble = 7
    b[6] = 0x70 | (rnd.nextInt(16));
    b[7] = rnd.nextInt(256);

    // variant = 0b10
    b[8] = 0x80 | (rnd.nextInt(64));

    for (var i = 9; i < 16; i++) {
      b[i] = rnd.nextInt(256);
    }

    final hex = b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    final v =
        '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
    return Id(v);
  }

  bool get isUuidV7 {
    final pattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-7][0-9a-fA-F]{3}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (!pattern.hasMatch(value)) return false;
    // Version nibble (1..7) already enforced above.
    return true;
  }

  @override
  bool operator ==(Object other) => other is Id && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Id($value)';
}

class InvalidIdFormat implements Exception {
  final String raw;
  InvalidIdFormat(this.raw);
  @override
  String toString() => 'InvalidIdFormat: "$raw" must be UUID v7';
}
