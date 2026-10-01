import 'package:flutter/material.dart';

import '../../domain/idea_models.dart';

class SlashCommandOption {
  final IdeaBlockType type;
  final String label;
  final String description;
  final IconData icon;

  const SlashCommandOption({
    required this.type,
    required this.label,
    required this.description,
    required this.icon,
  });
}

class SlashCommandMenu extends StatefulWidget {
  final String filter;
  final Function(IdeaBlockType selectedType) onSelect;
  final VoidCallback onDismiss;

  const SlashCommandMenu({
    super.key,
    required this.filter,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  State<SlashCommandMenu> createState() => _SlashCommandMenuState();
}

class _SlashCommandMenuState extends State<SlashCommandMenu> {
  static const List<SlashCommandOption> _allOptions = [
    SlashCommandOption(
      type: IdeaBlockType.paragraph,
      label: 'Text',
      description: 'Just start writing with plain text.',
      icon: Icons.notes_outlined,
    ),
    SlashCommandOption(
      type: IdeaBlockType.heading1,
      label: 'Heading 1',
      description: 'Large section heading.',
      icon: Icons.title,
    ),
    SlashCommandOption(
      type: IdeaBlockType.heading2,
      label: 'Heading 2',
      description: 'Medium section heading.',
      icon: Icons.format_size,
    ),
    SlashCommandOption(
      type: IdeaBlockType.heading3,
      label: 'Heading 3',
      description: 'Small subsection heading.',
      icon: Icons.text_fields,
    ),
    SlashCommandOption(
      type: IdeaBlockType.checklist,
      label: 'To-do List',
      description: 'Track tasks with a checklist.',
      icon: Icons.check_box_outlined,
    ),
    SlashCommandOption(
      type: IdeaBlockType.bulletList,
      label: 'Bulleted List',
      description: 'Create a simple bulleted list.',
      icon: Icons.format_list_bulleted,
    ),
    SlashCommandOption(
      type: IdeaBlockType.numberedList,
      label: 'Numbered List',
      description: 'Create a list with numbering.',
      icon: Icons.format_list_numbered,
    ),
    SlashCommandOption(
      type: IdeaBlockType.toggle,
      label: 'Toggle List',
      description: 'Toggles hide and show content inside.',
      icon: Icons.arrow_right,
    ),
    SlashCommandOption(
      type: IdeaBlockType.quote,
      label: 'Quote',
      description: 'Capture a quote or thought.',
      icon: Icons.format_quote,
    ),
    SlashCommandOption(
      type: IdeaBlockType.code,
      label: 'Code Block',
      description: 'Capture code snippet with syntax styling.',
      icon: Icons.code,
    ),
    SlashCommandOption(
      type: IdeaBlockType.callout,
      label: 'Callout',
      description: 'Make writing stand out with an alert box.',
      icon: Icons.announcement_outlined,
    ),
    SlashCommandOption(
      type: IdeaBlockType.divider,
      label: 'Divider',
      description: 'Visually divide sections.',
      icon: Icons.horizontal_rule,
    ),
    SlashCommandOption(
      type: IdeaBlockType.internalLink,
      label: 'Link to Idea',
      description: 'Reference an existing idea ([[Idea]]).',
      icon: Icons.link,
    ),
    SlashCommandOption(
      type: IdeaBlockType.image,
      label: 'Image',
      description: 'Upload or embed with a link.',
      icon: Icons.image_outlined,
    ),
    SlashCommandOption(
      type: IdeaBlockType.file,
      label: 'File Attachment',
      description: 'Attach PDF, XLSX, DOCX, etc.',
      icon: Icons.attach_file,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final query = widget.filter.toLowerCase().replaceAll('/', '').trim();
    final filtered = _allOptions.where((opt) {
      if (query.isEmpty) return true;
      return opt.label.toLowerCase().contains(query) ||
          opt.description.toLowerCase().contains(query) ||
          opt.type.name.toLowerCase().contains(query);
    }).toList();

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 280, maxWidth: 320),
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
                    'BASIC BLOCKS',
                    style: TextStyle(
                      color: Color(0xFFC6F135),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  InkWell(
                    onTap: widget.onDismiss,
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
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No matching blocks',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return InkWell(
                          onTap: () => widget.onSelect(item.type),
                          hoverColor: const Color(0xFFC6F135).withValues(alpha: 0.1),
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
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: Icon(
                                    item.icon,
                                    color: const Color(0xFFC6F135),
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        item.description,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
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
