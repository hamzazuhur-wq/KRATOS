// ignore_for_file: public_member_api_docs
// Wave 5: Create Goal / Sub-goal Task Dialog.
// Context-inherited from Goal or Sub-goal, uses real Task Categories, and connects to XP.

import 'dart:convert';
import 'dart:ui';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

import '../../../../app/kratos_motion.dart';

import '../../../../data/drift/app_database.dart';
import '../../../../domain/hlc.dart';
import '../../../../domain/ids.dart';

class CreateGoalTaskDialog extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final Goal goalContext; // May be a root goal or sub-goal
  final VoidCallback onTaskCreated;

  const CreateGoalTaskDialog({
    super.key,
    required this.database,
    required this.ownerId,
    required this.goalContext,
    required this.onTaskCreated,
  });

  @override
  State<CreateGoalTaskDialog> createState() => _CreateGoalTaskDialogState();
}

class _CreateGoalTaskDialogState extends State<CreateGoalTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedTaskCategoryId;
  String _selectedDuration = '25m Focus';
  final Set<String> _selectedSkillIds = {};
  bool _startTimerImmediately = false;

  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _durations = ['15m Quick', '25m Focus', '45m Block', '90m Deep'];

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isContextSubGoal => widget.goalContext.parentId != null;

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
                        color: const Color(0xFF141714),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFEEFF08).withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Icon(Icons.add_task, color: Color(0xFFEEFF08), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isContextSubGoal ? 'ADD TASK TO SUB-GOAL' : 'ADD TASK TO GOAL',
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        color: Color(0xFFF3F1E8),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Context banner (shows exclusivity: Goal OR Sub-goal)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141714),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isContextSubGoal ? Icons.subdirectory_arrow_right : Icons.track_changes,
                        size: 13,
                        color: const Color(0xFFEEFF08),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isContextSubGoal ? 'ATTACHED TO SUB-GOAL: ' : 'ATTACHED TO MAIN GOAL: ',
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF686D65),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.goalContext.title,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0xFFF3F1E8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Task Title *
                const Text(
                  'TASK NAME *',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFF686D65),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFFF3F1E8),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Implement Drift DAO unit tests',
                    hintStyle: const TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF686D65),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF141714),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFEEFF08)),
                    ),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Please enter task name' : null,
                ),
                const SizedBox(height: 14),

                // Task Category * (from Task Categories, NOT Goal Categories)
                const Text(
                  'TASK CATEGORY * (SETTINGS → TASK CATEGORIES)',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFF686D65),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                _buildTaskCategoryPicker(),
                const SizedBox(height: 14),

                // Time / Duration
                const Text(
                  'FOCUS DURATION',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFF686D65),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: _durations.map((d) {
                    final isSel = _selectedDuration == d;
                    return ChoiceChip(
                      label: Text(
                        d,
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: isSel ? const Color(0xFF020302) : const Color(0xFF979C92),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      selected: isSel,
                      onSelected: (val) {
                        if (val) setState(() => _selectedDuration = d);
                      },
                      selectedColor: const Color(0xFFEEFF08),
                      backgroundColor: const Color(0xFF141714),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: BorderSide(
                          color: isSel ? const Color(0xFFEEFF08) : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Skills (optional)
                const Text(
                  'SKILLS ATTRIBUTION (OPTIONAL)',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFF686D65),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                _buildSkillsPicker(),
                const SizedBox(height: 14),

                // Notes
                const Text(
                  'NOTES / CHECKLIST',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFF686D65),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFFF3F1E8),
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Acceptance criteria or instructions',
                    hintStyle: const TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF686D65),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF141714),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFEEFF08)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Timer support toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _startTimerImmediately,
                  onChanged: (val) => setState(() => _startTimerImmediately = val),
                  activeThumbColor: const Color(0xFFEEFF08),
                  title: const Text(
                    'Start Timer immediately after creation',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFFF3F1E8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: const Text(
                    'Launches global focus capture session',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF686D65),
                      fontSize: 11,
                    ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorMessage!, style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 12)),
                ],

                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF979C92),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
                        onPressed: _isSaving ? null : _saveTask,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEEFF08),
                          foregroundColor: const Color(0xFF020302),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF020302)),
                              )
                            : const Text(
                                'CREATE TASK',
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Mono',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: Color(0xFF020302),
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

  Widget _buildTaskCategoryPicker() {
    return StreamBuilder<List<Category>>(
      stream: widget.database.categoriesDao.watchCategoriesByType(widget.ownerId, 'task'),
      builder: (context, snapshot) {
        final cats = snapshot.data ?? [];
        if (cats.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'No Task Categories found.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _seedDefaultTaskCategory,
                  child: const Text('+ Add Default', style: TextStyle(color: Color(0xFFC6F135), fontSize: 12)),
                ),
              ],
            ),
          );
        }

        return Wrap(
          spacing: 8,
          children: cats.map((cat) {
            final isSel = _selectedTaskCategoryId == cat.id;
            return ChoiceChip(
              label: Text(cat.name),
              selected: isSel,
              onSelected: (val) {
                if (val) setState(() => _selectedTaskCategoryId = cat.id);
              },
              selectedColor: const Color(0xFFC6F135).withValues(alpha: 0.25),
              backgroundColor: Colors.white.withValues(alpha: 0.04),
              labelStyle: TextStyle(
                color: isSel ? const Color(0xFFC6F135) : Colors.white70,
                fontSize: 11,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _seedDefaultTaskCategory() async {
    final catId = Id.uuidV7().value;
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(Id.uuidV7()).toString();

    await widget.database.categoriesDao.upsertCategory(
      CategoriesCompanion(
        id: drift.Value(catId),
        ownerId: drift.Value(widget.ownerId),
        name: const drift.Value('Deep Work'),
        categoryType: const drift.Value('task'),
        description: const drift.Value('High focus cognitive execution'),
        baseXp: const drift.Value(50),
        isImmutable: const drift.Value(false),
        sortOrder: const drift.Value(0),
        versionHlc: drift.Value(hlc),
        createdAt: drift.Value(now),
        updatedAt: drift.Value(now),
      ),
    );
    setState(() => _selectedTaskCategoryId = catId);
  }

  Widget _buildSkillsPicker() {
    return StreamBuilder<List<Skill>>(
      stream: widget.database.select(widget.database.skills).watch(),
      builder: (context, snapshot) {
        final skills = snapshot.data ?? [];
        if (skills.isEmpty) {
          return const Text('No skills available', style: TextStyle(color: Colors.white24, fontSize: 11));
        }

        return Wrap(
          spacing: 6,
          children: skills.map((s) {
            final isSel = _selectedSkillIds.contains(s.id);
            return FilterChip(
              label: Text(s.name),
              selected: isSel,
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedSkillIds.add(s.id);
                  } else {
                    _selectedSkillIds.remove(s.id);
                  }
                });
              },
              selectedColor: const Color(0xFFC6F135).withValues(alpha: 0.2),
              backgroundColor: Colors.white.withValues(alpha: 0.03),
              labelStyle: TextStyle(
                color: isSel ? const Color(0xFFC6F135) : Colors.white60,
                fontSize: 11,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTaskCategoryId == null) {
      setState(() => _errorMessage = 'Please select a Task Category');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final taskId = Id.uuidV7().value;
      final now = DateTime.now().toUtc();
      final hlc = Hlc.now(Id.uuidV7()).toString();

      await widget.database.transaction(() async {
        // 1. Insert Task with categoryId and primaryGoalId
        await widget.database.tasksDao.upsert(
          TasksCompanion(
            id: drift.Value(taskId),
            ownerId: drift.Value(widget.ownerId),
            primaryGoalId: drift.Value(widget.goalContext.id),
            categoryId: drift.Value(_selectedTaskCategoryId),
            title: drift.Value(_titleController.text.trim()),
            notes: drift.Value(_notesController.text.trim().isNotEmpty
                ? _notesController.text.trim()
                : null),
            priority: const drift.Value(1),
            status: const drift.Value('open'),
            sortOrder: const drift.Value(0),
            versionHlc: drift.Value(hlc),
            createdAt: drift.Value(now),
            updatedAt: drift.Value(now),
          ),
        );

        // 2. Insert TaskGoalLink junction (M:N relationship)
        await widget.database.taskGoalLinksDao.upsert(
          TaskGoalLinksCompanion(
            taskId: drift.Value(taskId),
            goalId: drift.Value(widget.goalContext.id),
            role: const drift.Value('contributes_to'),
            sortOrder: const drift.Value(0),
            versionHlc: drift.Value(hlc),
            createdAt: drift.Value(now),
          ),
        );

        // 3. Enqueue to outbox
        await widget.database.into(widget.database.syncOutbox).insert(
          SyncOutboxCompanion.insert(
            userId: widget.ownerId,
            op: 'upsert',
            entity: 'tasks',
            entityId: taskId,
            payloadJson: jsonEncode({
              'id': taskId,
              'owner_id': widget.ownerId,
              'primary_goal_id': widget.goalContext.id,
              'category_id': _selectedTaskCategoryId,
              'title': _titleController.text.trim(),
              'notes': _notesController.text.trim(),
              'status': 'open',
            }),
            hlc: hlc,
            deviceId: 'local_device',
          ),
        );
      });

      widget.onTaskCreated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Failed to create task: $e';
        });
      }
    }
  }
}
