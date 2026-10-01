import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/domain/ids.dart';
import 'package:kratos_app/features/home/data/due_today_repository.dart';

void main() {
  late AppDatabase db;
  late String ownerId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ownerId = Id.uuidV7().value;
    await db
        .into(db.users)
        .insert(
          UsersCompanion.insert(
            id: ownerId,
            deviceId: 'device_due_001',
            timezone: 'UTC',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  });

  tearDown(() async => db.close());

  Future<String> insertTask({
    required String title,
    required DateTime? dueDate,
    String status = 'pending',
  }) async {
    final id = Id.uuidV7().value;
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: id,
            ownerId: ownerId,
            title: title,
            status: status,
            priority: 2,
            sortOrder: 0,
            versionHlc: '1:0:local',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
            dueDate: Value(dueDate),
          ),
        );
    return id;
  }

  test('splits overdue work from work that is due today', () async {
    final now = DateTime(2026, 4, 20, 10);
    await insertTask(
      title: 'Missed yesterday',
      dueDate: DateTime(2026, 4, 19, 9),
    );
    await insertTask(title: 'Due later today', dueDate: DateTime(2026, 4, 20, 18));
    await insertTask(
      title: 'Already completed',
      dueDate: DateTime(2026, 4, 18, 12),
      status: 'completed',
    );
    await insertTask(title: 'Tomorrow', dueDate: DateTime(2026, 4, 21, 9));
    await insertTask(title: 'No deadline', dueDate: null);

    final overview = await DueTodayRepository(db).getDueOverview(
      ownerId,
      now: now,
    );

    expect(overview.overdue.map((item) => item.title), ['Missed yesterday']);
    expect(overview.dueToday.map((item) => item.title), ['Due later today']);
    expect(overview.overdue.single.daysLate(now), 1);
  });

  test('includes overdue goals and projects in the same overview', () async {
    final now = DateTime(2026, 4, 20, 10);
    await db
        .into(db.goals)
        .insert(
          GoalsCompanion.insert(
            id: Id.uuidV7().value,
            ownerId: ownerId,
            title: 'Overdue goal',
            status: 'active',
            rootId: 'root',
            path: '1',
            depth: 0,
            progress: 0,
            versionHlc: '1:0:local',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
            dueDate: Value(DateTime(2026, 4, 15)),
          ),
        );
    await db
        .into(db.projects)
        .insert(
          ProjectsCompanion.insert(
            id: Id.uuidV7().value,
            ownerId: ownerId,
            title: 'Overdue project',
            status: 'active',
            memberIds: '[]',
            versionHlc: '1:0:local',
            createdAt: DateTime.now().toUtc(),
            updatedAt: DateTime.now().toUtc(),
            dueDate: Value(DateTime(2026, 4, 1)),
          ),
        );

    final overview = await DueTodayRepository(db).getDueOverview(
      ownerId,
      now: now,
    );

    expect(
      overview.overdue.map((item) => item.type),
      containsAll(<DueItemType>[DueItemType.goal, DueItemType.project]),
    );
    expect(overview.overdue.first.daysLate(now), greaterThan(0));
  });
}
