import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../../data/drift/app_database.dart';
import '../../../domain/hlc.dart';
import '../../goals/domain/goal_xp_service.dart';

/// One joined, read-only projection used by the Task Dashboard.
///
/// The projection deliberately contains only fields that already exist in
/// KRATOS. Planned time is not fabricated because the current Task schema
/// does not persist it; tracked time comes from persisted Sessions.
class TaskDashboardItem {
  final String id;
  final String title;
  final String status;
  final String? notes;
  final DateTime? dueDate;
  final int? xpReward;
  final String? lifeAreaId;
  final String? lifeAreaName;
  final String? goalTitle;
  final String? projectTitle;
  final String? categoryName;
  final int trackedDurationMs;

  const TaskDashboardItem({
    required this.id,
    required this.title,
    required this.status,
    this.notes,
    this.dueDate,
    this.xpReward,
    this.lifeAreaId,
    this.lifeAreaName,
    this.goalTitle,
    this.projectTitle,
    this.categoryName,
    required this.trackedDurationMs,
  });

  bool get isActive => status == 'pending' || status == 'open' || status == 'in_progress';
  bool get isPaused => status == 'paused';
  bool get isCompleted => status == 'completed' || status == 'done';
}

class TaskDashboardLifeArea {
  final String id;
  final String name;

  const TaskDashboardLifeArea({required this.id, required this.name});
}

enum TaskDashboardStatus { active, paused, completed }
enum TaskDashboardTime { today, week, month, custom }

class TaskDashboardRepository {
  final AppDatabase _db;

  TaskDashboardRepository(this._db);

  Stream<List<TaskDashboardItem>> watchTasks({
    required String ownerId,
    required TaskDashboardStatus status,
    String? lifeAreaId,
    required TaskDashboardTime time,
    DateTimeRange? customRange,
  }) {
    final args = <Variable<Object>>[Variable<String>(ownerId)];
    final filters = <String>['t.owner_id = ? AND t.deleted_at IS NULL'];

    switch (status) {
      case TaskDashboardStatus.active:
        filters.add("t.status IN ('pending', 'open', 'in_progress', 'active')");
      case TaskDashboardStatus.paused:
        filters.add("t.status = 'paused'");
      case TaskDashboardStatus.completed:
        filters.add("t.status IN ('completed', 'done')");
    }

    if (lifeAreaId != null) {
      filters.add('t.life_area_id = ?');
      args.add(Variable<String>(lifeAreaId));
    }

    final range = _dateRange(time, customRange);
    filters.add('t.due_date >= ? AND t.due_date < ?');
    args
      ..add(Variable.withDateTime(range.start.toUtc()))
      ..add(Variable.withDateTime(range.end.toUtc()));

    final query = '''
      SELECT
        t.id,
        t.title,
        t.status,
        t.notes,
        t.due_date,
        t.xp_reward,
        t.life_area_id,
        la.name AS life_area_name,
        g.title AS goal_title,
        p.title AS project_title,
        c.name AS category_name,
        COALESCE(SUM(CASE WHEN s.deleted_at IS NULL THEN COALESCE(s.duration_ms, 0) ELSE 0 END), 0)
          AS tracked_duration_ms
      FROM tasks t
      LEFT JOIN life_areas la ON la.id = t.life_area_id AND la.owner_id = t.owner_id
      LEFT JOIN goals g ON g.id = t.primary_goal_id AND g.owner_id = t.owner_id
      LEFT JOIN projects p ON p.id = t.project_id AND p.owner_id = t.owner_id
      LEFT JOIN categories c ON c.id = t.category_id AND c.owner_id = t.owner_id
      LEFT JOIN sessions s ON s.task_id = t.id AND s.owner_id = t.owner_id
      WHERE ${filters.join(' AND ')}
      GROUP BY t.id, t.title, t.status, t.notes, t.due_date, t.xp_reward,
               t.life_area_id, la.name, g.title, p.title, c.name
      ORDER BY CASE WHEN t.due_date IS NULL THEN 1 ELSE 0 END,
               t.due_date ASC, t.sort_order ASC, t.updated_at DESC
    ''';

    return _db.customSelect(
      query,
      variables: args,
      readsFrom: {
        _db.tasks,
        _db.lifeAreas,
        _db.goals,
        _db.projects,
        _db.categories,
        _db.sessions,
      },
    ).watch().map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<List<TaskDashboardLifeArea>> watchLifeAreas(String ownerId) {
    final query = (_db.select(_db.lifeAreas)
          ..where((a) => a.ownerId.equals(ownerId) & a.archivedAt.isNull() & a.deletedAt.isNull())
          ..orderBy([(a) => OrderingTerm.asc(a.sortOrder), (a) => OrderingTerm.asc(a.name)]))
        .watch();
    return query.map((rows) => rows
        .map((row) => TaskDashboardLifeArea(id: row.id, name: row.name))
        .toList(growable: false));
  }

  /// Updates a task's status.
  ///
  /// When [status] is `'completed'` or `'done'`, the call is routed through
  /// [GoalXpService.completeTask] — the single authoritative XP write path —
  /// which handles late-penalty calculation, streak-bonus computation, and the
  /// immutable ledger write.  The idempotency key inside [GoalXpService]
  /// (`'xp_task_<id>'`) prevents double-XP if the task was already marked
  /// done via another screen (e.g. goal_detail_screen).
  ///
  /// For non-completion status changes (paused, in_progress, etc.) only the
  /// Drift row and sync-outbox entry are updated, as before.
  Future<void> updateStatus({required String taskId, required String status}) async {
    final task = await (_db.select(_db.tasks)..where((t) => t.id.equals(taskId))).getSingle();
    final now = DateTime.now().toUtc();
    final clock = Hlc.now(Hlc.parse(task.versionHlc).nodeId);

    final isCompletion = status == 'completed' || status == 'done';

    if (isCompletion) {
      // Route through the authoritative XP completion path.
      // GoalXpService will: mark the task done, calculate late penalty,
      // apply streak bonus, write the XP ledger, and update goal progress.
      final xpService = GoalXpService(_db);
      await xpService.completeTask(
        task: task,
        ownerId: task.ownerId,
        lifeAreaId: task.lifeAreaId,
      );

      // Also enqueue a task-entity outbox entry so the status change syncs.
      await _db.into(_db.syncOutbox).insert(
        SyncOutboxCompanion.insert(
          userId: task.ownerId,
          op: 'upsert',
          entity: 'tasks',
          entityId: task.id,
          payloadJson: '{"status":"$status","completed_at":"${now.toIso8601String()}"}',
          hlc: clock.toString(),
          deviceId: clock.nodeId.value,
        ),
      );
    } else {
      // Non-completion status update: just update Drift row + outbox.
      await _db.transaction(() async {
        await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
          TasksCompanion(
            status: Value(status),
            versionHlc: Value(clock.toString()),
            updatedAt: Value(now),
          ),
        );
        await _db.into(_db.syncOutbox).insert(
          SyncOutboxCompanion.insert(
            userId: task.ownerId,
            op: 'upsert',
            entity: 'tasks',
            entityId: task.id,
            payloadJson: '{"status":"$status","completed_at":null}',
            hlc: clock.toString(),
            deviceId: clock.nodeId.value,
          ),
        );
      });
    }
  }

