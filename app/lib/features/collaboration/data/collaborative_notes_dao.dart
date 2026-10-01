// ignore_for_file: public_member_api_docs
// Wave 24: Drift DAO and Tables for Collaborative Notes & CRDT Deltas.

import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';

class CollaborativeNotes extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get sharedGoalId => text().nullable()();
  TextColumn get title => text()();
  BlobColumn get crdtDocState => blob().nullable()();
  TextColumn get plainText => text()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get deletedBy => text().nullable()();
  TextColumn get deletedReason => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CollaborativeNoteDeltas extends Table {
  TextColumn get id => text()();
  TextColumn get noteId => text()();
  TextColumn get authorId => text()();
  TextColumn get deltaOp => text()();
  IntColumn get clientSequence => integer()();
  TextColumn get versionHlc => text()();
  DateTimeColumn get appliedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftAccessor(tables: [CollaborativeNotes, CollaborativeNoteDeltas])
class CollaborativeNotesDao extends DatabaseAccessor<AppDatabase> {
  CollaborativeNotesDao(super.db);

  Future<void> createNote(CollaborativeNotesCompanion note) =>
      into(db.collaborativeNotes).insert(note);

  Future<CollaborativeNote?> getNoteById(String id) =>
      (select(db.collaborativeNotes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Future<List<CollaborativeNote>> notesForGoal(String sharedGoalId) =>
      (select(db.collaborativeNotes)
            ..where((n) =>
                n.sharedGoalId.equals(sharedGoalId) & n.deletedAt.isNull()))
          .get();

  Future<void> appendDelta(CollaborativeNoteDeltasCompanion delta) =>
      into(db.collaborativeNoteDeltas).insert(delta);

  Future<List<CollaborativeNoteDelta>> getDeltasForNote(String noteId) =>
      (select(db.collaborativeNoteDeltas)
            ..where((d) => d.noteId.equals(noteId))
            ..orderBy([(d) => OrderingTerm.asc(d.appliedAt)]))
          .get();

  Future<void> updatePlainText({
    required String noteId,
    required String plainText,
    required String versionHlc,
  }) =>
      (update(db.collaborativeNotes)..where((n) => n.id.equals(noteId))).write(
        CollaborativeNotesCompanion(
          plainText: Value(plainText),
          versionHlc: Value(versionHlc),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
}
