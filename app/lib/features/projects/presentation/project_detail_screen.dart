import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';

import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/kratos_skeleton.dart';
import '../../../app/kratos_theme.dart';
import '../../../app/kratos_visuals.dart';
import '../../../data/drift/app_database.dart';
import '../../activities/presentation/activity_detail_screen.dart';
import '../../activities/presentation/create_activity_dialog.dart';
import '../../ideas/data/ideas_repository.dart';
import '../../ideas/presentation/dialogs/idea_search_dialog.dart';
import '../../ideas/presentation/idea_editor_screen.dart';
import '../../tasks/data/task_dashboard_repository.dart';
import '../../tasks/presentation/create_task_dialog.dart';
import '../../xp/data/xp_ledger_writer_impl.dart';
import '../data/project_storage_service.dart';
import '../data/projects_repository.dart';
import '../domain/project_models.dart';
import 'dialogs/create_phase_dialog.dart';
import 'dialogs/edit_project_dialog.dart';
import 'phase_detail_screen.dart';
import 'widgets/skills_selector_dialog.dart';

/// Task filter modes within the project workspace.
enum ProjectTaskFilter { all, inProgress, pending, completed }

/// Main workspace for a Project.
///
/// Designed as ONE long scrollable workspace page composed of stacked Liquid Glass
/// cards in strict information architecture order:
/// 1. Overview Card
/// 2. Roadmap Card
/// 3. Tasks Card (with Total, Completed, In Progress/Active, Pending/Remaining metrics & filters)
/// 4. Connected Activities Card
/// 5. Project Ideas Card
/// 6. Project Notes Card
/// 7. Files & Attachments Card
/// 8. External Resources Card
class ProjectDetailScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final String projectId;

  const ProjectDetailScreen({
    super.key,
    required this.database,
    required this.ownerId,
    required this.projectId,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late final ProjectsRepository _repository;
  final _storageService = ProjectStorageService();

  ProjectWithDetails? _details;
  bool _loading = true;
  ProjectTaskFilter _taskFilter = ProjectTaskFilter.all;

  @override
  void initState() {
    super.initState();
    _repository = ProjectsRepository(
      database: widget.database,
      xpLedgerWriter: DriftXpLedgerWriter(widget.database),
    );
    _loadProject();
  }

  Future<void> _loadProject() async {
    final details = await _repository.getProjectWithDetails(widget.projectId);
    if (mounted) {
      setState(() {
        _details = details;
        _loading = false;
      });
    }
  }

  Future<void> _completeProject() async {
    final rewardPreview = ProjectDifficultyXpCalculator.calculateXp(
      difficulty: _details?.project.difficulty ?? 1,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text(
          'Complete Project?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Marking "${_details?.project.title}" complete will award '
          '${rewardPreview.baseXp} Base XP and '
          '${rewardPreview.bonusPoints} Completion Bonus XP '
          'to your Life Area progression.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: KratosTheme.acidLime,
              foregroundColor: Colors.black,
            ),
            child: const Text(
              'Complete Project',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final breakdown = await _repository.completeProject(
        projectId: widget.projectId,
        ownerId: widget.ownerId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E281E),
            content: Row(
              children: [
                const Icon(Icons.bolt, color: KratosTheme.acidLime, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Project Completed! +${breakdown?.totalXp ?? 0} XP '
                    '(${breakdown?.baseXp ?? 0} base + '
                    '${breakdown?.bonusPoints ?? 0} completion bonus)',
                    style: const TextStyle(
                      color: KratosTheme.acidLime,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        _loadProject();
      }
    }
  }

  Future<void> _openEditDialog() async {
    if (_details == null) return;
    final result = await showDialog(
      context: context,
      builder: (_) => EditProjectDialog(
        database: widget.database,
        ownerId: widget.ownerId,
        projectDetails: _details!,
      ),
    );
    if (result == 'deleted' && mounted) {
      Navigator.pop(context);
    } else {
      _loadProject();
    }
  }

  Future<void> _addPhase() async {
    final created = await CreatePhaseDialog.show(
      context,
      repository: _repository,
      ownerId: widget.ownerId,
      projectId: widget.projectId,
      projectTitle: _details?.project.title ?? 'Project',
      nextSortOrder: _details?.phases.length ?? 0,
    );

    if (created == true) {
      _loadProject();
    }
  }

  Future<void> _addTask() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => CreateTaskDialog(
        database: widget.database,
        ownerId: widget.ownerId,
        defaultProjectId: widget.projectId,
        defaultLifeAreaId: _details?.project.lifeAreaId,
        defaultGoalId: _details?.project.goalId,
      ),
    );
    if (created == true) {
      await _repository.recalculateProjectProgress(widget.projectId);
      _loadProject();
    }
  }

  Future<void> _manageProjectSkills() async {
    final allSkills = await widget.database.skillsDao.allSkills(widget.ownerId);
    if (!mounted || _details == null) return;
    final currentIds = _details!.skills.map((s) => s.id).toSet();
    final selectedIds = await showDialog<Set<String>>(
      context: context,
      builder: (_) => SkillsSelectorDialog(
        allSkills: allSkills,
        initiallySelectedIds: currentIds,
      ),
    );
    if (selectedIds == null || !mounted) return;

    await _repository.updateProject(
      projectId: _details!.project.id,
      ownerId: widget.ownerId,
      title: _details!.project.title,
      description: _details!.project.description,
      difficulty: _details!.project.difficulty,
      lifeAreaId: _details!.project.lifeAreaId,
      goalId: _details!.project.goalId,
      levelId: _details!.project.levelId,
      coverImagePath: _details!.project.coverImagePath,
      status: _details!.project.status,
      dueDate: _details!.project.dueDate,
      skillIds: selectedIds,
    );
    _loadProject();
  }

  Future<void> _addActivity() async {
    final activityId = await CreateActivityDialog.show(
      context,
      database: widget.database,
      ownerId: widget.ownerId,
      initialLifeAreaId: _details?.project.lifeAreaId,
    );
    if (activityId != null) {
      await _repository.linkActivityToProject(activityId, widget.projectId);
      _loadProject();
    }
  }

  Future<void> _showAddIdeaModal() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0D).withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEA00).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFFEA00).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: Color(0xFFFFEA00),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ADD PROJECT IDEA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Brainstorm new concepts or connect existing ideas',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Colors.white12),
                ),
                tileColor: Colors.white.withValues(alpha: 0.04),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: KratosTheme.acidLime.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add,
                    color: KratosTheme.acidLime,
                    size: 18,
                  ),
                ),
                title: const Text(
                  'Quick Capture New Idea',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  'Create an idea and link it directly to this project',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _quickCaptureIdea();
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Colors.white12),
                ),
                tileColor: Colors.white.withValues(alpha: 0.04),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.search,
                    color: Color(0xFF00E5FF),
                    size: 18,
                  ),
                ),
                title: const Text(
                  'Link Existing Idea',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  'Search your idea spaces and connect an existing thought',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Colors.white38,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _openIdeaSearch();
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _quickCaptureIdea() async {
    final titleController = TextEditingController();
    final noteController = TextEditingController();

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0D).withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEA00).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFFEA00).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      color: Color(0xFFFFEA00),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CAPTURE IDEA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Fast capture concept connected to this project',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  labelText: 'Idea Title *',
                  labelStyle: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  hintText: 'e.g. Adaptive Audio Pipeline architecture',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFFEA00)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Brief Notes / Initial Thoughts',
                  labelStyle: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  hintText:
                      'Record thoughts, details, or architectural sparks...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFFEA00)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
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
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFEA00),
                        foregroundColor: const Color(0xFF0D0D0D),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'SAVE IDEA',
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
        ),
      ),
    );

    if (created == true && titleController.text.trim().isNotEmpty) {
      await _repository.addIdea(
        ownerId: widget.ownerId,
        projectId: widget.projectId,
        title: titleController.text.trim(),
        contentJson: noteController.text.trim().isNotEmpty
            ? '[{"type":"paragraph","content":"${noteController.text.trim().replaceAll('"', '\\"')}"}]'
            : '[]',
      );
      _loadProject();
    }
  }

  void _openIdeaSearch() {
    showDialog(
      context: context,
      builder: (_) => IdeaSearchDialog(
        repository: IdeasRepository(widget.database),
        ownerId: widget.ownerId,
        onSelect: (selectedIdea) async {
          await _repository.linkExistingIdea(
            ownerId: widget.ownerId,
            projectId: widget.projectId,
            ideaId: selectedIdea.idea.id,
          );
          _loadProject();
        },
      ),
    );
  }

  Future<void> _unlinkIdea(String ideaId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161616),
        title: const Text(
          'Unlink Idea?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'This will disconnect the idea from this project without deleting the idea itself.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              'Unlink',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repository.unlinkIdea(projectId: widget.projectId, ideaId: ideaId);
      _loadProject();
    }
  }

  Future<void> _addNote() async {
    final textController = TextEditingController();
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0D).withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: KratosTheme.acidLime.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: KratosTheme.acidLime.withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.note_alt_outlined,
                      color: KratosTheme.acidLime,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ADD NOTE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Capture thoughts, specs, or meeting logs',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: textController,
                autofocus: true,
                maxLines: 4,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Project thoughts, specs, meeting notes...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: KratosTheme.acidLime),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
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
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: KratosTheme.acidLime,
                        foregroundColor: const Color(0xFF0D0D0D),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'SAVE NOTE',
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
        ),
      ),
    );

    if (created == true && textController.text.trim().isNotEmpty) {
      await _repository.addNote(
        ownerId: widget.ownerId,
        projectId: widget.projectId,
        bodyText: textController.text.trim(),
      );
      _loadProject();
    }
  }

  Future<void> _addLink() async {
    final urlController = TextEditingController();
    final titleController = TextEditingController();

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0D).withValues(alpha: 0.96),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white12, width: 1),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 14,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                      ),
                    ),
                    child: const Icon(
                      Icons.link_rounded,
                      color: Color(0xFFFFD700),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ADD EXTERNAL LINK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Text(
                        'Connect Figma, Docs, GitHub, or resources',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: urlController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'URL (https://...) *',
                  labelStyle: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  hintText: 'https://...',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFFD700)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Title (e.g. Figma Prototype)',
                  labelStyle: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  hintText: 'Resource Title',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFFFD700)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
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
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: const Color(0xFF0D0D0D),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'ADD LINK',
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
        ),
      ),
    );

    if (created == true && urlController.text.trim().isNotEmpty) {
      await _repository.addExternalLink(
        ownerId: widget.ownerId,
        projectId: widget.projectId,
        url: urlController.text.trim(),
        title: titleController.text.trim().isEmpty
            ? null
            : titleController.text.trim(),
      );
      _loadProject();
    }
  }

  Future<void> _uploadFile() async {
    final files = await _storageService.pickFiles(allowMultiple: true);
    if (files == null || files.isEmpty) return;

    for (final f in files) {
      final bytes = await f.readAsBytes();
      final size = (await f.length()) ?? bytes.length;
      final storageKey = await _storageService.uploadAttachmentFile(
        ownerId: widget.ownerId,
        projectId: widget.projectId,
        bytes: bytes,
        fileName: f.name,
      );
      await _repository.addFile(
        ownerId: widget.ownerId,
        projectId: widget.projectId,
        filename: f.name,
        storageKey: storageKey,
        sizeBytes: size,
      );
    }
    _loadProject();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Cannot open URL: $url')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
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
            'PROJECT DETAILS',
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

    if (_details == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text(
            'Project not found',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      );
    }

    final p = _details!.project;
    final romanDifficulty = ProjectDifficulty.toRoman(p.difficulty);
    final baseXp = ProjectDifficultyXpCalculator.baseXp(p.difficulty);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF3F1E8)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: KratosTheme.electricLime,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'PROJECTS / ${p.title.toUpperCase()}',
                style: const TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  color: KratosTheme.electricLime,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (p.status != 'completed')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: OutlinedButton.icon(
                onPressed: _completeProject,
                icon: const Icon(
                  Icons.bolt,
                  color: KratosTheme.electricLime,
                  size: 14,
                ),
                label: const Text(
                  'DONE',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: KratosTheme.electricLime,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: KratosTheme.electricLime.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          IconButton(
            onPressed: _openEditDialog,
            icon: const Icon(
              Icons.tune,
              color: Color(0xFF979C92),
              size: 18,
            ),
            tooltip: 'Configure Project',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. PRIMARY PROJECT OVERVIEW CARD
                    _buildOverviewCard(p, romanDifficulty, baseXp),
                    const SizedBox(height: 18),

                    // 2. ROADMAP CARD
                    _buildRoadmapCard(),
                    const SizedBox(height: 18),

                    // 3. TASKS CARD (Completed, Active, Remaining + live interactive tasks)
                    _buildTasksCard(),
                    const SizedBox(height: 18),

                    // 4. CONNECTED ACTIVITIES CARD
                    _buildActivitiesCard(),
                    const SizedBox(height: 18),

                    // 5. PROJECT IDEAS CARD
                    _buildIdeasCard(),
                    const SizedBox(height: 18),

                    // 6. PROJECT NOTES CARD
                    _buildNotesCard(),
                    const SizedBox(height: 18),

                    // 7. FILES & ATTACHMENTS CARD
                    _buildFilesCard(),
                    const SizedBox(height: 18),

                    // 8. EXTERNAL RESOURCES CARD
                    _buildLinksCard(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── 1. Primary Project Overview Card ──────────────────────────────────────

  Widget _buildOverviewCard(Project p, String romanDifficulty, int baseXp) {
    final progress = _details!.progress;

    return KratosGlassCard(
      variant: KratosSurfaceVariant.normal,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow & Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: KratosTheme.electricLime,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'PROJECT OVERVIEW // CORE SPEC',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF686D65),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildStatusChip(p.status),
            ],
          ),
          const SizedBox(height: 14),

          // Identity chips row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildDifficultyChip(romanDifficulty, baseXp),
              if (_details!.levelName != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.military_tech, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        _details!.levelName!.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              if (p.dueDate != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF979C92)),
                      const SizedBox(width: 4),
                      Text(
                        'DUE ${DateFormat('MMM d, yyyy').format(p.dueDate!)}',
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF979C92),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Hero Title
          Text(
            p.title,
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              color: Color(0xFFF3F1E8),
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),

          // Context pills (Life Area / Goal)
          if (_details!.lifeArea != null || _details!.goal != null || _details!.subGoal != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (_details!.lifeArea != null)
                  _buildContextPill(
                    icon: Icons.public,
                    label: _details!.lifeArea!.name,
                    accent: Colors.blueAccent,
                  ),
                if (_details!.goal != null)
                  _buildContextPill(
                    icon: Icons.track_changes,
                    label: _details!.goal!.title,
                    accent: KratosTheme.electricLime,
                  ),
                if (_details!.subGoal != null)
                  _buildContextPill(
                    icon: Icons.subdirectory_arrow_right,
                    label: _details!.subGoal!.title,
                    accent: Colors.tealAccent,
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Description / Objective
          if (p.description != null && p.description!.trim().isNotEmpty) ...[
            Text(
              p.description!,
              style: const TextStyle(
                fontFamily: 'Space Grotesk',
                color: Color(0xFF979C92),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Token Strip for Progress
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF050805).withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x1FEEFF08)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'TOTAL PROJECT COMPLETION',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF686D65),
                          letterSpacing: 1.4,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${progress.round()}%',
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        color: KratosTheme.electricLime,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 4,
                    color: Colors.white.withValues(alpha: 0.08),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (progress / 100.0).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: KratosTheme.electricLime,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_details!.completedTaskCount} OF ${_details!.taskCount} TASKS DONE',
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        color: Color(0xFF686D65),
                        fontSize: 9,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      '${_details!.phases.length} PHASES',
                      style: const TextStyle(
                        fontFamily: 'IBM Plex Mono',
                        color: Color(0xFF686D65),
                        fontSize: 9,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // System Alignment Grid
          const Text(
            'ALIGNMENT & ARCHITECTURE',
            style: TextStyle(
              fontFamily: 'IBM Plex Mono',
              color: Color(0xFF686D65),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _buildSpecRow(
                  icon: Icons.public,
                  label: 'Life Area',
                  value: _details!.lifeArea?.name ?? 'Not Assigned',
                  accentColor: Colors.blueAccent,
                ),
                const Divider(color: Colors.white10, height: 18),
                _buildSpecRow(
                  icon: Icons.track_changes,
                  label: 'Goal Alignment',
                  value: _details!.goal?.title ?? 'Not Assigned',
                  accentColor: KratosTheme.electricLime,
                ),
                if (_details!.subGoal != null) ...[
                  const Divider(color: Colors.white10, height: 18),
                  _buildSpecRow(
                    icon: Icons.subdirectory_arrow_right,
                    label: 'Sub-goal',
                    value: _details!.subGoal!.title,
                    accentColor: Colors.tealAccent,
                  ),
                ],
                const Divider(color: Colors.white10, height: 18),
                _buildSpecRow(
                  icon: Icons.military_tech,
                  label: 'Level Target',
                  value: _details!.levelName ?? 'No Level Attached',
                  accentColor: Colors.amberAccent,
                ),
                const Divider(color: Colors.white10, height: 18),
                _buildSpecRow(
                  icon: Icons.speed,
                  label: 'Difficulty Rating',
                  value: 'Difficulty $romanDifficulty (+$baseXp XP)',
                  accentColor: KratosTheme.electricLime,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Project Skills
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  'PROJECT SKILLS',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFF686D65),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _manageProjectSkills,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 12,
                        color: KratosTheme.electricLime,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'MANAGE SKILLS',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: KratosTheme.electricLime,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_details!.skills.isEmpty)
            const Text(
              'No skills attached to this project.',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                color: Color(0xFF686D65),
                fontSize: 12,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _details!.skills.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: KratosTheme.electricLime.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: KratosTheme.electricLime.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt,
                        color: KratosTheme.electricLime,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        s.name,
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: KratosTheme.electricLime,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
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
  }

  // ─── 2. Dedicated Roadmap Card ─────────────────────────────────────────────

  Widget _buildRoadmapCard() {
    final phases = _details!.phases;
    final completedCount = phases.where((p) => p.status == 'completed').length;
    final activePhase = phases
        .where((p) => p.status == 'in_progress' || p.status == 'active')
        .firstOrNull;

    return KratosGlassCard(
      variant: KratosSurfaceVariant.normal,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'ROADMAP & PHASES',
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF686D65),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${phases.length} STAGES',
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF979C92),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _addPhase,
                icon: const Icon(Icons.add, size: 12, color: Color(0xFF00E5FF)),
                label: const Text(
                  'ADD PHASE',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Overview Token Strip
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF050805).withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x1FEEFF08)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'TOTAL PHASES',
                    value: '${phases.length}',
                    color: const Color(0xFFF3F1E8),
                  ),
                ),
                Container(width: 1, height: 26, color: Colors.white10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'COMPLETED',
                    value: '$completedCount',
                    color: KratosTheme.electricLime,
                  ),
                ),
                Container(width: 1, height: 26, color: Colors.white10),
                Expanded(
                  child: _buildMetricTile(
                    label: 'CURRENT PHASE',
                    value:
                        activePhase?.name ??
                        (phases.isEmpty ? 'None' : 'All Complete'),
                    color: const Color(0xFF00E5FF),
                    isCompact: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Phases List / Navigation Preview
          if (phases.isEmpty)
            _buildEmptySectionState(
              icon: Icons.alt_route,
              message: 'No roadmap phases created yet.\nBreak down this project into progressive milestones.',
              actionLabel: 'Add First Phase',
              onAction: _addPhase,
            )
          else
            ...phases.asMap().entries.map((entry) {
              final idx = entry.key;
              final phase = entry.value;
              final phaseTasks = _details!.tasks
                  .where((t) => t.phaseId == phase.id)
                  .toList();
              final phaseProgress =
                  RoadmapProgressCalculator.computePhaseProgress(
                    phaseTasks: phaseTasks,
                    phaseStatus: phase.status,
                  );
              final isCompleted =
                  phase.status == 'completed' || phaseProgress >= 100;
              final isActive =
                  phase.status == 'in_progress' || phase.status == 'active';

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  key: Key('project_phase_tile_${phase.id}'),
                  onTap: () async {
                    await Navigator.of(context).push(
                      KratosMaterialPageRoute(
                        builder: (_) => PhaseDetailScreen(
                          database: widget.database,
                          ownerId: widget.ownerId,
                          projectId: widget.projectId,
                          phaseId: phase.id,
                        ),
                      ),
                    );
                    _loadProject();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0F0D).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.4)
                            : (isCompleted
                                  ? KratosTheme.electricLime.withValues(alpha: 0.3)
                                  : Colors.white10),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCompleted
                                    ? KratosTheme.electricLime
                                    : (isActive
                                          ? const Color(0xFF00E5FF)
                                                .withValues(alpha: 0.2)
                                          : Colors.white10),
                              ),
                              child: Center(
                                child: isCompleted
                                    ? const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.black,
                                      )
                                    : Text(
                                        '0${idx + 1}',
                                        style: TextStyle(
                                          fontFamily: 'IBM Plex Mono',
                                          color: isActive
                                              ? const Color(0xFF00E5FF)
                                              : Colors.white70,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                phase.name,
                                style: const TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  color: Color(0xFFF3F1E8),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildStatusChip(phase.status),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF686D65),
                              size: 16,
                            ),
                          ],
                        ),
                        if (phase.description != null &&
                            phase.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 34),
                            child: Text(
                              phase.description!,
                              style: const TextStyle(
                                fontFamily: 'Space Grotesk',
                                color: Color(0xFF979C92),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(left: 34),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${phaseTasks.where((t) => t.status == 'completed').length}/${phaseTasks.length} TASKS',
                                style: const TextStyle(
                                  fontFamily: 'IBM Plex Mono',
                                  color: Color(0xFF686D65),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${phaseProgress.round()}%',
                                style: TextStyle(
                                  fontFamily: 'IBM Plex Mono',
                                  color: isCompleted
                                      ? KratosTheme.electricLime
                                      : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 34),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              height: 4,
                              color: Colors.white.withValues(alpha: 0.08),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: (phaseProgress / 100.0).clamp(0.0, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isCompleted
                                          ? KratosTheme.electricLime
                                          : const Color(0xFF00E5FF),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  // ─── 3. Dedicated Tasks Card ───────────────────────────────────────────────

  Widget _buildTasksCard() {
    final tasks = _details!.tasks;
    final completedTasks = tasks
        .where((t) => t.status == 'completed' || t.status == 'done')
        .toList();
    final inProgressTasks = tasks
        .where((t) => t.status == 'in_progress' || t.status == 'active')
        .toList();
    final pendingTasks = tasks
        .where(
          (t) =>
              t.status != 'completed' &&
              t.status != 'done' &&
              t.status != 'in_progress' &&
              t.status != 'active',
        )
        .toList();

    final totalCount = tasks.length;
    final completedCount = completedTasks.length;
    final completionPct = totalCount == 0
        ? 0.0
        : (completedCount / totalCount) * 100;

    return KratosGlassCard(
      variant: KratosSurfaceVariant.normal,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: KratosTheme.electricLime,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'TASKS // WORK UNITS',
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF686D65),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${tasks.length} ITEMS',
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF979C92),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _addTask,
                icon: const Icon(
                  Icons.add,
                  size: 12,
                  color: KratosTheme.electricLime,
                ),
                label: const Text(
                  'ADD TASK',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: KratosTheme.electricLime,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: KratosTheme.electricLime.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Key Metrics Token Strip (Total, Completed, Active, Remaining)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF050805).withValues(alpha: 0.84),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x1FEEFF08)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        label: 'TOTAL',
                        value: '$totalCount',
                        color: const Color(0xFFF3F1E8),
                      ),
                    ),
                    Container(width: 1, height: 26, color: Colors.white10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'COMPLETED',
                        value: '$completedCount',
                        color: KratosTheme.electricLime,
                      ),
                    ),
                    Container(width: 1, height: 26, color: Colors.white10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'IN PROGRESS',
                        value: '${inProgressTasks.length}',
                        color: const Color(0xFF00E5FF),
                      ),
                    ),
                    Container(width: 1, height: 26, color: Colors.white10),
                    Expanded(
                      child: _buildMetricTile(
                        label: 'REMAINING',
                        value: '${pendingTasks.length}',
                        color: pendingTasks.isEmpty
                            ? KratosTheme.electricLime
                            : Colors.amberAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 4,
                    color: Colors.white.withValues(alpha: 0.08),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: (completionPct / 100.0).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: KratosTheme.electricLime,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Quick Filter Segmented Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTaskFilterChip(
                  label: 'ALL (${tasks.length})',
                  filter: ProjectTaskFilter.all,
                  activeColor: KratosTheme.electricLime,
                ),
                const SizedBox(width: 8),
                _buildTaskFilterChip(
                  label: 'IN PROGRESS (${inProgressTasks.length})',
                  filter: ProjectTaskFilter.inProgress,
                  activeColor: const Color(0xFF00E5FF),
                ),
                const SizedBox(width: 8),
                _buildTaskFilterChip(
                  label: 'PENDING (${pendingTasks.length})',
                  filter: ProjectTaskFilter.pending,
                  activeColor: Colors.amberAccent,
                ),
                const SizedBox(width: 8),
                _buildTaskFilterChip(
                  label: 'COMPLETED (${completedTasks.length})',
                  filter: ProjectTaskFilter.completed,
                  activeColor: KratosTheme.electricLime,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Task List (Categorized by status)
          if (tasks.isEmpty)
            _buildEmptySectionState(
              icon: Icons.checklist,
              message: 'No tasks created for this project yet.',
              actionLabel: 'Add First Task',
              onAction: _addTask,
            )
          else ...[
            if (_taskFilter == ProjectTaskFilter.all) ...[
              // In Progress Group
              if (inProgressTasks.isNotEmpty) ...[
                _buildTaskGroupHeader(
                  'IN PROGRESS / ACTIVE',
                  inProgressTasks.length,
                  const Color(0xFF00E5FF),
                ),
                const SizedBox(height: 8),
                ...inProgressTasks.map(_buildTaskItemTile),
                const SizedBox(height: 14),
              ],
              // Pending / Remaining Group
              if (pendingTasks.isNotEmpty) ...[
                _buildTaskGroupHeader(
                  'PENDING / REMAINING',
                  pendingTasks.length,
                  const Color(0xFF686D65),
                ),
                const SizedBox(height: 8),
                ...pendingTasks.map(_buildTaskItemTile),
                const SizedBox(height: 14),
              ],
              // Completed Group
              if (completedTasks.isNotEmpty) ...[
                _buildTaskGroupHeader(
                  'COMPLETED',
                  completedTasks.length,
                  KratosTheme.electricLime,
                ),
                const SizedBox(height: 8),
                ...completedTasks.map(_buildTaskItemTile),
              ],
            ] else if (_taskFilter == ProjectTaskFilter.inProgress) ...[
              if (inProgressTasks.isEmpty)
                _buildEmptyFilterState('No active tasks currently in progress.')
              else
                ...inProgressTasks.map(_buildTaskItemTile),
            ] else if (_taskFilter == ProjectTaskFilter.pending) ...[
              if (pendingTasks.isEmpty)
                _buildEmptyFilterState('No pending tasks remaining.')
              else
                ...pendingTasks.map(_buildTaskItemTile),
            ] else if (_taskFilter == ProjectTaskFilter.completed) ...[
              if (completedTasks.isEmpty)
                _buildEmptyFilterState('No completed tasks yet.')
              else
                ...completedTasks.map(_buildTaskItemTile),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTaskFilterChip({
    required String label,
    required ProjectTaskFilter filter,
    required Color activeColor,
  }) {
    final isSelected = _taskFilter == filter;
    return InkWell(
      onTap: () => setState(() => _taskFilter = filter),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? activeColor.withValues(alpha: 0.5)
                : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'IBM Plex Mono',
            color: isSelected ? activeColor : const Color(0xFF979C92),
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskGroupHeader(String title, int count, Color accent) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'IBM Plex Mono',
            color: accent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: const TextStyle(
            fontFamily: 'IBM Plex Mono',
            color: Color(0xFF686D65),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFilterState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            color: Color(0xFF686D65),
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItemTile(Task task) {
    final isDone = task.status == 'completed' || task.status == 'done';
    final phase = _details!.phases
        .where((p) => p.id == task.phaseId)
        .firstOrNull;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D0F0D).withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDone
                ? KratosTheme.electricLime.withValues(alpha: 0.25)
                : Colors.white10,
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 2,
          ),
          leading: InkWell(
            onTap: () async {
              final newStatus = isDone ? 'active' : 'completed';
              await TaskDashboardRepository(widget.database)
                  .updateStatus(taskId: task.id, status: newStatus);
              await _repository.recalculateProjectProgress(widget.projectId);
              _loadProject();
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                isDone ? Icons.check_box : Icons.check_box_outline_blank,
                color: isDone ? KratosTheme.electricLime : const Color(0xFF686D65),
                size: 20,
              ),
            ),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              color: isDone ? const Color(0xFF686D65) : const Color(0xFFF3F1E8),
              decoration: isDone ? TextDecoration.lineThrough : null,
              fontWeight: isDone ? FontWeight.normal : FontWeight.w600,
              fontSize: 13,
            ),
          ),
          subtitle: (phase != null || task.dueDate != null)
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      if (phase != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            phase.name,
                            style: const TextStyle(
                              fontFamily: 'IBM Plex Mono',
                              color: Color(0xFF00E5FF),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (phase != null && task.dueDate != null)
                        const SizedBox(width: 8),
                      if (task.dueDate != null)
                        Text(
                          'DUE ${DateFormat('MMM d').format(task.dueDate!).toUpperCase()}',
                          style: const TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            color: Color(0xFF686D65),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                )
              : null,
          trailing: _buildStatusChip(task.status),
        ),
      ),
    );
  }

  // ─── 4. Connected Activities Card ──────────────────────────────────────────

  Widget _buildActivitiesCard() {
    final activities = _details!.activities;

    return KratosGlassCard(
      variant: KratosSurfaceVariant.normal,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: KratosTheme.electricLime,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'CONNECTED ACTIVITIES // ROUTINES',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF686D65),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${activities.length} ACTIVE',
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF979C92),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _addActivity,
                icon: const Icon(
                  Icons.add,
                  size: 12,
                  color: KratosTheme.electricLime,
                ),
                label: const Text(
                  'ADD ACTIVITY',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: KratosTheme.electricLime,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: KratosTheme.electricLime.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (activities.isEmpty)
            _buildEmptySectionState(
              icon: Icons.repeat,
              message: 'No recurring activities linked to this project.\nAttach ongoing routines or practices.',
              actionLabel: 'Link Activity',
              onAction: _addActivity,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activities.length,
              separatorBuilder: (_, index) => const SizedBox(height: 8),
              itemBuilder: (_, idx) {
                final act = activities[idx];
                return InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      KratosMaterialPageRoute(
                        builder: (_) => ActivityDetailScreen(
                          database: widget.database,
                          ownerId: widget.ownerId,
                          activityId: act.id,
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0F0D).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: KratosTheme.electricLime.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.repeat,
                            color: KratosTheme.electricLime,
                            size: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                act.name,
                                style: const TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  color: Color(0xFFF3F1E8),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              if (act.description != null &&
                                  act.description!.trim().isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  act.description!,
                                  style: const TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    color: Color(0xFF979C92),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (act.targetDurationMinutes != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${act.targetDurationMinutes} MIN',
                              style: const TextStyle(
                                fontFamily: 'IBM Plex Mono',
                                color: Color(0xFF979C92),
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right,
                          color: Color(0xFF686D65),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── 5. Dedicated Project Ideas Card ───────────────────────────────────────

  Widget _buildIdeasCard() {
    final ideas = _details!.ideas;

    return KratosGlassCard(
      variant: KratosSurfaceVariant.normal,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEA00),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'PROJECT IDEAS // CONCEPTS',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF686D65),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${ideas.length}',
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF979C92),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _showAddIdeaModal,
                icon: const Icon(Icons.add, size: 12, color: Color(0xFFFFEA00)),
                label: const Text(
                  'ADD IDEA',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFFFFEA00),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: const Color(0xFFFFEA00).withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (ideas.isEmpty)
            _buildEmptySectionState(
              icon: Icons.lightbulb_outline,
              message: 'No ideas linked to this project yet.\nCapture thoughts, concept sparks, or architectural notes.',
              actionLabel: 'Capture Idea',
              onAction: _showAddIdeaModal,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ideas.length,
              separatorBuilder: (_, index) => const SizedBox(height: 8),
              itemBuilder: (_, idx) {
                final idea = ideas[idx];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0F0D).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEA00)
                              .withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline,
                          color: Color(0xFFFFEA00),
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              KratosMaterialPageRoute(
                                builder: (_) => IdeaEditorScreen(
                                  database: widget.database,
                                  ownerId: widget.ownerId,
                                  ideaId: idea.id,
                                ),
                              ),
                            );
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                idea.title,
                                style: const TextStyle(
                                  fontFamily: 'Space Grotesk',
                                  color: Color(0xFFF3F1E8),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (idea.excerpt != null &&
                                  idea.excerpt!.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  idea.excerpt!,
                                  style: const TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    color: Color(0xFF979C92),
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ] else ...[
                                const SizedBox(height: 2),
                                Text(
                                  'UPDATED ${DateFormat('MMM d, yyyy').format(idea.updatedAt).toUpperCase()}',
                                  style: const TextStyle(
                                    fontFamily: 'IBM Plex Mono',
                                    color: Color(0xFF686D65),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_note,
                          size: 18,
                          color: Color(0xFFFFEA00),
                        ),
                        tooltip: 'Open in Idea Editor',
                        onPressed: () {
                          Navigator.of(context).push(
                            KratosMaterialPageRoute(
                              builder: (_) => IdeaEditorScreen(
                                database: widget.database,
                                ownerId: widget.ownerId,
                                ideaId: idea.id,
                              ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.link_off,
                          size: 16,
                          color: Color(0xFF686D65),
                        ),
                        tooltip: 'Unlink from Project',
                        onPressed: () => _unlinkIdea(idea.id),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── 6. Project Notes Card ─────────────────────────────────────────────────

  Widget _buildNotesCard() {
    final notes = _details!.notes;

    return KratosGlassCard(
      variant: KratosSurfaceVariant.normal,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: KratosTheme.electricLime,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'PROJECT NOTES // LOGS',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF686D65),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${notes.length}',
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF979C92),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _addNote,
                icon: const Icon(
                  Icons.add,
                  size: 12,
                  color: KratosTheme.electricLime,
                ),
                label: const Text(
                  'ADD NOTE',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: KratosTheme.electricLime,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: KratosTheme.electricLime.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (notes.isEmpty)
            _buildEmptySectionState(
              icon: Icons.note_alt_outlined,
              message: 'No project notes yet. Capture thoughts, specs, or meeting logs.',
              actionLabel: 'Add Note',
              onAction: _addNote,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: notes.length,
              separatorBuilder: (_, index) => const SizedBox(height: 8),
              itemBuilder: (_, idx) {
                final note = notes[idx];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0F0D).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: KratosTheme.electricLime.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.note_alt_outlined,
                          color: KratosTheme.electricLime,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          note.bodyText,
                          style: const TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: Color(0xFFF3F1E8),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Color(0xFF686D65),
                        ),
                        onPressed: () async {
                          await _repository.deleteAttachment(
                            attachmentId: note.id,
                            attachmentKind: 'note',
                            ownerId: widget.ownerId,
                          );
                          _loadProject();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── 7. Files & Attachments Card ───────────────────────────────────────────

  Widget _buildFilesCard() {
    final files = _details!.files;

    return KratosGlassCard(
      variant: KratosSurfaceVariant.normal,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'FILES & ATTACHMENTS // ASSETS',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF686D65),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${files.length}',
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF979C92),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _uploadFile,
                icon: const Icon(
                  Icons.upload_file,
                  size: 12,
                  color: Color(0xFF00E5FF),
                ),
                label: const Text(
                  'UPLOAD',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFF00E5FF),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (files.isEmpty)
            _buildEmptySectionState(
              icon: Icons.insert_drive_file_outlined,
              message: 'No files attached. Support for PDF, DOCX, Images, etc.',
              actionLabel: 'Upload File',
              onAction: _uploadFile,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: files.length,
              separatorBuilder: (_, index) => const SizedBox(height: 8),
              itemBuilder: (_, idx) {
                final f = files[idx];
                final name = f.filename ?? f.storageKey.split('/').last;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0F0D).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.insert_drive_file_outlined,
                          color: Color(0xFF00E5FF),
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontFamily: 'Space Grotesk',
                                color: Color(0xFFF3F1E8),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${(f.sizeBytes / 1024).round()} KB',
                              style: const TextStyle(
                                fontFamily: 'IBM Plex Mono',
                                color: Color(0xFF686D65),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Color(0xFF686D65),
                        ),
                        onPressed: () async {
                          await _repository.deleteAttachment(
                            attachmentId: f.id,
                            attachmentKind: 'file',
                            ownerId: widget.ownerId,
                          );
                          _loadProject();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── 8. External Resources Card ────────────────────────────────────────────

  Widget _buildLinksCard() {
    final links = _details!.links;

    return KratosGlassCard(
      variant: KratosSurfaceVariant.normal,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'EXTERNAL RESOURCES // LINKS',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF686D65),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${links.length}',
                        style: const TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: Color(0xFF979C92),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _addLink,
                icon: const Icon(Icons.add, size: 12, color: Color(0xFFFFD700)),
                label: const Text(
                  'ADD LINK',
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (links.isEmpty)
            _buildEmptySectionState(
              icon: Icons.link,
              message: 'No external resources attached (Figma, GitHub, Notion, etc.).',
              actionLabel: 'Add Link',
              onAction: _addLink,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: links.length,
              separatorBuilder: (_, index) => const SizedBox(height: 8),
              itemBuilder: (_, idx) {
                final l = links[idx];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0F0D).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.link,
                          color: Color(0xFFFFD700),
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.title?.isNotEmpty == true ? l.title! : l.url,
                              style: const TextStyle(
                                fontFamily: 'Space Grotesk',
                                color: Color(0xFFF3F1E8),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              l.url,
                              style: const TextStyle(
                                fontFamily: 'IBM Plex Mono',
                                color: Color(0xFF686D65),
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: KratosTheme.electricLime,
                        ),
                        onPressed: () => _openUrl(l.url),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Color(0xFF686D65),
                        ),
                        onPressed: () async {
                          await _repository.deleteAttachment(
                            attachmentId: l.id,
                            attachmentKind: 'link',
                            ownerId: widget.ownerId,
                          );
                          _loadProject();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ─── Shared UI Helpers ─────────────────────────────────────────────────────

  Widget _buildContextPill({
    required IconData icon,
    required String label,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: accentColor),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Space Grotesk',
            color: Color(0xFF979C92),
            fontSize: 12,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Space Grotesk',
              color: Color(0xFFF3F1E8),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required Color color,
    bool isCompact = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'IBM Plex Mono',
            color: Color(0xFF686D65),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'IBM Plex Mono',
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: isCompact ? 12 : 16,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildEmptySectionState({
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F0D).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 28, color: const Color(0xFF686D65)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Space Grotesk',
                color: Color(0xFF979C92),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(
                Icons.add,
                size: 14,
                color: KratosTheme.electricLime,
              ),
              label: Text(
                actionLabel,
                style: const TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  color: KratosTheme.electricLime,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(String roman, int baseXp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: KratosTheme.electricLime.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: KratosTheme.electricLime.withValues(alpha: 0.35)),
      ),
      child: Text(
        'DIFFICULTY $roman · +$baseXp XP',
        style: const TextStyle(
          fontFamily: 'IBM Plex Mono',
          color: KratosTheme.electricLime,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          fontSize: 10,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color c;
    switch (status.toLowerCase()) {
      case 'completed':
      case 'done':
        c = KratosTheme.electricLime;
        break;
      case 'paused':
        c = Colors.amber;
        break;
      case 'in_progress':
      case 'active':
        c = const Color(0xFF00E5FF);
        break;
      default:
        c = const Color(0xFF979C92);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontFamily: 'IBM Plex Mono',
          color: c,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
