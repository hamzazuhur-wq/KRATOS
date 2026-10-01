import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/notifications/domain/notification_service.dart';
import 'package:kratos_app/features/notifications/domain/notification_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  const ownerId = 'notif_test_user_001';
  final service = NotificationService();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.progressionDao.ensureSeeded();

    final now = DateTime.now().toUtc();
    await db.into(db.users).insert(
          UsersCompanion.insert(
            id: ownerId,
            deviceId: 'dev_local',
            displayName: const drift.Value('Test User'),
            timezone: 'UTC',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await service.clearAll(db: db, ownerId: ownerId);
    await db.close();
  });

  test('NotificationService scans Ending Today, Overdue, and Stale Paused items correctly', () async {
    final now = DateTime.now();

    // 1. Task due yesterday (Overdue)
    final yesterday = now.subtract(const Duration(days: 1));
    await db.into(db.tasks).insert(
          TasksCompanion.insert(
            id: 'task_overdue_1',
            ownerId: ownerId,
            title: 'Complete tax report',
            priority: 1,
            sortOrder: 1,
            versionHlc: '0',
            status: 'pending',
            dueDate: drift.Value(yesterday),
            createdAt: yesterday,
            updatedAt: yesterday,
          ),
        );

    // 2. Task due today (Ending Today)
    final today = DateTime(now.year, now.month, now.day, 14, 0);
    await db.into(db.tasks).insert(
          TasksCompanion.insert(
            id: 'task_today_1',
            ownerId: ownerId,
            title: 'Ship feature release',
            priority: 2,
            sortOrder: 2,
            versionHlc: '0',
            status: 'in_progress',
            dueDate: drift.Value(today),
            createdAt: now,
            updatedAt: now,
          ),
        );

    // 3. Goal paused 10 days ago (Stale Paused)
    final tenDaysAgo = now.subtract(const Duration(days: 10));
    await db.into(db.goals).insert(
          GoalsCompanion.insert(
            id: 'goal_paused_1',
            ownerId: ownerId,
            rootId: 'goal_paused_1',
            path: 'goal_paused_1',
            depth: 0,
            progress: 0.0,
            versionHlc: '0',
            title: 'Master Machine Learning',
            status: 'paused',
            createdAt: tenDaysAgo,
            updatedAt: tenDaysAgo,
          ),
        );

    // Scan
    final alerts = await service.scanAllAlerts(
      db: db,
      ownerId: ownerId,
      dispatchSystem: false,
    );

    expect(alerts.length, 3);

    // Verify overdue alert
    final overdueAlert = alerts.firstWhere((a) => a.kind == NotificationKind.overdue);
    expect(overdueAlert.title, contains('Overdue Task'));
    expect(overdueAlert.targetId, 'task_overdue_1');
    expect(overdueAlert.severity, NotificationSeverity.urgent);

    // Verify ending today alert
    final todayAlert = alerts.firstWhere((a) => a.kind == NotificationKind.endingToday);
    expect(todayAlert.title, contains('Task Due Today'));
    expect(todayAlert.targetId, 'task_today_1');
    expect(todayAlert.severity, NotificationSeverity.info);

    // Verify stale paused alert
    final pausedAlert = alerts.firstWhere((a) => a.kind == NotificationKind.stalePaused);
    expect(pausedAlert.title, contains('Goal Paused for 10 Days'));
    expect(pausedAlert.targetId, 'goal_paused_1');
    expect(pausedAlert.severity, NotificationSeverity.warning);

    // Test mark as read & dismiss
    expect(service.unreadCount, 3);
    await service.markAsRead(overdueAlert.id, db: db);
    expect(service.unreadCount, 2);

    await service.dismiss(todayAlert.id, db: db);
    expect(service.currentNotifications.any((a) => a.id == todayAlert.id), isFalse);
  });
}
