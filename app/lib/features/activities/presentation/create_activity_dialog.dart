// ignore_for_file: public_member_api_docs
import 'dart:ui';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_text_prompt.dart';
import '../../../data/drift/app_database.dart';
import '../../categories/data/categories_dao.dart';
import '../../sessions/domain/global_active_session_controller.dart';
import '../../sessions/domain/session_models.dart';
import '../data/activity_dashboard_repository.dart';
import '../domain/activity_xp_calculator.dart';

class CreateActivityDialog extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final String? initialLifeAreaId;

  const CreateActivityDialog({
    super.key,
    required this.database,
    required this.ownerId,
    this.initialLifeAreaId,
  });

  static Future<String?> show(
    BuildContext context, {
    required AppDatabase database,
    required String ownerId,
    String? initialLifeAreaId,
  }) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => CreateActivityDialog(
        database: database,
        ownerId: ownerId,
        initialLifeAreaId: initialLifeAreaId,
      ),
    );
  }

  @override
  State<CreateActivityDialog> createState() => _CreateActivityDialogState();
}

class _CreateActivityDialogState extends State<CreateActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customDurationController = TextEditingController();

  String? _selectedLifeAreaId;
  String? _selectedCategoryId;
  final Set<String> _selectedSkillIds = {};
  int? _targetDurationMinutes;
  String _selectedPreset = 'none'; // 'none', '30m', '1h', '2h', 'custom'
  int _difficulty = 5;
  bool _startTimerImmediately = false;

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<LifeArea> _lifeAreas = [];
  List<Category> _activityCategories = [];
  List<Skill> _skills = [];

  @override
  void initState() {
    super.initState();
    _selectedLifeAreaId = widget.initialLifeAreaId;
    _loadPrerequisites();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _customDurationController.dispose();
    super.dispose();
  }

  Future<void> _loadPrerequisites() async {
    try {
      final areas = await (widget.database.select(widget.database.lifeAreas)
            ..where((a) =>
                a.ownerId.equals(widget.ownerId) &
                a.deletedAt.isNull() &
                a.archivedAt.isNull())
            ..orderBy([(a) => OrderingTerm.asc(a.sortOrder), (a) => OrderingTerm.asc(a.name)]))
          .get();

      final categoriesDao = CategoriesDao(widget.database);
      final categories = await categoriesDao.categoriesByType(widget.ownerId, 'activity');

      final skills = await (widget.database.select(widget.database.skills)
            ..where((s) => s.ownerId.equals(widget.ownerId) & s.deletedAt.isNull())
            ..orderBy([(s) => OrderingTerm.asc(s.name)]))
          .get();

      if (mounted) {
        setState(() {
          _lifeAreas = areas;
          _activityCategories = categories;
          _skills = skills;
          if (_selectedLifeAreaId == null && areas.isNotEmpty) {
            _selectedLifeAreaId = areas.first.id;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load options: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onPresetChanged(String preset) {
    setState(() {
      _selectedPreset = preset;
      switch (preset) {
        case 'none':
          _targetDurationMinutes = null;
          break;
        case '30m':
          _targetDurationMinutes = 30;
          break;
        case '1h':
          _targetDurationMinutes = 60;
          break;
        case '2h':
          _targetDurationMinutes = 120;
          break;
        case 'custom':
          final val = int.tryParse(_customDurationController.text);
          _targetDurationMinutes = val;
          break;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLifeAreaId == null || _selectedLifeAreaId!.isEmpty) {
      setState(() => _errorMessage = 'Please select a Life Area');
      return;
    }

    if (_selectedPreset == 'custom') {
      final customMinutes = int.tryParse(_customDurationController.text);
      if (customMinutes == null || customMinutes <= 0) {
        setState(() => _errorMessage = 'Please enter a valid target duration');
        return;
      }
      _targetDurationMinutes = customMinutes;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repo = ActivityDashboardRepository(widget.database);
      final activityId = await repo.createActivity(
        ownerId: widget.ownerId,
        name: _nameController.text.trim(),
        lifeAreaId: _selectedLifeAreaId!,
        categoryId: _selectedCategoryId,
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        targetDurationMinutes: _targetDurationMinutes,
        difficulty: _difficulty,
        skillIds: _selectedSkillIds.toList(),
        xpRule: ActivityXpRule(flatXp: ActivityXpCalculator.ceilingXp(_difficulty), perMinuteXp: 1),
      );

      if (_startTimerImmediately) {
        final area = _lifeAreas.where((a) => a.id == _selectedLifeAreaId).firstOrNull;
        final cat = _activityCategories.where((c) => c.id == _selectedCategoryId).firstOrNull;
        GlobalActiveSessionController().startSession(
          entityType: 'activity',
          entityId: activityId,
          title: _nameController.text.trim(),
          lifeAreaId: _selectedLifeAreaId,
          lifeAreaName: area?.name,
          categoryName: cat?.name,
          targetDurationMinutes: _targetDurationMinutes ?? 0,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(activityId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to create activity: $e';
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showAddCategoryDialog() async {
    final result = await KratosTextPrompt.show(
      context,
      title: 'ADD ACTIVITY CATEGORY',
      label: 'Category Name (e.g. Health, Deep Work, Music)',
      confirmLabel: 'ADD',
    );

    if (result != null && result.isNotEmpty) {
      final categoriesDao = CategoriesDao(widget.database);
      final id = 'cat_act_${DateTime.now().millisecondsSinceEpoch}';
      await categoriesDao.createCategory(
        category: CategoriesCompanion.insert(
          id: id,
          ownerId: widget.ownerId,
          name: result,
          categoryType: const Value('activity'),
          baseXp: 10,
          isImmutable: false,
          sortOrder: 0,
          versionHlc: '0:0:0',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
        actions: [],
      );
      await _loadPrerequisites();
      setState(() => _selectedCategoryId = id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D0D).withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFC6F135).withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC6F135).withValues(alpha: 0.08),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFC6F135)),
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFC6F135).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.local_activity,
                                  color: Color(0xFFC6F135),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'NEW ACTIVITY',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                                onPressed: () => Navigator.of(context).pop(),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),

                        // Form body
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              if (_errorMessage != null)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                                  ),
                                ),

                              // 1. Activity Name
                              const Text(
                                'ACTIVITY NAME *',
                                style: TextStyle(
                                  color: Color(0xFFC6F135),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _nameController,
                                autofocus: true,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'e.g. Reading, Gym, Studying English, Coding Practice',
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.04),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFC6F135), width: 1.2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) {
                                    return 'Activity name is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // 2. Life Area
                              const Text(
                                'LIFE AREA *',
                                style: TextStyle(
                                  color: Color(0xFFC6F135),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              KratosDropdownFormField<String>(
                                initialValue: _selectedLifeAreaId,
                                hint: 'Select Life Area',
                                prefixIcon: Icons.folder_outlined,
                                items: _lifeAreas.map((la) {
                                  return KratosDropdownItem(
                                    value: la.id,
                                    label: la.name,
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedLifeAreaId = val),
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Life Area is required';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // 3. Activity Category
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'ACTIVITY CATEGORY',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _showAddCategoryDialog,
                                    icon: const Icon(Icons.add, size: 14, color: Color(0xFFC6F135)),
                                    label: const Text(
                                      'Add Category',
                                      style: TextStyle(color: Color(0xFFC6F135), fontSize: 11),
                                    ),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              KratosDropdownFormField<String?>(
                                initialValue: _selectedCategoryId,
                                hint: 'None (General Activity)',
                                prefixIcon: Icons.category_outlined,
                                items: [
                                  const KratosDropdownItem<String?>(
                                    value: null,
                                    label: 'None (General Activity)',
                                  ),
                                  ..._activityCategories.map((c) => KratosDropdownItem<String?>(
                                        value: c.id,
                                        label: c.name,
                                      )),
                                ],
                                onChanged: (val) => setState(() => _selectedCategoryId = val),
                              ),
                              const SizedBox(height: 16),

                              // 4. Target Duration Presets
                              const Text(
                                'TARGET DURATION (OPTIONAL)',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildPresetChip('none', 'None'),
                                  _buildPresetChip('30m', '30m'),
                                  _buildPresetChip('1h', '1h'),
                                  _buildPresetChip('2h', '2h'),
                                  _buildPresetChip('custom', 'Custom'),
                                ],
                              ),
                              if (_selectedPreset == 'custom') ...[
                                const SizedBox(height: 10),
                                TextFormField(
                                  controller: _customDurationController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Target duration in minutes (e.g. 45)',
                                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.04),
                                    suffixText: 'mins',
                                    suffixStyle: const TextStyle(color: Color(0xFFC6F135)),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),

                              // Difficulty & XP Ceiling (Phase 2)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'DIFFICULTY & MAX XP (1–10)',
                                    style: TextStyle(
                                      color: Color(0xFFC6F135),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  Text(
                                    'Max: ${ActivityXpCalculator.ceilingXp(_difficulty)} XP / 12h',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: List.generate(10, (i) => i + 1).map((diff) {
                                  final isSel = _difficulty == diff;
                                  final ceil = ActivityXpCalculator.ceilingXp(diff);
                                  return InkWell(
                                    onTap: () => setState(() {
                                      _difficulty = diff;
                                    }),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSel
                                            ? const Color(0xFFC6F135).withValues(alpha: 0.2)
                                            : Colors.white.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSel ? const Color(0xFFC6F135) : Colors.white12,
                                          width: isSel ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Text(
                                        'D$diff ($ceil XP)',
                                        style: TextStyle(
                                          color: isSel ? const Color(0xFFC6F135) : Colors.white70,
                                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),

                              // 5. Linked Skills
                              if (_skills.isNotEmpty) ...[
                                const Text(
                                  'LINKED SKILLS (MULTI-SELECT)',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _skills.map((s) {
                                    final isSelected = _selectedSkillIds.contains(s.id);
                                    return FilterChip(
                                      selected: isSelected,
                                      label: Text(s.name, style: TextStyle(fontSize: 12, color: isSelected ? Colors.black : Colors.white70)),
                                      selectedColor: const Color(0xFFC6F135),
                                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                                      checkmarkColor: Colors.black,
                                      side: BorderSide(
                                        color: isSelected
                                            ? const Color(0xFFC6F135)
                                            : Colors.white.withValues(alpha: 0.12),
                                      ),
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            _selectedSkillIds.add(s.id);
                                          } else {
                                            _selectedSkillIds.remove(s.id);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // 6. Description / Notes
                              const Text(
                                'DESCRIPTION / GOAL OF PRACTICE',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _descriptionController,
                                maxLines: 3,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Describe this repeatable habit or practice routine...',
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                                  filled: true,
                                  fillColor: Colors.white.withValues(alpha: 0.04),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Instant Focus Timer Toggle
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _startTimerImmediately
                                        ? const Color(0xFFC6F135).withValues(alpha: 0.4)
                                        : Colors.white10,
                                  ),
                                ),
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _startTimerImmediately,
                                  onChanged: (val) => setState(() => _startTimerImmediately = val),
                                  activeThumbColor: const Color(0xFFC6F135),
                                  title: const Text(
                                    'Start Focus Timer immediately',
                                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: const Text(
                                    'Launches the active practice timer upon creating this activity',
                                    style: TextStyle(color: Colors.white38, fontSize: 11),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action Buttons
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                                child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _isSubmitting ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC6F135),
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                      )
                                    : const Text(
                                        'Create Activity',
                                        style: TextStyle(
                                          color: Color(0xFF0D0D0D),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String key, String label) {
    final isSelected = _selectedPreset == key;
    return ChoiceChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selectedColor: const Color(0xFFC6F135),
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      side: BorderSide(
        color: isSelected ? const Color(0xFFC6F135) : Colors.white.withValues(alpha: 0.12),
      ),
      onSelected: (_) => _onPresetChanged(key),
    );
  }
}
