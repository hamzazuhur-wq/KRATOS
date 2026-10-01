import 'package:flutter/material.dart';

import '../../data/ideas_repository.dart';
import '../../domain/idea_models.dart';

class BacklinksSection extends StatelessWidget {
  final IdeasRepository repository;
  final String ideaId;
  final Function(String sourceIdeaId) onOpenIdea;

  const BacklinksSection({
    super.key,
    required this.repository,
    required this.ideaId,
    required this.onOpenIdea,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<IdeaBacklinkItem>>(
      stream: repository.watchBacklinks(ideaId),
      builder: (context, snapshot) {
        final backlinks = snapshot.data ?? [];
        if (backlinks.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 32, bottom: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141814),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC6F135).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.hub_outlined,
                      color: Color(0xFFC6F135),
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'BACKLINKS (${backlinks.length})',
                    style: const TextStyle(
                      color: Color(0xFFC6F135),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: backlinks.map((link) {
                  return InkWell(
                    onTap: () => onOpenIdea(link.sourceIdeaId),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B221B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFC6F135).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_back,
                            color: Color(0xFFC6F135),
                            size: 12,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            link.sourceIdeaTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
