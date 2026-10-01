import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/kratos_dropdown.dart';
import '../../domain/idea_models.dart';

class IdeaCard extends StatelessWidget {
  final IdeaDetail ideaDetail;
  final VoidCallback onTap;
  final VoidCallback onManageSpaces;
  final VoidCallback onDelete;

  const IdeaCard({
    super.key,
    required this.ideaDetail,
    required this.onTap,
    required this.onManageSpaces,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final idea = ideaDetail.idea;
    final spaces = ideaDetail.spaces;
    final dateStr = DateFormat('MMM d, y • h:mm a').format(idea.updatedAt.toLocal());

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF141814),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: idea.isPinned
                ? const Color(0xFFC6F135).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: idea.isPinned ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (idea.isPinned)
                  const Padding(
                    padding: EdgeInsets.only(right: 8, top: 2),
                    child: Icon(
                      Icons.push_pin,
                      color: Color(0xFFC6F135),
                      size: 16,
                    ),
                  ),
                Expanded(
                  child: Text(
                    idea.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                KratosPopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white38,
                    size: 18,
                  ),
                  onSelected: (val) {
                    if (val == 'spaces') onManageSpaces();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    const KratosPopupMenuItem(
                      value: 'spaces',
                      child: Row(
                        children: [
                          Icon(Icons.folder_outlined,
                              color: Color(0xFFC6F135), size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Manage Spaces',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const KratosPopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              color: Colors.redAccent, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Delete Idea',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (idea.excerpt != null && idea.excerpt!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                idea.excerpt!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                if (spaces.isNotEmpty)
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: spaces.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC6F135).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: const Color(0xFFC6F135).withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.folder_outlined,
                                color: Color(0xFFC6F135),
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                s.name,
                                style: const TextStyle(
                                  color: Color(0xFFC6F135),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Uncategorized',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: const TextStyle(
                    color: Colors.white30,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
