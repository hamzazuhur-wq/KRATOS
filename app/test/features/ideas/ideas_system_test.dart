import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/ideas/data/ideas_repository.dart';
import 'package:kratos_app/features/ideas/domain/idea_models.dart';

void main() {
  late AppDatabase db;
  late IdeasRepository repo;
  const userId = 'usr_test_ideas_01';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = IdeasRepository(db);

    // Insert user into DB
    await db.into(db.users).insert(
          UsersCompanion.insert(
            id: userId,
            displayName: const drift.Value('Test Operative'),
            deviceId: 'dev_test_01',
            timezone: 'UTC',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('KRATOS Idea Capture & Knowledge System Tests', () {
    test('1. Create and edit an Idea with structured blocks and autosave',
        () async {
      final initialBlocks = [
        const IdeaBlock(
          id: 'blk_1',
          type: IdeaBlockType.heading1,
          content: 'Hermes Agent Architecture',
        ),
        const IdeaBlock(
          id: 'blk_2',
          type: IdeaBlockType.paragraph,
          content: 'Autonomous coding agent design for local orchestration.',
        ),
      ];

      final ideaId = await repo.createIdea(
        ownerId: userId,
        title: 'Hermes Agent Architecture',
        initialBlocks: initialBlocks,
      );

      final detail = await repo.getIdeaDetail(ideaId);
      expect(detail, isNotNull);
      expect(detail!.idea.title, equals('Hermes Agent Architecture'));
      expect(detail.idea.blocks.length, equals(2));
      expect(detail.idea.blocks[0].type, equals(IdeaBlockType.heading1));
      expect(detail.idea.blocks[1].type, equals(IdeaBlockType.paragraph));

      // Update blocks and toggle isPinned
      final updatedBlocks = [
        ...initialBlocks,
        const IdeaBlock(
          id: 'blk_3',
          type: IdeaBlockType.code,
          content: 'class HermesRunner {}',
          payload: {'language': 'dart'},
        ),
      ];

      await repo.updateIdeaContent(
        ideaId: ideaId,
        title: 'Hermes Architecture V2',
        blocks: updatedBlocks,
        isPinned: true,
      );

      final updatedDetail = await repo.getIdeaDetail(ideaId);
      expect(updatedDetail!.idea.title, equals('Hermes Architecture V2'));
      expect(updatedDetail.idea.isPinned, isTrue);
      expect(updatedDetail.idea.blocks.length, equals(3));
      expect(updatedDetail.idea.blocks[2].type, equals(IdeaBlockType.code));
      expect(updatedDetail.idea.blocks[2].payload['language'], equals('dart'));
    });

    test('2. Idea Spaces: create, query with counts, and multi-space assignment',
        () async {
      final space1 = await repo.createSpace(
        ownerId: userId,
        name: 'Professional',
        description: 'Work and engineering',
        icon: 'work',
      );

      final space2 = await repo.createSpace(
        ownerId: userId,
        name: 'Business',
        description: 'Ventures and economics',
        icon: 'business',
      );

      final space3 = await repo.createSpace(
        ownerId: userId,
        name: 'Learning',
        description: 'Books and papers',
        icon: 'menu_book',
      );

      // Create an Idea and assign to all three spaces
      final ideaId = await repo.createIdea(
        ownerId: userId,
        title: 'AI Business Model',
      );

      await repo.assignIdeaToSpaces(
        ideaId: ideaId,
        ownerId: userId,
        spaceIds: [space1, space2, space3],
      );

      final detail = await repo.getIdeaDetail(ideaId);
      expect(detail!.spaces.length, equals(3));
      final spaceNames = detail.spaces.map((s) => s.name).toSet();
      expect(spaceNames, containsAll(['Professional', 'Business', 'Learning']));

      // Check count summaries
      final summaries = await repo.watchIdeaSpacesWithCounts(userId).first;
      expect(summaries.length, equals(3));
      for (final s in summaries) {
        expect(s.ideaCount, equals(1));
      }

      // Verify querying ideas in specific spaces returns the exact same Idea ID
      final ideasInProf = await repo.watchIdeasInSpace(userId, space1).first;
      final ideasInBus = await repo.watchIdeasInSpace(userId, space2).first;
      final ideasInLearn = await repo.watchIdeasInSpace(userId, space3).first;

      expect(ideasInProf.first.idea.id, equals(ideaId));
      expect(ideasInBus.first.idea.id, equals(ideaId));
      expect(ideasInLearn.first.idea.id, equals(ideaId));
    });

    test('3. Uncategorized / Inbox: ideas without spaces appear in Inbox',
        () async {
      final spaceId = await repo.createSpace(
        ownerId: userId,
        name: 'Research',
      );

      // Create idea without space (from Home / Quick Capture)
      final uncatId = await repo.createIdea(
        ownerId: userId,
        title: 'Random Shower Thought',
      );

      // Create idea inside space
      final spaceIdeaId = await repo.createIdea(
        ownerId: userId,
        title: 'Quantum Computing Paper',
        initialSpaceId: spaceId,
      );

      final uncatCount = await repo.watchUncategorizedCount(userId).first;
      expect(uncatCount, equals(1));

      final uncatIdeas = await repo.watchUncategorizedIdeas(userId).first;
      expect(uncatIdeas.length, equals(1));
      expect(uncatIdeas.first.idea.id, equals(uncatId));
      expect(uncatIdeas.first.spaces, isEmpty);

      final spaceIdeas = await repo.watchIdeasInSpace(userId, spaceId).first;
      expect(spaceIdeas.length, equals(1));
      expect(spaceIdeas.first.idea.id, equals(spaceIdeaId));
    });

    test(
        '4. Internal Links and Backlinks: ID-based resolution preserves links upon renaming',
        () async {
      // Create Target Idea (Idea B)
      final ideaBId = await repo.createIdea(
        ownerId: userId,
        title: 'Hermes Architecture',
      );

      // Create Source Idea (Idea A) with an internal link pointing to Idea B ID
      final blocksA = [
        const IdeaBlock(
          id: 'blk_a1',
          type: IdeaBlockType.paragraph,
          content: 'Reference to core system:',
        ),
        IdeaBlock(
          id: 'blk_a2',
          type: IdeaBlockType.internalLink,
          content: 'Hermes Architecture',
          payload: {
            'target_idea_id': ideaBId,
            'target_idea_title': 'Hermes Architecture',
          },
        ),
      ];

      final ideaAId = await repo.createIdea(
        ownerId: userId,
        title: 'Autonomous Systems Overview',
        initialBlocks: blocksA,
      );

      // Verify Backlink on Idea B points to Idea A
      final backlinksToB = await repo.watchBacklinks(ideaBId).first;
      expect(backlinksToB.length, equals(1));
      expect(backlinksToB.first.sourceIdeaId, equals(ideaAId));
      expect(backlinksToB.first.sourceIdeaTitle,
          equals('Autonomous Systems Overview'));

      // Now rename Idea B -> 'Hermes Agent Architecture V3'
      await repo.updateIdeaContent(
        ideaId: ideaBId,
        title: 'Hermes Agent Architecture V3',
        blocks: [
          const IdeaBlock(
            id: 'blk_b1',
            type: IdeaBlockType.heading1,
            content: 'Updated Title Heading',
          ),
        ],
      );

      // Re-query backlinks on Idea B
      final updatedBacklinks = await repo.watchBacklinks(ideaBId).first;
      expect(updatedBacklinks.length, equals(1));
      expect(updatedBacklinks.first.sourceIdeaId, equals(ideaAId));

      // Query Idea A: its internal link still targets ideaBId
      final detailA = await repo.getIdeaDetail(ideaAId);
      final linkBlock = detailA!.idea.blocks
          .firstWhere((b) => b.type == IdeaBlockType.internalLink);
      expect(linkBlock.targetIdeaId, equals(ideaBId));
    });

    test('5. Toggle Block: collapsible state persistence', () async {
      final blocks = [
        const IdeaBlock(
          id: 'toggle_1',
          type: IdeaBlockType.toggle,
          content: 'Technical Specs',
          payload: {
            'is_collapsed': true,
            'details': 'Memory: 16GB, SQLite: v3.45',
          },
        ),
      ];

      final ideaId = await repo.createIdea(
        ownerId: userId,
        title: 'Server Specs',
        initialBlocks: blocks,
      );

      final detail = await repo.getIdeaDetail(ideaId);
      expect(detail!.idea.blocks.first.isCollapsed, isTrue);

      // Expand toggle
      final expandedBlocks = [
        blocks[0].copyWith(
          payload: {
            'is_collapsed': false,
            'details': 'Memory: 16GB, SQLite: v3.45',
          },
        ),
      ];

      await repo.updateIdeaContent(
        ideaId: ideaId,
        title: 'Server Specs',
        blocks: expandedBlocks,
      );

      final updatedDetail = await repo.getIdeaDetail(ideaId);
      expect(updatedDetail!.idea.blocks.first.isCollapsed, isFalse);
    });

    test('6. Sync Outbox pattern: all operations enqueue sync outbox payloads',
        () async {
      final spaceId = await repo.createSpace(
        ownerId: userId,
        name: 'Mindset',
      );

      await repo.createIdea(
        ownerId: userId,
        title: 'Stoic Principles',
        initialSpaceId: spaceId,
      );

      final outboxItems = await (db.select(db.syncOutbox)).get();
      final tableNames = outboxItems.map((o) => o.entity).toSet();

      expect(tableNames, contains('idea_spaces'));
      expect(tableNames, contains('ideas'));
      expect(tableNames, contains('idea_space_links'));
    });
  });
}
