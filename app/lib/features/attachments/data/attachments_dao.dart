// ignore_for_file: public_member_api_docs
// Wave 13: Drift DAO for Attachments, Files, Links, and Evidence.
// Evidence Hub: unified browser for files, links, and evidence items.

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/drift/aux_tables.dart';

part 'attachments_dao.g.dart';

@DriftAccessor(tables: [AttachmentLinks, Files, Links, Evidence])
class AttachmentsDao extends DatabaseAccessor<AppDatabase>
    with _$AttachmentsDaoMixin {
  AttachmentsDao(super.db);

  // ─── Attachment Links ─────────────────────────────────────────────────

  /// All attachment links for an entity (e.g. a Task, Goal, or Session).
  Future<List<AttachmentLink>> attachmentsForEntity(
          String entityId, String entityKind) =>
      (select(db.attachmentLinks)
            ..where((a) =>
                a.entityId.equals(entityId) &
                a.entityKind.equals(entityKind))
            ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
          .get();

  Future<void> linkAttachment(AttachmentLinksCompanion companion) =>
      into(db.attachmentLinks).insert(companion);

  Future<void> unlinkAttachment(String linkId) =>
      (delete(db.attachmentLinks)
            ..where((a) => a.id.equals(linkId)))
          .go();

  // ─── Files ────────────────────────────────────────────────────────────

  Future<File?> findFileById(String id) =>
      (select(db.files)..where((f) => f.id.equals(id))).getSingleOrNull();

  Future<void> upsertFile(FilesCompanion companion) =>
      into(db.files).insertOnConflictUpdate(companion);

  Future<void> softDeleteFile(
          String fileId, String deletedBy, String versionHlc) =>
      (update(db.files)..where((f) => f.id.equals(fileId))).write(
        FilesCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          deletedBy: Value(deletedBy),
          versionHlc: Value(versionHlc),
        ),
      );

  // ─── Links (URLs) ─────────────────────────────────────────────────────

  Future<List<Link>> allLinks(String ownerId) =>
      (select(db.links)
            ..where((l) => l.ownerId.equals(ownerId) & l.deletedAt.isNull())
            ..orderBy([(l) => OrderingTerm.desc(l.createdAt)]))
          .get();

  Future<void> upsertLink(LinksCompanion companion) =>
      into(db.links).insertOnConflictUpdate(companion);

  Future<void> softDeleteLink(
          String linkId, String deletedBy, String versionHlc) =>
      (update(db.links)..where((l) => l.id.equals(linkId))).write(
        LinksCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          deletedBy: Value(deletedBy),
          versionHlc: Value(versionHlc),
        ),
      );

  // ─── Evidence ─────────────────────────────────────────────────────────

  Future<List<EvidenceData>> allEvidence(String ownerId) =>
      (select(db.evidence)
            ..where(
                (e) => e.ownerId.equals(ownerId) & e.deletedAt.isNull())
            ..orderBy([(e) => OrderingTerm.desc(e.capturedAt)]))
          .get();

  Future<void> insertEvidence(EvidenceCompanion companion) =>
      into(db.evidence).insert(companion);

  Future<void> softDeleteEvidence(
          String evidenceId, String deletedBy, String versionHlc) =>
      (update(db.evidence)..where((e) => e.id.equals(evidenceId))).write(
        EvidenceCompanion(
          deletedAt: Value(DateTime.now().toUtc()),
          deletedBy: Value(deletedBy),
          versionHlc: Value(versionHlc),
        ),
      );
}
