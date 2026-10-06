import 'package:flutter/material.dart';

import '../../../../app/kratos_motion.dart';
import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../domain/idea_models.dart';

class ManageIdeaSpacesDialog extends StatefulWidget {
  final List<IdeaSpace> availableSpaces;
  final List<String> currentSpaceIds;
  final Function(List<String> selectedSpaceIds) onSave;

  const ManageIdeaSpacesDialog({
    super.key,
    required this.availableSpaces,
    required this.currentSpaceIds,
    required this.onSave,
  });

  @override
  State<ManageIdeaSpacesDialog> createState() => _ManageIdeaSpacesDialogState();
}

class _ManageIdeaSpacesDialogState extends State<ManageIdeaSpacesDialog> {
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.currentSpaceIds.toSet();
  }

  @override
  Widget build(BuildContext context) {
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
                        Icons.folder_copy_outlined,
                        color: lime,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ADD TO IDEA SPACES',
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
                const SizedBox(height: 8),
                Text(
                  'An idea can belong to zero, one, or multiple spaces simultaneously.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: mutedColor,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.availableSpaces.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No Idea Spaces created yet.\nCreate one from the Dashboard.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: mutedColor.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: widget.availableSpaces.length,
                      separatorBuilder: (_, _) => Divider(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : KratosTheme.lightBorderGlass,
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final space = widget.availableSpaces[index];
                        final isChecked = _selectedIds.contains(space.id);
                        return CheckboxListTile(
                          value: isChecked,
                          checkColor: isDark ? const Color(0xFF020302) : Colors.white,
                          activeColor: lime,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            space.name,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: space.description != null && space.description!.isNotEmpty
                              ? Text(
                                  space.description!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: mutedColor,
                                    fontSize: 11,
                                  ),
                                )
                              : null,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(space.id);
                              } else {
                                _selectedIds.remove(space.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),
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
                        widget.onSave(_selectedIds.toList());
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
                          'DONE',
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
    );
  }
}
