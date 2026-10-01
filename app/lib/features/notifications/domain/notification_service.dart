// ignore_for_file: public_member_api_docs

import 'dart:async';
import 'package:drift/drift.dart';
import '../../../data/drift/app_database.dart';
import '../data/notifications_dao.dart';
import 'notification_models.dart';
import 'notification_processor.dart';
import 'system_notification_bridge.dart';

enum NotificationKind {
  endingToday,
  overdue,
  stalePaused,
  streakReminder,
  freezeConsumed,
  weeklyBonusUnlocked,
  levelPromoted,
}

class KratosNotification {
  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final String? targetType; // 'task', 'goal', 'project', 'streak', 'life_area', 'achievement'
  final String? targetId;
  final NotificationSeverity severity;
  final DateTime timestamp;
  final bool isRead;
  final bool isDismissed;
  final String ownerId;
  final String? activityEventId;
  final Map<String, dynamic> metadata;
  final String versionHlc;

  const KratosNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    this.targetType,
    this.targetId,
    this.severity = NotificationSeverity.info,
    required this.timestamp,
    this.isRead = false,
    this.isDismissed = false,
    this.ownerId = '',
    this.activityEventId,
    this.metadata = const {},
    this.versionHlc = '',
  });

  KratosNotification copyWith({
    bool? isRead,
    bool? isDismissed,
    String? title,
    String? body,
    NotificationSeverity? severity,
    DateTime? timestamp,
    String? ownerId,
    String? activityEventId,
    Map<String, dynamic>? metadata,
    String? versionHlc,
  }) {
    return KratosNotification(
      id: id,
      kind: kind,
      title: title ?? this.title,
      body: body ?? this.body,
      targetType: targetType,
      targetId: targetId,
      severity: severity ?? this.severity,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isDismissed: isDismissed ?? this.isDismissed,
      ownerId: ownerId ?? this.ownerId,
      activityEventId: activityEventId ?? this.activityEventId,
      metadata: metadata ?? this.metadata,
      versionHlc: versionHlc ?? this.versionHlc,
    );
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final _notifications = <KratosNotification>[];
  final _dismissedIds = <String>{};
  final _readIds = <String>{};
  final _dispatchedSystemIds = <String>{};
  NotificationsDao? _dao;
  AppDatabase? _daoDatabase;

  final _streamController = StreamController<List<KratosNotification>>.broadcast();

  Stream<List<KratosNotification>> get notificationsStream => _streamController.stream;
  List<KratosNotification> get currentNotifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead && !n.isDismissed).length;

  NotificationsDao _getDao(AppDatabase db) {
    if (_dao == null || !identical(_daoDatabase, db)) {
      _dao = NotificationsDao(db);
      _daoDatabase = db;
    }
    return _dao!;
  }

  /// Scans SQLite database for live alerts: Ending Today, Overdue, and Stale Paused,
  /// processes any pending ActivityEvents into notifications, and loads persisted state.
  Future<List<KratosNotification>> scanAllAlerts({
    required AppDatabase db,
    required String ownerId,
    bool dispatchSystem = true,
  }) async {
    final dao = _getDao(db);
    await dao.ensureTableExists();

    // 0. Process any pending ActivityEvents into notifications (Phase 7 rule processor)
    final processor = NotificationProcessor(dao: dao, database: db);
    await processor.processPendingEvents(ownerId);

    final scanned = <KratosNotification>[];
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // 1. Scan Tasks
    try {
      final tasks = await (db.select(db.tasks)
            ..where((t) => t.ownerId.equals(ownerId) & t.deletedAt.isNull()))
          .get();

      for (final t in tasks) {
        if (t.status == 'completed' || t.status == 'done') continue;
        if (t.dueDate == null) continue;

        final localDue = t.dueDate!.toLocal();
        final dueDay = DateTime(localDue.year, localDue.month, localDue.day);

        if (dueDay.isBefore(todayStart)) {
          // OVERDUE
          final daysOverdue = todayStart.difference(dueDay).inDays;
          final id = 'overdue_task_${t.id}';
          final existing = await dao.getById(id);
          final isRead = _readIds.contains(id) || (existing != null && existing.isRead);
          final isDismissed = _dismissedIds.contains(id) || (existing != null && existing.isDismissed);

          if (!isDismissed) {
            final alert = KratosNotification(
              id: id,
              kind: NotificationKind.overdue,
              title: 'Overdue Task: ${t.title}',
              body: 'Was due ${daysOverdue == 1 ? 'yesterday' : '$daysOverdue days ago'}. Tap to complete or reschedule.',
              targetType: 'task',
              targetId: t.id,
              severity: NotificationSeverity.urgent,
              timestamp: localDue,
              isRead: isRead,
              isDismissed: isDismissed,
              ownerId: ownerId,
            );
            scanned.add(alert);

            if (existing == null) {
              await dao.upsertNotification(
                NotificationRecord(
                  id: id,
                  ownerId: ownerId,
                  type: 'overdue',
                  title: alert.title,
                  body: alert.body,
                  entityType: 'task',
                  entityId: t.id,
                  severity: NotificationSeverity.urgent,
                  versionHlc: t.versionHlc,
                  createdAt: localDue,
                  updatedAt: DateTime.now().toUtc(),
                ),
              );
            }
          }
        } else if (localDue.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
            localDue.isBefore(todayEnd)) {
          // ENDING TODAY
          final id = 'today_task_${t.id}';
          final existing = await dao.getById(id);
          final isRead = _readIds.contains(id) || (existing != null && existing.isRead);
          final isDismissed = _dismissedIds.contains(id) || (existing != null && existing.isDismissed);

          if (!isDismissed) {
            final alert = KratosNotification(
              id: id,
              kind: NotificationKind.endingToday,
              title: 'Task Due Today: ${t.title}',
              body: 'Scheduled for completion today. Don\'t lose momentum!',
              targetType: 'task',
              targetId: t.id,
              severity: NotificationSeverity.info,
              timestamp: localDue,
              isRead: isRead,
              isDismissed: isDismissed,
              ownerId: ownerId,
            );
            scanned.add(alert);

            if (existing == null) {
              await dao.upsertNotification(
                NotificationRecord(
                  id: id,
                  ownerId: ownerId,
                  type: 'ending_today',
                  title: alert.title,
                  body: alert.body,
                  entityType: 'task',
                  entityId: t.id,
                  severity: NotificationSeverity.info,
                  versionHlc: t.versionHlc,
                  createdAt: localDue,
                  updatedAt: DateTime.now().toUtc(),
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    // 2. Scan Goals
    try {
      final goals = await (db.select(db.goals)
            ..where((g) => g.ownerId.equals(ownerId) & g.deletedAt.isNull()))
          .get();

      for (final g in goals) {
        if (g.status == 'completed' || g.status == 'done') continue;

        if (g.dueDate != null) {
          final localDue = g.dueDate!.toLocal();
          final dueDay = DateTime(localDue.year, localDue.month, localDue.day);

          if (dueDay.isBefore(todayStart)) {
            final daysOverdue = todayStart.difference(dueDay).inDays;
            final id = 'overdue_goal_${g.id}';
            final existing = await dao.getById(id);
            final isRead = _readIds.contains(id) || (existing != null && existing.isRead);
            final isDismissed = _dismissedIds.contains(id) || (existing != null && existing.isDismissed);

            if (!isDismissed) {
              final alert = KratosNotification(
                id: id,
                kind: NotificationKind.overdue,
                title: 'Overdue Goal: ${g.title}',
                body: 'Target deadline was ${daysOverdue == 1 ? 'yesterday' : '$daysOverdue days ago'}. Review milestones.',
                targetType: 'goal',
                targetId: g.id,
                severity: NotificationSeverity.urgent,
                timestamp: localDue,
                isRead: isRead,
                isDismissed: isDismissed,
                ownerId: ownerId,
              );
              scanned.add(alert);

              if (existing == null) {
                await dao.upsertNotification(
                  NotificationRecord(
                    id: id,
                    ownerId: ownerId,
                    type: 'overdue',
                    title: alert.title,
                    body: alert.body,
                    entityType: 'goal',
                    entityId: g.id,
                    severity: NotificationSeverity.urgent,
                    versionHlc: g.versionHlc,
                    createdAt: localDue,
                    updatedAt: DateTime.now().toUtc(),
                  ),
                );
              }
            }
          } else if (localDue.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
              localDue.isBefore(todayEnd)) {
            final id = 'today_goal_${g.id}';
            final existing = await dao.getById(id);
            final isRead = _readIds.contains(id) || (existing != null && existing.isRead);
            final isDismissed = _dismissedIds.contains(id) || (existing != null && existing.isDismissed);

            if (!isDismissed) {
              final alert = KratosNotification(
                id: id,
                kind: NotificationKind.endingToday,
                title: 'Goal Due Today: ${g.title}',
                body: 'Target milestone reaches its deadline today.',
                targetType: 'goal',
                targetId: g.id,
                severity: NotificationSeverity.info,
                timestamp: localDue,
                isRead: isRead,
                isDismissed: isDismissed,
                ownerId: ownerId,
              );
              scanned.add(alert);

              if (existing == null) {
                await dao.upsertNotification(
                  NotificationRecord(
                    id: id,
                    ownerId: ownerId,
                    type: 'ending_today',
                    title: alert.title,
                    body: alert.body,
                    entityType: 'goal',
                    entityId: g.id,
                    severity: NotificationSeverity.info,
                    versionHlc: g.versionHlc,
                    createdAt: localDue,
                    updatedAt: DateTime.now().toUtc(),
                  ),
                );
              }
            }
          }
        }

        // Stale Paused check (paused >= 7 days)
        if (g.status == 'paused' && g.updatedAt.isBefore(now.subtract(const Duration(days: 7)))) {
          final daysPaused = now.difference(g.updatedAt).inDays;
          final id = 'paused_goal_${g.id}';
          final existing = await dao.getById(id);
          final isRead = _readIds.contains(id) || (existing != null && existing.isRead);
          final isDismissed = _dismissedIds.contains(id) || (existing != null && existing.isDismissed);

          if (!isDismissed) {
            final alert = KratosNotification(
              id: id,
              kind: NotificationKind.stalePaused,
              title: 'Goal Paused for $daysPaused Days: ${g.title}',
              body: 'Has been paused for over a week. Consider resuming or archiving.',
              targetType: 'goal',
              targetId: g.id,
              severity: NotificationSeverity.warning,
              timestamp: g.updatedAt,
              isRead: isRead,
              isDismissed: isDismissed,
              ownerId: ownerId,
            );
            scanned.add(alert);

            if (existing == null) {
              await dao.upsertNotification(
                NotificationRecord(
                  id: id,
                  ownerId: ownerId,
                  type: 'stale_paused',
                  title: alert.title,
                  body: alert.body,
                  entityType: 'goal',
                  entityId: g.id,
                  severity: NotificationSeverity.warning,
                  versionHlc: g.versionHlc,
                  createdAt: g.updatedAt,
                  updatedAt: DateTime.now().toUtc(),
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    // 3. Scan Projects
    try {
      final projects = await (db.select(db.projects)
            ..where((p) => p.ownerId.equals(ownerId) & p.deletedAt.isNull()))
          .get();

      for (final p in projects) {
        if (p.status == 'completed' || p.status == 'done') continue;

        if (p.dueDate != null) {
          final localDue = p.dueDate!.toLocal();
          final dueDay = DateTime(localDue.year, localDue.month, localDue.day);

          if (dueDay.isBefore(todayStart)) {
            final daysOverdue = todayStart.difference(dueDay).inDays;
            final id = 'overdue_proj_${p.id}';
            final existing = await dao.getById(id);
            final isRead = _readIds.contains(id) || (existing != null && existing.isRead);
            final isDismissed = _dismissedIds.contains(id) || (existing != null && existing.isDismissed);

            if (!isDismissed) {
              final alert = KratosNotification(
                id: id,
                kind: NotificationKind.overdue,
                title: 'Overdue Project: ${p.title}',
                body: 'Target delivery was ${daysOverdue == 1 ? 'yesterday' : '$daysOverdue days ago'}. Check roadmap phases.',
                targetType: 'project',
                targetId: p.id,
                severity: NotificationSeverity.urgent,
                timestamp: localDue,
                isRead: isRead,
                isDismissed: isDismissed,
                ownerId: ownerId,
              );
              scanned.add(alert);

              if (existing == null) {
                await dao.upsertNotification(
                  NotificationRecord(
                    id: id,
                    ownerId: ownerId,
                    type: 'overdue',
                    title: alert.title,
                    body: alert.body,
                    entityType: 'project',
                    entityId: p.id,
                    severity: NotificationSeverity.urgent,
                    versionHlc: p.versionHlc,
                    createdAt: localDue,
                    updatedAt: DateTime.now().toUtc(),
                  ),
                );
              }
            }
          } else if (localDue.isAfter(todayStart.subtract(const Duration(seconds: 1))) &&
              localDue.isBefore(todayEnd)) {
            final id = 'today_proj_${p.id}';
            final existing = await dao.getById(id);
            final isRead = _readIds.contains(id) || (existing != null && existing.isRead);
            final isDismissed = _dismissedIds.contains(id) || (existing != null && existing.isDismissed);

            if (!isDismissed) {
              final alert = KratosNotification(
                id: id,
                kind: NotificationKind.endingToday,
                title: 'Project Due Today: ${p.title}',
                body: 'Roadmap target deadline is today.',
                targetType: 'project',
                targetId: p.id,
                severity: NotificationSeverity.info,
                timestamp: localDue,
                isRead: isRead,
                isDismissed: isDismissed,
                ownerId: ownerId,
              );
              scanned.add(alert);

              if (existing == null) {
                await dao.upsertNotification(
                  NotificationRecord(
                    id: id,
                    ownerId: ownerId,
                    type: 'ending_today',
                    title: alert.title,
                    body: alert.body,
                    entityType: 'project',
                    entityId: p.id,
                    severity: NotificationSeverity.info,
                    versionHlc: p.versionHlc,
                    createdAt: localDue,
                    updatedAt: DateTime.now().toUtc(),
                  ),
                );
              }
            }
          }
        }

        // Stale Paused check (paused >= 7 days)
        if (p.status == 'paused' && p.updatedAt.isBefore(now.subtract(const Duration(days: 7)))) {
          final daysPaused = now.difference(p.updatedAt).inDays;
          final id = 'paused_proj_${p.id}';
          final existing = await dao.getById(id);
          final isRead = _readIds.contains(id) || (existing != null && existing.isRead);
          final isDismissed = _dismissedIds.contains(id) || (existing != null && existing.isDismissed);

          if (!isDismissed) {
            final alert = KratosNotification(
              id: id,
              kind: NotificationKind.stalePaused,
              title: 'Project Paused for $daysPaused Days: ${p.title}',
              body: 'Has been paused for over a week. Review active phases.',
              targetType: 'project',
              targetId: p.id,
              severity: NotificationSeverity.warning,
              timestamp: p.updatedAt,
              isRead: isRead,
              isDismissed: isDismissed,
              ownerId: ownerId,
            );
            scanned.add(alert);

            if (existing == null) {
              await dao.upsertNotification(
                NotificationRecord(
                  id: id,
                  ownerId: ownerId,
                  type: 'stale_paused',
                  title: alert.title,
                  body: alert.body,
                  entityType: 'project',
                  entityId: p.id,
                  severity: NotificationSeverity.warning,
                  versionHlc: p.versionHlc,
                  createdAt: p.updatedAt,
                  updatedAt: DateTime.now().toUtc(),
                ),
              );
            }
          }
        }
      }
    } catch (_) {}

    // 4. Merge other persistent event-driven notifications from DAO (Level up, Achievements, Streaks, etc.)
    try {
      final persistedRecords = await dao.getNotifications(ownerId, includeDismissed: false);
      final scannedIds = scanned.map((s) => s.id).toSet();

      for (final rec in persistedRecords) {
        if (!scannedIds.contains(rec.id) && !rec.isDismissed && !_dismissedIds.contains(rec.id)) {
          final isRead = _readIds.contains(rec.id) || rec.isRead;
          scanned.add(rec.toKratosNotification().copyWith(isRead: isRead));
        }
      }
    } catch (_) {}

    // Sort: urgent first, then warning, then info, then newest
    scanned.sort((a, b) {
      final sevCompare = a.severity.index.compareTo(b.severity.index);
      if (sevCompare != 0) return sevCompare;
      return b.timestamp.compareTo(a.timestamp);
    });

    _notifications
      ..clear()
      ..addAll(scanned);

    _streamController.add(List.unmodifiable(_notifications));

    // Dispatch system OS notifications for unread urgent and ending-today alerts
    if (dispatchSystem) {
      for (final item in _notifications) {
        if (!item.isRead && !item.isDismissed && !_dispatchedSystemIds.contains(item.id)) {
          _dispatchedSystemIds.add(item.id);
          SystemNotificationBridge.instance.showNotification(item.title, item.body);
        }
      }
    }

    return _notifications;
  }

  Future<void> markAsRead(String id, {AppDatabase? db}) async {
    _readIds.add(id);
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      _streamController.add(List.unmodifiable(_notifications));
    }
    if (db != null) {
      await _getDao(db).markAsRead(id);
    } else if (_dao != null) {
      await _dao!.markAsRead(id);
    }
  }

  void markAllAsRead({AppDatabase? db, String? ownerId}) {
    for (final n in _notifications) {
      _readIds.add(n.id);
    }
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    _streamController.add(List.unmodifiable(_notifications));

    final effectiveOwnerId = ownerId ?? (_notifications.isNotEmpty ? _notifications.first.ownerId : null);
    if (effectiveOwnerId != null) {
      if (_dao != null) {
        _dao!.markAllAsRead(effectiveOwnerId);
      } else if (db != null) {
        _getDao(db).markAllAsRead(effectiveOwnerId);
      }
    }
  }

  Future<void> dismiss(String id, {AppDatabase? db}) async {
    _dismissedIds.add(id);
    _notifications.removeWhere((n) => n.id == id);
    _streamController.add(List.unmodifiable(_notifications));

    if (_dao != null) {
      await _dao!.dismiss(id);
    } else if (db != null) {
      await _getDao(db).dismiss(id);
    }
  }

  Future<void> clearAll({AppDatabase? db, String? ownerId}) async {
    final effectiveOwnerId = ownerId ??
        (_notifications.isNotEmpty ? _notifications.first.ownerId : null);
    for (final n in _notifications) {
      _dismissedIds.add(n.id);
    }
    _notifications.clear();
    _streamController.add(List.unmodifiable(_notifications));

    if (effectiveOwnerId != null) {
      if (db != null) {
        await _getDao(db).clearAll(effectiveOwnerId);
      } else if (_dao != null) {
        await _dao!.clearAll(effectiveOwnerId);
      }
    }
  }

  /// Legacy in-memory notification entry point retained for callers that do
  /// not yet have a database-backed owner context.
  List<KratosNotification> get pendingNotifications => currentNotifications;

  Future<void> scheduleStreakReminder({
    required String lifeAreaName,
    required int currentStreak,
    required DateTime reminderTime,
  }) async {
    _notifications.add(
      KratosNotification(
        id: 'streak_reminder_${DateTime.now().microsecondsSinceEpoch}',
        kind: NotificationKind.streakReminder,
        title: 'Keep your $lifeAreaName streak alive',
        body: '$currentStreak-day streak in progress. Continue today to protect it.',
        targetType: 'streak',
        severity: NotificationSeverity.info,
        timestamp: reminderTime,
      ),
    );
    _streamController.add(List.unmodifiable(_notifications));
  }

  Future<void> sendFreezeConsumedAlert({
    required String lifeAreaName,
    required int tokensRemaining,
  }) async {
    final tokenLabel = tokensRemaining == 1 ? 'token' : 'tokens';
    _notifications.add(
      KratosNotification(
        id: 'freeze_consumed_${DateTime.now().microsecondsSinceEpoch}',
        kind: NotificationKind.freezeConsumed,
        title: 'Streak Protected: $lifeAreaName',
        body: '$tokensRemaining $tokenLabel remaining.',
        targetType: 'streak',
        severity: NotificationSeverity.warning,
        timestamp: DateTime.now().toUtc(),
      ),
    );
    _streamController.add(List.unmodifiable(_notifications));
  }

  Future<void> sendWeeklyBonusUnlocked({required String lifeAreaName}) async {
    _notifications.add(
      KratosNotification(
        id: 'weekly_bonus_${DateTime.now().microsecondsSinceEpoch}',
        kind: NotificationKind.weeklyBonusUnlocked,
        title: 'Weekly +20% XP Bonus Active!',
        body: 'Your consistency in $lifeAreaName unlocked a +20% XP bonus.',
        targetType: 'life_area',
        severity: NotificationSeverity.info,
        timestamp: DateTime.now().toUtc(),
      ),
    );
    _streamController.add(List.unmodifiable(_notifications));
  }

  void dispose() {
    _streamController.close();
  }
}
