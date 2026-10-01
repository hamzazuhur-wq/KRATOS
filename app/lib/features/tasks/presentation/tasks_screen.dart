import 'package:flutter/material.dart';

import '../../../app/kratos_dropdown.dart';
import '../../../app/kratos_skeleton.dart';
import '../../../app/kratos_visuals.dart';
import '../../../app/kratos_theme.dart';
import '../../../app/number_pop_in.dart';
import '../../../data/drift/app_database.dart';
import '../../sessions/domain/global_active_session_controller.dart';
import '../../sessions/presentation/timer_status_badge.dart';
import '../data/task_dashboard_repository.dart';
import 'create_task_dialog.dart';

/// Persisted Task command centre. Rows and filter options come from Drift.
class TasksScreen extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;
  const TasksScreen({super.key, required this.database, required this.ownerId});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  late final TaskDashboardRepository _repository;
  TaskDashboardStatus _status = TaskDashboardStatus.active;
  TaskDashboardTime _time = TaskDashboardTime.today;
  String? _lifeAreaId;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _repository = TaskDashboardRepository(widget.database);
    GlobalActiveSessionController().bindDatabase(
      widget.database,
      widget.ownerId,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0D0D0D),
    body: Stack(
      fit: StackFit.expand,
      children: [
        const KratosEnvironment(),
        StreamBuilder<List<TaskDashboardLifeArea>>(
          stream: _repository.watchLifeAreas(widget.ownerId),
          builder: (context, areasSnapshot) {
            final areas = areasSnapshot.data ?? const <TaskDashboardLifeArea>[];
            if (_lifeAreaId != null &&
                !areas.any((area) => area.id == _lifeAreaId)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() => _lifeAreaId = null);
                }
              });
            }
            return _taskBody(areas);
          },
        ),
      ],
    ),
  );

  Widget _taskBody(List<TaskDashboardLifeArea> areas) =>
      StreamBuilder<List<TaskDashboardItem>>(
        stream: _repository.watchTasks(
          ownerId: widget.ownerId,
          status: _status,
          lifeAreaId: _lifeAreaId,
          time: _time,
          customRange: _customRange,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(message: '${snapshot.error}');
          }

          final isLoading = !snapshot.hasData;
          final tasks = snapshot.data;

          return SkeletonReveal(
            loading: isLoading,
            skeleton: const TasksPageSkeleton(),
            child: tasks == null
                ? const SizedBox.shrink()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 110),
                    children: [
                      _Header(onNewTask: _openCreateDialog),
                      const SizedBox(height: 18),
                      _StatusFilters(
                        selected: _status,
                        onChanged: (value) => setState(() => _status = value),
                      ),
                      const SizedBox(height: 12),
                      _DynamicFilters(
                        areas: areas,
                        selectedAreaId: _lifeAreaId,
                        time: _time,
                        customRange: _customRange,
                        onAreaChanged: (value) => setState(() => _lifeAreaId = value),
                        onTimeChanged: _selectTime,
                        onReset: _resetFilters,
                      ),
                      const SizedBox(height: 16),
                      _WorkloadSummary(tasks: tasks, status: _status),
                      const SizedBox(height: 22),
                      StreamBuilder<ActiveSessionState?>(
                        stream: GlobalActiveSessionController().stream,
                        initialData: GlobalActiveSessionController().currentState,
                        builder: (context, sessionSnapshot) => _Section(
                          title: _statusLabel(_status).toUpperCase(),
                          tasks: tasks,
                          activeState: sessionSnapshot.data,
                          emptyMessage:
                              _lifeAreaId == null && _time == TaskDashboardTime.today
                              ? 'No ${_status.name} tasks due today.'
                              : 'No tasks match these filters.',
                          onStatusChanged: _changeStatus,
                          onFocus: _startFocus,
                          onComplete: _completeFocus,
                          onDelete: _deleteTask,
                        ),
                      ),
                    ],
                  ),
          );
        },
      );

  Future<void> _selectTime(TaskDashboardTime time) async {
    if (time != TaskDashboardTime.custom) {
      setState(() {
        _time = time;
        _customRange = null;
      });
      return;
    }
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _customRange,
      helpText: 'SELECT TASK DATE RANGE',
      saveText: 'APPLY',
    );
    if (range != null && mounted) {
      setState(() {
        _time = TaskDashboardTime.custom;
        _customRange = range;
      });
    }
  }

  void _resetFilters() => setState(() {
    _lifeAreaId = null;
    _time = TaskDashboardTime.today;
    _customRange = null;
  });

  Future<void> _changeStatus(TaskDashboardItem task, String status) async {
    final willComplete = status == 'completed' || status == 'done';
    try {
      await _repository.updateStatus(taskId: task.id, status: status);
      if (mounted && willComplete) {
        final xp = task.xpReward ?? 50;
        final areaName = task.lifeAreaName ?? 'Life Area';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF141F14),
            content: Row(
              children: [
                const Icon(Icons.bolt, color: Color(0xFFC6F135), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Task completed! +$xp XP awarded to $areaName.',
                    style: const TextStyle(
                      color: Color(0xFFC6F135),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating task: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _deleteTask(TaskDashboardItem task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete “${task.title}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _repository.softDelete(task.id);
  }

  void _startFocus(TaskDashboardItem task) {
    final controller = GlobalActiveSessionController();
    final current = controller.currentState;
    if (current != null && current.entityId != task.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Complete ${current.title} before starting another timer.',
          ),
        ),
      );
      return;
    }
    controller.startSession(
      entityType: 'task',
      entityId: task.id,
      title: task.title,
      lifeAreaId: task.lifeAreaId,
      lifeAreaName: task.lifeAreaName,
      targetDurationMinutes: 0,
    );
  }

  Future<void> _completeFocus(TaskDashboardItem task) async {
    final result = await GlobalActiveSessionController().completeSession(
      database: widget.database,
      ownerId: widget.ownerId,
    );
    if (mounted && result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Task timer complete: ${_formatDuration(result['durationMs'] as int)} tracked.',
          ),
        ),
      );
    }
  }

  Future<void> _openCreateDialog() => showDialog<void>(
    context: context,
    builder: (_) =>
        CreateTaskDialog(database: widget.database, ownerId: widget.ownerId),
  );
}

