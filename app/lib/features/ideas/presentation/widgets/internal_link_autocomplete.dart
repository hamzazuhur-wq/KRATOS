import 'package:flutter/material.dart';

import '../../data/ideas_repository.dart';
import '../../domain/idea_models.dart';

class InternalLinkAutocomplete extends StatelessWidget {
  final IdeasRepository repository;
  final String ownerId;
  final String query;
  final Function(IdeaDetail selectedIdea) onSelect;
  final VoidCallback onDismiss;

  const InternalLinkAutocomplete({
    super.key,
    required this.repository,
    required this.ownerId,
    required this.query,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cleanQuery = query.replaceAll('[[', '').replaceAll(']]', '').trim();

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 250, maxWidth: 320),
        decoration: BoxDecoration(
          color: const Color(0xFF141814),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFC6F135).withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'LINK TO AN EXISTING IDEA',
                    style: TextStyle(
                      color: Color(0xFFC6F135),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  InkWell(
                    onTap: onDismiss,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white38,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Flexible(
              child: StreamBuilder<List<IdeaDetail>>(
                stream: repository.watchAllIdeas(
                  ownerId,
                  query: cleanQuery.isEmpty ? null : cleanQuery,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(
                          color: Color(0xFFC6F135),
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  final ideas = snapshot.data ?? [];
                  if (ideas.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        cleanQuery.isEmpty
                            ? 'No existing ideas to link'
                            : 'No idea found matching "$cleanQuery"',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: ideas.length,
                    itemBuilder: (context, index) {
                      final item = ideas[index];
                      return InkWell(
                        onTap: () => onSelect(item),
                        hoverColor:
                            const Color(0xFFC6F135).withValues(alpha: 0.1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1B221B),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.link,
                                  color: Color(0xFFC6F135),
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.idea.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
