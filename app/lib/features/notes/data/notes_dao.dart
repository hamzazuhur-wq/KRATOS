// ignore_for_file: public_member_api_docs
// Wave 11: Drift DAO for Notes and AI Artifacts.
// Notes: pinnable rich-text entries linked to entities.
// AiArtifacts: immutable AI interaction audit log.

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/drift/aux_tables.dart';

part 'notes_dao.g.dart';

@DriftAccessor(tables: [Notes, AiArtifacts])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  // ─── Notes ──────────────────────────────────────────────────────────

  Future<List<NoteData>> allNotes(String ownerId) =>
      (select(db.notes)
            ..where((n) => n.ownerId.equals(ownerId) & n.deletedAt.isNull())
            ..orderBy([
              (n) => OrderingTerm.desc(n.pinned),
              (n) => OrderingTerm.desc(n.updatedAt),
            ]))
          .get();

  Future<NoteData?> findNoteById(String id) =>
      (select(db.notes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Future<void> upsertNote(NotesCompanion companion) =>
      into(db.notes).insertOnConflictUpdate(companion);

  Future<void> togglePin(String noteId, bool pinned, String versionHlc) =>
      (update(db.notes)..where((n) => n.id.equals(noteId))).write(
        NotesCompanion(
          pinned: Value(pinned),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> softDeleteNote(
          String noteId, String deletedBy, String versionHlc) =>
      (update(db.notes)..where((n) => n.id.equals(noteId))).write(
        NotesCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          deletedBy: Value(deletedBy),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  // ─── AI Artifacts ────────────────────────────────────────────────────

  /// All AI interactions for an owner (newest first).
  Future<List<AiArtifactData>> allAiArtifacts(String ownerId) =>
      (select(db.aiArtifacts)
            ..where((a) => a.ownerId.equals(ownerId))
            ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
          .get();

  /// AI interactions related to a specific entity (e.g. a Goal or Task).
  Future<List<AiArtifactData>> artifactsForEntity(
          String entityId, String entityKind) =>
      (select(db.aiArtifacts)
            ..where((a) =>
                a.relatedEntityId.equals(entityId) &
                a.relatedEntityKind.equals(entityKind))
            ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
          .get();

  Future<void> insertAiArtifact(AiArtifactsCompanion companion) =>
      into(db.aiArtifacts).insert(companion);
}
