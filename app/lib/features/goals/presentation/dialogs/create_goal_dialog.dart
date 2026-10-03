// ignore_for_file: public_member_api_docs
// Wave 3: Create Main Goal & Sub-goal Dialog.
// Real data persistence, Life Area / Category linking, outbox sync, and navigation.

import 'dart:convert';
import 'dart:ui';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

import '../../../../app/kratos_motion.dart';
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
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: KratosModalEntrance(
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0D).withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white12, width: 1),
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
                      color: Colors.white24,
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
                        color: const Color(0xFFC6F135).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFC6F135).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Icon(
                        _isSubGoal ? Icons.subdirectory_arrow_right : Icons.track_changes,
                        color: const Color(0xFFC6F135),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isSubGoal ? 'ADD SUB-GOAL' : 'CREATE MAIN GOAL',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                if (_isSubGoal) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_upward, size: 12, color: Colors.white38),
                        const SizedBox(width: 6),
                        const Text(
                          'Parent: ',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                        Expanded(
                          child: Text(
                            widget.parentGoal!.title,
                            style: const TextStyle(
                              color: Color(0xFFC6F135),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
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
                const Text(
                  'GOAL TITLE *',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: _isSubGoal ? 'e.g. Master Drift ORM' : 'e.g. Become Lead Architect',
                    hintStyle: const TextStyle(color: Colors.white24),
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
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a goal title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 2. Description (optional)
                const Text(
                  'DESCRIPTION',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'What does achieving this look like? Why does it matter?',
                    hintStyle: const TextStyle(color: Colors.white24),
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
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Life Area *
                const Text(
                  'LIFE AREA *',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                _buildLifeAreaPicker(),
                const SizedBox(height: 16),

                // 4. Goal Category *
                const Text(
                  'GOAL CATEGORY *',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                _buildCategoryPicker(),
                const SizedBox(height: 16),

                // 5. Time / Duration *
                const Text(
                  'TIME / DURATION *',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                _buildDurationPicker(),
                const SizedBox(height: 16),

                // 6. Skills (optional)
                const Text(
                  'SKILLS (OPTIONAL ATTRIBUTION)',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
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
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSaveGoal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFC6F135),
                          foregroundColor: const Color(0xFF020302),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF020302),
                                ),
                              )
                            : Text(
                                _isSubGoal ? 'CREATE SUB-GOAL' : 'CREATE MAIN GOAL',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
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
              selectedColor: const Color(0xFFC6F135).withValues(alpha: 0.25),
              backgroundColor: Colors.white.withValues(alpha: 0.04),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFFC6F135) : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFFC6F135) : Colors.white12,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCategoryPicker() {
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
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'No Goal Categories defined yet in Settings.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _seedDefaultGoalCategory,
                  child: const Text(
                    '+ Add Default',
                    style: TextStyle(color: Color(0xFFC6F135), fontSize: 12),
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
              selectedColor: const Color(0xFFC6F135).withValues(alpha: 0.25),
              backgroundColor: Colors.white.withValues(alpha: 0.04),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFFC6F135) : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFFC6F135) : Colors.white12,
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
          selectedColor: const Color(0xFFC6F135).withValues(alpha: 0.25),
          backgroundColor: Colors.white.withValues(alpha: 0.04),
          labelStyle: TextStyle(
            color: isSelected ? const Color(0xFFC6F135) : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          side: BorderSide(
            color: isSelected ? const Color(0xFFC6F135) : Colors.white12,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkillsPicker() {
    return StreamBuilder<List<Skill>>(
      stream: widget.database.select(widget.database.skills).watch(),
      builder: (context, snapshot) {
        final skills = snapshot.data ?? [];
        if (skills.isEmpty) {
          return const Text(
            'No skills configured yet.',
            style: TextStyle(color: Colors.white24, fontSize: 11),
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
              selectedColor: const Color(0xFFC6F135).withValues(alpha: 0.2),
              backgroundColor: Colors.white.withValues(alpha: 0.03),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFFC6F135) : Colors.white60,
                fontSize: 11,
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFFC6F135) : Colors.white10,
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
