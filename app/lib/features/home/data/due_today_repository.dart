// ignore_for_file: public_member_api_docs
//
// Due Today / Overdue overview.
//
// Powers the dedicated "Due Today" navigation page and the overdue system
// notifications. It answers one question: what did I commit to that is due
// today, and what slipped past its deadline without being completed?

import 'package:drift/drift.dart';

import '../../../data/drift/app_database.dart';

enum DueItemType { task, goal, project }

class DueItem {
  final String id;
  final String title;
  final DueItemType type;
  final String? lifeAreaName;
  final String? goalTitle;
  final String? projectTitle;
  final DateTime dueDate;
  final String status;
  final int? xpReward;

  const DueItem({
    required this.id,
    required this.title,
    required this.type,
    required this.dueDate,
    required this.status,
    this.lifeAreaName,
    this.goalTitle,
    this.projectTitle,
    this.xpReward,
  });

  String get typeLabel => switch (type) {
    DueItemType.task => 'Task',
    DueItemType.goal => 'Goal',
    DueItemType.project => 'Project',
  };

  /// Whole days past the deadline (0 when still due today).
  int daysLate(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diff = today.difference(due).inDays;
    return diff > 0 ? diff : 0;
  }
}

class DueOverview {
  final List<DueItem> overdue;
  final List<DueItem> dueToday;

  const DueOverview({required this.overdue, required this.dueToday});

  static const empty = DueOverview(overdue: [], dueToday: []);

  int get overdueCount => overdue.length;
  int get dueTodayCount => dueToday.length;
  bool get isEmpty => overdue.isEmpty && dueToday.isEmpty;
}

class DueTodayRepository {
  final AppDatabase database;

  DueTodayRepository(this.database);

  /// Reactive overview of overdue + due-today items.
  Stream<DueOverview> watchDueOverview(String ownerId) {
    final trigger = database
        .customSelect(
          'SELECT 1',
          readsFrom: {
            database.tasks,
            database.goals,
            database.projects,
            database.lifeAreas,
          },
        )
        .watch();
    return trigger.asyncMap((_) => getDueOverview(ownerId));
  }

  Future<DueOverview> getDueOverview(String ownerId, {DateTime? now}) async {
    final reference = now ?? DateTime.now();
    final startOfToday = DateTime(
      reference.year,
      reference.month,
      reference.day,
    );
    final endOfToday = startOfToday.add(const Duration(days: 1));

    final endUtc = endOfToday.toUtc();

    final lifeAreas = await (database.select(database.lifeAreas)
          ..where((a) => a.ownerId.equals(ownerId) & a.deletedAt.isNull()))
        .get();
    final lifeAreaNames = {for (final area in lifeAreas) area.id: area.name};

    final items = <DueItem>[];

    // Tasks --------------------------------------------------------------
    final tasks =
        await (database.select(database.tasks)..where(
              (t) =>
                  t.ownerId.equals(ownerId) &
                  t.deletedAt.isNull() &
                  t.dueDate.isNotNull() &
                  t.dueDate.isSmallerThanValue(endUtc) &
                  t.status.isNotIn(const ['completed', 'done', 'cancelled']),
            ))
            .get();
    for (final task in tasks) {
      items.add(
        DueItem(
          id: task.id,
          title: task.title,
          type: DueItemType.task,
          dueDate: task.dueDate!.toLocal(),
          status: task.status,
          lifeAreaName: task.lifeAreaId == null
              ? null
              : lifeAreaNames[task.lifeAreaId],
          projectTitle: null,
          xpReward: task.xpReward,
        ),
      );
    }

    // Goals --------------------------------------------------------------
    final goals =
        await (database.select(database.goals)..where(
              (g) =>
                  g.ownerId.equals(ownerId) &
                  g.deletedAt.isNull() &
                  g.dueDate.isNotNull() &
                  g.dueDate.isSmallerThanValue(endUtc) &
                  g.status.isNotIn(const ['completed', 'done', 'cancelled']),
            ))
            .get();
    for (final goal in goals) {
      items.add(
        DueItem(
          id: goal.id,
          title: goal.title,
          type: DueItemType.goal,
          dueDate: goal.dueDate!.toLocal(),
          status: goal.status,
          lifeAreaName: goal.lifeAreaId == null
              ? null
              : lifeAreaNames[goal.lifeAreaId],
        ),
      );
    }

    // Projects -----------------------------------------------------------
    final projects =
        await (database.select(database.projects)..where(
              (p) =>
                  p.ownerId.equals(ownerId) &
                  p.deletedAt.isNull() &
                  p.dueDate.isNotNull() &
                  p.dueDate.isSmallerThanValue(endUtc) &
                  p.status.isNotIn(const ['completed', 'done', 'cancelled']),
            ))
            .get();
    for (final project in projects) {
      items.add(
        DueItem(
          id: project.id,
          title: project.title,
          type: DueItemType.project,
          dueDate: project.dueDate!.toLocal(),
          status: project.status,
          lifeAreaName: project.lifeAreaId == null
              ? null
              : lifeAreaNames[project.lifeAreaId],
        ),
      );
    }

    final overdue = <DueItem>[];
    final dueToday = <DueItem>[];
    for (final item in items) {
      if (item.dueDate.isBefore(startOfToday)) {
        overdue.add(item);
      } else {
        dueToday.add(item);
      }
    }

    int byDueDate(DueItem a, DueItem b) => a.dueDate.compareTo(b.dueDate);
    overdue.sort(byDueDate);
    dueToday.sort(byDueDate);

    return DueOverview(overdue: overdue, dueToday: dueToday);
  }

  /// Convenience for the notification scheduler: only the items that slipped.
  Future<List<DueItem>> getOverdueItems(String ownerId) async =>
      (await getDueOverview(ownerId)).overdue;
}
