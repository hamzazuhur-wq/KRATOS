import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/home/data/home_dashboard_repository.dart';

void main() {
  late AppDatabase database;
  const ownerA = 'dashboard-owner-a';
  const ownerB = 'dashboard-owner-b';

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.progressionDao.ensureSeeded();
    final now = DateTime.now().toUtc();
    for (final id in [ownerA, ownerB]) {
      await database.into(database.users).insert(
            UsersCompanion.insert(
              id: id,
              deviceId: 'device-$id',
              timezone: 'UTC',
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });

  tearDown(() => database.close());

  test('dashboard summary reads real work and activity data per owner', () async {
    final now = DateTime.now().toUtc();
    await database.into(database.tasks).insert(
          TasksCompanion.insert(
            id: 'dashboard-task-a',
            ownerId: ownerA,
            title: 'Real task',
            priority: 2,
            sortOrder: 1,
            status: 'pending',
            dueDate: drift.Value(now),
            versionHlc: '0',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database.into(database.tasks).insert(
          TasksCompanion.insert(
            id: 'dashboard-task-b',
            ownerId: ownerB,
            title: 'Other user task',
            priority: 2,
            sortOrder: 1,
            status: 'pending',
            versionHlc: '0',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database.into(database.activityEvents).insert(
          ActivityEventsCompanion.insert(
            id: 'dashboard-event-a',
            ownerId: ownerA,
            eventType: 'task_created',
            entityType: 'task',
            entityId: const drift.Value('dashboard-task-a'),
            occurredAt: now,
            versionHlc: '0',
            createdAt: now,
          ),
        );

    final ownerData = await HomeDashboardRepository(database)
        .getHomeDashboard(ownerA);
    final otherData = await HomeDashboardRepository(database)
        .getHomeDashboard(ownerB);

    expect(ownerData.workSummary.activeTasks, 1);
    expect(ownerData.workSummary.dueTodayTasks, 1);
    expect(ownerData.recentItems.any((item) => item.id == 'dashboard-event-a'), isTrue);
    expect(otherData.workSummary.activeTasks, 1);
    expect(otherData.recentItems.any((item) => item.id == 'dashboard-event-a'), isFalse);
  });

  test('empty owner receives safe zero summaries and empty states', () async {
    final data = await HomeDashboardRepository(database).getHomeDashboard(ownerA);

    expect(data.aggregateProgression.totalXp, 0);
    expect(data.workSummary.activeTasks, 0);
    expect(data.workSummary.activeGoals, 0);
    expect(data.workSummary.activeProjects, 0);
    expect(data.endingTodayItems, isEmpty);
    expect(data.recentItems, isEmpty);
    expect(data.streakInfo.currentStreak, 0);
  });
}
