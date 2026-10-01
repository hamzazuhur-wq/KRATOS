import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';
import '../data/notifications_dao.dart';
import 'notification_models.dart';

/// Processes ActivityEvents into user notifications with strict idempotency (Phase 7).
/// Ensures that duplicate events, sync replays, or event re-scans never create duplicate notifications.
class NotificationProcessor {
  final NotificationsDao dao;
  final AppDatabase database;

  static const Set<int> streakMilestones = {3, 7, 14, 21, 30, 50, 60, 90, 100, 180, 365};

  NotificationProcessor({
    required this.dao,
    required this.database,
  });

  /// Processes a single ActivityEvent. Returns true if a notification was generated.
  Future<bool> processEvent(ActivityEvent event, {String? deviceId}) async {
    // 1. Strict Idempotency Check: skip if already converted into a notification
    final alreadyProcessed = await dao.isActivityEventProcessed(event.ownerId, event.id);
    if (alreadyProcessed) {
      return false;
    }

    Map<String, dynamic> meta = {};
    try {
      meta = jsonDecode(event.metadata) as Map<String, dynamic>;
    } catch (_) {}

    NotificationRecord? record;

    switch (event.eventType) {
      case 'level_up':
        final toLevel = meta['to_level'] ?? 2;
        final lifeAreaId = event.lifeAreaId ?? meta['life_area_id'] as String?;
        String areaName = 'Life Area';
        if (lifeAreaId != null) {
          final area = await (database.select(database.lifeAreas)..where((l) => l.id.equals(lifeAreaId))).getSingleOrNull();
          if (area != null) areaName = area.name;
        }

        record = NotificationRecord(
          id: 'notif_lvl_${event.id}',
          ownerId: event.ownerId,
          type: 'level_up',
          title: 'LEVEL UP! Level $toLevel reached',
          body: 'Phenomenal progress in $areaName. Your dedication is compounding.',
          entityType: 'life_area',
          entityId: lifeAreaId,
          activityEventId: event.id,
          severity: NotificationSeverity.info,
          metadata: meta,
          versionHlc: event.versionHlc,
          createdAt: event.occurredAt,
          updatedAt: DateTime.now().toUtc(),
        );
        break;

      case 'achievement_unlocked':
        final kind = meta['kind'] as String? ?? 'Mastery Badge';
        record = NotificationRecord(
          id: 'notif_ach_${event.id}',
          ownerId: event.ownerId,
          type: 'achievement_unlocked',
          title: 'ACHIEVEMENT UNLOCKED!',
          body: 'Earned badge: $kind. Bonus freeze tokens granted.',
          entityType: 'achievement',
          entityId: event.entityId,
          activityEventId: event.id,
          severity: NotificationSeverity.info,
          metadata: meta,
          versionHlc: event.versionHlc,
          createdAt: event.occurredAt,
          updatedAt: DateTime.now().toUtc(),
        );
        break;

      case 'goal_completed':
        final goalTitle = meta['title'] as String? ?? 'Main Goal';
        record = NotificationRecord(
          id: 'notif_goal_${event.id}',
          ownerId: event.ownerId,
          type: 'goal_completed',
          title: 'GOAL COMPLETED!',
          body: 'Successfully finished "$goalTitle". Completion bonus awarded.',
          entityType: 'goal',
          entityId: event.entityId,
          activityEventId: event.id,
          severity: NotificationSeverity.info,
          metadata: meta,
          versionHlc: event.versionHlc,
          createdAt: event.occurredAt,
          updatedAt: DateTime.now().toUtc(),
        );
        break;

      case 'project_completed':
        final projTitle = meta['title'] as String? ?? 'Project';
        record = NotificationRecord(
          id: 'notif_proj_${event.id}',
          ownerId: event.ownerId,
          type: 'project_completed',
          title: 'PROJECT DELIVERED!',
          body: 'All milestones completed for "$projTitle". Full XP unlocked.',
          entityType: 'project',
          entityId: event.entityId,
          activityEventId: event.id,
          severity: NotificationSeverity.info,
          metadata: meta,
          versionHlc: event.versionHlc,
          createdAt: event.occurredAt,
          updatedAt: DateTime.now().toUtc(),
        );
        break;

      case 'streak_extended':
        final currentStreak = (meta['current_streak'] as num?)?.toInt() ?? 1;
        if (streakMilestones.contains(currentStreak)) {
          record = NotificationRecord(
            id: 'notif_strk_${event.id}',
            ownerId: event.ownerId,
            type: 'streak_milestone',
            title: '🔥 $currentStreak-DAY STREAK MILESTONE!',
            body: 'Unstoppable consistency. Keep pushing forward!',
            entityType: 'streak',
            entityId: event.entityId,
            activityEventId: event.id,
            severity: NotificationSeverity.info,
            metadata: meta,
            versionHlc: event.versionHlc,
            createdAt: event.occurredAt,
            updatedAt: DateTime.now().toUtc(),
          );
        }
        break;

      case 'xp_earned':
        final action = meta['action'] as String?;
        if (action == 'goal_completion_bonus') {
          final points = meta['points'] ?? 0;
          record = NotificationRecord(
            id: 'notif_bonus_${event.id}',
            ownerId: event.ownerId,
            type: 'weekly_bonus',
            title: 'GOAL COMPLETION BONUS AWARDED!',
            body: '+$points XP bonus granted for completing all milestones in your goal.',
            entityType: 'goal',
            entityId: event.entityId,
            activityEventId: event.id,
            severity: NotificationSeverity.info,
            metadata: meta,
            versionHlc: event.versionHlc,
            createdAt: event.occurredAt,
            updatedAt: DateTime.now().toUtc(),
          );
        }
        break;
    }

    if (record != null) {
      await dao.upsertNotification(record, deviceId: deviceId);
      return true;
    }

    return false;
  }

  /// Processes all un-notified activity events for a user.
  Future<int> processPendingEvents(String ownerId, {String? deviceId}) async {
    final recentEvents = await (database.select(database.activityEvents)
          ..where((e) => e.ownerId.equals(ownerId))
          ..orderBy([(e) => OrderingTerm.desc(e.occurredAt)])
          ..limit(100))
        .get();

    int generated = 0;
    for (final event in recentEvents) {
      final created = await processEvent(event, deviceId: deviceId);
      if (created) generated++;
    }
    return generated;
  }
}
