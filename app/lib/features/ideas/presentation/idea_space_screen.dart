import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';

import '../../../data/drift/app_database.dart';
import '../data/ideas_repository.dart';
import '../domain/idea_models.dart';
import 'dialogs/create_idea_space_dialog.dart';
import 'dialogs/manage_idea_spaces_dialog.dart';
import 'idea_editor_screen.dart';
import 'widgets/idea_card.dart';

class IdeaSpaceScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final String? spaceId; // null means "Uncategorized / Inbox"

  const IdeaSpaceScreen({
    super.key,
    required this.database,
    required this.ownerId,
    this.spaceId,
  });

  @override
  State<IdeaSpaceScreen> createState() => _IdeaSpaceScreenState();
}

class _IdeaSpaceScreenState extends State<IdeaSpaceScreen> {
  late final IdeasRepository _repository;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _repository = IdeasRepository(widget.database);
  }

  bool get isUncategorized => widget.spaceId == null;

  Future<void> _createNewIdea() async {
    // When inside a Space, automatically assign that space without asking! (Rule #9 Case A)
    final newId = await _repository.createIdea(
      ownerId: widget.ownerId,
      title: 'Untitled',
      initialSpaceId: widget.spaceId,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!isUncategorized) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white70),
              onPressed: () async {
                final space = await _repository.getSpace(widget.spaceId!);
                if (!context.mounted || space == null) return;
                showDialog(
                  context: context,
                  builder: (_) => CreateIdeaSpaceDialog(
                    existingSpace: space,
                    onSave: (name, desc, icon) async {
                      await _repository.updateSpace(
                        spaceId: space.id,
                        name: name,
                        description: desc,
                        icon: icon,
                      );
                    },
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1B221B),
                    title: const Text(
                      'Delete Idea Space?',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'Ideas in this space will not be deleted; they will simply be unassigned from this space.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await _repository.deleteSpace(
                    widget.spaceId!,
                    widget.ownerId,
                  );
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
            ),
          ],
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          StreamBuilder<List<IdeaDetail>>(
            stream: isUncategorized
                ? _repository.watchUncategorizedIdeas(widget.ownerId)
                : _repository.watchIdeasInSpace(
                    widget.ownerId,
                    widget.spaceId!,
                  ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFFC6F135)),
                );
              }

              final allIdeas = snapshot.data ?? [];
              final filteredIdeas = allIdeas.where((item) {
                if (_searchQuery.isEmpty) return true;
                final q = _searchQuery.toLowerCase();
                return item.idea.title.toLowerCase().contains(q) ||
                    (item.idea.excerpt != null &&
                        item.idea.excerpt!.toLowerCase().contains(q));
              }).toList();

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC6F135)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  isUncategorized
                                      ? Icons.inbox_outlined
                                      : Icons.folder_outlined,
                                  color: const Color(0xFFC6F135),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isUncategorized
                                          ? 'Uncategorized / Inbox'
                                          : 'Idea Space',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${allIdeas.length} ideas saved',
                                      style: const TextStyle(
                                        color: Color(0xFFC6F135),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Action bar: Search + New Idea button
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search ideas in this space...',
                                    hintStyle: const TextStyle(
                                      color: Colors.white30,
                                      fontSize: 13,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search,
                                      color: Colors.white38,
                                      size: 18,
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF141814),
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: 0.08,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFC6F135),
                                      ),
                                    ),
                                  ),
                                  onChanged: (val) =>
                                      setState(() => _searchQuery = val),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC6F135),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text(
                                  'New Idea',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                onPressed: _createNewIdea,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  if (filteredIdeas.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              size: 48,
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No ideas in this space yet'
                                  : 'No matching ideas found',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (_searchQuery.isEmpty)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFC6F135),
                                  side: const BorderSide(
                                    color: Color(0xFFC6F135),
                                  ),
                                ),
                                icon: const Icon(Icons.add, size: 16),
                                label: const Text('Capture First Idea'),
                                onPressed: _createNewIdea,
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = filteredIdeas[index];
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
                        }, childCount: filteredIdeas.length),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
