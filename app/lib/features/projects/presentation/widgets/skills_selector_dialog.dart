import 'package:flutter/material.dart';
import '../../../../app/kratos_motion.dart';
import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../../../data/drift/app_database.dart';

/// Modal dialog providing search and unlimited multi-selection of real persisted Skills.
class SkillsSelectorDialog extends StatefulWidget {
  final List<Skill> allSkills;
  final Set<String> initiallySelectedIds;

  const SkillsSelectorDialog({
    super.key,
    required this.allSkills,
    required this.initiallySelectedIds,
  });

  @override
  State<SkillsSelectorDialog> createState() => _SkillsSelectorDialogState();
}

class _SkillsSelectorDialogState extends State<SkillsSelectorDialog> {
  late final Set<String> _selectedIds;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initiallySelectedIds);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final textColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final mutedColor = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary;

    final filteredSkills = widget.allSkills.where((s) {
      if (_search.trim().isEmpty) return true;
      return s.name.toLowerCase().contains(_search.trim().toLowerCase()) ||
          (s.description?.toLowerCase().contains(_search.trim().toLowerCase()) ?? false);
    }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 580),
        child: KratosModalEntrance(
          child: KratosGlassCard(
            variant: KratosSurfaceVariant.elevated,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SELECT SKILLS',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: lime,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${_selectedIds.length} Selected',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        color: mutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Search
                TextField(
                  onChanged: (val) => setState(() => _search = val),
                  style: TextStyle(fontFamily: 'Inter', color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search skills...',
                    hintStyle: TextStyle(color: mutedColor),
                    prefixIcon: Icon(Icons.search, color: mutedColor, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: lime),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Skills List / Wrap
                Expanded(
                  child: filteredSkills.isEmpty
                      ? Center(
                          child: Text(
                            widget.allSkills.isEmpty
                                ? 'No skills in registry yet.\nCreate skills in Skills Registry.'
                                : 'No matching skills found',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Inter', color: mutedColor, fontSize: 13),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: filteredSkills.map((skill) {
                              final isSelected = _selectedIds.contains(skill.id);
                              return FilterChip(
                                label: Text(skill.name),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedIds.add(skill.id);
                                    } else {
                                      _selectedIds.remove(skill.id);
                                    }
                                  });
                                },
                                selectedColor: lime.withValues(alpha: 0.2),
                                checkmarkColor: isDark ? lime : Colors.white,
                                labelStyle: TextStyle(
                                  fontFamily: 'Inter',
                                  color: isSelected ? lime : textColor,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12.5,
                                ),
                                backgroundColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                                side: BorderSide(
                                  color: isSelected
                                      ? lime.withValues(alpha: 0.6)
                                      : (isDark ? Colors.white12 : Colors.black12),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel', style: TextStyle(fontFamily: 'IBM Plex Mono', color: mutedColor)),
                    ),
                    const SizedBox(width: 8),
                    KratosPressable(
                      onTap: () => Navigator.pop(context, _selectedIds),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: lime,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'CONFIRM SELECTION',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                            letterSpacing: 0.6,
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
