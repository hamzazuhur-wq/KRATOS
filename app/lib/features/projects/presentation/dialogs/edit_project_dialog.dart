import 'package:flutter/material.dart';

import '../../../../app/active_glass_card.dart';
import '../../../../app/kratos_dropdown.dart';
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
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 680),
        child: ActiveGlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'EDIT PROJECT',
                    style: TextStyle(
                      color: Color(0xFFC6F135),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
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
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          labelText: 'Project Name *',
                          labelStyle: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Description
                      TextField(
                        controller: _descriptionController,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          labelStyle: TextStyle(color: Colors.white70),
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
                      const Text(
                        'DIFFICULTY',
                        style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.2),
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
                                selectedColor: const Color(0xFFC6F135),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.black : Colors.white70,
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
                      const Text(
                        'ASSIGN TO',
                        style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.2),
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
                                ? const Center(child: CircularProgressIndicator(color: Color(0xFFC6F135)))
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
                          const Text(
                            'SKILLS',
                            style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.2),
                          ),
                          TextButton(
                            onPressed: _openSkillsDialog,
                            child: const Text('+ Edit Skills', style: TextStyle(color: Color(0xFFC6F135))),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _allUserSkills
                            .where((s) => _selectedSkillIds.contains(s.id))
                            .map((s) => Chip(
                                  label: Text(s.name, style: const TextStyle(fontSize: 11)),
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
                        builder: (_) => AlertDialog(
                          title: const Text('Delete Project?'),
                          content: Text('Delete “${widget.projectDetails.project.title}”?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                              child: const Text('Delete'),
                            ),
                          ],
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
                    label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _saving ? null : _saveChanges,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFC6F135),
                          foregroundColor: const Color(0xFF0D0D0D),
                        ),
                        child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
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
