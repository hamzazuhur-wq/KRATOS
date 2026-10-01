import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../data/drift/ideas_tables.dart';

part 'ideas_dao.g.dart';

@DriftAccessor(tables: [
  IdeaSpaces,
  Ideas,
  IdeaSpaceLinks,
  IdeaBlocks,
  IdeaLinks,
  Tags,
  IdeaTags,
  IdeaAttachments,
])
class IdeasDao extends DatabaseAccessor<AppDatabase> with _$IdeasDaoMixin {
  IdeasDao(super.db);

  // ─── Idea Spaces ──────────────────────────────────────────────────────────

  Stream<List<DriftIdeaSpace>> watchIdeaSpaces(String ownerId) {
    return (select(db.ideaSpaces)
          ..where((s) => s.ownerId.equals(ownerId) & s.deletedAt.isNull())
          ..orderBy([(s) => OrderingTerm.asc(s.name)]))
        .watch();
  }

  Future<List<DriftIdeaSpace>> allIdeaSpaces(String ownerId) {
    return (select(db.ideaSpaces)
          ..where((s) => s.ownerId.equals(ownerId) & s.deletedAt.isNull())
          ..orderBy([(s) => OrderingTerm.asc(s.name)]))
        .get();
  }

  Future<DriftIdeaSpace?> findSpaceById(String spaceId) {
    return (select(db.ideaSpaces)..where((s) => s.id.equals(spaceId)))
        .getSingleOrNull();
  }

  Future<void> insertSpace(IdeaSpacesCompanion companion) {
    return into(db.ideaSpaces).insert(companion);
  }

  Future<void> updateSpace(IdeaSpacesCompanion companion) {
    return (update(db.ideaSpaces)..where((s) => s.id.equals(companion.id.value)))
        .write(companion);
  }

  Future<void> softDeleteSpace(
    String spaceId,
    String deletedBy,
    String versionHlc,
  ) {
    return (update(db.ideaSpaces)..where((s) => s.id.equals(spaceId))).write(
      IdeaSpacesCompanion(
        deletedAt: Value(DateTime.now().toUtc()),
        deletedBy: Value(deletedBy),
        versionHlc: Value(versionHlc),
      ),
    );
  }

  // ─── Ideas ────────────────────────────────────────────────────────────────

  Stream<List<DriftIdea>> watchAllIdeas(String ownerId, {String? query}) {
    final q = select(db.ideas)
      ..where((i) => i.ownerId.equals(ownerId) & i.deletedAt.isNull())
      ..orderBy([
        (i) => OrderingTerm.desc(i.isPinned),
        (i) => OrderingTerm.desc(i.updatedAt),
      ]);

    if (query != null && query.trim().isNotEmpty) {
      final term = '%${query.trim().toLowerCase()}%';
      q.where((i) => i.title.lower().like(term) | i.contentJson.lower().like(term));
    }

    return q.watch();
  }

  Stream<List<DriftIdea>> watchIdeasInSpace(String ownerId, String spaceId) {
    final query = select(db.ideas).join([
      innerJoin(
        db.ideaSpaceLinks,
        db.ideaSpaceLinks.ideaId.equalsExp(db.ideas.id),
      ),
    ])
      ..where(db.ideaSpaceLinks.ideaSpaceId.equals(spaceId))
      ..where(db.ideas.ownerId.equals(ownerId))
      ..where(db.ideas.deletedAt.isNull())
      ..orderBy([
        OrderingTerm.desc(db.ideas.isPinned),
        OrderingTerm.desc(db.ideas.updatedAt),
      ]);

    return query.map((row) => row.readTable(db.ideas)).watch();
  }

  Stream<List<DriftIdea>> watchUncategorizedIdeas(String ownerId) {
    return (select(db.ideas)
          ..where((i) => i.ownerId.equals(ownerId) & i.deletedAt.isNull())
          ..orderBy([
            (i) => OrderingTerm.desc(i.isPinned),
            (i) => OrderingTerm.desc(i.updatedAt),
          ]))
        .watch()
        .asyncMap((ideas) async {
      final linkedIds = await (selectOnly(db.ideaSpaceLinks)
            ..addColumns([db.ideaSpaceLinks.ideaId]))
          .map((row) => row.read(db.ideaSpaceLinks.ideaId)!)
          .get();
      final linkedSet = linkedIds.toSet();
      return ideas.where((i) => !linkedSet.contains(i.id)).toList();
    });
  }

  Future<DriftIdea?> findIdeaById(String ideaId) {
    return (select(db.ideas)..where((i) => i.id.equals(ideaId)))
        .getSingleOrNull();
  }

  Stream<DriftIdea?> watchIdea(String ideaId) {
    return (select(db.ideas)..where((i) => i.id.equals(ideaId)))
        .watchSingleOrNull();
  }

  Future<void> insertIdea(IdeasCompanion companion) {
    return into(db.ideas).insert(companion);
  }

  Future<void> updateIdea(IdeasCompanion companion) {
    return (update(db.ideas)..where((i) => i.id.equals(companion.id.value)))
        .write(companion);
  }

  Future<void> softDeleteIdea(
    String ideaId,
    String deletedBy,
    String versionHlc,
  ) {
    return (update(db.ideas)..where((i) => i.id.equals(ideaId))).write(
      IdeasCompanion(
        deletedAt: Value(DateTime.now().toUtc()),
        deletedBy: Value(deletedBy),
        versionHlc: Value(versionHlc),
      ),
    );
  }

  // ─── Idea Space Links ─────────────────────────────────────────────────────