class _Header extends StatelessWidget {
  final VoidCallback onNewTask;
  const _Header({required this.onNewTask});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'TASKS',
        style: TextStyle(
          color: KratosTheme.acidLime,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      const SizedBox(height: 7),
      const Text(
        'Turn your plans into action.',
        style: TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 16),
      KratosGlassCard(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onNewTask,
          borderRadius: BorderRadius.circular(18),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.add, color: KratosTheme.acidLime),
                SizedBox(width: 10),
                Text(
                  'New Task',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Spacer(),
                Icon(Icons.arrow_forward, size: 18, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _StatusFilters extends StatelessWidget {
  final TaskDashboardStatus selected;
  final ValueChanged<TaskDashboardStatus> onChanged;
  const _StatusFilters({required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(
    children: TaskDashboardStatus.values.map((status) {
      final active = selected == status;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: OutlinedButton(
            onPressed: () => onChanged(status),
            style: OutlinedButton.styleFrom(
              foregroundColor: active ? KratosTheme.acidLime : Colors.white60,
              backgroundColor: active
                  ? KratosTheme.acidLime.withValues(alpha: .12)
                  : Colors.white.withValues(alpha: .03),
              side: BorderSide(
                color: active
                    ? KratosTheme.acidLime.withValues(alpha: .65)
                    : Colors.white12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            child: Text(
              _statusLabel(status),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );
    }).toList(),
  );
}

class _DynamicFilters extends StatelessWidget {
  final List<TaskDashboardLifeArea> areas;
  final String? selectedAreaId;
  final TaskDashboardTime time;
  final DateTimeRange? customRange;
  final ValueChanged<String?> onAreaChanged;
  final ValueChanged<TaskDashboardTime> onTimeChanged;
  final VoidCallback onReset;
  const _DynamicFilters({
    required this.areas,
    required this.selectedAreaId,
    required this.time,
    required this.customRange,
    required this.onAreaChanged,
    required this.onTimeChanged,
    required this.onReset,
  });
  @override
  Widget build(BuildContext context) {
    final selectedArea = areas
        .where((area) => area.id == selectedAreaId)
        .firstOrNull;
    final timeLabel = time == TaskDashboardTime.custom && customRange != null
        ? '${_shortDate(customRange!.start)} – ${_shortDate(customRange!.end)}'
        : _timeLabel(time);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SelectButton(
          label: selectedArea?.name ?? 'Life Area',
          icon: Icons.track_changes,
          onTap: () async {
            final picked = await showModalBottomSheet<String?>(
              context: context,
              builder: (_) => _ChoiceSheet<String?>(
                title: 'LIFE AREA',
                values: [
                  (null, 'All Life Areas'),
                  ...areas.map((area) => (area.id, area.name)),
                ],
              ),
            );
            if (picked != null || selectedAreaId != null) onAreaChanged(picked);
          },
        ),
        _SelectButton(
          label: timeLabel,
          icon: Icons.calendar_today,
          onTap: () async {
            final picked = await showModalBottomSheet<TaskDashboardTime>(
              context: context,
              builder: (_) => const _ChoiceSheet<TaskDashboardTime>(
                title: 'TIME RANGE',
                values: [
                  (TaskDashboardTime.today, 'Today'),
                  (TaskDashboardTime.week, 'This Week'),
                  (TaskDashboardTime.month, 'This Month'),
                  (TaskDashboardTime.custom, 'Custom'),
                ],
              ),
            );
            if (picked != null) onTimeChanged(picked);
          },
        ),
        if (selectedAreaId != null || time != TaskDashboardTime.today)
          TextButton(onPressed: onReset, child: const Text('Reset')),
      ],
    );
  }
}

class _SelectButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SelectButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 16),
    label: Text(label, overflow: TextOverflow.ellipsis),
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white70,
      side: const BorderSide(color: Colors.white12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

class _ChoiceSheet<T> extends StatelessWidget {
  final String title;
  final List<(T, String)> values;
  const _ChoiceSheet({required this.title, required this.values});
  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        ...values.map(
          (value) => ListTile(
            title: Text(value.$2),
            onTap: () => Navigator.pop(context, value.$1),
          ),
        ),
      ],
    ),
  );
}

class _WorkloadSummary extends StatelessWidget {
  final List<TaskDashboardItem> tasks;
  final TaskDashboardStatus status;
  const _WorkloadSummary({required this.tasks, required this.status});
  @override
  Widget build(BuildContext context) {
    final tracked = tasks.fold<int>(
      0,
      (sum, task) => sum + task.trackedDurationMs,
    );
    return KratosGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FILTERED WORKLOAD',
            style: TextStyle(
              color: KratosTheme.acidLime,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Metric(
                value: '${tasks.length}',
                label: '${_statusLabel(status)} Tasks',
              ),
              const _Metric(value: '—', label: 'Planned Time'),
              _Metric(value: _formatDuration(tracked), label: 'Tracked'),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Planned time is not persisted in the current Task schema.',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  const _Metric({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KratosNumberPopIn(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  final String title;
  final List<TaskDashboardItem> tasks;
  final ActiveSessionState? activeState;
  final String emptyMessage;
  final Future<void> Function(TaskDashboardItem, String) onStatusChanged;
  final ValueChanged<TaskDashboardItem> onFocus;
  final ValueChanged<TaskDashboardItem> onComplete;
  final ValueChanged<TaskDashboardItem> onDelete;
  const _Section({
    required this.title,
    required this.tasks,
    required this.activeState,
    required this.emptyMessage,
    required this.onStatusChanged,
    required this.onFocus,
    required this.onComplete,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Colors.white12)),
        ],
      ),
      const SizedBox(height: 10),
      if (tasks.isEmpty)
        _EmptyState(message: emptyMessage)
      else
        ...tasks.map(
          (task) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TaskCard(
              task: task,
              activeState: activeState,
              onStatusChanged: onStatusChanged,
              onFocus: onFocus,
              onComplete: onComplete,
              onDelete: onDelete,
            ),
          ),
        ),
    ],
  );
}

class _TaskCard extends StatelessWidget {
  final TaskDashboardItem task;
  final ActiveSessionState? activeState;
  final Future<void> Function(TaskDashboardItem, String) onStatusChanged;
  final ValueChanged<TaskDashboardItem> onFocus;
  final ValueChanged<TaskDashboardItem> onComplete;
  final ValueChanged<TaskDashboardItem> onDelete;
  const _TaskCard({
    required this.task,
    required this.activeState,
    required this.onStatusChanged,
    required this.onFocus,
    required this.onComplete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDone = task.isCompleted;
    final current = activeState;
    final isTiming =
        current != null &&
        current.entityType == 'task' &&
        current.entityId == task.id;
    final activeSession = isTiming ? current : null;

    return KratosGlassCard(
      padding: const EdgeInsets.all(16),
      accentColor: isDone
          ? const Color(0xFFC6F135).withValues(alpha: 0.1)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Interactive Checkbox
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Semantics(
                  button: true,
                  label: isDone ? 'Mark task incomplete' : 'Mark task complete',
                  child: InkWell(
                    onTap: () =>
                        onStatusChanged(task, isDone ? 'pending' : 'completed'),
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone
                                ? const Color(0xFFC6F135)
                                : Colors.transparent,
                            border: Border.all(
                              color: isDone
                                  ? const Color(0xFFC6F135)
                                  : Colors.white38,
                              width: 1.8,
                            ),
                          ),
                          child: isDone
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Color(0xFF0D0D0D),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 2. Title (tappable to toggle)
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      onStatusChanged(task, isDone ? 'pending' : 'completed'),
                  child: Text(
                    task.title,
                    style: TextStyle(
                      color: isDone ? Colors.white38 : Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.white38,
                    ),
                  ),
                ),
              ),

              if (activeSession != null) ...[
                TimerStatusBadge(isPaused: activeSession.isPaused),
                const SizedBox(width: 8),
                KratosNumberPopIn(
                  activeSession.formattedElapsed,
                  style: const TextStyle(
                    color: Color(0xFFC6F135),
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],

              // 3. Popup Menu
              KratosPopupMenuButton<String>(
                tooltip: 'Task actions',
                onSelected: (action) {
                  if (action == 'complete') onStatusChanged(task, 'completed');
                  if (action == 'reopen') onStatusChanged(task, 'pending');
                  if (action == 'pause') onStatusChanged(task, 'paused');
                  if (action == 'resume') onStatusChanged(task, 'pending');
                  if (action == 'delete') onDelete(task);
                },
                itemBuilder: (_) => [
                  if (!isDone)
                    const KratosPopupMenuItem(
                      value: 'complete',
                      child: Text('Complete (+XP)'),
                    )
                  else
                    const KratosPopupMenuItem(
                      value: 'reopen',
                      child: Text('Mark Incomplete'),
                    ),
                  if (task.isActive)
                    const KratosPopupMenuItem(
                      value: 'pause',
                      child: Text('Pause'),
                    ),
                  if (task.isPaused)
                    const KratosPopupMenuItem(
                      value: 'resume',
                      child: Text('Resume'),
                    ),
                  const KratosPopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
              ),
            ],
          ),
          if (task.lifeAreaName != null ||
              task.projectTitle != null ||
              task.goalTitle != null) ...[
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Text(
                [
                  task.lifeAreaName,
                  task.projectTitle,
                  task.goalTitle,
                ].whereType<String>().join(' · '),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
          ],
          if (task.categoryName != null)
            Padding(
              padding: const EdgeInsets.only(top: 7, left: 36),
              child: Text(
                task.categoryName!,
                style: const TextStyle(
                  color: KratosTheme.acidLime,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                if (task.dueDate != null)
                  _Info(icon: Icons.event, text: _shortDate(task.dueDate!)),
                _Info(
                  icon: Icons.timer_outlined,
                  text: _formatDuration(task.trackedDurationMs),
                  animateNumber: true,
                ),
                _Info(
                  icon: Icons.bolt,
                  text: '+${task.xpReward ?? 50} XP',
                  animateNumber: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 36),
            child: Row(
              children: [
                if (activeSession != null) ...[
                  TextButton.icon(
                    onPressed: activeSession.isPaused
                        ? () => GlobalActiveSessionController().resumeSession()
                        : () => GlobalActiveSessionController().pauseSession(),
                    icon: Icon(
                      activeSession.isPaused ? Icons.play_arrow : Icons.pause,
                      size: 17,
                    ),
                    label: Text(activeSession.isPaused ? 'Resume' : 'Pause'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => onComplete(task),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('COMPLETE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC6F135),
                      foregroundColor: const Color(0xFF0D0D0D),
                    ),
                  ),
                ] else
                  TextButton.icon(
                    onPressed: isDone ? null : () => onFocus(task),
                    icon: const Icon(Icons.play_arrow, size: 17),
                    label: const Text('START TIMER'),
                  ),
                const Spacer(),
                Text(
                  task.status.toUpperCase(),
                  style: TextStyle(
                    color: isDone ? const Color(0xFFC6F135) : Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool animateNumber;
  const _Info({
    required this.icon,
    required this.text,
    this.animateNumber = false,
  });
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: Colors.white38),
      const SizedBox(width: 5),
      animateNumber
          ? KratosNumberPopIn(
              text,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            )
          : Text(
              text,
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});
  @override
  Widget build(BuildContext context) => KratosGlassCard(
    padding: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54),
        ),
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Could not load tasks.\n$message',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.redAccent),
      ),
    ),
  );
}

String _statusLabel(TaskDashboardStatus status) => switch (status) {
  TaskDashboardStatus.active => 'Active',
  TaskDashboardStatus.paused => 'Paused',
  TaskDashboardStatus.completed => 'Completed',
};
String _timeLabel(TaskDashboardTime time) => switch (time) {
  TaskDashboardTime.today => 'Today',
  TaskDashboardTime.week => 'This Week',
  TaskDashboardTime.month => 'This Month',
  TaskDashboardTime.custom => 'Custom',
};
String _shortDate(DateTime value) =>
    '${value.month}/${value.day}/${value.year}';
String _formatDuration(int milliseconds) {
  final minutes = milliseconds ~/ 60000;
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return hours > 0 ? '${hours}h ${remainder}m' : '${remainder}m';
}
