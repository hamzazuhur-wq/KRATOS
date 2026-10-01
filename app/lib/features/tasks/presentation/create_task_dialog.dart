import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

import '../../../app/active_glass_card.dart';
import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_theme.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../../domain/entities/task.dart' as domain;
import '../data/task_repository_impl.dart';

/// Real Task creation dialog for KRATOS.
///
/// Implements full domain/persistence integration:
/// - Title (Required)
/// - Life Area (Required, real persisted IDs)
/// - Goal / Sub-goal (Optional, scoped to Life Area)
/// - Project (Optional, scoped to Life Area / Goal)
/// - Skills (Optional, multi-select, persisted to AttachmentLinks)
/// - Task Category (Optional, category_type == 'task', with inline creation)
/// - Priority (1 to 5)
/// - Planned Due Date (Optional)
/// - Notes (Optional)
class CreateTaskDialog extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final String? initialLifeAreaId;
  final String? initialGoalId;
  final String? initialProjectId;
  final String? initialPhaseId;
  final VoidCallback? onCreated;

  const CreateTaskDialog({
    super.key,
    required this.database,
    required this.ownerId,
    String? initialLifeAreaId,
    String? initialGoalId,
    String? initialProjectId,
    String? initialPhaseId,
    String? defaultLifeAreaId,
    String? defaultGoalId,
    String? defaultProjectId,
    String? defaultPhaseId,
    this.onCreated,
  }) : initialLifeAreaId = initialLifeAreaId ?? defaultLifeAreaId,
       initialGoalId = initialGoalId ?? defaultGoalId,
       initialProjectId = initialProjectId ?? defaultProjectId,
       initialPhaseId = initialPhaseId ?? defaultPhaseId;

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  String? _lifeAreaId;
  String? _goalId;
  String? _projectId;
  String? _phaseId;
  String? _projectTitle;
  String? _phaseTitle;
  String? _categoryId;
  final Set<String> _selectedSkillIds = {};
  int _priority = 2; // 1: Low, 2: Normal, 3: High, 4: Urgent, 5: Critical
  DateTime? _dueDate;
  int _xpReward = 50;

  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _lifeAreaId = widget.initialLifeAreaId;
    _goalId = widget.initialGoalId;
    _projectId = widget.initialProjectId;
    _phaseId = widget.initialPhaseId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ActiveGlassCard(
          active: false,
          borderRadius: BorderRadius.circular(24),
          padding: EdgeInsets.zero,
          child: FutureBuilder<(List<LifeArea>, List<Category>, List<Skill>)>(
            future: _loadPrerequisites(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Error loading task dependencies: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: KratosTheme.acidLime,
                    ),
                  ),
                );
              }

              final (lifeAreas, taskCategories, skills) = snapshot.data!;
              final selectedArea = lifeAreas
                  .where((a) => a.id == _lifeAreaId)
                  .firstOrNull;
              final selectedCat = taskCategories
                  .where((c) => c.id == _categoryId)
                  .firstOrNull;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NEW TASK',
                              style: TextStyle(
                                color: KratosTheme.acidLime,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2.0,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Actionable unit of focused execution',
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white60,
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // 2. Error message banner if validation failed
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 3. Task Title Field (Required)
                    _buildLabel('TASK TITLE *'),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('task_title_input'),
                      controller: _titleController,
                      autofocus: true,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: 'What needs to be accomplished?',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Context Banner if inside a project/phase
                    if (_projectId != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: KratosTheme.acidLime.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: KratosTheme.acidLime.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.folder_outlined,
                              color: KratosTheme.acidLime,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'PROJECT: ${_projectTitle ?? 'Attached to Project'}',
                                    style: const TextStyle(
                                      color: KratosTheme.acidLime,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  if (_phaseTitle != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Phase: $_phaseTitle',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 4. Life Area, Goal & Project Selectors (Only shown if NOT inside a project context)
                    if (_projectId == null) ...[
                      _buildLabel('LIFE AREA *'),
                      const SizedBox(height: 6),
                      _PickerTile(
                        key: const Key('task_life_area_picker'),
                        icon: Icons.public,
                        label: 'Life Area',
                        value: selectedArea != null
                            ? '${selectedArea.icon ?? '🌐'} ${selectedArea.name}'
                            : null,
                        placeholder: lifeAreas.isEmpty
                            ? 'No Life Areas defined'
                            : 'Select Life Area (Required)',
                        onTap: lifeAreas.isEmpty
                            ? null
                            : () => _pickLifeArea(lifeAreas),
                      ),
                      const SizedBox(height: 16),

                      // 5. Goal / Sub-goal Selector (Optional, scoped to Life Area)
                      if (_lifeAreaId != null) ...[
                        FutureBuilder<List<Goal>>(
                          future: _loadGoalsForArea(_lifeAreaId!),
                          builder: (context, goalSnapshot) {
                            final goals = goalSnapshot.data ?? const <Goal>[];
                            final selectedGoal = goals
                                .where((g) => g.id == _goalId)
                                .firstOrNull;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('GOAL / SUB-GOAL (OPTIONAL)'),
                                const SizedBox(height: 6),
                                _PickerTile(
                                  key: const Key('task_goal_picker'),
                                  icon: Icons.track_changes,
                                  label: 'Goal / Sub-goal',
                                  value: selectedGoal != null
                                      ? (selectedGoal.parentId != null
                                            ? '↳ ${selectedGoal.title}'
                                            : selectedGoal.title)
                                      : null,
                                  placeholder: goals.isEmpty
                                      ? 'No goals for this Life Area'
                                      : 'Attach to Goal or Sub-goal',
                                  onClear: selectedGoal != null
                                      ? () => setState(() => _goalId = null)
                                      : null,
                                  onTap: goals.isEmpty
                                      ? null
                                      : () => _pickGoal(goals),
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        ),

                        // 6. Project Selector (Optional, scoped to Life Area)
                        FutureBuilder<List<Project>>(
                          future: _loadProjectsForArea(_lifeAreaId!),
                          builder: (context, projSnapshot) {
                            final projects =
                                projSnapshot.data ?? const <Project>[];
                            final selectedProject = projects
                                .where((p) => p.id == _projectId)
                                .firstOrNull;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('PROJECT (OPTIONAL)'),
                                const SizedBox(height: 6),
                                _PickerTile(
                                  key: const Key('task_project_picker'),
                                  icon: Icons.folder_outlined,
                                  label: 'Project',
                                  value: selectedProject?.title,
                                  placeholder: projects.isEmpty
                                      ? 'No projects for this Life Area'
                                      : 'Attach to Project',
                                  onClear: selectedProject != null
                                      ? () => setState(() => _projectId = null)
                                      : null,
                                  onTap: projects.isEmpty
                                      ? null
                                      : () => _pickProject(projects),
                                ),
                                const SizedBox(height: 16),
                              ],
                            );
                          },
                        ),
                      ],
                    ],

                    // 7. Skills Multi-Select
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildLabel('SKILLS (OPTIONAL)')),
                        if (skills.isNotEmpty)
                          InkWell(
                            onTap: () => _openSkillsPicker(skills),
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 13,
                                    color: KratosTheme.acidLime,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Add Skill',
                                    style: TextStyle(
                                      color: KratosTheme.acidLime,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (_selectedSkillIds.isEmpty)
                      InkWell(
                        key: const Key('task_skills_picker'),
                        onTap: skills.isEmpty
                            ? null
                            : () => _openSkillsPicker(skills),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.bolt,
                                size: 18,
                                color: Colors.white38,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                skills.isEmpty
                                    ? 'No skills registered'
                                    : 'Select relevant skills...',
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ..._selectedSkillIds.map((skillId) {
                            final sk = skills
                                .where((s) => s.id == skillId)
                                .firstOrNull;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: KratosTheme.acidLime.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: KratosTheme.acidLime.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    sk?.icon ?? '⚡',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    sk?.name ?? 'Skill',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => setState(
                                      () => _selectedSkillIds.remove(skillId),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 14,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          ActionChip(
                            avatar: const Icon(
                              Icons.add,
                              size: 14,
                              color: KratosTheme.acidLime,
                            ),
                            label: const Text(
                              'Add',
                              style: TextStyle(
                                color: KratosTheme.acidLime,
                                fontSize: 11,
                              ),
                            ),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.06,
                            ),
                            side: BorderSide(
                              color: KratosTheme.acidLime.withValues(
                                alpha: 0.3,
                              ),
                            ),
                            onPressed: () => _openSkillsPicker(skills),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // 8. Task Category Selector (Only shown if NOT inside a project context)
                    if (_projectId == null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _buildLabel('TASK CATEGORY (OPTIONAL)'),
                          ),
                          InkWell(
                            onTap: _openAddTaskCategoryDialog,
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 13,
                                    color: KratosTheme.acidLime,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Add Category',
                                    style: TextStyle(
                                      color: KratosTheme.acidLime,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _PickerTile(
                        key: const Key('task_category_picker'),
                        icon: Icons.label_outline,
                        label: 'Task Category',
                        value: selectedCat?.name,
                        placeholder: taskCategories.isEmpty
                            ? 'No task categories'
                            : 'Select Task Category',
                        onClear: selectedCat != null
                            ? () => setState(() => _categoryId = null)
                            : null,
                        onTap: taskCategories.isEmpty
                            ? () => _openAddTaskCategoryDialog()
                            : () => _pickTaskCategory(taskCategories),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 9. Priority & Due Date Row
                    Row(
                      children: [
                        // Priority Selector
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('PRIORITY'),
                              const SizedBox(height: 6),
                              KratosDropdown<int>(
                                key: const Key('task_priority_dropdown'),
                                value: _priority,
                                hint: 'Priority',
                                isExpanded: true,
                                height: 42,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                items: const [
                                  KratosDropdownItem(
                                    value: 1,
                                    label: 'Low (1)',
                                    leading: Text('🟢', style: TextStyle(fontSize: 12)),
                                  ),
                                  KratosDropdownItem(
                                    value: 2,
                                    label: 'Normal (2)',
                                    leading: Text('🔵', style: TextStyle(fontSize: 12)),
                                  ),
                                  KratosDropdownItem(
                                    value: 3,
                                    label: 'High (3)',
                                    leading: Text('🟡', style: TextStyle(fontSize: 12)),
                                  ),
                                  KratosDropdownItem(
                                    value: 4,
                                    label: 'Urgent (4)',
                                    leading: Text('🟠', style: TextStyle(fontSize: 12)),
                                  ),
                                  KratosDropdownItem(
                                    value: 5,
                                    label: 'Critical (5)',
                                    leading: Text('🔴', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                                onChanged: (p) {
                                  if (p != null) {
                                    setState(() => _priority = p);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Due Date Picker
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('PLANNED DUE DATE'),
                              const SizedBox(height: 6),
                              InkWell(
                                key: const Key('task_due_date_picker'),
                                onTap: _pickDueDate,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 13,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.event,
                                        size: 16,
                                        color: Colors.white54,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _dueDate != null
                                              ? '${_dueDate!.year}-${_dueDate!.month.toString().padLeft(2, '0')}-${_dueDate!.day.toString().padLeft(2, '0')}'
                                              : 'No due date',
                                          style: TextStyle(
                                            color: _dueDate != null
                                                ? Colors.white
                                                : Colors.white38,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (_dueDate != null)
                                        InkWell(
                                          onTap: () =>
                                              setState(() => _dueDate = null),
                                          child: const Icon(
                                            Icons.close,
                                            size: 14,
                                            color: Colors.white54,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // XP Reward Section
                    _buildLabel('XP REWARD ON COMPLETION'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [25, 50, 100, 200].map((xp) {
                        final isSel = _xpReward == xp;
                        return Padding(
                          padding: EdgeInsets.zero,
                          child: InkWell(
                            onTap: () => setState(() => _xpReward = xp),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? KratosTheme.acidLime.withValues(alpha: 0.2)
                                    : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? KratosTheme.acidLime : Colors.white12,
                                  width: isSel ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bolt,
                                    size: 14,
                                    color: isSel ? KratosTheme.acidLime : Colors.white54,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+$xp XP',
                                    style: TextStyle(
                                      color: isSel ? KratosTheme.acidLime : Colors.white70,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // 10. Notes Field (Optional)
                    _buildLabel('NOTES & CONTEXT (OPTIONAL)'),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('task_notes_input'),
                      controller: _notesController,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText:
                            'Checklist items, links, or execution details...',
                        hintStyle: const TextStyle(color: Colors.white24),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: KratosTheme.acidLime,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 11. Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              foregroundColor: Colors.white54,
                            ),
                            child: const Text(
                              'CANCEL',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            key: const Key('submit_create_task_button'),
                            onPressed: _saving ? null : _saveTask,
                            style: FilledButton.styleFrom(
                              backgroundColor: KratosTheme.acidLime,
                              foregroundColor: const Color(0xFF0D0D0D),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _saving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0D0D0D),
                                    ),
                                  )
                                : const Text(
                                    'CREATE TASK',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Future<(List<LifeArea>, List<Category>, List<Skill>)>
  _loadPrerequisites() async {
    // If inside a project or phase context, attempt to auto-derive lifeAreaId, goalId, and names
    if (_projectId != null) {
      final prj = await widget.database.projectsDao.findById(_projectId!);
      if (prj != null) {
        _projectTitle = prj.title;
        _lifeAreaId ??= prj.lifeAreaId;
        _goalId ??= prj.goalId;
      }
    } else if (_phaseId != null && _projectId == null) {
      final ph = await widget.database.projectsDao.findPhaseById(_phaseId!);
      if (ph != null) {
        _phaseTitle = ph.name;
        _projectId = ph.projectId;
        final prj = await widget.database.projectsDao.findById(ph.projectId);
        if (prj != null) {
          _projectTitle = prj.title;
          _lifeAreaId ??= prj.lifeAreaId;
          _goalId ??= prj.goalId;
        }
      }
    }
    if (_phaseId != null && _phaseTitle == null) {
      final ph = await widget.database.projectsDao.findPhaseById(_phaseId!);
      if (ph != null) {
        _phaseTitle = ph.name;
      }
    }

    final lifeAreas =
        await (widget.database.select(widget.database.lifeAreas)
              ..where(
                (a) =>
                    a.ownerId.equals(widget.ownerId) &
                    a.archivedAt.isNull() &
                    a.deletedAt.isNull(),
              )
              ..orderBy([(a) => drift.OrderingTerm.asc(a.sortOrder)]))
            .get();

    final taskCategories = await widget.database.categoriesDao.categoriesByType(
      widget.ownerId,
      'task',
    );

    final skills = await widget.database.skillsDao.allSkills(widget.ownerId);

    return (lifeAreas, taskCategories, skills);
  }

  Future<List<Goal>> _loadGoalsForArea(String areaId) {
    return (widget.database.select(widget.database.goals)
          ..where(
            (g) =>
                g.ownerId.equals(widget.ownerId) &
                (g.lifeAreaId.equals(areaId) | g.lifeAreaId.isNull()) &
                g.deletedAt.isNull(),
          )
          ..orderBy([
            (g) => drift.OrderingTerm.asc(g.path),
            (g) => drift.OrderingTerm.asc(g.title),
          ]))
        .get();
  }

  Future<List<Project>> _loadProjectsForArea(String areaId) {
    return (widget.database.select(widget.database.projects)
          ..where(
            (p) =>
                p.ownerId.equals(widget.ownerId) &
                (p.lifeAreaId.equals(areaId) | p.lifeAreaId.isNull()) &
                p.deletedAt.isNull(),
          )
          ..orderBy([(p) => drift.OrderingTerm.asc(p.title)]))
        .get();
  }

  Future<void> _pickLifeArea(List<LifeArea> areas) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF161616),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              'SELECT LIFE AREA',
              style: TextStyle(
                color: KratosTheme.acidLime,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
          ),
          ...areas.map(
            (a) => ListTile(
              leading: Text(
                a.icon ?? '🌐',
                style: const TextStyle(fontSize: 18),
              ),
              title: Text(
                a.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: a.description != null
                  ? Text(
                      a.description!,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    )
                  : null,
              onTap: () => Navigator.pop(context, a.id),
            ),
          ),
        ],
      ),
    );

    if (picked != null) {
      setState(() {
        _lifeAreaId = picked;
        // Revalidate dependent relationships
        _goalId = null;
        _projectId = null;
        _errorMessage = null;
      });
    }
  }

  Future<void> _pickGoal(List<Goal> goals) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF161616),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              'SELECT GOAL OR SUB-GOAL',
              style: TextStyle(
                color: KratosTheme.acidLime,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.clear, color: Colors.white38, size: 20),
            title: const Text(
              'None (Detached)',
              style: TextStyle(color: Colors.white70),
            ),
            onTap: () => Navigator.pop(context, '__NONE__'),
          ),
          ...goals.map((g) {
            final isSubGoal = g.parentId != null;
            return ListTile(
              contentPadding: EdgeInsets.only(
                left: isSubGoal ? 32.0 : 16.0,
                right: 16.0,
              ),
              leading: Icon(
                isSubGoal
                    ? Icons.subdirectory_arrow_right
                    : Icons.track_changes,
                color: isSubGoal ? KratosTheme.cyan : KratosTheme.acidLime,
                size: isSubGoal ? 18 : 20,
              ),
              title: Text(
                g.title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: isSubGoal ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Text(
                isSubGoal
                    ? 'Sub-goal • ${g.status.toUpperCase()}'
                    : 'Root Goal • ${g.status.toUpperCase()}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              onTap: () => Navigator.pop(context, g.id),
            );
          }),
        ],
      ),
    );

    if (picked != null) {
      setState(() {
        _goalId = picked == '__NONE__' ? null : picked;
      });
    }
  }

  Future<void> _pickProject(List<Project> projects) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF161616),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              'SELECT PROJECT',
              style: TextStyle(
                color: KratosTheme.acidLime,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.clear, color: Colors.white38, size: 20),
            title: const Text(
              'None (No Project)',
              style: TextStyle(color: Colors.white70),
            ),
            onTap: () => Navigator.pop(context, '__NONE__'),
          ),
          ...projects.map(
            (p) => ListTile(
              leading: const Icon(
                Icons.folder_outlined,
                color: KratosTheme.acidLime,
                size: 20,
              ),
              title: Text(
                p.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                p.status.toUpperCase(),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              onTap: () => Navigator.pop(context, p.id),
            ),
          ),
        ],
      ),
    );

    if (picked != null) {
      setState(() {
        _projectId = picked == '__NONE__' ? null : picked;
      });
    }
  }

  Future<void> _pickTaskCategory(List<Category> categories) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF161616),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Text(
              'SELECT TASK CATEGORY',
              style: TextStyle(
                color: KratosTheme.acidLime,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.clear, color: Colors.white38, size: 20),
            title: const Text(
              'None (Uncategorized)',
              style: TextStyle(color: Colors.white70),
            ),
            onTap: () => Navigator.pop(context, '__NONE__'),
          ),
          ...categories.map(
            (c) => ListTile(
              leading: Text(
                c.icon ?? '🏷️',
                style: const TextStyle(fontSize: 18),
              ),
              title: Text(
                c.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () => Navigator.pop(context, c.id),
            ),
          ),
        ],
      ),
    );

    if (picked != null) {
      setState(() {
        _categoryId = picked == '__NONE__' ? null : picked;
      });
    }
  }

  Future<void> _openSkillsPicker(List<Skill> skills) async {
    final tempSelected = Set<String>.from(_selectedSkillIds);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF161616),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'SELECT SKILLS',
                    style: TextStyle(
                      color: KratosTheme.acidLime,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      fontSize: 12,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'DONE',
                      style: TextStyle(
                        color: KratosTheme.acidLime,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              ...skills.map((sk) {
                final isSelected = tempSelected.contains(sk.id);
                return CheckboxListTile(
                  activeColor: KratosTheme.acidLime,
                  checkColor: const Color(0xFF0D0D0D),
                  value: isSelected,
                  secondary: Text(
                    sk.icon ?? '⚡',
                    style: const TextStyle(fontSize: 18),
                  ),
                  title: Text(
                    sk.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    'Level ${sk.level} • ${sk.xpTotal} XP',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  onChanged: (checked) {
                    setModalState(() {
                      if (checked == true) {
                        tempSelected.add(sk.id);
                      } else {
                        tempSelected.remove(sk.id);
                      }
                    });
                  },
                );
              }),
            ],
          );
        },
      ),
    );

    setState(() {
      _selectedSkillIds.clear();
      _selectedSkillIds.addAll(tempSelected);
    });
  }

  Future<void> _openAddTaskCategoryDialog() async {
    final nameCtrl = TextEditingController();
    final created = await showDialog<Category?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          'New Task Category',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Deep Work, Quick Win',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: KratosTheme.acidLime,
              foregroundColor: const Color(0xFF0D0D0D),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final id = 'cat_task_${DateTime.now().microsecondsSinceEpoch}';
              final now = DateTime.now().toUtc();
              const hlc = '0:0:1';

              final comp = CategoriesCompanion.insert(
                id: id,
                ownerId: widget.ownerId,
                name: name,
                categoryType: const drift.Value('task'),
                baseXp: 100,
                isImmutable: false,
                sortOrder: 0,
                versionHlc: hlc,
                createdAt: now,
                updatedAt: now,
              );
              await widget.database.categoriesDao.upsertCategory(comp);
              final saved = await widget.database.categoriesDao.findById(id);
              if (ctx.mounted) Navigator.pop(ctx, saved);
            },
            child: const Text('Create Category'),
          ),
        ],
      ),
    );

    if (created != null) {
      setState(() => _categoryId = created.id);
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: KratosTheme.acidLime,
            onPrimary: Color(0xFF0D0D0D),
            surface: Color(0xFF1A1A1A),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _saveTask() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _errorMessage = 'Task Title is required.');
      return;
    }

    if (_lifeAreaId == null && _projectId == null) {
      setState(
        () => _errorMessage = 'Please select a Life Area for this task.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final taskId = Id.uuidV7();
    final now = DateTime.now().toUtc();
    final hlc = Hlc.now(taskId);

    try {
      await widget.database.transaction(() async {
        // Persist through the domain repository so the local row and sync
        // outbox follow the same path as every other Task mutation.
        final task = domain.Task.fromData(
          id: taskId,
          ownerId: Id(widget.ownerId),
          title: title,
          status: domain.TaskStatus.pending,
          priority: _priority,
          sortOrder: 0,
          versionHlc: hlc,
          createdAt: now,
          lifeAreaId: _lifeAreaId == null ? null : Id(_lifeAreaId!),
          primaryGoalId: _goalId == null ? null : Id(_goalId!),
          projectId: _projectId == null ? null : Id(_projectId!),
          phaseId: _phaseId == null ? null : Id(_phaseId!),
          categoryId: _categoryId == null ? null : Id(_categoryId!),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          dueDate: _dueDate?.toUtc(),
          xpReward: _xpReward,
        );
        await DriftTaskRepository(widget.database).save(task);

        // 2. If goal is selected, record TaskGoalLinks junction
        if (_goalId != null) {
          await widget.database.taskGoalLinksDao.upsert(
            TaskGoalLinksCompanion(
              taskId: drift.Value(taskId.value),
              goalId: drift.Value(_goalId!),
              role: const drift.Value('contributes_to'),
              sortOrder: const drift.Value(0),
              versionHlc: drift.Value(hlc.toString()),
              createdAt: drift.Value(now),
            ),
          );
        }

        // 3. For each selected skill, insert into AttachmentLinks table
        for (final skillId in _selectedSkillIds) {
          await widget.database.attachmentLinksDao.upsertSkillLink(
            ownerId: widget.ownerId,
            entityId: taskId.value,
            entityKind: 'task',
            skillId: skillId,
            versionHlc: hlc.toString(),
          );
        }
      });

      widget.onCreated?.call();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMessage = 'Failed to create task: $e';
        });
      }
    }
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback? onTap;
  final VoidCallback? onClear;

  const _PickerTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: value != null
                ? KratosTheme.acidLime.withValues(alpha: 0.3)
                : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: value != null ? KratosTheme.acidLime : Colors.white38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value ?? placeholder,
                style: TextStyle(
                  color: value != null ? Colors.white : Colors.white38,
                  fontSize: 13,
                  fontWeight: value != null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              IconButton(
                icon: const Icon(Icons.clear, size: 16, color: Colors.white54),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              )
            else
              const Icon(Icons.expand_more, size: 18, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
