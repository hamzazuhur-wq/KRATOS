// ignore_for_file: public_member_api_docs
// Wave 24: Domain models and deterministic CRDT text merge engine.
//
// Allows two or more devices/partners to edit shared notes asynchronously
// and converge deterministically to the exact same text state.
// References: 04-sync-architecture.md (§future_v2_collaborative)

import 'dart:convert';

enum CrdtOpType { insert, delete, replace }

class CrdtDelta {
  final String id;
  final String noteId;
  final String authorId;
  final CrdtOpType opType;
  final int position;
  final String text;
  final int length; // for delete/replace
  final int sequence;
  final String versionHlc;
  final DateTime appliedAt;

  const CrdtDelta({
    required this.id,
    required this.noteId,
    required this.authorId,
    required this.opType,
    required this.position,
    this.text = '',
    this.length = 0,
    required this.sequence,
    required this.versionHlc,
    required this.appliedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'note_id': noteId,
        'author_id': authorId,
        'op_type': opType.name,
        'position': position,
        'text': text,
        'length': length,
        'sequence': sequence,
        'version_hlc': versionHlc,
        'applied_at': appliedAt.toIso8601String(),
      };

  factory CrdtDelta.fromJson(Map<String, dynamic> map) => CrdtDelta(
        id: map['id'] as String,
        noteId: map['note_id'] as String,
        authorId: map['author_id'] as String,
        opType: CrdtOpType.values.byName(map['op_type'] as String),
        position: (map['position'] as num).toInt(),
        text: (map['text'] as String?) ?? '',
        length: (map['length'] as num?)?.toInt() ?? 0,
        sequence: (map['sequence'] as num).toInt(),
        versionHlc: map['version_hlc'] as String,
        appliedAt: DateTime.parse(map['applied_at'] as String),
      );

  String serialize() => jsonEncode(toJson());
  static CrdtDelta deserialize(String raw) =>
      CrdtDelta.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}

class CollaborativeNoteEntity {
  final String id;
  final String ownerId;
  final String? sharedGoalId;
  final String title;
  final String plainText;
  final String versionHlc;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CollaborativeNoteEntity({
    required this.id,
    required this.ownerId,
    this.sharedGoalId,
    required this.title,
    required this.plainText,
    required this.versionHlc,
    required this.createdAt,
    required this.updatedAt,
  });

  CollaborativeNoteEntity copyWith({
    String? title,
    String? plainText,
    String? versionHlc,
    DateTime? updatedAt,
  }) =>
      CollaborativeNoteEntity(
        id: id,
        ownerId: ownerId,
        sharedGoalId: sharedGoalId,
        title: title ?? this.title,
        plainText: plainText ?? this.plainText,
        versionHlc: versionHlc ?? this.versionHlc,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Deterministic text CRDT merge engine for collaborative editing.
class CrdtTextMergeEngine {
  /// Applies a single delta to the current text buffer safely.
  static String applyDelta(String currentText, CrdtDelta delta) {
    final pos = delta.position.clamp(0, currentText.length);

    switch (delta.opType) {
      case CrdtOpType.insert:
        if (pos >= currentText.length) {
          return currentText + delta.text;
        }
        return currentText.substring(0, pos) +
            delta.text +
            currentText.substring(pos);

      case CrdtOpType.delete:
        final end = (pos + delta.length).clamp(0, currentText.length);
        if (pos >= end) return currentText;
        return currentText.substring(0, pos) + currentText.substring(end);

      case CrdtOpType.replace:
        final end = (pos + delta.length).clamp(0, currentText.length);
        return currentText.substring(0, pos) +
            delta.text +
            currentText.substring(end);
    }
  }

  /// Merges a sequence of deltas ordered deterministically by HLC timestamp.
  static String mergeLog(String baseText, List<CrdtDelta> deltas) {
    // Deterministic sort: HLC timestamp first, then sequence number, then authorId
    final sorted = List<CrdtDelta>.from(deltas)..sort((a, b) {
      final hlcComp = a.versionHlc.compareTo(b.versionHlc);
      if (hlcComp != 0) return hlcComp;
      final seqComp = a.sequence.compareTo(b.sequence);
      if (seqComp != 0) return seqComp;
      return a.authorId.compareTo(b.authorId);
    });

    var result = baseText;
    for (final delta in sorted) {
      result = applyDelta(result, delta);
    }
    return result;
  }
}
