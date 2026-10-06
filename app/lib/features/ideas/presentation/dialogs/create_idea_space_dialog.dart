import 'package:flutter/material.dart';

import '../../../../app/kratos_motion.dart';
import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final textColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final mutedColor = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: KratosModalEntrance(
          child: KratosGlassCard(
            variant: KratosSurfaceVariant.elevated,
            borderRadius: BorderRadius.circular(22),
            padding: const EdgeInsets.all(22),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: lime.withValues(alpha: isDark ? 0.15 : 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: lime.withValues(alpha: 0.3)),
                        ),
                        child: Icon(
                          Icons.dashboard_customize_outlined,
                          color: lime,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          (isEditing ? 'EDIT IDEA SPACE' : 'NEW IDEA SPACE'),
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

              // Name Field
              Text(
                'SPACE NAME *',
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  color: mutedColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: TextStyle(fontFamily: 'Inter', color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Professional, Mindset, Research',
                  hintStyle: TextStyle(fontFamily: 'Inter', color: mutedColor.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF141714) : Colors.white.withValues(alpha: 0.7),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : KratosTheme.lightBorderGlass,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: lime, width: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Description Field
              Text(
                'DESCRIPTION (OPTIONAL)',
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  color: mutedColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                style: TextStyle(fontFamily: 'Inter', color: textColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'What kind of ideas belong in this space?',
                  hintStyle: TextStyle(fontFamily: 'Inter', color: mutedColor.withValues(alpha: 0.6)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF141714) : Colors.white.withValues(alpha: 0.7),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : KratosTheme.lightBorderGlass,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: lime, width: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Icon Selector
              Text(
                'ICON',
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  color: mutedColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
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
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? lime.withValues(alpha: isDark ? 0.2 : 0.15)
                            : (isDark ? const Color(0xFF141714) : Colors.white.withValues(alpha: 0.6)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? lime
                              : (isDark ? Colors.white.withValues(alpha: 0.08) : KratosTheme.lightBorderGlass),
                          width: isSelected ? 1.2 : 1.0,
                        ),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: isSelected
                            ? lime
                            : mutedColor,
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
                    style: TextButton.styleFrom(
                      foregroundColor: mutedColor,
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  KratosPressable(
                    onTap: () {
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
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      decoration: BoxDecoration(
                        color: lime,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          if (isDark)
                            BoxShadow(
                              color: lime.withValues(alpha: 0.2),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: Text(
                        (isEditing ? 'SAVE CHANGES' : 'CREATE SPACE'),
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? const Color(0xFF020302) : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}
