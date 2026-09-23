// ignore_for_file: public_member_api_docs
// Wave 16: Notification Service domain model & scheduler.
// Manages streak reminders, freeze alerts, and weekly bonus notifications.

import 'dart:async';

enum NotificationKind {
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
  final DateTime scheduledFor;
  final bool isDelivered;

  const KratosNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.scheduledFor,
    this.isDelivered = false,
  });
}

class NotificationService {
  final _notifications = <KratosNotification>[];
  final _streamController = StreamController<List<KratosNotification>>.broadcast();

  Stream<List<KratosNotification>> get notificationsStream =>
      _streamController.stream;
  List<KratosNotification> get pendingNotifications =>
      List.unmodifiable(_notifications);

  /// Schedule daily streak check reminder if activity is missing.
  Future<void> scheduleStreakReminder({
    required String lifeAreaName,
    required int currentStreak,
    required DateTime reminderTime,
  }) async {
    final notification = KratosNotification(
      id: 'streak_rem_${DateTime.now().millisecondsSinceEpoch}',
      kind: NotificationKind.streakReminder,
      title: 'Maintain Your $lifeAreaName Streak! 🔥',
      body: 'You have a $currentStreak-day streak going. Complete an action before midnight to keep it alive!',
      scheduledFor: reminderTime,
    );
    _notifications.add(notification);
    _streamController.add(_notifications);
  }

  /// Alert user that a freeze token was automatically consumed.
  Future<void> sendFreezeConsumedAlert({
    required String lifeAreaName,
    required int tokensRemaining,
  }) async {
    final notification = KratosNotification(
      id: 'freeze_${DateTime.now().millisecondsSinceEpoch}',
      kind: NotificationKind.freezeConsumed,
      title: 'Streak Protected ❄️',
      body: 'A freeze token was used for $lifeAreaName. You have $tokensRemaining token${tokensRemaining == 1 ? '' : 's'} remaining.',
      scheduledFor: DateTime.now().toUtc(),
      isDelivered: true,
    );
    _notifications.add(notification);
    _streamController.add(_notifications);
  }

  /// Celebrate weekly +20% bonus unlocked.
  Future<void> sendWeeklyBonusUnlocked({
    required String lifeAreaName,
  }) async {
    final notification = KratosNotification(
      id: 'bonus_${DateTime.now().millisecondsSinceEpoch}',
      kind: NotificationKind.weeklyBonusUnlocked,
      title: 'Weekly +20% XP Bonus Active! ⚡',
      body: '7 consecutive days in $lifeAreaName! All positive XP earned this week receives a +20% boost.',
      scheduledFor: DateTime.now().toUtc(),
      isDelivered: true,
    );
    _notifications.add(notification);
    _streamController.add(_notifications);
  }

  void dispose() {
    _streamController.close();
  }
}
