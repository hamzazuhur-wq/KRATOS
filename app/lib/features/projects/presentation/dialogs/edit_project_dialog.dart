import 'package:flutter/material.dart';

import '../../../../app/kratos_dropdown.dart';
import '../../../../app/kratos_motion.dart';
import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../../../data/drift/app_database.dart';
import '../../../xp/data/xp_ledger_writer_impl.dart';
import '../../data/projects_repository.dart';
import '../../domain/project_models.dart';
import '../widgets/skills_selector_dialog.dart';

/// Modal dialog for modifying an existing Project.
class EditProjectDialog extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final ProjectWithDetails projectDetails;

  const EditProjectDialog({
    super.key,
    required this.database,
    required this.ownerId,
    required this.projectDetails,
  });

  @override
  State<EditProjectDialog> createState() => _EditProjectDialogState();
}

class _EditProjectDialogState extends State<EditProjectDialog> {
  late final ProjectsRepository _repository;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late int _difficulty;
  late String _status;
  ProjectAssignmentType _selectedAssignmentType = ProjectAssignmentType.goal;
  String? _selectedTargetId;
  List<ProjectAssignmentTarget> _availableTargets = [];
  bool _loadingTargets = false;

  late final Set<String> _selectedSkillIds;
  List<Skill> _allUserSkills = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = ProjectsRepository(
      database: widget.database,
      xpLedgerWriter: DriftXpLedgerWriter(widget.database),
    );

    final p = widget.projectDetails.project;
    _titleController = TextEditingController(text: p.title);
    _descriptionController = TextEditingController(text: p.description ?? '');
    _difficulty = p.difficulty;
    _status = p.status;
    _selectedSkillIds = widget.projectDetails.skills.map((s) => s.id).toSet();

    if (p.goalId != null) {
      if (widget.projectDetails.subGoal != null) {
        _selectedAssignmentType = ProjectAssignmentType.subGoal;
        _selectedTargetId = widget.projectDetails.subGoal!.id;
      } else {
        _selectedAssignmentType = ProjectAssignmentType.goal;
        _selectedTargetId = p.goalId;
      }
    } else if (p.lifeAreaId != null) {
      _selectedAssignmentType = ProjectAssignmentType.lifeArea;
      _selectedTargetId = p.lifeAreaId;
    } else if (p.levelId != null) {
      _selectedAssignmentType = ProjectAssignmentType.level;
      _selectedTargetId = p.levelId.toString();
    }

    _loadSkills();
    _loadTargetsForType(_selectedAssignmentType);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadSkills() async {
    final skills = await widget.database.skillsDao.listSkills(widget.ownerId);
    if (mounted) setState(() => _allUserSkills = skills);
  }

  Future<void> _loadTargetsForType(ProjectAssignmentType type) async {
    setState(() {
      _loadingTargets = true;
      _availableTargets = [];
    });

    final targets = await _repository.loadAssignmentTargets(widget.ownerId, type);
    if (mounted) {
      setState(() {
        _availableTargets = targets;
        if (!targets.any((t) => t.id == _selectedTargetId)) {
          _selectedTargetId = targets.isNotEmpty ? targets.first.id : null;
        }
        _loadingTargets = false;
      });
    }
  }

