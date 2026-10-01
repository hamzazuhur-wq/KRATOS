// ignore_for_file: public_member_api_docs
//
// Deadline notification scheduler.
//
// Two responsibilities:
//   1. On app launch/resume — push real OS notifications for anything overdue
//      or ending today (the "you did not finish yesterday's task" alert).
//   2. Keep a single repeating daily reminder scheduled at the user's time.
//
// Notifications are delivered through [SystemNotificationBridge] /
// [LocalNotificationsService] so they land in the phone's notification shade,
// lock screen and iOS notification centre.

import 'package:flutter/foundation.dart';

import '../../../data/drift/app_database.dart';
import '../data/local_notifications_service.dart';
import 'notification_preferences.dart';
import 'notification_service.dart';

class DeadlineNotificationScheduler {
  DeadlineNotificationScheduler(this.database);

  final AppDatabase database;
  bool _bootstrapped = false;

  /// Requests permission and pushes the current alert set to the OS.
  ///
  /// Safe to call on every app start and on resume.
  Future<void> bootstrap({required String ownerId}) async {
    try {
      final service = LocalNotificationsService.instance;
      await service.initialize();

      final preferences = await NotificationPreferences.load();

      // Push overdue / ending-today alerts to the system right away.
      await NotificationService().scanAllAlerts(
        db: database,
        ownerId: ownerId,
        dispatchSystem: true,
      );

      await applyPreferences(preferences);
      _bootstrapped = true;
    } catch (error) {
      debugPrint('DeadlineNotificationScheduler.bootstrap failed: $error');
    }
  }

  /// Applies the stored preference: schedules or cancels the daily reminder.
  Future<void> applyPreferences(NotificationPreferences preferences) async {
    final service = LocalNotificationsService.instance;
    if (preferences.dailyReminderEnabled) {
      await service.scheduleDailyReminder(
        id: kDailyReminderNotificationId,
        hour: preferences.hour,
        minute: preferences.minute,
        title: 'KRATOS — Daily deadline check',
        body:
            'Open KRATOS to review what is due today and what already slipped.',
      );
    } else {
      await service.cancel(kDailyReminderNotificationId);
    }
  }

  /// Called when the user changes the preference in Settings.
  Future<void> updatePreferences(NotificationPreferences preferences) async {
    await preferences.save();
    await applyPreferences(preferences);
  }

  /// Requests OS permission explicitly (used by the Settings screen).
  Future<String> requestPermission() async {
    final service = LocalNotificationsService.instance;
    await service.initialize();
    return service.requestPermission();
  }

  bool get isBootstrapped => _bootstrapped;
}
