// ignore_for_file: public_member_api_docs
// Wave 3: Create Main Goal & Sub-goal Dialog.
// Real data persistence, Life Area / Category linking, outbox sync, and navigation.

import 'dart:convert';
import 'dart:ui';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

import '../../../../app/kratos_motion.dart';
import '../../../../app/kratos_theme.dart';
import '../../../../data/drift/app_database.dart';
import '../../../../domain/hlc.dart';
import '../../../../domain/ids.dart';
import '../../../../domain/invariants.dart';

class CreateGoalDialog extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final Goal? parentGoal; // null for Main Goal, non-null for Sub-goal
  final String? defaultLifeAreaId;
  final ValueChanged<Goal> onGoalCreated;

  const CreateGoalDialog({
    super.key,
    required this.database,
    required this.ownerId,
    this.parentGoal,
    this.defaultLifeAreaId,
    required this.onGoalCreated,
  });

  @override
  State<CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends State<CreateGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedLifeAreaId;
  String? _selectedCategoryId;
  String _selectedDuration = '3 Months';
  final Set<String> _selectedSkillIds = {};

  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _durationOptions = [
    '2 Weeks',
    '1 Month',
    '3 Months',
    '6 Months',
    '1 Year',
    'Ongoing',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.parentGoal != null) {
      _selectedLifeAreaId = widget.parentGoal!.lifeAreaId;
      _selectedCategoryId = widget.parentGoal!.categoryId;
    } else {
      _selectedLifeAreaId = widget.defaultLifeAreaId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isSubGoal => widget.parentGoal != null;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final textColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final mutedColor = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary;
    final surfaceColor = isDark ? const Color(0xFF0D0F0D).withValues(alpha: 0.94) : KratosTheme.lightSurface;
    final cardColor = isDark ? const Color(0xFF141714) : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: KratosModalEntrance(
        child: Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: borderColor, width: 1),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: lime.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Icon(
                        _isSubGoal ? Icons.subdirectory_arrow_right : Icons.track_changes,
                        color: lime,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isSubGoal ? 'ADD SUB-GOAL' : 'CREATE MAIN GOAL',
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                if (_isSubGoal) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141714),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_upward, size: 12, color: Color(0xFF686D65)),
                        const SizedBox(width: 6),
                        const Text(
                          'PARENT: ',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            color: Color(0xFF686D65),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.parentGoal!.title,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFFEEFF08),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // 1. Goal Title *
                Text(
                  'GOAL TITLE *',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: textColor,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: _isSubGoal ? 'e.g. Master Drift ORM' : 'e.g. Become Lead Architect',
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      color: mutedColor,
                    ),
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: lime),
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a goal title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 2. Description (optional)
                Text(
                  'DESCRIPTION',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  style: TextStyle(fontFamily: 'Inter', color: textColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'What does achieving this look like? Why does it matter?',
                    hintStyle: TextStyle(color: mutedColor),
                    filled: true,
                    fillColor: cardColor,
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
                const SizedBox(height: 16),

                // 3. Life Area *
                Text(
                  'LIFE AREA *',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                _buildLifeAreaPicker(),
                const SizedBox(height: 16),

                // 4. Goal Category *
                Text(
                  'GOAL CATEGORY *',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                _buildCategoryPicker(),
                const SizedBox(height: 16),

                // 5. Time / Duration *
                Text(
                  'TIME / DURATION *',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                _buildDurationPicker(),
                const SizedBox(height: 16),

                // 6. Skills (optional)
                Text(
                  'SKILLS (OPTIONAL ATTRIBUTION)',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                _buildSkillsPicker(),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFF3B30)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Color(0xFFFF3B30), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFFF3B30),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: mutedColor,
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSaveGoal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: lime,
                          foregroundColor: isDark ? const Color(0xFF020302) : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: _isSaving
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isDark ? const Color(0xFF020302) : Colors.white,
                                ),
                              )
                            : Text(
                                _isSubGoal ? 'CREATE SUB-GOAL' : 'CREATE MAIN GOAL',
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Mono',
                                  fontSize: 11.5,
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

  Widget _buildLifeAreaPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final textColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;

    return StreamBuilder<List<LifeArea>>(
      stream: (widget.database.select(widget.database.lifeAreas)
            ..where((l) =>
                l.ownerId.equals(widget.ownerId) & l.deletedAt.isNull())
            ..orderBy([(l) => drift.OrderingTerm.asc(l.sortOrder)]))
          .watch(),
      builder: (context, snapshot) {
        final lifeAreas = snapshot.data ?? [];
        if (lifeAreas.isEmpty) {
          return const Text(
            'No life areas available. Please complete onboarding first.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 6,
          children: lifeAreas.map((area) {
            final isSelected = _selectedLifeAreaId == area.id;
            final isLocked = _isSubGoal;

            return ChoiceChip(
              label: Text(area.name),
              selected: isSelected,
              onSelected: isLocked
                  ? null
                  : (selected) {
                      if (selected) {
                        setState(() => _selectedLifeAreaId = area.id);
                      }
                    },
              selectedColor: lime.withValues(alpha: 0.25),
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
              labelStyle: TextStyle(
                fontFamily: 'Inter',
                color: isSelected ? lime : textColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? lime : (isDark ? Colors.white12 : Colors.black12),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCategoryPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final textColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;

    return StreamBuilder<List<Category>>(
      stream: widget.database.categoriesDao.watchCategoriesByType(
        widget.ownerId,
        'goal',
      ),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? [];

        if (categories.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'No Goal Categories defined yet in Settings.',
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _seedDefaultGoalCategory,
                  child: Text(
                    '+ Add Default',
                    style: TextStyle(color: lime, fontSize: 12),
                  ),
                ),
              ],
            ),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 6,
          children: categories.map((cat) {
            final isSelected = _selectedCategoryId == cat.id;

            return ChoiceChip(
              label: Text(cat.name),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedCategoryId = cat.id);
                }
              },
              selectedColor: lime.withValues(alpha: 0.25),
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
              labelStyle: TextStyle(
                fontFamily: 'Inter',
                color: isSelected ? lime : textColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? lime : (isDark ? Colors.white12 : Colors.black12),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _seedDefaultGoalCategory() async {
    final catId = Id.uuidV7().value;
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id.uuidV7()).toString();

    await widget.database.categoriesDao.upsertCategory(
      CategoriesCompanion(
        id: drift.Value(catId),
        ownerId: drift.Value(widget.ownerId),
        name: const drift.Value('Milestone'),
        categoryType: const drift.Value('goal'),
        description: const drift.Value('Major progression milestone'),
        baseXp: const drift.Value(100),
        isImmutable: const drift.Value(false),
        sortOrder: const drift.Value(0),
        versionHlc: drift.Value(hlc),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    setState(() => _selectedCategoryId = catId);
  }

  Widget _buildDurationPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final textColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _durationOptions.map((opt) {
        final isSelected = _selectedDuration == opt;

        return ChoiceChip(
          label: Text(opt),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              setState(() => _selectedDuration = opt);
            }
          },
          selectedColor: lime.withValues(alpha: 0.25),
          backgroundColor: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04),
          labelStyle: TextStyle(
            fontFamily: 'Inter',
            color: isSelected ? lime : textColor,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected ? lime : (isDark ? Colors.white12 : Colors.black12),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkillsPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final textColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final mutedColor = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary;

    return StreamBuilder<List<Skill>>(
      stream: widget.database.select(widget.database.skills).watch(),
      builder: (context, snapshot) {
        final skills = snapshot.data ?? [];
        if (skills.isEmpty) {
          return Text(
            'No skills configured yet.',
            style: TextStyle(fontFamily: 'Inter', color: mutedColor, fontSize: 11),
          );
        }

        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: skills.map((skill) {
            final isSelected = _selectedSkillIds.contains(skill.id);

            return FilterChip(
              label: Text(skill.name),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedSkillIds.add(skill.id);
                  } else {
                    _selectedSkillIds.remove(skill.id);
                  }
                });
              },
              selectedColor: lime.withValues(alpha: 0.2),
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.03),
              labelStyle: TextStyle(
                fontFamily: 'Inter',
                color: isSelected ? lime : textColor,
                fontSize: 11,
              ),
              side: BorderSide(
                color: isSelected ? lime : (isDark ? Colors.white10 : Colors.black12),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _handleSaveGoal() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedLifeAreaId == null) {
      setState(() => _errorMessage = 'Please select a Life Area');
      return;
    }

    if (_selectedCategoryId == null) {
      setState(() => _errorMessage = 'Please select a Goal Category');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final goalId = Id.uuidV7().value;
      final now = DateTime.now().toUtc();
      final hlc = Hlc.now(Id.uuidV7()).toString();

      String rootId;
      String? parentId;
      String path;
      int depth;

      if (_isSubGoal) {
        parentId = widget.parentGoal!.id;
        rootId = widget.parentGoal!.rootId;
        path = GoalPath.buildPath(rootId, widget.parentGoal!.path, goalId);
        depth = widget.parentGoal!.depth + 1;
      } else {
        parentId = null;
        rootId = goalId;
        path = goalId;
        depth = 0;
      }

      // Compute dueDate from duration option
      DateTime? dueDate;
      switch (_selectedDuration) {
        case '2 Weeks':
          dueDate = now.add(const Duration(days: 14));
          break;
        case '1 Month':
          dueDate = DateTime(now.year, now.month + 1, now.day);
          break;
        case '3 Months':
          dueDate = DateTime(now.year, now.month + 3, now.day);
          break;
        case '6 Months':
          dueDate = DateTime(now.year, now.month + 6, now.day);
          break;
        case '1 Year':
          dueDate = DateTime(now.year + 1, now.month, now.day);
          break;
        default:
          dueDate = null;
      }

      final companion = GoalsCompanion(
        id: drift.Value(goalId),
        ownerId: drift.Value(widget.ownerId),
        parentId: drift.Value(parentId),
        rootId: drift.Value(rootId),
        path: drift.Value(path),
        depth: drift.Value(depth),
        title: drift.Value(_titleController.text.trim()),
        description: drift.Value(_descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null),
        lifeAreaId: drift.Value(_selectedLifeAreaId),
        categoryId: drift.Value(_selectedCategoryId),
        status: const drift.Value('active'),
        xpTarget: const drift.Value(500),
        progress: const drift.Value(0.0),
        progressHlc: drift.Value(hlc),
        dueDate: drift.Value(dueDate),
        versionHlc: drift.Value(hlc),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      );

      await widget.database.transaction(() async {
        await widget.database.goalsDao.upsert(companion);

        // Enqueue to outbox
        await widget.database.into(widget.database.syncOutbox).insert(
          SyncOutboxCompanion.insert(
            userId: widget.ownerId,
            op: 'upsert',
            entity: 'goals',
            entityId: goalId,
            payloadJson: jsonEncode({
              'id': goalId,
              'owner_id': widget.ownerId,
              'parent_id': parentId,
              'root_id': rootId,
              'path': path,
              'depth': depth,
              'title': _titleController.text.trim(),
              'description': _descriptionController.text.trim(),
              'life_area_id': _selectedLifeAreaId,
              'category_id': _selectedCategoryId,
              'status': 'active',
              'due_date': dueDate?.toIso8601String(),
            }),
            hlc: hlc,
            deviceId: 'local_device',
          ),
        );
      });

      final created = await widget.database.goalsDao.findById(goalId);
      if (mounted && created != null) {
        widget.onGoalCreated(created);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to create goal: $e';
        });
      }
    }
  }
}