  Future<void> _openSkillsDialog() async {
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (_) => SkillsSelectorDialog(
        allSkills: _allUserSkills,
        initiallySelectedIds: _selectedSkillIds,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedSkillIds
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _saveChanges() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);

    String? lifeAreaId;
    String? goalId;
    int? levelId;

    if (_selectedTargetId != null) {
      switch (_selectedAssignmentType) {
        case ProjectAssignmentType.lifeArea:
          lifeAreaId = _selectedTargetId;
          break;
        case ProjectAssignmentType.goal:
        case ProjectAssignmentType.subGoal:
          goalId = _selectedTargetId;
          final g = await (widget.database.select(widget.database.goals)
                ..where((row) => row.id.equals(_selectedTargetId!)))
              .getSingleOrNull();
          lifeAreaId = g?.lifeAreaId;
          break;
        case ProjectAssignmentType.level:
          levelId = int.tryParse(_selectedTargetId!);
          break;
      }
    }

    await _repository.updateProject(
      projectId: widget.projectDetails.project.id,
      ownerId: widget.ownerId,
      title: title,
      description: _descriptionController.text.trim(),
      difficulty: _difficulty,
      lifeAreaId: lifeAreaId,
      goalId: goalId,
      levelId: levelId,
      skillIds: _selectedSkillIds,
      status: _status,
    );

    if (mounted) Navigator.pop(context, true);
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
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
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
                      'EDIT PROJECT',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: lime,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        fontSize: 16,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: mutedColor, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title
                        TextField(
                          controller: _titleController,
                          style: TextStyle(fontFamily: 'Inter', color: textColor, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            labelText: 'Project Name *',
                            labelStyle: TextStyle(fontFamily: 'IBM Plex Mono', color: mutedColor),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Description
                        TextField(
                          controller: _descriptionController,
                          maxLines: 2,
                          style: TextStyle(fontFamily: 'Inter', color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Description',
                            labelStyle: TextStyle(fontFamily: 'IBM Plex Mono', color: mutedColor),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Status Dropdown
                        KratosDropdownFormField<String>(
                          initialValue: _status,
                          labelText: 'STATUS',
                          hint: 'Status',
                          items: const [
                            KratosDropdownItem(value: 'active', label: 'Active'),
                            KratosDropdownItem(value: 'paused', label: 'Paused'),
                            KratosDropdownItem(value: 'completed', label: 'Completed'),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _status = val);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Difficulty
                        Text(
                          'DIFFICULTY',
                          style: TextStyle(fontFamily: 'IBM Plex Mono', color: mutedColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: List.generate(10, (idx) {
                              final d = idx + 1;
                              final roman = ProjectDifficulty.toRoman(d);
                              final isSelected = _difficulty == d;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(roman),
                                  selected: isSelected,
                                  selectedColor: lime,
                                  backgroundColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
                                  side: BorderSide(
                                    color: isSelected ? lime : (isDark ? Colors.white12 : Colors.black12),
                                  ),
                                  labelStyle: TextStyle(
                                    fontFamily: 'IBM Plex Mono',
                                    color: isSelected ? (isDark ? Colors.black : Colors.white) : textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  onSelected: (sel) {
                                    if (sel) setState(() => _difficulty = d);
                                  },
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Assign To
                        Text(
                          'ASSIGN TO',
                          style: TextStyle(fontFamily: 'IBM Plex Mono', color: mutedColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: KratosDropdownFormField<ProjectAssignmentType>(
                                initialValue: _selectedAssignmentType,
                                labelText: 'TYPE',
                                hint: 'Type',
                                items: ProjectAssignmentType.values.map((t) {
                                  return KratosDropdownItem(value: t, label: t.label);
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedAssignmentType = val);
                                    _loadTargetsForType(val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: _loadingTargets
                                  ? Center(child: CircularProgressIndicator(color: lime))
                                  : KratosDropdownFormField<String>(
                                      initialValue: _selectedTargetId,
                                      labelText: _selectedAssignmentType.label.toUpperCase(),
                                      hint: _selectedAssignmentType.label,
                                      items: _availableTargets.map((t) {
                                        return KratosDropdownItem(value: t.id, label: t.title);
                                      }).toList(),
                                      onChanged: (val) => setState(() => _selectedTargetId = val),
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Skills
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SKILLS',
                              style: TextStyle(fontFamily: 'IBM Plex Mono', color: mutedColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2),
                            ),
                            TextButton(
                              onPressed: _openSkillsDialog,
                              child: Text('+ Edit Skills', style: TextStyle(fontFamily: 'IBM Plex Mono', color: lime, fontSize: 12)),
                            ),
                          ],
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _allUserSkills
                              .where((s) => _selectedSkillIds.contains(s.id))
                              .map((s) => Chip(
                                    label: Text(s.name, style: TextStyle(fontFamily: 'Inter', fontSize: 11, color: textColor)),
                                    backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                                    side: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                                    deleteIconColor: mutedColor,
                                    onDeleted: () => setState(() => _selectedSkillIds.remove(s.id)),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogCtx) => Dialog(
                            backgroundColor: Colors.transparent,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 400),
                              child: KratosModalEntrance(
                                child: KratosGlassCard(
                                  variant: KratosSurfaceVariant.elevated,
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'DELETE PROJECT?',
                                        style: TextStyle(
                                          fontFamily: 'Space Grotesk',
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Delete "${widget.projectDetails.project.title}"?',
                                        style: TextStyle(fontFamily: 'Inter', color: textColor, fontSize: 13),
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(dialogCtx, false),
                                            child: Text('Cancel', style: TextStyle(fontFamily: 'IBM Plex Mono', color: mutedColor)),
                                          ),
                                          const SizedBox(width: 8),
                                          KratosPressable(
                                            onTap: () => Navigator.pop(dialogCtx, true),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent,
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Text(
                                                'DELETE',
                                                style: TextStyle(
                                                  fontFamily: 'IBM Plex Mono',
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11,
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
                        if (confirmed == true) {
                          await _repository.softDeleteProject(
                            widget.projectDetails.project.id,
                            widget.ownerId,
                          );
                          if (mounted) {
                            nav.pop('deleted');
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      label: const Text('Delete', style: TextStyle(fontFamily: 'IBM Plex Mono', color: Colors.redAccent)),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: TextStyle(fontFamily: 'IBM Plex Mono', color: mutedColor)),
                        ),
                        const SizedBox(width: 8),
                        KratosPressable(
                          onTap: _saving ? null : _saveChanges,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                            decoration: BoxDecoration(
                              color: lime,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'SAVE CHANGES',
                              style: TextStyle(
                                fontFamily: 'IBM Plex Mono',
                                color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ),
                      ],
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