  Future<void> softDelete(String taskId) async {
    final task = await (_db.select(_db.tasks)..where((t) => t.id.equals(taskId))).getSingle();
    final now = DateTime.now().toUtc();
    final clock = Hlc.now(Hlc.parse(task.versionHlc).nodeId);
    await _db.transaction(() async {
      await (_db.update(_db.tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(deletedAt: Value(now), versionHlc: Value(clock.toString()), updatedAt: Value(now)),
      );
      await _db.into(_db.syncOutbox).insert(
        SyncOutboxCompanion.insert(
          userId: task.ownerId,
          op: 'delete',
          entity: 'tasks',
          entityId: task.id,
          payloadJson: '{"status":"${task.status}"}',
          hlc: clock.toString(),
          deviceId: clock.nodeId.value,
        ),
      );
    });
  }

  static TaskDashboardItem _fromRow(QueryRow row) => TaskDashboardItem(
        id: row.read<String>('id'),
        title: row.read<String>('title'),
        status: row.read<String>('status'),
        notes: row.readNullable<String>('notes'),
        dueDate: row.readNullable<DateTime>('due_date'),
        xpReward: row.readNullable<int>('xp_reward'),
        lifeAreaId: row.readNullable<String>('life_area_id'),
        lifeAreaName: row.readNullable<String>('life_area_name'),
        goalTitle: row.readNullable<String>('goal_title'),
        projectTitle: row.readNullable<String>('project_title'),
        categoryName: row.readNullable<String>('category_name'),
        trackedDurationMs: row.read<int>('tracked_duration_ms'),
      );

  static DateTimeRange _dateRange(TaskDashboardTime time, DateTimeRange? custom) {
    if (time == TaskDashboardTime.custom) {
      if (custom == null) throw ArgumentError('Custom time requires a date range.');
      final start = DateTime(custom.start.year, custom.start.month, custom.start.day);
      final end = DateTime(custom.end.year, custom.end.month, custom.end.day).add(const Duration(days: 1));
      return DateTimeRange(start: start, end: end);
    }
    final now = DateTime.now();
    final start = switch (time) {
      TaskDashboardTime.today => DateTime(now.year, now.month, now.day),
      TaskDashboardTime.week => DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1)),
      TaskDashboardTime.month => DateTime(now.year, now.month),
      TaskDashboardTime.custom => throw StateError('unreachable'),
    };
    final end = switch (time) {
      TaskDashboardTime.today => start.add(const Duration(days: 1)),
      TaskDashboardTime.week => start.add(const Duration(days: 7)),
      TaskDashboardTime.month => DateTime(start.year, start.month + 1),
      TaskDashboardTime.custom => throw StateError('unreachable'),
    };
    return DateTimeRange(start: start, end: end);
  }

  /// Exposed for deterministic boundary tests and other presentation clients.
  static DateTimeRange dateRangeFor(TaskDashboardTime time, DateTimeRange? custom) =>
      _dateRange(time, custom);
}
