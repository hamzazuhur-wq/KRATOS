// ignore_for_file: public_member_api_docs
//
// Due Today — dedicated navigation page for everything that is due today and
// everything that already slipped past its deadline.
//
// Reached from the app drawer and from the Home "Ending Today" section.

import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';

import '../../../app/kratos_visuals.dart';
import '../../../data/drift/app_database.dart';
import '../../goals/presentation/goal_detail_screen.dart';
import '../../projects/presentation/projects_screen.dart';
import '../../sessions/domain/global_timer_controller.dart';
import '../../tasks/data/task_dashboard_repository.dart';
import '../data/due_today_repository.dart';

const _alertRed = Color(0xFFFF3B30);
const _acidLime = Color(0xFFC6F135);

class DueTodayScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;

  const DueTodayScreen({
    super.key,
    required this.database,
    required this.ownerId,
  });

  @override
  State<DueTodayScreen> createState() => _DueTodayScreenState();
}

class _DueTodayScreenState extends State<DueTodayScreen> {
  late final DueTodayRepository _repository;
  late final TaskDashboardRepository _taskRepository;
  final Set<String> _completing = {};

  @override
  void initState() {
    super.initState();
    _repository = DueTodayRepository(widget.database);
    _taskRepository = TaskDashboardRepository(widget.database);
  }

  Future<void> _completeTask(DueItem item) async {
    if (_completing.contains(item.id)) return;
    setState(() => _completing.add(item.id));
    try {
      await _taskRepository.updateStatus(taskId: item.id, status: 'completed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${item.title}" completed.'),
            backgroundColor: const Color(0xFF141714),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not complete task: $error'),
            backgroundColor: _alertRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _completing.remove(item.id));
    }
  }

  void _startFocusTimer(DueItem item) {
    GlobalTimerController().startTimer(
      taskId: item.id,
      taskTitle: item.title,
      lifeAreaName: item.lifeAreaName,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Focus timer started.'),
        backgroundColor: Color(0xFF141714),
      ),
    );
  }

  void _openItem(DueItem item) {
    switch (item.type) {
      case DueItemType.task:
        _startFocusTimer(item);
      case DueItemType.goal:
        Navigator.of(context).push(
          KratosMaterialPageRoute(
            builder: (_) => GoalDetailScreen(
              database: widget.database,
              ownerId: widget.ownerId,
              goalId: item.id,
            ),
          ),
        );
      case DueItemType.project:
        Navigator.of(context).push(
          KratosMaterialPageRoute(
            builder: (_) => ProjectsScreen(
              database: widget.database,
              ownerId: widget.ownerId,
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DUE TODAY',
              style: TextStyle(
                color: _acidLime,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            Text(
              'What is ending now and what already slipped.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
      body: StreamBuilder<DueOverview>(
        stream: _repository.watchDueOverview(widget.ownerId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.error_outline,
              color: _alertRed,
              title: 'Could not load your deadlines',
              subtitle: '${snapshot.error}',
            );
          }
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _acidLime),
            );
          }

          final overview = snapshot.data!;
          if (overview.isEmpty) {
            return const _MessageState(
              icon: Icons.check_circle_outline,
              color: _acidLime,
              title: 'Nothing is ending today',
              subtitle: 'No overdue work and nothing due before midnight.',
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _Metric(
                      label: 'OVERDUE',
                      value: '${overview.overdueCount}',
                      color: _alertRed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Metric(
                      label: 'DUE TODAY',
                      value: '${overview.dueTodayCount}',
                      color: _acidLime,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (overview.overdue.isNotEmpty) ...[
                const _SectionHeader(
                  label: 'SLIPPED PAST DEADLINE',
                  color: _alertRed,
                  icon: Icons.warning_amber_rounded,
                ),
                const SizedBox(height: 10),
                ...overview.overdue.map(
                  (item) => _DueCard(
                    item: item,
                    overdue: true,
                    completing: _completing.contains(item.id),
                    onComplete: item.type == DueItemType.task
                        ? () => _completeTask(item)
                        : null,
                    onTap: () => _openItem(item),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              if (overview.dueToday.isNotEmpty) ...[
                const _SectionHeader(
                  label: 'ENDING TODAY',
                  color: _acidLime,
                  icon: Icons.schedule,
                ),
                const SizedBox(height: 10),
                ...overview.dueToday.map(
                  (item) => _DueCard(
                    item: item,
                    overdue: false,
                    completing: _completing.contains(item.id),
                    onComplete: item.type == DueItemType.task
                        ? () => _completeTask(item)
                        : null,
                    onTap: () => _openItem(item),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _SectionHeader({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(width: 8),
      Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => KratosGlassCard(
    accentColor: color.withValues(alpha: 0.35),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _DueCard extends StatelessWidget {
  final DueItem item;
  final bool overdue;
  final bool completing;
  final VoidCallback? onComplete;
  final VoidCallback onTap;

  const _DueCard({
    required this.item,
    required this.overdue,
    required this.completing,
    required this.onTap,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = overdue ? _alertRed : _acidLime;
    final now = DateTime.now();
    final late = item.daysLate(now);
    final subtitleParts = <String>[
      item.typeLabel,
      if (item.lifeAreaName != null) item.lifeAreaName!,
      if (overdue && late > 0) '$late day${late == 1 ? '' : 's'} late',
      if (!overdue)
        'Due ${item.dueDate.hour.toString().padLeft(2, '0')}:'
            '${item.dueDate.minute.toString().padLeft(2, '0')}',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KratosGlassCard(
        accentColor: accent.withValues(alpha: 0.35),
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  if (onComplete != null)
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: completing
                          ? const Padding(
                              padding: EdgeInsets.all(4),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _acidLime,
                              ),
                            )
                          : Checkbox(
                              value: false,
                              activeColor: _acidLime,
                              checkColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              onChanged: (_) => onComplete!(),
                            ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        switch (item.type) {
                          DueItemType.task => Icons.checklist,
                          DueItemType.goal => Icons.track_changes,
                          DueItemType.project => Icons.folder_outlined,
                        },
                        color: accent,
                        size: 16,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitleParts.join(' • '),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      overdue ? 'OVERDUE' : 'DUE TODAY',
                      style: TextStyle(
                        color: accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
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
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _MessageState({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 42),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
