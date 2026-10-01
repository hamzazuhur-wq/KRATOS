import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kratos_app/data/drift/app_database.dart';
import 'package:kratos_app/features/activities/data/activity_timeline_repository.dart';
import 'package:kratos_app/features/notifications/data/notifications_dao.dart';
import 'package:kratos_app/features/notifications/domain/notification_models.dart';
import 'package:kratos_app/features/notifications/domain/notification_processor.dart';
import 'package:kratos_app/features/notifications/domain/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NotificationsDao notifDao;
  late NotificationProcessor processor;
  late ActivityTimelineRepository timelineRepo;
  const ownerId = 'user_phase7_test_001';
  const lifeAreaId = 'area_career_001';

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    notifDao = NotificationsDao(db);
    await notifDao.ensureTableExists();
    processor = NotificationProcessor(dao: notifDao, database: db);
    timelineRepo = ActivityTimelineRepository(database: db);

    final now = DateTime.now().toUtc();
    await db.into(db.users).insert(
      UsersCompanion.insert(
        id: ownerId,
        deviceId: 'device_test_1',
        displayName: const drift.Value('Phase7 User'),
        timezone: 'UTC',
        createdAt: now,
        updatedAt: now,
      ),
    );

    await db.into(db.lifeAreas).insert(
      LifeAreasCompanion.insert(
        id: lifeAreaId,
        ownerId: ownerId,
        name: 'Career & Craft',
        sortOrder: 1,
        versionHlc: '0',
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    NotificationService().clearAll();
    await db.close();
  });

  group('Phase 7 — Activity Events & Timeline Repository', () {
    test('Activity Events are immutable and ordered newest first', () async {
      final t1 = DateTime.now().toUtc().subtract(const Duration(minutes: 30));
      final t2 = DateTime.now().toUtc().subtract(const Duration(minutes: 15));
      final t3 = DateTime.now().toUtc();

      await db.into(db.activityEvents).insert(
        ActivityEventsCompanion.insert(
          id: 'ev_1',
          ownerId: ownerId,
          eventType: 'xp_earned',
          entityType: 'task',
          lifeAreaId: const drift.Value(lifeAreaId),
          occurredAt: t1,
          versionHlc: '1',
          createdAt: t1,
        ),
      );

      await db.into(db.activityEvents).insert(
        ActivityEventsCompanion.insert(
          id: 'ev_2',
          ownerId: ownerId,
          eventType: 'level_up',
          entityType: 'life_area',
          lifeAreaId: const drift.Value(lifeAreaId),
          metadata: const drift.Value('{"from_level": 1, "to_level": 2}'),
          occurredAt: t2,
          versionHlc: '2',
          createdAt: t2,
        ),
      );

      await db.into(db.activityEvents).insert(
        ActivityEventsCompanion.insert(
          id: 'ev_3',
          ownerId: ownerId,
          eventType: 'streak_extended',
          entityType: 'streak',
          lifeAreaId: const drift.Value(lifeAreaId),
          metadata: const drift.Value('{"current_streak": 7}'),
          occurredAt: t3,
          versionHlc: '3',
          createdAt: t3,
        ),
      );

      // Verify newest first ordering
      final timeline = await timelineRepo.fetchTimeline(ownerId: ownerId);
      expect(timeline.length, 3);
      expect(timeline[0].id, 'ev_3');
      expect(timeline[1].id, 'ev_2');
      expect(timeline[2].id, 'ev_1');

      // Verify eventType filtering
      final levelUps = await timelineRepo.fetchTimeline(ownerId: ownerId, eventType: 'level_up');
      expect(levelUps.length, 1);
      expect(levelUps.first.id, 'ev_2');

      // Verify lifeArea filtering
      final areaEvents = await timelineRepo.fetchTimeline(ownerId: ownerId, lifeAreaId: lifeAreaId);
      expect(areaEvents.length, 3);

      // Verify pagination
      final page1 = await timelineRepo.fetchTimeline(ownerId: ownerId, limit: 2, offset: 0);
      expect(page1.length, 2);
      expect(page1[0].id, 'ev_3');
      expect(page1[1].id, 'ev_2');
    });
  });

  group('Phase 7 — Notifications DAO & Persistence', () {
    test('Stores notifications with read/dismissed state and updates outbox', () async {
      final now = DateTime.now().toUtc();
      final record = NotificationRecord(
        id: 'notif_test_1',
        ownerId: ownerId,
        type: 'level_up',
        title: 'Level Up!',
        body: 'You reached Level 2 in Career',
        severity: NotificationSeverity.info,
        versionHlc: '1',
        createdAt: now,
        updatedAt: now,
      );

      await notifDao.upsertNotification(record);

      // Verify retrieval
      final list = await notifDao.getNotifications(ownerId);
      expect(list.length, 1);
      expect(list.first.title, 'Level Up!');
      expect(list.first.isRead, isFalse);
      expect(list.first.isDismissed, isFalse);

      // Verify unread count
      final unread = await notifDao.getUnreadCount(ownerId);
      expect(unread, 1);

      // Verify outbox record created for sync
      final outbox = await (db.select(db.syncOutbox)..where((o) => o.entity.equals('notifications'))).get();
      expect(outbox.length, 1);
      expect(outbox.first.op, 'upsert');
      expect(outbox.first.entityId, 'notif_test_1');

      // Mark as read
      await notifDao.markAsRead('notif_test_1');
      final updated = await notifDao.getById('notif_test_1');
      expect(updated!.isRead, isTrue);
      expect(await notifDao.getUnreadCount(ownerId), 0);

      // Dismiss
      await notifDao.dismiss('notif_test_1');
      final activeList = await notifDao.getNotifications(ownerId, includeDismissed: false);
      expect(activeList, isEmpty);
      final allList = await notifDao.getNotifications(ownerId, includeDismissed: true);
      expect(allList.length, 1);
      expect(allList.first.isDismissed, isTrue);
    });
  });

  group('Phase 7 — Notification Rules & Idempotency', () {
    test('Selective event triggering and strict idempotency check', () async {
      final now = DateTime.now().toUtc();

      // 1. Level up event
      final levelUpEvent = ActivityEvent(
        id: 'ev_lvl_1',
        ownerId: ownerId,
        eventType: 'level_up',
        entityType: 'life_area',
        lifeAreaId: lifeAreaId,
        metadata: jsonEncode({'to_level': 3, 'life_area_id': lifeAreaId}),
        occurredAt: now,
        versionHlc: '1',
        createdAt: now,
      );

      final p1 = await processor.processEvent(levelUpEvent);
      expect(p1, isTrue);

      // Idempotency: re-processing the same event must return false and not duplicate
      final p1Again = await processor.processEvent(levelUpEvent);
      expect(p1Again, isFalse);

      final notifs = await notifDao.getNotifications(ownerId);
      expect(notifs.length, 1);
      expect(notifs.first.title, contains('Level 3'));

      // 2. Streak Milestone event (7-day milestone triggers notification)
      final streakMilestoneEvent = ActivityEvent(
        id: 'ev_strk_7',
        ownerId: ownerId,
        eventType: 'streak_extended',
        entityType: 'streak',
        lifeAreaId: lifeAreaId,
        metadata: jsonEncode({'current_streak': 7}),
        occurredAt: now,
        versionHlc: '2',
        createdAt: now,
      );

      final p2 = await processor.processEvent(streakMilestoneEvent);
      expect(p2, isTrue);

      // Non-milestone streak event (e.g. 2 days) should NOT trigger a notification
      final streakNonMilestoneEvent = ActivityEvent(
        id: 'ev_strk_2',
        ownerId: ownerId,
        eventType: 'streak_extended',
        entityType: 'streak',
        lifeAreaId: lifeAreaId,
        metadata: jsonEncode({'current_streak': 2}),
        occurredAt: now,
        versionHlc: '3',
        createdAt: now,
      );
      final p3 = await processor.processEvent(streakNonMilestoneEvent);
      expect(p3, isFalse);

      // 3. Goal completed event
      final goalEvent = ActivityEvent(
        id: 'ev_goal_done_1',
        ownerId: ownerId,
        eventType: 'goal_completed',
        entityType: 'goal',
        entityId: 'goal_123',
        lifeAreaId: lifeAreaId,
        metadata: jsonEncode({'title': 'Launch KRATOS v2'}),
        occurredAt: now,
        versionHlc: '4',
        createdAt: now,
      );
      final p4 = await processor.processEvent(goalEvent);
      expect(p4, isTrue);

      // Verify total generated notifications
      final allNotifs = await notifDao.getNotifications(ownerId);
      expect(allNotifs.length, 3); // Level up, 7-day streak milestone, Goal completed
    });
  });

  group('Phase 7 — NotificationService Scans & State Persistence', () {
    test('Deadline alerts preserve read/dismissed state across multiple scans', () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      await db.into(db.tasks).insert(
        TasksCompanion.insert(
          id: 'task_overdue_phase7',
          ownerId: ownerId,
          title: 'Quarterly review',
          priority: 1,
          sortOrder: 1,
          versionHlc: '0',
          status: 'pending',
          dueDate: drift.Value(yesterday),
          createdAt: yesterday,
          updatedAt: yesterday,
        ),
      );

      final service = NotificationService();

      // Scan 1
      final alerts1 = await service.scanAllAlerts(db: db, ownerId: ownerId, dispatchSystem: false);
      expect(alerts1.length, 1);
      final overdueAlert = alerts1.first;
      expect(overdueAlert.isRead, isFalse);
      expect(service.unreadCount, 1);

      // Mark as read in service
      service.markAsRead(overdueAlert.id, db: db);
      expect(service.unreadCount, 0);

      // Scan 2: Must preserve read status from SQLite database
      final alerts2 = await service.scanAllAlerts(db: db, ownerId: ownerId, dispatchSystem: false);
      expect(alerts2.length, 1);
      expect(alerts2.first.isRead, isTrue);
      expect(service.unreadCount, 0);

      // Dismiss in service
      service.dismiss(overdueAlert.id, db: db);
      expect(service.currentNotifications, isEmpty);

      // Scan 3: Must preserve dismissed status from SQLite database
      final alerts3 = await service.scanAllAlerts(db: db, ownerId: ownerId, dispatchSystem: false);
      expect(alerts3, isEmpty);
    });
  });
}
