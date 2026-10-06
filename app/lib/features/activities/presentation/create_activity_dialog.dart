// ignore_for_file: public_member_api_docs
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';

import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_motion.dart';
import '../../../app/kratos_text_prompt.dart';
import '../../../app/kratos_theme.dart';
import '../../../app/kratos_visuals.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final textColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final mutedColor = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: KratosModalEntrance(
        child: KratosGlassCard(
          variant: KratosSurfaceVariant.elevated,
          padding: EdgeInsets.zero,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: lime),
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
                                color: isDark ? Colors.white10 : Colors.black12,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: lime.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.local_activity,
                                  color: lime,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'NEW ACTIVITY',
                                  style: TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    color: textColor,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: mutedColor, size: 20),
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
                              Text(
                                'ACTIVITY NAME *',
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Mono',
                                  color: lime,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _nameController,
                                autofocus: true,
                                style: TextStyle(fontFamily: 'Inter', color: textColor, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'e.g. Reading, Gym, Studying English, Coding Practice',
                                  hintStyle: TextStyle(color: mutedColor),
                                  filled: true,
                                  fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: lime, width: 1.2),
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
                              Text(
                                'LIFE AREA *',
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Mono',
                                  color: lime,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
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
                                  Text(
                                    'ACTIVITY CATEGORY',
                                    style: TextStyle(
                                      fontFamily: 'IBM Plex Mono',
                                      color: mutedColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _showAddCategoryDialog,
                                    icon: Icon(Icons.add, size: 14, color: lime),
                                    label: Text(
                                      'Add Category',
                                      style: TextStyle(
                                        fontFamily: 'IBM Plex Mono',
                                        color: lime,
                                        fontSize: 11,
                                      ),
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
                              Text(
                                'TARGET DURATION (OPTIONAL)',
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Mono',
                                  color: mutedColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
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
                                  style: TextStyle(fontFamily: 'Inter', color: textColor, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Target duration in minutes (e.g. 45)',
                                    hintStyle: TextStyle(color: mutedColor),
                                    filled: true,
                                    fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                                    suffixText: 'mins',
                                    suffixStyle: TextStyle(color: lime),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
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
                                  Text(
                                    'DIFFICULTY & MAX XP (1–10)',
                                    style: TextStyle(
                                      fontFamily: 'IBM Plex Mono',
                                      color: lime,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  Text(
                                    'Max: ${ActivityXpCalculator.ceilingXp(_difficulty)} XP / 12h',
                                    style: TextStyle(
                                      fontFamily: 'IBM Plex Mono',
                                      color: mutedColor,
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
                                            ? lime.withValues(alpha: 0.18)
                                            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03)),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSel ? lime : (isDark ? Colors.white12 : Colors.black12),
                                          width: isSel ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Text(
                                        'D$diff ($ceil XP)',
                                        style: TextStyle(
                                          fontFamily: 'IBM Plex Mono',
                                          color: isSel ? lime : mutedColor,
                                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
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
                                Text(
                                  'LINKED SKILLS (MULTI-SELECT)',
                                  style: TextStyle(
                                    fontFamily: 'IBM Plex Mono',
                                    color: mutedColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
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
                                      label: Text(
                                        s.name,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 12,
                                          color: isSelected ? (isDark ? Colors.black : Colors.white) : textColor,
                                        ),
                                      ),
                                      selectedColor: lime,
                                      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                                      checkmarkColor: isDark ? Colors.black : Colors.white,
                                      side: BorderSide(
                                        color: isSelected
                                            ? lime
                                            : (isDark ? Colors.white12 : Colors.black12),
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
                              Text(
                                'DESCRIPTION / GOAL OF PRACTICE',
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Mono',
                                  color: mutedColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _descriptionController,
                                maxLines: 3,
                                style: TextStyle(fontFamily: 'Inter', color: textColor, fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: 'Describe this repeatable habit or practice routine...',
                                  hintStyle: TextStyle(color: mutedColor),
                                  filled: true,
                                  fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Instant Focus Timer Toggle
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _startTimerImmediately
                                        ? lime.withValues(alpha: 0.4)
                                        : (isDark ? Colors.white10 : Colors.black12),
                                  ),
                                ),
                                child: SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  value: _startTimerImmediately,
                                  onChanged: (val) => setState(() => _startTimerImmediately = val),
                                  activeThumbColor: lime,
                                  title: Text(
                                    'Start Focus Timer immediately',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: textColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Launches the active practice timer upon creating this activity',
                                    style: TextStyle(fontFamily: 'Inter', color: mutedColor, fontSize: 11),
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
                              top: BorderSide(color: isDark ? Colors.white10 : Colors.black12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                                child: Text('Cancel', style: TextStyle(fontFamily: 'IBM Plex Mono', color: mutedColor)),
                              ),
                              const SizedBox(width: 12),
                              KratosPressable(
                                onTap: _isSubmitting ? null : _submit,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: lime,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: _isSubmitting
                                      ? SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: isDark ? Colors.black : Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'Create Activity',
                                          style: TextStyle(
                                            fontFamily: 'IBM Plex Mono',
                                            color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            letterSpacing: 0.6,
                                          ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final textColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final isSelected = _selectedPreset == key;

    return ChoiceChip(
      selected: isSelected,
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'IBM Plex Mono',
          color: isSelected ? (isDark ? Colors.black : Colors.white) : textColor,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selectedColor: lime,
      backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
      side: BorderSide(
        color: isSelected ? lime : (isDark ? Colors.white12 : Colors.black12),
      ),
      onSelected: (_) => _onPresetChanged(key),
    );
  }
}
