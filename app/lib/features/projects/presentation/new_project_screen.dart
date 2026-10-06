import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';

import 'package:image_picker/image_picker.dart';

import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_visuals.dart';
import '../../../data/drift/app_database.dart';
import '../../xp/data/xp_ledger_writer_impl.dart';
import '../data/project_storage_service.dart';
import '../data/projects_repository.dart';
import '../domain/project_models.dart';
import 'project_detail_screen.dart';
import 'widgets/skills_selector_dialog.dart';

/// Full, real implementation of New Project creation flow.
class NewProjectScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;

  const NewProjectScreen({
    super.key,
    required this.database,
    required this.ownerId,
  });

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  late final ProjectsRepository _repository;
  final _storageService = ProjectStorageService();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _difficulty = 5; // Default â…¤
  ProjectAssignmentType _selectedAssignmentType = ProjectAssignmentType.goal;
  String? _selectedTargetId;
  List<ProjectAssignmentTarget> _availableTargets = [];
  bool _loadingTargets = false;

  final Set<String> _selectedSkillIds = {};
  List<Skill> _allUserSkills = [];

  XFile? _coverImageFile;
  Uint8List? _coverImageBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repository = ProjectsRepository(
      database: widget.database,
      xpLedgerWriter: DriftXpLedgerWriter(widget.database),
    );
    _loadSkills();
    _loadTargetsForType(_selectedAssignmentType);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadSkills() async {
    final skills = await widget.database.skillsDao.listSkills(widget.ownerId);
    if (mounted) {
      setState(() => _allUserSkills = skills);
    }
  }

  Future<void> _loadTargetsForType(ProjectAssignmentType type) async {
    setState(() {
      _loadingTargets = true;
      _selectedTargetId = null;
      _availableTargets = [];
    });

    final targets = await _repository.loadAssignmentTargets(
      widget.ownerId,
      type,
    );
    if (mounted) {
      setState(() {
        _availableTargets = targets;
        if (targets.isNotEmpty) {
          _selectedTargetId = targets.first.id;
        }
        _loadingTargets = false;
      });
    }
  }

  Future<void> _pickCoverImage() async {
    final file = await _storageService.pickCoverImage();
    if (file != null) {
      final bytes = await file.readAsBytes();
      setState(() {
        _coverImageFile = file;
        _coverImageBytes = bytes;
      });
    }
  }

  void _removeCoverImage() {
    setState(() {
      _coverImageFile = null;
      _coverImageBytes = null;
    });
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

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
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
            // Also inherit Life Area if goal has one
            final g =
                await (widget.database.select(widget.database.goals)
                      ..where((row) => row.id.equals(_selectedTargetId!)))
                    .getSingleOrNull();
            lifeAreaId = g?.lifeAreaId;
            break;
          case ProjectAssignmentType.level:
            levelId = int.tryParse(_selectedTargetId!);
            break;
        }
      }

      String? coverImagePath;
      if (_coverImageBytes != null && _coverImageFile != null) {
        coverImagePath = await _storageService.uploadCoverImage(
          ownerId: widget.ownerId,
          projectId: 'temp',
          bytes: _coverImageBytes!,
          fileName: _coverImageFile!.name,
        );
      }

      final projectId = await _repository.createProject(
        ownerId: widget.ownerId,
        title: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        difficulty: _difficulty,
        lifeAreaId: lifeAreaId,
        goalId: goalId,
        levelId: levelId,
        skillIds: _selectedSkillIds,
        coverImagePath: coverImagePath,
      );

      if (mounted) {
        // Navigate directly to Project Detail as specified
        Navigator.of(context).pushReplacement(
          KratosMaterialPageRoute(
            builder: (_) => ProjectDetailScreen(
              database: widget.database,
              ownerId: widget.ownerId,
              projectId: projectId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating project: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'NEW PROJECT',
          style: TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final formWidth = w > 1400
                    ? w * 0.85
                    : (w > 800 ? w * 0.90 : w);
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: formWidth),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Cover Image Picker
                          _buildCoverImageSection(),
                          const SizedBox(height: 20),

                          // 2. Name Field
                          KratosGlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PROJECT NAME *',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    letterSpacing: 1.2,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _nameController,
                                  autofocus: true,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. AVORI Brand System',
                                    hintStyle: const TextStyle(
                                      color: Colors.white38,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withValues(
                                      alpha: 0.03,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white12,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white12,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFC6F135),
                                      ),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Project name is required';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                // Description
                                const Text(
                                  'DESCRIPTION',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    letterSpacing: 1.2,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _descriptionController,
                                  maxLines: 3,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Strategic workspace overview, vision, and deliverables...',
                                    hintStyle: const TextStyle(
                                      color: Colors.white38,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white.withValues(
                                      alpha: 0.03,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white12,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Colors.white12,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFC6F135),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 3. Difficulty Scale (â… â€“â…©)
                          _buildDifficultySection(),
                          const SizedBox(height: 18),

                          // 4. "Assign To" Dual Selector
                          _buildAssignToSection(),
                          const SizedBox(height: 18),

                          // 5. Skills Multi-Select
                          _buildSkillsSection(),
                          const SizedBox(height: 28),

                          // Submit Button
                          FilledButton.icon(
                            onPressed: _saving ? null : _saveProject,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFC6F135),
                              foregroundColor: const Color(0xFF0D0D0D),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0D0D0D),
                                    ),
                                  )
                                : const Icon(Icons.check_circle, size: 20),
                            label: Text(
                              _saving
                                  ? 'CREATING PROJECT...'
                                  : 'CREATE PROJECT',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverImageSection() {
    if (_coverImageBytes != null) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          image: DecorationImage(
            image: MemoryImage(_coverImageBytes!),
            fit: BoxFit.cover,
          ),
          border: Border.all(
            color: const Color(0xFFC6F135).withValues(alpha: 0.3),
          ),
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Row(
                children: [
                  IconButton.filled(
                    onPressed: _pickCoverImage,
                    icon: const Icon(Icons.edit, size: 16),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: const Color(0xFFC6F135),
                    ),
                    tooltip: 'Replace Cover',
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _removeCoverImage,
                    icon: const Icon(Icons.close, size: 16),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.redAccent,
                    ),
                    tooltip: 'Remove Cover',
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _pickCoverImage,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12, style: BorderStyle.solid),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                color: Color(0xFFC6F135),
                size: 24,
              ),
              SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ADD COVER IMAGE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Choose image directly from device',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultySection() {
    final baseReward = ProjectDifficultyXpCalculator.baseXp(_difficulty);

    return KratosGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DIFFICULTY',
                style: TextStyle(
                  color: Colors.white70,
                  letterSpacing: 1.2,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFC6F135).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$baseReward Base XP',
                  style: const TextStyle(
                    color: Color(0xFFC6F135),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Roman Numeral Selectors (â…  to â…©)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(10, (index) {
                final d = index + 1;
                final roman = ProjectDifficulty.toRoman(d);
                final isSelected = _difficulty == d;

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      roman,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: isSelected
                            ? const Color(0xFF0D0D0D)
                            : Colors.white70,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: const Color(0xFFC6F135),
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFFC6F135)
                          : Colors.white12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _difficulty = d);
                    },
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignToSection() {
    return KratosGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ASSIGN TO',
            style: TextStyle(
              color: Colors.white70,
              letterSpacing: 1.2,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          // Two responsive dropdown selectors
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 460;
              final typeDropdown =
                  KratosDropdownFormField<ProjectAssignmentType>(
                    initialValue: _selectedAssignmentType,
                    labelText: 'TARGET TYPE',
                    hint: 'Target Type',
                    items: ProjectAssignmentType.values.map((type) {
                      return KratosDropdownItem(value: type, label: type.label);
                    }).toList(),
                    onChanged: (val) {
                      if (val != null && val != _selectedAssignmentType) {
                        setState(() => _selectedAssignmentType = val);
                        _loadTargetsForType(val);
                      }
                    },
                  );

              final targetDropdown = KratosDropdownFormField<String>(
                initialValue: _selectedTargetId,
                labelText:
                    'SELECT ${_selectedAssignmentType.label.toUpperCase()}',
                hint: 'Select ${_selectedAssignmentType.label}',
                items: _availableTargets.map((target) {
                  return KratosDropdownItem(
                    value: target.id,
                    label: target.title,
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedTargetId = val);
                },
              );

              if (isNarrow) {
                return Column(
                  children: [
                    typeDropdown,
                    const SizedBox(height: 12),
                    if (_loadingTargets)
                      const LinearProgressIndicator(color: Color(0xFFC6F135))
                    else
                      targetDropdown,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 2, child: typeDropdown),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: _loadingTargets
                        ? const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFC6F135),
                              ),
                            ),
                          )
                        : targetDropdown,
                  ),
                ],
              );
            },
          ),
          if (_availableTargets.isEmpty && !_loadingTargets)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No ${_selectedAssignmentType.label.toLowerCase()} records available.',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection() {
    final selectedSkills = _allUserSkills
        .where((s) => _selectedSkillIds.contains(s.id))
        .toList();

    return KratosGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SKILLS (UNLIMITED)',
                style: TextStyle(
                  color: Colors.white70,
                  letterSpacing: 1.2,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: _openSkillsDialog,
                icon: const Icon(Icons.add, size: 16, color: Color(0xFFC6F135)),
                label: const Text(
                  '+ Add Skills',
                  style: TextStyle(
                    color: Color(0xFFC6F135),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (selectedSkills.isEmpty)
            InkWell(
              onTap: _openSkillsDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.psychology_outlined,
                      color: Colors.white38,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'No skills attached â€¢ Tap to select skills',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedSkills.map((skill) {
                return Chip(
                  label: Text(skill.name),
                  onDeleted: () {
                    setState(() => _selectedSkillIds.remove(skill.id));
                  },
                  deleteIconColor: Colors.white54,
                  backgroundColor: const Color(0xFFC6F135)
                      .withValues(alpha: 0.12),
                  labelStyle: const TextStyle(
                    color: Color(0xFFC6F135),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: const Color(0xFFC6F135).withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
