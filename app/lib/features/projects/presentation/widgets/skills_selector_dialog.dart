import 'package:flutter/material.dart';
import '../../../../app/active_glass_card.dart';
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
    final filteredSkills = widget.allSkills.where((s) {
      if (_search.trim().isEmpty) return true;
      return s.name.toLowerCase().contains(_search.trim().toLowerCase()) ||
          (s.description?.toLowerCase().contains(_search.trim().toLowerCase()) ?? false);
    }).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 580),
        child: ActiveGlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SELECT SKILLS',
                    style: TextStyle(
                      color: Color(0xFFC6F135),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    '${_selectedIds.length} Selected',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search
              TextField(
                onChanged: (val) => setState(() => _search = val),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search skills...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 18),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFC6F135)),
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
                          style: const TextStyle(color: Colors.white38, fontSize: 13),
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
                              selectedColor: const Color(0xFFC6F135).withValues(alpha: 0.2),
                              checkmarkColor: const Color(0xFFC6F135),
                              labelStyle: TextStyle(
                                color: isSelected ? const Color(0xFFC6F135) : Colors.white70,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                              backgroundColor: Colors.white.withValues(alpha: 0.04),
                              side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFFC6F135).withValues(alpha: 0.6)
                                    : Colors.white12,
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
                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _selectedIds),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC6F135),
                      foregroundColor: const Color(0xFF0D0D0D),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Confirm Selection', style: TextStyle(fontWeight: FontWeight.bold)),
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
