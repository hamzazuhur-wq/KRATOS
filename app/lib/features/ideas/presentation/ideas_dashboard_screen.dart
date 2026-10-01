import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';

import '../../../app/kratos_visuals.dart';
import '../../../data/drift/app_database.dart';
import '../data/ideas_repository.dart';
import '../domain/idea_models.dart';
import 'dialogs/create_idea_space_dialog.dart';
import 'dialogs/idea_search_dialog.dart';
import 'dialogs/manage_idea_spaces_dialog.dart';
import 'idea_editor_screen.dart';
import 'idea_space_screen.dart';
import 'widgets/idea_card.dart';

class IdeasDashboardScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;

  const IdeasDashboardScreen({
    super.key,
    required this.database,
    required this.ownerId,
  });

  @override
  State<IdeasDashboardScreen> createState() => _IdeasDashboardScreenState();
}

class _IdeasDashboardScreenState extends State<IdeasDashboardScreen> {
  late final IdeasRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = IdeasRepository(widget.database);
  }

  Future<void> _createQuickIdea() async {
    // When created from Dashboard/Home, creates an Uncategorized idea without forcing a Space! (Rule #9 Case B)
    final newId = await _repository.createIdea(
      ownerId: widget.ownerId,
      title: 'Untitled',
    );

    if (mounted) {
      Navigator.of(context).push(
        KratosMaterialPageRoute(
          builder: (_) => IdeaEditorScreen(
            database: widget.database,
            ownerId: widget.ownerId,
            ideaId: newId,
          ),
        ),
      );
    }
  }

  void _openSearch() {
    showDialog(
      context: context,
      builder: (_) => IdeaSearchDialog(
        repository: _repository,
        ownerId: widget.ownerId,
        onSelect: (selectedIdea) {
          Navigator.of(context).push(
            KratosMaterialPageRoute(
              builder: (_) => IdeaEditorScreen(
                database: widget.database,
                ownerId: widget.ownerId,
                ideaId: selectedIdea.idea.id,
              ),
            ),
          );
        },
      ),
    );
  }

  void _openCreateSpace() {
    showDialog(
      context: context,
      builder: (_) => CreateIdeaSpaceDialog(
        onSave: (name, desc, icon) async {
          await _repository.createSpace(
            ownerId: widget.ownerId,
            name: name,
            description: desc,
            icon: icon,
          );
        },
      ),
    );
  }

  IconData _getIconForName(String? iconName) {
    switch (iconName) {
      case 'lightbulb':
        return Icons.lightbulb_outline;
      case 'work':
        return Icons.work_outline;
      case 'psychology':
        return Icons.psychology_outlined;
      case 'menu_book':
        return Icons.menu_book_outlined;
      case 'science':
        return Icons.science_outlined;
      case 'palette':
        return Icons.palette_outlined;
      case 'code':
        return Icons.code;
      case 'business':
        return Icons.business_center_outlined;
      case 'favorite':
        return Icons.favorite_border;
      case 'folder':
      default:
        return Icons.folder_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const KratosEnvironment(),
          CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFC6F135)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.lightbulb_outlined,
                                        color: Color(0xFFC6F135),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Flexible(
                                      child: Text(
                                        'IDEA CAPTURE',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Capture your thoughts, ideas and knowledge.',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFC6F135),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text(
                              'New Idea',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            onPressed: _createQuickIdea,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Search Bar
                      InkWell(
                        onTap: _openSearch,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141814),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.search,
                                color: Colors.white38,
                                size: 20,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Search ideas, spaces, notes...',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Spaces Header & + New Space
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'IDEA SPACES',
                            style: TextStyle(
                              color: Color(0xFFC6F135),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          InkWell(
                            onTap: _openCreateSpace,
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: Color(0xFFC6F135),
                                    size: 14,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'New Space',
                                    style: TextStyle(
                                      color: Color(0xFFC6F135),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Spaces Grid
              StreamBuilder<List<IdeaSpaceSummary>>(
                stream: _repository.watchIdeaSpacesWithCounts(widget.ownerId),
                builder: (context, snapshot) {
                  final spaces = snapshot.data ?? [];

                  return StreamBuilder<int>(
                    stream: _repository.watchUncategorizedCount(widget.ownerId),
                    builder: (context, uncatSnapshot) {
                      final uncatCount = uncatSnapshot.data ?? 0;

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisExtent: 110,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            // First card is Uncategorized / Inbox
                            if (index == 0) {
                              return _buildSpaceCard(
                                title: 'Uncategorized',
                                subtitle: 'Inbox',
                                count: uncatCount,
                                icon: Icons.inbox_outlined,
                                isUncategorized: true,
                                onTap: () {
                                  Navigator.of(context).push(
                                    KratosMaterialPageRoute(
                                      builder: (_) => IdeaSpaceScreen(
                                        database: widget.database,
                                        ownerId: widget.ownerId,
                                        spaceId: null,
                                      ),
                                    ),
                                  );
                                },
                              );
                            }

                            final summary = spaces[index - 1];
                            return _buildSpaceCard(
                              title: summary.space.name,
                              subtitle: summary.space.description,
                              count: summary.ideaCount,
                              icon: _getIconForName(summary.space.icon),
                              onTap: () {
                                Navigator.of(context).push(
                                  KratosMaterialPageRoute(
                                    builder: (_) => IdeaSpaceScreen(
                                      database: widget.database,
                                      ownerId: widget.ownerId,
                                      spaceId: summary.space.id,
                                    ),
                                  ),
                                );
                              },
                            );
                          }, childCount: spaces.length + 1),
                        ),
                      );
                    },
                  );
                },
              ),

              // Recent Ideas Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC6F135)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.history,
                          color: Color(0xFFC6F135),
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'RECENT IDEAS',
                        style: TextStyle(
                          color: Color(0xFFC6F135),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Recent Ideas Stream
              StreamBuilder<List<IdeaDetail>>(
                stream: _repository.watchAllIdeas(widget.ownerId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(
                            color: Color(0xFFC6F135),
                          ),
                        ),
                      ),
                    );
                  }

                  final ideas = snapshot.data ?? [];
                  if (ideas.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 32,
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                size: 40,
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'No ideas captured yet',
                                style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFC6F135),
                                  side: const BorderSide(
                                    color: Color(0xFFC6F135),
                                  ),
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Capture First Idea'),
                                onPressed: _createQuickIdea,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = ideas[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: IdeaCard(
                            ideaDetail: item,
                            onTap: () {
                              Navigator.of(context).push(
                                KratosMaterialPageRoute(
                                  builder: (_) => IdeaEditorScreen(
                                    database: widget.database,
                                    ownerId: widget.ownerId,
                                    ideaId: item.idea.id,
                                  ),
                                ),
                              );
                            },
                            onManageSpaces: () async {
                              final allSpaces = await _repository
                                  .watchIdeaSpacesWithCounts(widget.ownerId)
                                  .first;
                              if (!context.mounted) return;
                              final available = allSpaces
                                  .map((s) => s.space)
                                  .toList();
                              final curIds = item.spaces
                                  .map((s) => s.id)
                                  .toList();

                              showDialog(
                                context: context,
                                builder: (_) => ManageIdeaSpacesDialog(
                                  availableSpaces: available,
                                  currentSpaceIds: curIds,
                                  onSave: (selIds) async {
                                    await _repository.assignIdeaToSpaces(
                                      ideaId: item.idea.id,
                                      ownerId: widget.ownerId,
                                      spaceIds: selIds,
                                    );
                                  },
                                ),
                              );
                            },
                            onDelete: () async {
                              await _repository.deleteIdea(
                                item.idea.id,
                                widget.ownerId,
                              );
                            },
                          ),
                        );
                      }, childCount: ideas.length),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpaceCard({
    required String title,
    String? subtitle,
    required int count,
    required IconData icon,
    bool isUncategorized = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF141814),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUncategorized
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFFC6F135).withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isUncategorized
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFC6F135).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    color: isUncategorized
                        ? Colors.white70
                        : const Color(0xFFC6F135),
                    size: 18,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: isUncategorized
                          ? Colors.white70
                          : const Color(0xFFC6F135),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '$count ${count == 1 ? 'Idea' : 'Ideas'}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
