import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/tasks/data/task_dashboard_repository.dart';

void main() {
  group('TaskDashboardRepository date ranges', () {
    test('uses local calendar-day boundaries for today', () {
      final range = TaskDashboardRepository.dateRangeFor(TaskDashboardTime.today, null);
      expect(range.end.difference(range.start), const Duration(days: 1));
      expect(range.start.hour, 0);
      expect(range.start.minute, 0);
    });

    test('uses Monday-to-next-Monday for the calendar week', () {
      final range = TaskDashboardRepository.dateRangeFor(TaskDashboardTime.week, null);
      expect(range.start.weekday, DateTime.monday);
      expect(range.end.difference(range.start), const Duration(days: 7));
    });

    test('uses the first day of next month as exclusive end', () {
      final range = TaskDashboardRepository.dateRangeFor(TaskDashboardTime.month, null);
      expect(range.start.day, 1);
      expect(range.end.day, 1);
      expect(range.end.isAfter(range.start), isTrue);
    });

    test('custom range is inclusive by date and exclusive at next midnight', () {
      final range = TaskDashboardRepository.dateRangeFor(
        TaskDashboardTime.custom,
        DateTimeRange(start: DateTime(2026, 12, 31), end: DateTime(2027, 1, 1)),
      );
      expect(range.start, DateTime(2026, 12, 31));
      expect(range.end, DateTime(2027, 1, 2));
    });
  });

  test('dashboard reads persisted task, relationship, category, and session data', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    const ownerId = 'owner-dashboard';
    final now = DateTime.now();

    await database.into(database.users).insert(UsersCompanion.insert(
      id: ownerId,
      deviceId: 'device-dashboard',
      timezone: 'Europe/Istanbul',
      createdAt: now,
      updatedAt: now,
    ));
    await database.into(database.lifeAreas).insert(LifeAreasCompanion.insert(
      id: 'area-dashboard',
      ownerId: ownerId,
      name: 'Business',
      sortOrder: 0,
      versionHlc: '1:0:00000000-0000-7000-8000-000000000001',
      createdAt: now,
      updatedAt: now,
    ));
    await database.into(database.categories).insert(CategoriesCompanion.insert(
      id: 'category-dashboard',
      ownerId: ownerId,
      name: 'Deep Work',
      baseXp: 10,
      isImmutable: false,
      sortOrder: 0,
      categoryType: const Value('task'),
      versionHlc: '1:0:00000000-0000-7000-8000-000000000001',
      createdAt: now,
      updatedAt: now,
    ));
    await database.into(database.tasks).insert(TasksCompanion.insert(
      id: 'task-dashboard',
      ownerId: ownerId,
      lifeAreaId: const Value('area-dashboard'),
      categoryId: const Value('category-dashboard'),
      title: 'Ship dashboard',
      dueDate: Value(DateTime(now.year, now.month, now.day, 12)),
      priority: 2,
      status: 'pending',
      sortOrder: 0,
      xpReward: const Value(25),
      versionHlc: '1:0:00000000-0000-7000-8000-000000000001',
      createdAt: now,
      updatedAt: now,
    ));
    await database.into(database.sessions).insert(SessionsCompanion.insert(
      id: 'session-dashboard',
      ownerId: ownerId,
      taskId: const Value('task-dashboard'),
      startedAt: now.subtract(const Duration(minutes: 30)),
      endedAt: Value(now),
      durationMs: const Value(1800000),
      versionHlc: '1:0:00000000-0000-7000-8000-000000000001',
      createdAt: now,
      updatedAt: now,
    ));
    for (final entry in [
      ('task-paused', 'paused'),
      ('task-completed', 'completed'),
    ]) {
      await database.into(database.tasks).insert(TasksCompanion.insert(
        id: entry.$1,
        ownerId: ownerId,
        lifeAreaId: const Value('area-dashboard'),
        title: entry.$1,
        dueDate: Value(DateTime(now.year, now.month, now.day, 12)),
        priority: 2,
        status: entry.$2,
        sortOrder: 0,
        completedAt: entry.$2 == 'completed' ? Value(now) : const Value.absent(),
        versionHlc: '1:0:00000000-0000-7000-8000-000000000001',
        createdAt: now,
        updatedAt: now,
      ));
    }

    final repository = TaskDashboardRepository(database);
    final rows = await repository.watchTasks(
      ownerId: ownerId,
      status: TaskDashboardStatus.active,
      lifeAreaId: 'area-dashboard',
      time: TaskDashboardTime.today,
    ).first;

    expect(rows, hasLength(1));
    expect(rows.single.lifeAreaName, 'Business');
    expect(rows.single.categoryName, 'Deep Work');
    expect(rows.single.trackedDurationMs, 1800000);
    expect(rows.single.xpReward, 25);

    final paused = await repository.watchTasks(
      ownerId: ownerId,
      status: TaskDashboardStatus.paused,
      lifeAreaId: 'area-dashboard',
      time: TaskDashboardTime.today,
    ).first;
    final completed = await repository.watchTasks(
      ownerId: ownerId,
      status: TaskDashboardStatus.completed,
      lifeAreaId: 'area-dashboard',
      time: TaskDashboardTime.today,
    ).first;
    expect(paused.map((task) => task.id), contains('task-paused'));
    expect(completed.map((task) => task.id), contains('task-completed'));
  });
}
