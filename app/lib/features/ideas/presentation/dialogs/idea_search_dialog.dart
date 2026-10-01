import 'package:flutter/material.dart';

import '../../data/ideas_repository.dart';
import '../../domain/idea_models.dart';

class IdeaSearchDialog extends StatefulWidget {
  final IdeasRepository repository;
  final String ownerId;
  final Function(IdeaDetail idea) onSelect;

  const IdeaSearchDialog({
    super.key,
    required this.repository,
    required this.ownerId,
    required this.onSelect,
  });

  @override
  State<IdeaSearchDialog> createState() => _IdeaSearchDialogState();
}

class _IdeaSearchDialogState extends State<IdeaSearchDialog> {
  final TextEditingController _queryController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF141814),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFFC6F135).withValues(alpha: 0.2),
        ),
      ),
      child: Container(
        width: 500,
        height: 500,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _queryController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search ideas by title or content...',
                hintStyle: const TextStyle(color: Colors.white30),
                prefixIcon: const Icon(Icons.search, color: Color(0xFFC6F135)),
                filled: true,
                fillColor: const Color(0xFF1B221B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFC6F135)),
                ),
              ),
              onChanged: (val) => setState(() => _query = val),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<List<IdeaDetail>>(
                stream: widget.repository.watchAllIdeas(
                  widget.ownerId,
                  query: _query.isEmpty ? null : _query,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFC6F135)),
                    );
                  }
                  final ideas = snapshot.data ?? [];
                  if (ideas.isEmpty) {
                    return Center(
                      child: Text(
                        _query.isEmpty
                            ? 'No ideas found'
                            : 'No ideas matching "$_query"',
                        style: const TextStyle(color: Colors.white38),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: ideas.length,
                    separatorBuilder: (_, _) => const Divider(
                      color: Colors.white12,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final item = ideas[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: const Icon(
                          Icons.lightbulb_outline,
                          color: Color(0xFFC6F135),
                          size: 20,
                        ),
                        title: Text(
                          item.idea.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: item.idea.excerpt != null &&
                                item.idea.excerpt!.isNotEmpty
                            ? Text(
                                item.idea.excerpt!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        trailing: item.spaces.isNotEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC6F135).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.spaces.first.name,
                                  style: const TextStyle(
                                    color: Color(0xFFC6F135),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onSelect(item);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
