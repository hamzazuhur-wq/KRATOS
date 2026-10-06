// ignore_for_file: public_member_api_docs
// Wave 4: Goal Detail Command Center.
// Comprehensive control hub for Sub-goals, Tasks, Activities, Projects, and XP progression.

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';

import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_skeleton.dart';
import '../../../app/kratos_visuals.dart';
import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../../domain/ids.dart';
import '../../sessions/domain/global_timer_controller.dart';
import '../domain/goal_xp_service.dart';
import 'dialogs/attach_project_dialog.dart';
import 'dialogs/create_goal_activity_dialog.dart';
import 'dialogs/create_goal_dialog.dart';
import 'dialogs/create_goal_task_dialog.dart';
import 'dialogs/edit_goal_dialog.dart';
import 'widgets/goal_card.dart';

class GoalDetailScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final String goalId;

  const GoalDetailScreen({
    super.key,
    required this.database,
    required this.ownerId,
    required this.goalId,
  });

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  late final GoalXpService _goalXpService;
  String _selectedSection =
      'all'; // 'all', 'subgoals', 'tasks', 'projects', 'activities'

  @override
  void initState() {
    super.initState();
    _goalXpService = GoalXpService(widget.database);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Goal?>(
      stream: widget.database.goalsDao.watchById(widget.goalId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'GOAL DETAILS',
                style: TextStyle(
                  color: Color(0xFFC6F135),
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            body: const KratosShimmer(child: GenericDetailSkeleton()),
          );
        }

        final goal = snapshot.data;
        if (goal == null || goal.deletedAt != null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: const Center(
              child: Text(
                'Goal not found or deleted.',
                style: TextStyle(color: Colors.white54),
              ),
            ),
          );
        }

        return Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFFF3F1E8)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEFF08).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFFEEFF08).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Text(
                      goal.parentId == null ? 'ROOT' : 'D${goal.depth}',
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        color: Color(0xFFEEFF08),
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      goal.parentId == null
                          ? 'MAIN GOAL'
                          : 'SUB-GOAL (DEPTH ${goal.depth})',
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        color: Color(0xFFF3F1E8),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF979C92)),
                  tooltip: 'Edit Goal',
                  onPressed: () => _openEditDialog(goal),
                ),
                KratosPopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF979C92)),
                  onSelected: (action) async {
                    if (action == 'pause') {
                      await _toggleGoalStatus(goal, 'paused');
                    } else if (action == 'resume') {
                      await _toggleGoalStatus(goal, 'active');
                    } else if (action == 'delete') {
                      await _confirmDeleteGoal(goal);
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (goal.status == 'active')
                      const KratosPopupMenuItem(
                        value: 'pause',
                        child: Row(
                          children: [
                            Icon(
                              Icons.pause_circle_outline,
                              color: Colors.amber,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Pause Goal',
                              style: TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    if (goal.status == 'paused')
                      const KratosPopupMenuItem(
                        value: 'resume',
                        child: Row(
                          children: [
                            Icon(
                              Icons.play_circle_outline,
                              color: Color(0xFFEEFF08),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Resume Goal',
                              style: TextStyle(color: Colors.white, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    const KratosPopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Delete Goal',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  children: [
                    // Header Card
                    _buildGoalHeaderCard(goal),
                    const SizedBox(height: 10),

                    // Quick Actions Bar
                    _buildQuickActionsBar(goal),
                    const SizedBox(height: 4),

                    // Section Dropdown Selector (Liquid Glass Dropdown)
                    _buildSectionFilterDropdown(),

                    // Selected Section Content
                    Expanded(child: _buildCurrentSectionContent(goal)),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }

  Widget _buildSectionFilterDropdown() {
    final Map<String, ({String label, IconData icon})> sections = {
      'all': (
        label: 'All Overview (الكل والتحليل الشامل)',
        icon: Icons.dashboard_outlined,
      ),
      'subgoals': (
        label: 'Sub-goals (الأهداف الفرعية)',
        icon: Icons.account_tree_outlined,
      ),
      'tasks': (
        label: 'Tasks & Execution (المهام والتنفيذ)',
        icon: Icons.checklist_rtl_outlined,
      ),
      'projects': (
        label: 'Linked Projects (المشاريع المرتبطة)',
        icon: Icons.folder_shared_outlined,
      ),
      'activities': (
        label: 'Activities (الأنشطة وجلسات التركيز)',
        icon: Icons.repeat,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: KratosDropdown<String>(
        value: _selectedSection,
        hint: 'Select Section',
        isExpanded: true,
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        items: sections.entries.map((e) {
          final isSelected = e.key == _selectedSection;
          return KratosDropdownItem<String>(
            value: e.key,
            label: e.value.label,
            leading: Icon(
              e.value.icon,
              size: 16,
              color: isSelected ? const Color(0xFFEEFF08) : Colors.white70,
            ),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            setState(() => _selectedSection = val);
          }
        },
      ),
    );
  }

  Widget _buildCurrentSectionContent(Goal goal) {
    switch (_selectedSection) {
      case 'subgoals':
        return _buildSubGoalsTab(goal);
      case 'tasks':
        return _buildTasksTab(goal);
      case 'projects':
        return _buildProjectsTab(goal);
      case 'activities':
        return _buildActivitiesTab(goal);
      case 'all':
      default:
        return _buildAllSectionsView(goal);
    }
  }

  Widget _buildGoalHeaderCard(Goal goal) {
    final isCompleted = goal.status == 'completed';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: KratosGlassCard(
        variant: KratosSurfaceVariant.normal,
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(18),
        accentColor: isCompleted
            ? const Color(0xFF30D158).withValues(alpha: 0.4)
            : const Color(0xFFEEFF08).withValues(alpha: 0.4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Breadcrumb Path if sub-goal
            if (goal.parentId != null) ...[
              Row(
                children: [
                  const Icon(
                    Icons.account_tree_outlined,
                    size: 13,
                    color: Color(0xFF686D65),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'PATH: ${goal.path.replaceAll('/', '  ›  ')}',
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        fontSize: 9.5,
                        color: Color(0xFF686D65),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Row 2: Status Tag + Life Area + Category + XP Target
            Row(
              children: [
                // Status Tag
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF30D158).withValues(alpha: 0.15)
                        : const Color(0xFFEEFF08).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isCompleted
                          ? const Color(0xFF30D158).withValues(alpha: 0.3)
                          : const Color(0xFFEEFF08).withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    goal.status.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      color: isCompleted
                          ? const Color(0xFF30D158)
                          : const Color(0xFFEEFF08),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Life Area
                if (goal.lifeAreaId != null)
                  StreamBuilder<LifeArea?>(
                    stream: (widget.database.select(widget.database.lifeAreas)
                          ..where((l) => l.id.equals(goal.lifeAreaId!)))
                        .watchSingleOrNull(),
                    builder: (context, snapshot) {
                      final area = snapshot.data;
                      if (area == null) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141714),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          area.name.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            color: Color(0xFF979C92),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),

                // Goal Category
                if (goal.categoryId != null)
                  StreamBuilder<Category?>(
                    stream: widget.database.categoriesDao
                        .findById(goal.categoryId!)
                        .asStream(),
                    builder: (context, snapshot) {
                      final cat = snapshot.data;
                      if (cat == null) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEFF08).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFEEFF08).withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          cat.name.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            color: Color(0xFFEEFF08),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),

                const Spacer(),
                if (goal.xpTarget != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEFF08).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFEEFF08).withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '+${goal.xpTarget} XP',
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        color: Color(0xFFEEFF08),
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              goal.title,
              style: const TextStyle(
                fontFamily: 'Space Grotesk',
                color: Color(0xFFF3F1E8),
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),

            if (goal.description != null && goal.description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                goal.description!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  color: Color(0xFF979C92),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Progress Bar
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: goal.progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCompleted
                            ? const Color(0xFF30D158)
                            : const Color(0xFFEEFF08),
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(goal.progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFFF3F1E8),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 14),

                // Complete Goal Button
                if (!isCompleted)
                  ElevatedButton.icon(
                    onPressed: () => _handleCompleteGoal(goal),
                    icon: const Icon(Icons.check, size: 14, color: Color(0xFF020302)),
                    label: const Text(
                      'COMPLETE',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Color(0xFF020302),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEEFF08),
                      foregroundColor: const Color(0xFF020302),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsBar(Goal goal) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildQuickActionButton(
            label: '+ Sub-goal',
            icon: Icons.subdirectory_arrow_right,
            onTap: () => _openAddSubGoalDialog(goal),
          ),
          const SizedBox(width: 8),
          _buildQuickActionButton(
            label: '+ Task',
            icon: Icons.add_task,
            onTap: () => _openAddTaskDialog(goal),
          ),
          const SizedBox(width: 8),
          _buildQuickActionButton(
            label: '+ Activity',
            icon: Icons.repeat,
            onTap: () => _openAddActivityDialog(goal),
          ),
          const SizedBox(width: 8),
          _buildQuickActionButton(
            label: '+ Project',
            icon: Icons.folder_shared_outlined,
            onTap: () => _openAttachProjectDialog(goal),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFEEFF08).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: const Color(0xFFEEFF08).withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: const Color(0xFFEEFF08)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'IBM Plex Mono',
                color: Color(0xFFEEFF08),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Complete Goal Command Center (All Sections View) ─────────────────────

  Widget _buildAllSectionsView(Goal goal) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        // 1. Life Area & Dev Points Card
        _buildLifeAreaAndDevPointsSection(goal),
        const SizedBox(height: 12),

        // 2. Task Execution Progress & Breakdown
        _buildTasksExecutionSection(goal),
        const SizedBox(height: 12),

        // 3. Sub-goals Progression
        _buildSubGoalsSection(goal),
        const SizedBox(height: 12),

        // 4. Linked Projects
        _buildProjectsSection(goal),
        const SizedBox(height: 12),

        // 5. Activities & Practice
        _buildActivitiesSection(goal),
        const SizedBox(height: 12),

        // 6. Skills Utilized
        _buildSkillsSection(goal),
        const SizedBox(height: 12),

        // 7. What Happened / Highlights & Points
        _buildHighlightsSection(goal),
      ],
    );
  }

  Widget _buildLifeAreaAndDevPointsSection(Goal goal) {
    if (goal.lifeAreaId == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0F110F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Row(
          children: [
            Icon(Icons.public_off, size: 18, color: Color(0xFF686D65)),
            SizedBox(width: 10),
            Text(
              'No Life Area bound to this goal',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF979C92),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<LifeArea?>(
      stream: (widget.database.select(
        widget.database.lifeAreas,
      )..where((l) => l.id.equals(goal.lifeAreaId!))).watchSingleOrNull(),
      builder: (context, snapshot) {
        final area = snapshot.data;
        if (area == null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0D).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141714),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFEEFF08).withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.explore_outlined,
                      color: Color(0xFFEEFF08),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LIFE AREA DOMAIN',
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            color: Color(0xFF686D65),
                            fontSize: 9.5,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          area.name,
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: Color(0xFFF3F1E8),
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEFF08).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFEEFF08).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.bolt,
                          size: 13,
                          color: Color(0xFFEEFF08),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${goal.xpTarget ?? 0} DEV PTS',
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            color: Color(0xFFEEFF08),
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (area.description != null && area.description!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  area.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF979C92),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTasksExecutionSection(Goal goal) {
    return StreamBuilder<List<TaskGoalLink>>(
      stream: (widget.database.select(
        widget.database.taskGoalLinks,
      )..where((l) => l.goalId.equals(goal.id))).watch(),
      builder: (context, linksSnapshot) {
        final links = linksSnapshot.data ?? [];
        final linkedTaskIds = links.map((l) => l.taskId).toList();

        return StreamBuilder<List<Task>>(
          stream:
              (widget.database.select(widget.database.tasks)
                    ..where(
                      (t) =>
                          (t.primaryGoalId.equals(goal.id) |
                              t.id.isIn(linkedTaskIds)) &
                          t.deletedAt.isNull(),
                    )
                    ..orderBy([(t) => drift.OrderingTerm.asc(t.sortOrder)]))
                  .watch(),
          builder: (context, tasksSnapshot) {
            final tasks = tasksSnapshot.data ?? [];
            final totalTasks = tasks.length;
            final completedTasks = tasks
                .where((t) => t.status == 'done')
                .length;
            final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0F0D).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.checklist_rtl_outlined,
                        color: Color(0xFFEEFF08),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'TASK EXECUTION PROGRESS',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF686D65),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          fontSize: 9.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$completedTasks / $totalTasks TASKS',
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFFEEFF08),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFEEFF08),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (tasks.isEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'No execution tasks yet',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: Color(0xFF979C92),
                            fontSize: 12,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _openAddTaskDialog(goal),
                          icon: const Icon(
                            Icons.add,
                            size: 14,
                            color: Color(0xFFEEFF08),
                          ),
                          label: const Text(
                            'Add Task',
                            style: TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              color: Color(0xFFEEFF08),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    )
                  else ...[
                    ...tasks.take(4).map((task) {
                      final isDone = task.status == 'done';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141714),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isDone,
                              activeColor: const Color(0xFFEEFF08),
                              checkColor: const Color(0xFF020302),
                              onChanged: isDone
                                  ? null
                                  : (val) async {
                                      final xp = await _goalXpService
                                          .completeTask(
                                            task: task,
                                            ownerId: widget.ownerId,
                                            lifeAreaId: goal.lifeAreaId,
                                          );
                                      if (context.mounted && xp > 0) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Task completed! +$xp XP earned.',
                                            ),
                                            backgroundColor: const Color(
                                              0xFF141414,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                            ),
                            Expanded(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  color: isDone ? const Color(0xFF686D65) : const Color(0xFFF3F1E8),
                                  fontSize: 12.5,
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (!isDone)
                              IconButton(
                                icon: const Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: Color(0xFFEEFF08),
                                ),
                                tooltip: 'Focus Timer',
                                onPressed: () {
                                  GlobalTimerController().startTimer(
                                    taskId: task.id,
                                    taskTitle: task.title,
                                    goalId: goal.id,
                                    goalTitle: goal.title,
                                    lifeAreaId: goal.lifeAreaId,
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    }),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () => _openAddTaskDialog(goal),
                          icon: const Icon(
                            Icons.add,
                            size: 14,
                            color: Color(0xFFEEFF08),
                          ),
                          label: const Text(
                            '+ New Task',
                            style: TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              color: Color(0xFFEEFF08),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (totalTasks > 4)
                          TextButton(
                            onPressed: () =>
                                setState(() => _selectedSection = 'tasks'),
                            child: Text(
                              'View all ($totalTasks) →',
                              style: const TextStyle(
                                fontFamily: 'IBM Plex Mono',
                                color: Color(0xFF979C92),
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSubGoalsSection(Goal goal) {
    return StreamBuilder<List<Goal>>(
      stream: widget.database.goalsDao.watchChildrenOf(goal.id),
      builder: (context, snapshot) {
        final subGoals = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0D).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_tree_outlined,
                    color: Color(0xFFEEFF08),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SUB-GOALS & MILESTONES',
                    style: TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      color: Color(0xFF686D65),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontSize: 9.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${subGoals.length} MILESTONES',
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      color: Color(0xFFEEFF08),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (subGoals.isEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'No sub-goals added yet',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF979C92),
                        fontSize: 12,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openAddSubGoalDialog(goal),
                      icon: const Icon(
                        Icons.add,
                        size: 14,
                        color: Color(0xFFEEFF08),
                      ),
                      label: const Text(
                        'Add Sub-goal',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFFEEFF08),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                ...subGoals.map(
                  (child) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: GoalCard(
                      goal: child,
                      onTap: () {
                        Navigator.of(context).push(
                          KratosMaterialPageRoute(
                            builder: (context) => GoalDetailScreen(
                              database: widget.database,
                              ownerId: widget.ownerId,
                              goalId: child.id,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _openAddSubGoalDialog(goal),
                    icon: const Icon(
                      Icons.add,
                      size: 14,
                      color: Color(0xFFC6F135),
                    ),
                    label: const Text(
                      '+ Add Another Sub-goal',
                      style: TextStyle(
                        color: Color(0xFFC6F135),
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjectsSection(Goal goal) {
    return StreamBuilder<List<Project>>(
      stream: (widget.database.select(
        widget.database.projects,
      )..where((p) => p.goalId.equals(goal.id) & p.deletedAt.isNull())).watch(),
      builder: (context, snapshot) {
        final projects = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0D).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.folder_shared_outlined,
                    color: Color(0xFFEEFF08),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'CONNECTED PROJECTS',
                    style: TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      color: Color(0xFF686D65),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontSize: 9.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${projects.length} PROJECTS',
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      color: Color(0xFFEEFF08),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (projects.isEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'No projects linked yet',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF979C92),
                        fontSize: 12,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openAttachProjectDialog(goal),
                      icon: const Icon(
                        Icons.link,
                        size: 14,
                        color: Color(0xFFEEFF08),
                      ),
                      label: const Text(
                        'Link Project',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFFEEFF08),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                ...projects.map(
                  (proj) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141714),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.folder_outlined,
                          color: Color(0xFFEEFF08),
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            proj.title,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFFF3F1E8),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEFF08).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFEEFF08).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            proj.status.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              color: Color(0xFFEEFF08),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _openAttachProjectDialog(goal),
                    icon: const Icon(
                      Icons.link,
                      size: 14,
                      color: Color(0xFFEEFF08),
                    ),
                    label: const Text(
                      '+ Link Another Project',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        color: Color(0xFFEEFF08),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivitiesSection(Goal goal) {
    return StreamBuilder<List<Activity>>(
      stream:
          (widget.database.select(widget.database.activities)..where(
                (a) =>
                    (a.lifeAreaId.equals(goal.lifeAreaId ?? '') |
                        a.xpRule.like('%${goal.id}%')) &
                    a.deletedAt.isNull() &
                    a.archivedAt.isNull(),
              ))
              .watch(),
      builder: (context, snapshot) {
        final activities = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0D).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.repeat, color: Color(0xFFEEFF08), size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'FOCUS & ROUTINE ACTIVITIES',
                    style: TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      color: Color(0xFF686D65),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontSize: 9.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${activities.length} ACTIVITIES',
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      color: Color(0xFFEEFF08),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (activities.isEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'No activities bound to routine',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        color: Color(0xFF979C92),
                        fontSize: 12,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _openAddActivityDialog(goal),
                      icon: const Icon(
                        Icons.add,
                        size: 14,
                        color: Color(0xFFEEFF08),
                      ),
                      label: const Text(
                        'Add Activity',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFFEEFF08),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                ...activities.map(
                  (act) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141714),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.repeat,
                          color: Color(0xFFEEFF08),
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            act.name,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFFF3F1E8),
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            GlobalTimerController().startTimer(
                              taskId: act.id,
                              taskTitle: act.name,
                              goalId: goal.id,
                              goalTitle: goal.title,
                              lifeAreaId: goal.lifeAreaId,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEEFF08)
                                .withValues(alpha: 0.12),
                            foregroundColor: const Color(0xFFEEFF08),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                              side: BorderSide(
                                color: const Color(0xFFEEFF08).withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                          child: const Text(
                            'Practice',
                            style: TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _openAddActivityDialog(goal),
                    icon: const Icon(
                      Icons.add,
                      size: 14,
                      color: Color(0xFFEEFF08),
                    ),
                    label: const Text(
                      '+ Add Activity',
                      style: TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        color: Color(0xFFEEFF08),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkillsSection(Goal goal) {
    return FutureBuilder<List<Skill>>(
      future: widget.database.skillsDao.allSkills(widget.ownerId),
      builder: (context, snapshot) {
        final allSkills = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0D).withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.psychology_outlined,
                    color: Color(0xFFEEFF08),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'SKILLS UTILIZED & TRAINED',
                    style: TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      color: Color(0xFF686D65),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontSize: 9.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${allSkills.length} REGISTERED',
                    style: const TextStyle(
                      fontFamily: 'IBM Plex Mono',
                      color: Color(0xFFEEFF08),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (allSkills.isEmpty)
                const Text(
                  'No skills registered yet. Create skills in the Skills registry.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    color: Color(0xFF979C92),
                    fontSize: 12,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: allSkills.take(6).map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141714),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFFEEFF08)
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 12,
                            color: Color(0xFFEEFF08),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${skill.name} (Lv.${skill.level})',
                            style: const TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              color: Color(0xFFF3F1E8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHighlightsSection(Goal goal) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F0D).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.history_edu_outlined,
                color: Color(0xFFEEFF08),
                size: 16,
              ),
              SizedBox(width: 8),
              Text(
                'WHAT HAPPENED & HIGHLIGHTS',
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  color: Color(0xFF686D65),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141714),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL XP VALUE',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF686D65),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+${goal.xpTarget ?? 0} XP',
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFFEEFF08),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141714),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'STATUS',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF686D65),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        goal.status.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFFF3F1E8),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141714),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.flag_outlined,
                  size: 15,
                  color: Color(0xFFEEFF08),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Created on ${goal.createdAt.toLocal().toString().split(' ').first}. Goal tracking active with complete offline-first ledger guarantee.',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF979C92),
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Sub-goals Tab ──────────────────────────────────────────────────────────

  Widget _buildSubGoalsTab(Goal goal) {
    return StreamBuilder<List<Goal>>(
      stream: widget.database.goalsDao.watchChildrenOf(goal.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFC6F135)),
          );
        }

        final subGoals = snapshot.data!;
        if (subGoals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  size: 40,
                  color: Colors.white24,
                ),
                const SizedBox(height: 10),
                const Text(
                  'No Sub-goals in this branch',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () => _openAddSubGoalDialog(goal),
                  icon: const Icon(
                    Icons.add,
                    size: 16,
                    color: Color(0xFFC6F135),
                  ),
                  label: const Text(
                    'Add First Sub-goal',
                    style: TextStyle(color: Color(0xFFC6F135)),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: subGoals.length,
          itemBuilder: (context, index) {
            final child = subGoals[index];
            return GoalCard(
              goal: child,
              onTap: () {
                Navigator.of(context).push(
                  KratosMaterialPageRoute(
                    builder: (context) => GoalDetailScreen(
                      database: widget.database,
                      ownerId: widget.ownerId,
                      goalId: child.id,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── Tasks Tab ──────────────────────────────────────────────────────────────

  Widget _buildTasksTab(Goal goal) {
    return StreamBuilder<List<TaskGoalLink>>(
      stream: (widget.database.select(
        widget.database.taskGoalLinks,
      )..where((l) => l.goalId.equals(goal.id))).watch(),
      builder: (context, linksSnapshot) {
        final links = linksSnapshot.data ?? [];
        final linkedTaskIds = links.map((l) => l.taskId).toList();

        return StreamBuilder<List<Task>>(
          stream:
              (widget.database.select(widget.database.tasks)
                    ..where(
                      (t) =>
                          (t.primaryGoalId.equals(goal.id) |
                              t.id.isIn(linkedTaskIds)) &
                          t.deletedAt.isNull(),
                    )
                    ..orderBy([(t) => drift.OrderingTerm.asc(t.sortOrder)]))
                  .watch(),
          builder: (context, tasksSnapshot) {
            if (!tasksSnapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFFC6F135)),
              );
            }

            final tasks = tasksSnapshot.data!;
            if (tasks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.checklist, size: 40, color: Colors.white24),
                    const SizedBox(height: 10),
                    const Text(
                      'No Tasks Added Yet',
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () => _openAddTaskDialog(goal),
                      icon: const Icon(
                        Icons.add,
                        size: 16,
                        color: Color(0xFFC6F135),
                      ),
                      label: const Text(
                        'Add Task',
                        style: TextStyle(color: Color(0xFFC6F135)),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                final isDone = task.status == 'done';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ListTile(
                    leading: Checkbox(
                      value: isDone,
                      activeColor: const Color(0xFFC6F135),
                      checkColor: const Color(0xFF020302),
                      onChanged: isDone
                          ? null
                          : (val) async {
                              final xpEarned = await _goalXpService
                                  .completeTask(
                                    task: task,
                                    ownerId: widget.ownerId,
                                    lifeAreaId: goal.lifeAreaId,
                                  );
                              if (context.mounted && xpEarned > 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Task completed! +$xpEarned XP earned.',
                                    ),
                                    backgroundColor: const Color(0xFF141414),
                                  ),
                                );
                              }
                            },
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        color: isDone ? Colors.white38 : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    subtitle: task.notes != null
                        ? Text(
                            task.notes!,
                            style: const TextStyle(
                              color: Colors.white30,
                              fontSize: 11,
                            ),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isDone)
                          IconButton(
                            icon: const Icon(
                              Icons.timer_outlined,
                              color: Color(0xFFC6F135),
                              size: 20,
                            ),
                            tooltip: 'Start Focus Timer',
                            onPressed: () {
                              GlobalTimerController().startTimer(
                                taskId: task.id,
                                taskTitle: task.title,
                                goalId: goal.id,
                                goalTitle: goal.title,
                                lifeAreaId: goal.lifeAreaId,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Timer started for "${task.title}"',
                                  ),
                                  backgroundColor: const Color(0xFF141414),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ─── Activities Tab ─────────────────────────────────────────────────────────

  Widget _buildActivitiesTab(Goal goal) {
    return StreamBuilder<List<Activity>>(
      stream:
          (widget.database.select(widget.database.activities)..where(
                (a) =>
                    (a.lifeAreaId.equals(goal.lifeAreaId ?? '') |
                        a.xpRule.like('%${goal.id}%')) &
                    a.deletedAt.isNull() &
                    a.archivedAt.isNull(),
              ))
              .watch(),
      builder: (context, snapshot) {
        final activities = snapshot.data ?? [];
        if (activities.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.repeat, size: 40, color: Colors.white24),
                const SizedBox(height: 10),
                const Text(
                  'No Activities linked',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () => _openAddActivityDialog(goal),
                  icon: const Icon(
                    Icons.add,
                    size: 16,
                    color: Color(0xFFC6F135),
                  ),
                  label: const Text(
                    'Add Activity',
                    style: TextStyle(color: Color(0xFFC6F135)),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final act = activities[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.repeat,
                  color: Color(0xFFC6F135),
                  size: 20,
                ),
                title: Text(
                  act.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                subtitle: act.description != null
                    ? Text(
                        act.description!,
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 11,
                        ),
                      )
                    : null,
                trailing: ElevatedButton(
                  onPressed: () {
                    GlobalTimerController().startTimer(
                      taskId: act.id,
                      taskTitle: act.name,
                      goalId: goal.id,
                      goalTitle: goal.title,
                      lifeAreaId: goal.lifeAreaId,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC6F135)
                        .withValues(alpha: 0.15),
                    foregroundColor: const Color(0xFFC6F135),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                  child: const Text(
                    'Practice',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Projects Tab ──────────────────────────────────────────────────────────

  Widget _buildProjectsTab(Goal goal) {
    return StreamBuilder<List<Project>>(
      stream: (widget.database.select(
        widget.database.projects,
      )..where((p) => p.goalId.equals(goal.id) & p.deletedAt.isNull())).watch(),
      builder: (context, snapshot) {
        final projects = snapshot.data ?? [];
        if (projects.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 40, color: Colors.white24),
                const SizedBox(height: 10),
                const Text(
                  'No Projects attached to this Goal',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: () => _openAttachProjectDialog(goal),
                  icon: const Icon(
                    Icons.link,
                    size: 16,
                    color: Color(0xFFC6F135),
                  ),
                  label: const Text(
                    'Attach Existing Project',
                    style: TextStyle(color: Color(0xFFC6F135)),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final proj = projects[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: ListTile(
                leading: const Icon(
                  Icons.folder,
                  color: Color(0xFFC6F135),
                  size: 20,
                ),
                title: Text(
                  proj.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                subtitle: proj.description != null
                    ? Text(
                        proj.description!,
                        style: const TextStyle(
                          color: Colors.white30,
                          fontSize: 11,
                        ),
                      )
                    : null,
                trailing: Text(
                  proj.status.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFC6F135),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Modal Openers ─────────────────────────────────────────────────────────

  void _openEditDialog(Goal goal) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EditGoalDialog(
        database: widget.database,
        ownerId: widget.ownerId,
        goal: goal,
        onSaved: () => setState(() {}),
      ),
    );
  }

  void _openAddSubGoalDialog(Goal goal) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateGoalDialog(
        database: widget.database,
        ownerId: widget.ownerId,
        parentGoal: goal,
        onGoalCreated: (newSubGoal) {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _openAddTaskDialog(Goal goal) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateGoalTaskDialog(
        database: widget.database,
        ownerId: widget.ownerId,
        goalContext: goal,
        onTaskCreated: () => setState(() {}),
      ),
    );
  }

  void _openAddActivityDialog(Goal goal) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateGoalActivityDialog(
        database: widget.database,
        ownerId: widget.ownerId,
        goalContext: goal,
        onActivityCreated: () => setState(() {}),
      ),
    );
  }

  void _openAttachProjectDialog(Goal goal) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AttachProjectDialog(
        database: widget.database,
        ownerId: widget.ownerId,
        goal: goal,
        onProjectAttached: () => setState(() {}),
      ),
    );
  }

  Future<void> _handleCompleteGoal(Goal goal) async {
    final bonus = await _goalXpService.completeGoal(
      goal: goal,
      ownerId: widget.ownerId,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            goal.parentId == null
                ? 'Main Goal completed! +$bonus XP completion bonus awarded (+30% descendant XP)!'
                : 'Sub-goal completed!',
          ),
          backgroundColor: const Color(0xFF141414),
        ),
      );
    }
  }

  Future<void> _toggleGoalStatus(Goal goal, String newStatus) async {
    final hlc = Hlc.now(Id.uuidV7()).toString();
    final now = DateTime.now().toUtc();
    await (widget.database.update(
      widget.database.goals,
    )..where((g) => g.id.equals(goal.id))).write(
      GoalsCompanion(
        status: drift.Value(newStatus),
        versionHlc: drift.Value(hlc),
        updatedAt: drift.Value(now),
      ),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Goal ${newStatus == "paused" ? "paused" : "resumed"} successfully',
          ),
          backgroundColor: const Color(0xFF1E281E),
        ),
      );
    }
  }

  Future<void> _confirmDeleteGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text(
          'Delete Goal?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Delete “${goal.title}”? Sub-goals and linked items will be unlinked.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final hlc = Hlc.now(Id.uuidV7()).toString();
      await widget.database.goalsDao.softDelete(
        goalId: goal.id,
        deletedBy: widget.ownerId,
        versionHlc: hlc,
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
