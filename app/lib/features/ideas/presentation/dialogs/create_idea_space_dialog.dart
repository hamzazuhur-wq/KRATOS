import 'package:flutter/material.dart';

import '../../domain/idea_models.dart';

class CreateIdeaSpaceDialog extends StatefulWidget {
  final IdeaSpace? existingSpace;
  final Function(String name, String? description, String? icon) onSave;

  const CreateIdeaSpaceDialog({
    super.key,
    this.existingSpace,
    required this.onSave,
  });

  @override
  State<CreateIdeaSpaceDialog> createState() => _CreateIdeaSpaceDialogState();
}

class _CreateIdeaSpaceDialogState extends State<CreateIdeaSpaceDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  String _selectedIcon = 'folder';

  final List<Map<String, dynamic>> _availableIcons = [
    {'name': 'folder', 'icon': Icons.folder_outlined},
    {'name': 'lightbulb', 'icon': Icons.lightbulb_outline},
    {'name': 'work', 'icon': Icons.work_outline},
    {'name': 'psychology', 'icon': Icons.psychology_outlined},
    {'name': 'menu_book', 'icon': Icons.menu_book_outlined},
    {'name': 'science', 'icon': Icons.science_outlined},
    {'name': 'palette', 'icon': Icons.palette_outlined},
    {'name': 'code', 'icon': Icons.code},
    {'name': 'business', 'icon': Icons.business_center_outlined},
    {'name': 'favorite', 'icon': Icons.favorite_border},
  ];

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.existingSpace?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.existingSpace?.description ?? '');
    _selectedIcon = widget.existingSpace?.icon ?? 'folder';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSpace != null;

    return Dialog(
      backgroundColor: const Color(0xFF141814),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: const Color(0xFFC6F135).withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC6F135).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.dashboard_customize_outlined,
                      color: Color(0xFFC6F135),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isEditing ? 'Edit Idea Space' : 'New Idea Space',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Name Field
              const Text(
                'Space Name',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Professional, Mindset, Research',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF1B221B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFC6F135)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description Field
              const Text(
                'Description (Optional)',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'What kind of ideas belong in this space?',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: const Color(0xFF1B221B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFC6F135)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Icon Selector
              const Text(
                'Icon',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableIcons.map((item) {
                  final isSelected = _selectedIcon == item['name'];
                  return InkWell(
                    onTap: () => setState(() => _selectedIcon = item['name']),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFC6F135).withValues(alpha: 0.2)
                            : const Color(0xFF1B221B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFFC6F135)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: isSelected
                            ? const Color(0xFFC6F135)
                            : Colors.white70,
                        size: 20,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC6F135),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      final name = _nameController.text.trim();
                      if (name.isEmpty) return;
                      widget.onSave(
                        name,
                        _descriptionController.text.trim().isEmpty
                            ? null
                            : _descriptionController.text.trim(),
                        _selectedIcon,
                      );
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      isEditing ? 'Save Changes' : 'Create Space',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
