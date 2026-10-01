import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../domain/idea_models.dart';

class IdeasRepository {
  final AppDatabase _db;

  IdeasRepository(this._db);

  String _currentHlc() => Hlc.now(const Id('node_local')).toString();

  // ─── Idea Spaces & Summaries ──────────────────────────────────────────────

  Stream<List<IdeaSpaceSummary>> watchIdeaSpacesWithCounts(String ownerId) {
    return _db.ideasDao.watchIdeaSpaces(ownerId).asyncMap((spaces) async {
      final summaries = <IdeaSpaceSummary>[];
      for (final s in spaces) {
        final count = await _db.ideasDao.countIdeasInSpace(s.id);
        summaries.add(
          IdeaSpaceSummary(
            space: IdeaSpace(
              id: s.id,
              ownerId: s.ownerId,
              name: s.name,
              description: s.description,
              icon: s.icon,
              archivedAt: s.archivedAt,
              deletedAt: s.deletedAt,
              versionHlc: s.versionHlc,
              createdAt: s.createdAt,
              updatedAt: s.updatedAt,
            ),
            ideaCount: count,
          ),
        );
      }
      return summaries;
    });
  }

  Stream<int> watchUncategorizedCount(String ownerId) {
    return _db.ideasDao
        .watchUncategorizedIdeas(ownerId)
        .map((list) => list.length);
  }

  Future<IdeaSpace?> getSpace(String spaceId) async {
    final s = await _db.ideasDao.findSpaceById(spaceId);
    if (s == null) return null;
    return IdeaSpace(
      id: s.id,
      ownerId: s.ownerId,
      name: s.name,
      description: s.description,
      icon: s.icon,
      archivedAt: s.archivedAt,
      deletedAt: s.deletedAt,
      versionHlc: s.versionHlc,
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    );
  }

