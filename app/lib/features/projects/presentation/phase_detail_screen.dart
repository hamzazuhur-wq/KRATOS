import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_theme.dart';
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
        backgroundColor: Colors.transparent,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFC6F135)),
        ),
      );
    }

    if (_phase == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
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
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF3F1E8)),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Row(
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
            Text(
              'ROADMAP / PHASE 0${phase.sortOrder + 1}',
              style: const TextStyle(
                fontFamily: 'IBM Plex Mono',
                color: KratosTheme.electricLime,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          KratosPopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF979C92)),
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
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Phase Header Card (Manus Hero Overview)
                    KratosGlassCard(
                      variant: KratosSurfaceVariant.normal,
                      borderRadius: BorderRadius.circular(20),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: KratosTheme.electricLime.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: KratosTheme.electricLime.withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: Text(
                                            'STAGE 0${phase.sortOrder + 1}',
                                            style: const TextStyle(
                                              fontFamily: 'IBM Plex Mono',
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: KratosTheme.electricLime,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _buildStatusBadge(phase.status),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      phase.name,
                                      style: const TextStyle(
                                        fontFamily: 'Space Grotesk',
                                        color: Color(0xFFF3F1E8),
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (phase.description != null &&
                              phase.description!.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              phase.description!,
                              style: const TextStyle(
                                fontFamily: 'Space Grotesk',
                                color: Color(0xFF979C92),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),

                          // Token Strip for Phase Metrics
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
                                    const Text(
                                      'PHASE COMPLETION RATIO',
                                      style: TextStyle(
                                        fontFamily: 'IBM Plex Mono',
                                        color: Color(0xFF686D65),
                                        letterSpacing: 1.4,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${progress.round()}%',
                                      style: const TextStyle(
                                        fontFamily: 'IBM Plex Mono',
                                        color: KratosTheme.electricLime,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Phase Tasks Section
                    KratosGlassCard(
                      variant: KratosSurfaceVariant.normal,
                      borderRadius: BorderRadius.circular(20),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: KratosTheme.electricLime,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'PHASE CHECKLIST',
                                        style: TextStyle(
                                          fontFamily: 'IBM Plex Mono',
                                          fontSize: 10,
                                          letterSpacing: 1.6,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF686D65),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Text(
                                        'Associated Tasks',
                                        style: TextStyle(
                                          fontFamily: 'Space Grotesk',
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFF3F1E8),
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.05),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                        ),
                                        child: Text(
                                          '${_tasks.where((t) => t.status == 'completed').length} / ${_tasks.length}',
                                          style: const TextStyle(
                                            fontFamily: 'IBM Plex Mono',
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF979C92),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              OutlinedButton.icon(
                                onPressed: _addNewTask,
                                icon: const Icon(
                                  Icons.add,
                                  size: 14,
                                  color: KratosTheme.electricLime,
                                ),
                                label: const Text(
                                  'ADD TASK',
                                  style: TextStyle(
                                    fontFamily: 'IBM Plex Mono',
                                    color: KratosTheme.electricLime,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: KratosTheme.electricLime.withValues(alpha: 0.35),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (_tasks.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F1510).withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Center(
                                child: Column(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(alpha: 0.04),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                      ),
                                      child: const Icon(Icons.checklist, size: 18, color: Color(0xFF686D65)),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'No tasks linked to this phase.\nAdd tasks to track execution towards this milestone.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Space Grotesk',
                                        color: Color(0xFF979C92),
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _tasks.length,
                              separatorBuilder: (_, index) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, idx) {
                                final task = _tasks[idx];
                                final isDone = task.status == 'completed' || task.status == 'done';

                                return Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F1510).withValues(alpha: 0.76),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDone
                                          ? KratosTheme.electricLime.withValues(alpha: 0.22)
                                          : Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                    leading: InkWell(
                                      onTap: () => _toggleTask(task),
                                      borderRadius: BorderRadius.circular(6),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 180),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          color: isDone
                                              ? KratosTheme.electricLime
                                              : Colors.white.withValues(alpha: 0.04),
                                          border: Border.all(
                                            color: isDone
                                                ? KratosTheme.electricLime
                                                : Colors.white.withValues(alpha: 0.2),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Center(
                                          child: isDone
                                              ? const Icon(
                                                  Icons.check,
                                                  size: 14,
                                                  color: Color(0xFF10130F),
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      task.title,
                                      style: TextStyle(
                                        fontFamily: 'Space Grotesk',
                                        color: isDone ? const Color(0xFF686D65) : const Color(0xFFF3F1E8),
                                        decoration: isDone ? TextDecoration.lineThrough : null,
                                        decorationColor: const Color(0xFF686D65),
                                        fontSize: 13,
                                        fontWeight: isDone ? FontWeight.w400 : FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: task.notes != null && task.notes!.isNotEmpty
                                        ? Text(
                                            task.notes!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: 'Space Grotesk',
                                              color: Color(0xFF686D65),
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
                      KratosGlassCard(
                        variant: KratosSurfaceVariant.normal,
                        borderRadius: BorderRadius.circular(20),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E5FF),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'PHASE ATTACHMENTS',
                                  style: TextStyle(
                                    fontFamily: 'IBM Plex Mono',
                                    color: Color(0xFF686D65),
                                    letterSpacing: 1.6,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                if (_notes.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: KratosTheme.electricLime.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: KratosTheme.electricLime.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.note_alt_outlined, size: 14, color: KratosTheme.electricLime),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${_notes.length} Notes',
                                          style: const TextStyle(
                                            fontFamily: 'IBM Plex Mono',
                                            fontSize: 10,
                                            color: KratosTheme.electricLime,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_files.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.attach_file, size: 14, color: Color(0xFF00E5FF)),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${_files.length} Files',
                                          style: const TextStyle(
                                            fontFamily: 'IBM Plex Mono',
                                            fontSize: 10,
                                            color: Color(0xFF00E5FF),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_links.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.link, size: 14, color: Color(0xFFFFD700)),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${_links.length} Links',
                                          style: const TextStyle(
                                            fontFamily: 'IBM Plex Mono',
                                            fontSize: 10,
                                            color: Color(0xFFFFD700),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
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
        color = KratosTheme.electricLime;
        break;
      case 'paused':
        color = const Color(0xFFE5C07B);
        break;
      default:
        color = const Color(0xFF00E5FF);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontFamily: 'IBM Plex Mono',
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
