import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../app/active_glass_card.dart';
import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_visuals.dart';
import '../../../data/drift/app_database.dart';
import '../../tasks/data/task_dashboard_repository.dart';
import '../../tasks/presentation/create_task_dialog.dart';
import '../../xp/data/xp_ledger_writer_impl.dart';
import '../data/projects_repository.dart';
import '../domain/project_models.dart';

/// Rich workspace for a single Roadmap Phase.
class PhaseDetailScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  final String projectId;
  final String phaseId;

  const PhaseDetailScreen({
    super.key,
    required this.database,
    required this.ownerId,
    required this.projectId,
    required this.phaseId,
  });

  @override
  State<PhaseDetailScreen> createState() => _PhaseDetailScreenState();
}

class _PhaseDetailScreenState extends State<PhaseDetailScreen> {
  late final ProjectsRepository _repository;

  ProjectPhase? _phase;
  List<Task> _tasks = [];
  List<Note> _notes = [];
  List<File> _files = [];
  List<Link> _links = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository = ProjectsRepository(
      database: widget.database,
      xpLedgerWriter: DriftXpLedgerWriter(widget.database),
    );
    _loadPhaseData();
  }

  Future<void> _loadPhaseData() async {
    setState(() => _loading = true);

    final phase = await widget.database.projectsDao.findPhaseById(
      widget.phaseId,
    );
    final tasks =
        await (widget.database.select(widget.database.tasks)..where(
              (t) => t.phaseId.equals(widget.phaseId) & t.deletedAt.isNull(),
            ))
            .get();

    final links = await widget.database.attachmentLinksDao.forEntity(
      widget.phaseId,
      'roadmap_phase',
    );

    final noteIds = links
        .where((l) => l.attachmentKind == 'note')
        .map((l) => l.attachmentId)
        .toSet();
    final fileIds = links
        .where((l) => l.attachmentKind == 'file')
        .map((l) => l.attachmentId)
        .toSet();
    final urlIds = links
        .where((l) => l.attachmentKind == 'link')
        .map((l) => l.attachmentId)
        .toSet();

    final notes = noteIds.isEmpty
        ? <Note>[]
        : await (widget.database.select(
            widget.database.notes,
          )..where((n) => n.id.isIn(noteIds) & n.deletedAt.isNull())).get();

    final files = fileIds.isEmpty
        ? <File>[]
        : await (widget.database.select(
            widget.database.files,
          )..where((f) => f.id.isIn(fileIds) & f.deletedAt.isNull())).get();

    final urlLinks = urlIds.isEmpty
        ? <Link>[]
        : await (widget.database.select(
            widget.database.links,
          )..where((l) => l.id.isIn(urlIds) & l.deletedAt.isNull())).get();

    if (mounted) {
      setState(() {
        _phase = phase;
        _tasks = tasks;
        _notes = notes;
        _files = files;
        _links = urlLinks;
        _loading = false;
      });
    }
  }

  Future<void> _toggleTask(Task task) async {
    final newStatus = task.status == 'completed' ? 'active' : 'completed';
    await TaskDashboardRepository(widget.database)
        .updateStatus(taskId: task.id, status: newStatus);
    await _repository.recalculateProjectProgress(widget.projectId);
    await _loadPhaseData();
  }

  Future<void> _addNewTask() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => CreateTaskDialog(
        database: widget.database,
        ownerId: widget.ownerId,
        defaultProjectId: widget.projectId,
        defaultPhaseId: widget.phaseId,
      ),
    );
    if (created == true) {
      await _repository.recalculateProjectProgress(widget.projectId);
      await _loadPhaseData();
    }
  }

  Future<void> _togglePhaseStatus(String status) async {
    await _repository.updatePhase(
      phaseId: widget.phaseId,
      projectId: widget.projectId,
      ownerId: widget.ownerId,
      name: _phase?.name ?? 'Phase',
      status: status,
    );
    await _loadPhaseData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D0D),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFC6F135)),
        ),
      );
    }

    if (_phase == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D0D),
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(
          child: Text(
            'Phase not found',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    final phase = _phase!;
    final progress = RoadmapProgressCalculator.computePhaseProgress(
      phaseTasks: _tasks,
      phaseStatus: phase.status,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          'PHASE ${phase.sortOrder + 1}',
          style: const TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 14,
          ),
        ),
        actions: [
          KratosPopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            onSelected: (val) async {
              if (val == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Phase?'),
                    content: Text(
                      'Delete “${phase.name}”? Tasks will be unlinked.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _repository.softDeletePhase(
                    phase.id,
                    widget.projectId,
                    widget.ownerId,
                  );
                  if (context.mounted) Navigator.pop(context, true);
                }
              } else {
                await _togglePhaseStatus(val);
              }
            },
            itemBuilder: (_) => [
              const KratosPopupMenuItem(
                value: 'active',
                child: Text('Mark Active'),
              ),
              const KratosPopupMenuItem(
                value: 'paused',
                child: Text('Mark Paused'),
              ),
              const KratosPopupMenuItem(
                value: 'completed',
                child: Text('Mark Completed'),
              ),
              const KratosPopupMenuDivider(),
              const KratosPopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete Phase',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const KratosEnvironment(),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Phase Header Card
                    ActiveGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  phase.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              _buildStatusBadge(phase.status),
                            ],
                          ),
                          if (phase.description != null &&
                              phase.description!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              phase.description!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Progress Bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'PHASE PROGRESS',
                                style: TextStyle(
                                  color: Colors.white54,
                                  letterSpacing: 1.2,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${progress.round()}%',
                                style: const TextStyle(
                                  color: Color(0xFFC6F135),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress / 100.0,
                              minHeight: 6,
                              backgroundColor: Colors.white10,
                              valueColor: const AlwaysStoppedAnimation(
                                Color(0xFFC6F135),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Phase Tasks Section
                    ActiveGlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: Color(0xFFC6F135),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'TASKS (${_tasks.where((t) => t.status == 'completed').length}/${_tasks.length})',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              TextButton.icon(
                                onPressed: _addNewTask,
                                icon: const Icon(
                                  Icons.add,
                                  size: 16,
                                  color: Color(0xFFC6F135),
                                ),
                                label: const Text(
                                  '+ Add Task',
                                  style: TextStyle(
                                    color: Color(0xFFC6F135),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          if (_tasks.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: const Center(
                                child: Text(
                                  'No tasks linked to this phase.\nTap "+ Add Task" to create one.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _tasks.length,
                              separatorBuilder: (_, index) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (_, idx) {
                                final task = _tasks[idx];
                                final isDone = task.status == 'completed';

                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDone
                                          ? const Color(0xFFC6F135)
                                                .withValues(alpha: 0.2)
                                          : Colors.white10,
                                    ),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    leading: InkWell(
                                      onTap: () => _toggleTask(task),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Icon(
                                        isDone
                                            ? Icons.check_box
                                            : Icons.check_box_outline_blank,
                                        color: isDone
                                            ? const Color(0xFFC6F135)
                                            : Colors.white54,
                                        size: 20,
                                      ),
                                    ),
                                    title: Text(
                                      task.title,
                                      style: TextStyle(
                                        color: isDone
                                            ? Colors.white54
                                            : Colors.white,
                                        decoration: isDone
                                            ? TextDecoration.lineThrough
                                            : null,
                                        fontSize: 14,
                                        fontWeight: isDone
                                            ? FontWeight.normal
                                            : FontWeight.bold,
                                      ),
                                    ),
                                    subtitle:
                                        task.notes != null &&
                                            task.notes!.isNotEmpty
                                        ? Text(
                                            task.notes!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11,
                                            ),
                                          )
                                        : null,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Phase Notes & Files summary
                    if (_notes.isNotEmpty ||
                        _files.isNotEmpty ||
                        _links.isNotEmpty)
                      ActiveGlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PHASE ATTACHMENTS',
                              style: TextStyle(
                                color: Colors.white70,
                                letterSpacing: 1.2,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                if (_notes.isNotEmpty)
                                  Chip(
                                    avatar: const Icon(
                                      Icons.note_alt_outlined,
                                      size: 16,
                                      color: Color(0xFFC6F135),
                                    ),
                                    label: Text('${_notes.length} Notes'),
                                  ),
                                if (_files.isNotEmpty)
                                  Chip(
                                    avatar: const Icon(
                                      Icons.attach_file,
                                      size: 16,
                                      color: Color(0xFF00E5FF),
                                    ),
                                    label: Text('${_files.length} Files'),
                                  ),
                                if (_links.isNotEmpty)
                                  Chip(
                                    avatar: const Icon(
                                      Icons.link,
                                      size: 16,
                                      color: Color(0xFFFFD700),
                                    ),
                                    label: Text('${_links.length} Links'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'completed':
        color = const Color(0xFFC6F135);
        break;
      case 'paused':
        color = Colors.amber;
        break;
      default:
        color = Colors.cyanAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