  Future<String> createSpace({
    required String ownerId,
    required String name,
    String? description,
    String? icon,
  }) async {
    final spaceId = Id.uuidV7().value;
    final now = DateTime.now().toUtc();
    final hlc = _currentHlc();

    await _db.ideasDao.insertSpace(
      IdeaSpacesCompanion(
        id: Value(spaceId),
        ownerId: Value(ownerId),
        name: Value(name.trim()),
        description: Value(description?.trim()),
        icon: Value(icon),
        versionHlc: Value(hlc),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    await _enqueueOutbox(
      'idea_spaces',
      spaceId,
      'INSERT',
      {
        'id': spaceId,
        'owner_id': ownerId,
        'name': name.trim(),
        'description': description?.trim(),
        'icon': icon,
        'version_hlc': hlc,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      ownerId,
      hlc,
    );

    return spaceId;
  }

  Future<void> updateSpace({
    required String spaceId,
    required String name,
    String? description,
    String? icon,
  }) async {
    final existing = await _db.ideasDao.findSpaceById(spaceId);
    if (existing == null) return;
    final now = DateTime.now().toUtc();
    final hlc = _currentHlc();

    await _db.ideasDao.updateSpace(
      IdeaSpacesCompanion(
        id: Value(spaceId),
        name: Value(name.trim()),
        description: Value(description?.trim()),
        icon: Value(icon),
        versionHlc: Value(hlc),
        updatedAt: Value(now),
      ),
    );

    await _enqueueOutbox(
      'idea_spaces',
      spaceId,
      'UPDATE',
      {
        'id': spaceId,
        'name': name.trim(),
        'description': description?.trim(),
        'icon': icon,
        'version_hlc': hlc,
        'updated_at': now.toIso8601String(),
      },
      existing.ownerId,
      hlc,
    );
  }

  Future<void> deleteSpace(String spaceId, String deletedBy) async {
    final existing = await _db.ideasDao.findSpaceById(spaceId);
    if (existing == null) return;
    final hlc = _currentHlc();

    await _db.ideasDao.softDeleteSpace(spaceId, deletedBy, hlc);

    await _enqueueOutbox(
      'idea_spaces',
      spaceId,
      'DELETE',
      {
        'id': spaceId,
        'deleted_by': deletedBy,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'version_hlc': hlc,
      },
      existing.ownerId,
      hlc,
    );
  }

  // ─── Ideas Querying ───────────────────────────────────────────────────────

  Stream<List<IdeaDetail>> watchIdeasInSpace(String ownerId, String spaceId) {
    return _db.ideasDao
        .watchIdeasInSpace(ownerId, spaceId)
        .asyncMap((ideas) async {
      final details = <IdeaDetail>[];
      for (final i in ideas) {
        final d = await _buildIdeaDetail(i);
        details.add(d);
      }
      return details;
    });
  }

  Stream<List<IdeaDetail>> watchUncategorizedIdeas(String ownerId) {
    return _db.ideasDao
        .watchUncategorizedIdeas(ownerId)
        .asyncMap((ideas) async {
      final details = <IdeaDetail>[];
      for (final i in ideas) {
        final d = await _buildIdeaDetail(i);
        details.add(d);
      }
      return details;
    });
  }

  Stream<List<IdeaDetail>> watchAllIdeas(String ownerId, {String? query}) {
    return _db.ideasDao
        .watchAllIdeas(ownerId, query: query)
        .asyncMap((ideas) async {
      final details = <IdeaDetail>[];
      for (final i in ideas) {
        final d = await _buildIdeaDetail(i);
        details.add(d);
      }
      return details;
    });
  }

  Stream<IdeaDetail?> watchIdeaDetail(String ideaId) {
    return _db.ideasDao.watchIdea(ideaId).asyncMap((idea) async {
      if (idea == null) return null;
      return _buildIdeaDetail(idea);
    });
  }

  Future<IdeaDetail?> getIdeaDetail(String ideaId) async {
    final idea = await _db.ideasDao.findIdeaById(ideaId);
    if (idea == null) return null;
    return _buildIdeaDetail(idea);
  }

  Stream<List<IdeaBacklinkItem>> watchBacklinks(String targetIdeaId) {
    return _db.ideasDao.watchLinksToIdea(targetIdeaId).asyncMap((links) async {
      final items = <IdeaBacklinkItem>[];
      for (final link in links) {
        final source = await _db.ideasDao.findIdeaById(link.sourceIdeaId);
        if (source != null && source.deletedAt == null) {
          items.add(
            IdeaBacklinkItem(
              linkId: link.id,
              sourceIdeaId: source.id,
              sourceIdeaTitle: source.title,
              displayText: link.displayText,
              createdAt: link.createdAt,
            ),
          );
        }
      }
      return items;
    });
  }

  Future<IdeaDetail> _buildIdeaDetail(DriftIdea row) async {
    final idea = Idea(
      id: row.id,
      ownerId: row.ownerId,
      title: row.title,
      contentJson: row.contentJson,
      excerpt: row.excerpt,
      isPinned: row.isPinned,
      archivedAt: row.archivedAt,
      deletedAt: row.deletedAt,
      versionHlc: row.versionHlc,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );

    final spaceRows = await _db.ideasDao.spacesForIdea(row.id);
    final spaces = spaceRows
        .map((s) => IdeaSpace(
              id: s.id,
              ownerId: s.ownerId,
              name: s.name,
              description: s.description,
              icon: s.icon,
              archivedAt: s.archivedAt,
              deletedAt: s.deletedAt,
              versionHlc: s.versionHlc,
              createdAt: s.createdAt,
              updatedAt: s.updatedAt,
            ))
        .toList();

    return IdeaDetail(
      idea: idea,
      spaces: spaces,
    );
  }

  // ─── Idea Mutations ───────────────────────────────────────────────────────

  Future<String> createIdea({
    required String ownerId,
    required String title,
    String? initialSpaceId,
    List<IdeaBlock>? initialBlocks,
    List<String>? tags,
  }) async {
    final ideaId = Id.uuidV7().value;
    final now = DateTime.now().toUtc();
    final hlc = _currentHlc();

    final blocks = initialBlocks ??
        [
          IdeaBlock(
            id: Id.uuidV7().value,
            type: IdeaBlockType.paragraph,
            content: '',
          ),
        ];

    final contentJson = jsonEncode(blocks.map((b) => b.toJson()).toList());
    final excerpt = _generateExcerpt(blocks);

    await _db.ideasDao.insertIdea(
      IdeasCompanion(
        id: Value(ideaId),
        ownerId: Value(ownerId),
        title: Value(title.trim().isEmpty ? 'Untitled' : title.trim()),
        contentJson: Value(contentJson),
        excerpt: Value(excerpt),
        isPinned: const Value(false),
        versionHlc: Value(hlc),
        createdAt: Value(now),
        updatedAt: Value(now),
      ),
    );

    await _enqueueOutbox(
      'ideas',
      ideaId,
      'INSERT',
      {
        'id': ideaId,
        'owner_id': ownerId,
        'title': title.trim().isEmpty ? 'Untitled' : title.trim(),
        'content_json': contentJson,
        'excerpt': excerpt,
        'is_pinned': false,
        'version_hlc': hlc,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      ownerId,
      hlc,
    );

    // Link initial space if provided (e.g. creating inside a space)
    if (initialSpaceId != null && initialSpaceId.isNotEmpty) {
      final linkId = Id.uuidV7().value;
      await _db.ideasDao.linkIdeaToSpace(
        IdeaSpaceLinksCompanion(
          id: Value(linkId),
          ideaId: Value(ideaId),
          ideaSpaceId: Value(initialSpaceId),
          ownerId: Value(ownerId),
          versionHlc: Value(hlc),
          createdAt: Value(now),
        ),
      );

      await _enqueueOutbox(
        'idea_space_links',
        linkId,
        'INSERT',
        {
          'id': linkId,
          'idea_id': ideaId,
          'idea_space_id': initialSpaceId,
          'owner_id': ownerId,
          'version_hlc': hlc,
          'created_at': now.toIso8601String(),
        },
        ownerId,
        hlc,
      );
    }

    // Process initial tags
    if (tags != null) {
      for (final t in tags) {
        await addTag(ideaId: ideaId, ownerId: ownerId, tagName: t);
      }
    }

    // Process internal links from blocks
    await _extractAndSyncLinks(ideaId, ownerId, blocks, hlc, now);

    return ideaId;
  }

  Future<void> updateIdeaContent({
    required String ideaId,
    required String title,
    required List<IdeaBlock> blocks,
    String? excerpt,
    bool? isPinned,
  }) async {
    final existing = await _db.ideasDao.findIdeaById(ideaId);
    if (existing == null) return;

    final now = DateTime.now().toUtc();
    final hlc = _currentHlc();
    final contentJson = jsonEncode(blocks.map((b) => b.toJson()).toList());
    final computedExcerpt = excerpt ?? _generateExcerpt(blocks);

    await _db.ideasDao.updateIdea(
      IdeasCompanion(
        id: Value(ideaId),
        title: Value(title.trim().isEmpty ? 'Untitled' : title.trim()),
        contentJson: Value(contentJson),
        excerpt: Value(computedExcerpt),
        isPinned: isPinned != null ? Value(isPinned) : Value(existing.isPinned),
        versionHlc: Value(hlc),
        updatedAt: Value(now),
      ),
    );

    await _enqueueOutbox(
      'ideas',
      ideaId,
      'UPDATE',
      {
        'id': ideaId,
        'title': title.trim().isEmpty ? 'Untitled' : title.trim(),
        'content_json': contentJson,
        'excerpt': computedExcerpt,
        'is_pinned': isPinned ?? existing.isPinned,
        'version_hlc': hlc,
        'updated_at': now.toIso8601String(),
      },
      existing.ownerId,
      hlc,
    );

    // Sync internal links
    await _extractAndSyncLinks(ideaId, existing.ownerId, blocks, hlc, now);
  }

  Future<void> assignIdeaToSpaces({
    required String ideaId,
    required String ownerId,
    required List<String> spaceIds,
  }) async {
    final now = DateTime.now().toUtc();
    final hlc = _currentHlc();

    await _db.ideasDao.clearIdeaSpaces(ideaId);

    for (final spaceId in spaceIds) {
      final linkId = Id.uuidV7().value;
      await _db.ideasDao.linkIdeaToSpace(
        IdeaSpaceLinksCompanion(
          id: Value(linkId),
          ideaId: Value(ideaId),
          ideaSpaceId: Value(spaceId),
          ownerId: Value(ownerId),
          versionHlc: Value(hlc),
          createdAt: Value(now),
        ),
      );

      await _enqueueOutbox(
        'idea_space_links',
        linkId,
        'INSERT',
        {
          'id': linkId,
          'idea_id': ideaId,
          'idea_space_id': spaceId,
          'owner_id': ownerId,
          'version_hlc': hlc,
          'created_at': now.toIso8601String(),
        },
        ownerId,
        hlc,
      );
    }
  }

  Future<void> removeIdeaFromSpace({
    required String ideaId,
    required String spaceId,
  }) async {
    await _db.ideasDao.unlinkIdeaFromSpace(ideaId, spaceId);
  }

  Future<void> deleteIdea(String ideaId, String deletedBy) async {
    final existing = await _db.ideasDao.findIdeaById(ideaId);
    if (existing == null) return;
    final hlc = _currentHlc();

    await _db.ideasDao.softDeleteIdea(ideaId, deletedBy, hlc);

    await _enqueueOutbox(
      'ideas',
      ideaId,
      'DELETE',
      {
        'id': ideaId,
        'deleted_by': deletedBy,
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'version_hlc': hlc,
      },
      existing.ownerId,
      hlc,
    );
  }

  // ─── Internal Links Extraction ────────────────────────────────────────────

  Future<void> _extractAndSyncLinks(
    String sourceIdeaId,
    String ownerId,
    List<IdeaBlock> blocks,
    String hlc,
    DateTime now,
  ) async {
    final companions = <IdeaLinksCompanion>[];

    for (final block in blocks) {
      if (block.type == IdeaBlockType.internalLink &&
          block.targetIdeaId != null &&
          block.targetIdeaId!.isNotEmpty) {
        companions.add(
          IdeaLinksCompanion(
            id: Value(Id.uuidV7().value),
            ownerId: Value(ownerId),
            sourceIdeaId: Value(sourceIdeaId),
            sourceBlockId: Value(block.id),
            targetIdeaId: Value(block.targetIdeaId!),
            displayText: Value(block.targetIdeaTitle ?? block.content),
            versionHlc: Value(hlc),
            createdAt: Value(now),
          ),
        );
      }
    }

    await _db.ideasDao.replaceIdeaLinks(sourceIdeaId, companions);
  }

  // ─── Tags ─────────────────────────────────────────────────────────────────

  Future<void> addTag({
    required String ideaId,
    required String ownerId,
    required String tagName,
  }) async {
    final cleanTag = tagName.trim().replaceAll('#', '');
    if (cleanTag.isEmpty) return;

    final hlc = _currentHlc();
    final now = DateTime.now().toUtc();

    var tag = await _db.ideasDao.findTagByName(ownerId, cleanTag);
    var tagId = tag?.id;

    if (tagId == null) {
      tagId = Id.uuidV7().value;
      await _db.ideasDao.insertTag(
        TagsCompanion(
          id: Value(tagId),
          ownerId: Value(ownerId),
          name: Value(cleanTag),
          versionHlc: Value(hlc),
          createdAt: Value(now),
        ),
      );
    }

    final linkId = Id.uuidV7().value;
    await _db.ideasDao.linkIdeaTag(
      IdeaTagsCompanion(
        id: Value(linkId),
        ideaId: Value(ideaId),
        tagId: Value(tagId),
        ownerId: Value(ownerId),
        versionHlc: Value(hlc),
        createdAt: Value(now),
      ),
    );
  }

  Future<void> removeTag({
    required String ideaId,
    required String tagId,
  }) async {
    await _db.ideasDao.unlinkIdeaTag(ideaId, tagId);
  }

  // ─── Attachments ──────────────────────────────────────────────────────────

  Future<String> addAttachment({
    required String ideaId,
    required String ownerId,
    required String fileName,
    required String storagePath,
    required String mimeType,
    required int fileSize,
    String? blockId,
  }) async {
    final id = Id.uuidV7().value;
    final now = DateTime.now().toUtc();
    final hlc = _currentHlc();

    await _db.ideasDao.insertAttachment(
      IdeaAttachmentsCompanion(
        id: Value(id),
        ideaId: Value(ideaId),
        blockId: Value(blockId),
        ownerId: Value(ownerId),
        storagePath: Value(storagePath),
        fileName: Value(fileName),
        mimeType: Value(mimeType),
        fileSize: Value(fileSize),
        versionHlc: Value(hlc),
        createdAt: Value(now),
      ),
    );

    await _enqueueOutbox(
      'idea_attachments',
      id,
      'INSERT',
      {
        'id': id,
        'idea_id': ideaId,
        'block_id': blockId,
        'owner_id': ownerId,
        'storage_path': storagePath,
        'file_name': fileName,
        'mime_type': mimeType,
        'file_size': fileSize,
        'version_hlc': hlc,
        'created_at': now.toIso8601String(),
      },
      ownerId,
      hlc,
    );

    return id;
  }

  Future<void> removeAttachment(String attachmentId) async {
    await _db.ideasDao.removeAttachment(attachmentId);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String _generateExcerpt(List<IdeaBlock> blocks) {
    for (final b in blocks) {
      if (b.content.trim().isNotEmpty) {
        final text = b.content.trim();
        return text.length > 120 ? '${text.substring(0, 117)}...' : text;
      }
    }
    return '';
  }

  Future<void> _enqueueOutbox(
    String tableName,
    String rowId,
    String op,
    Map<String, dynamic> payload,
    String userId,
    String hlc,
  ) async {
    await _db.into(_db.syncOutbox).insert(
      SyncOutboxCompanion.insert(
        userId: userId,
        op: op,
        entity: tableName,
        entityId: rowId,
        payloadJson: jsonEncode(payload),
        hlc: hlc,
        deviceId: 'local_device',
      ),
    );
  }
}