  Future<List<DriftIdeaSpace>> spacesForIdea(String ideaId) {
    final query = select(db.ideaSpaces).join([
      innerJoin(
        db.ideaSpaceLinks,
        db.ideaSpaceLinks.ideaSpaceId.equalsExp(db.ideaSpaces.id),
      ),
    ])
      ..where(db.ideaSpaceLinks.ideaId.equals(ideaId))
      ..where(db.ideaSpaces.deletedAt.isNull());

    return query.map((row) => row.readTable(db.ideaSpaces)).get();
  }

  Stream<List<DriftIdeaSpace>> watchSpacesForIdea(String ideaId) {
    final query = select(db.ideaSpaces).join([
      innerJoin(
        db.ideaSpaceLinks,
        db.ideaSpaceLinks.ideaSpaceId.equalsExp(db.ideaSpaces.id),
      ),
    ])
      ..where(db.ideaSpaceLinks.ideaId.equals(ideaId))
      ..where(db.ideaSpaces.deletedAt.isNull());

    return query.map((row) => row.readTable(db.ideaSpaces)).watch();
  }

  Future<void> linkIdeaToSpace(IdeaSpaceLinksCompanion companion) {
    return into(db.ideaSpaceLinks).insertOnConflictUpdate(companion);
  }

  Future<void> unlinkIdeaFromSpace(String ideaId, String spaceId) {
    return (delete(db.ideaSpaceLinks)
          ..where((l) =>
              l.ideaId.equals(ideaId) & l.ideaSpaceId.equals(spaceId)))
        .go();
  }

  Future<void> clearIdeaSpaces(String ideaId) {
    return (delete(db.ideaSpaceLinks)..where((l) => l.ideaId.equals(ideaId)))
        .go();
  }

  Future<int> countIdeasInSpace(String spaceId) async {
    final count = db.ideas.id.count();
    final query = selectOnly(db.ideas).join([
      innerJoin(
        db.ideaSpaceLinks,
        db.ideaSpaceLinks.ideaId.equalsExp(db.ideas.id),
      ),
    ])
      ..where(db.ideaSpaceLinks.ideaSpaceId.equals(spaceId))
      ..where(db.ideas.deletedAt.isNull())
      ..addColumns([count]);

    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  Future<int> countUncategorizedIdeas(String ownerId) async {
    final allIdeas = await (select(db.ideas)
          ..where((i) => i.ownerId.equals(ownerId) & i.deletedAt.isNull()))
        .get();
    final linkedIds = await (selectOnly(db.ideaSpaceLinks)
          ..addColumns([db.ideaSpaceLinks.ideaId]))
        .map((row) => row.read(db.ideaSpaceLinks.ideaId)!)
        .get();
    final linkedSet = linkedIds.toSet();
    return allIdeas.where((i) => !linkedSet.contains(i.id)).length;
  }

  // ─── Internal Idea Links & Backlinks ──────────────────────────────────────

  Stream<List<DriftIdeaLink>> watchLinksFromIdea(String sourceIdeaId) {
    return (select(db.ideaLinks)
          ..where((l) => l.sourceIdeaId.equals(sourceIdeaId)))
        .watch();
  }

  Stream<List<DriftIdeaLink>> watchLinksToIdea(String targetIdeaId) {
    return (select(db.ideaLinks)
          ..where((l) => l.targetIdeaId.equals(targetIdeaId)))
        .watch();
  }

  Future<void> replaceIdeaLinks(
    String sourceIdeaId,
    List<IdeaLinksCompanion> links,
  ) async {
    await (delete(db.ideaLinks)
          ..where((l) => l.sourceIdeaId.equals(sourceIdeaId)))
        .go();
    for (final l in links) {
      await into(db.ideaLinks).insert(l);
    }
  }

  // ─── Tags ─────────────────────────────────────────────────────────────────

  Stream<List<DriftTag>> watchAllTags(String ownerId) {
    return (select(db.tags)
          ..where((t) => t.ownerId.equals(ownerId))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<DriftTag?> findTagByName(String ownerId, String name) {
    return (select(db.tags)
          ..where((t) =>
              t.ownerId.equals(ownerId) & t.name.lower().equals(name.toLowerCase())))
        .getSingleOrNull();
  }

  Future<void> insertTag(TagsCompanion companion) {
    return into(db.tags).insert(companion);
  }

  Stream<List<DriftTag>> watchTagsForIdea(String ideaId) {
    final query = select(db.tags).join([
      innerJoin(
        db.ideaTags,
        db.ideaTags.tagId.equalsExp(db.tags.id),
      ),
    ])..where(db.ideaTags.ideaId.equals(ideaId));

    return query.map((row) => row.readTable(db.tags)).watch();
  }

  Future<void> linkIdeaTag(IdeaTagsCompanion companion) {
    return into(db.ideaTags).insertOnConflictUpdate(companion);
  }

  Future<void> unlinkIdeaTag(String ideaId, String tagId) {
    return (delete(db.ideaTags)
          ..where((t) => t.ideaId.equals(ideaId) & t.tagId.equals(tagId)))
        .go();
  }

  // ─── Attachments ──────────────────────────────────────────────────────────

  Stream<List<DriftIdeaAttachment>> watchAttachmentsForIdea(String ideaId) {
    return (select(db.ideaAttachments)
          ..where((a) => a.ideaId.equals(ideaId))
          ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
        .watch();
  }

  Future<void> insertAttachment(IdeaAttachmentsCompanion companion) {
    return into(db.ideaAttachments).insert(companion);
  }

  Future<void> removeAttachment(String attachmentId) {
    return (delete(db.ideaAttachments)
          ..where((a) => a.id.equals(attachmentId)))
        .go();
  }
}
