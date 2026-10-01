import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/features/notifications/data/local_notifications_service.dart';
import 'package:kratos_app/features/notifications/domain/notification_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(() {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  group('daily reminder scheduling', () {
    test('schedules later today when the time has not passed yet', () {
      final from = DateTime.utc(2026, 4, 20, 6, 30);
      final scheduled = LocalNotificationsService.nextInstanceOf(
        hour: 8,
        minute: 0,
        from: from,
      );

      expect(scheduled.year, 2026);
      expect(scheduled.month, 4);
      expect(scheduled.day, 20);
      expect(scheduled.hour, 8);
      expect(scheduled.minute, 0);
    });

    test('rolls to tomorrow when the time already passed', () {
      final from = DateTime.utc(2026, 4, 20, 9, 15);
      final scheduled = LocalNotificationsService.nextInstanceOf(
        hour: 8,
        minute: 0,
        from: from,
      );

      expect(scheduled.day, 21);
      expect(scheduled.hour, 8);
    });

    test('rolls to tomorrow when called exactly at the reminder minute', () {
      final from = DateTime.utc(2026, 4, 20, 8, 0);
      final scheduled = LocalNotificationsService.nextInstanceOf(
        hour: 8,
        minute: 0,
        from: from,
      );

      expect(scheduled.day, 21);
    });

    test('notification ids are stable and positive', () {
      final id = LocalNotificationsService.notificationIdFor('overdue_task_1');
      expect(id, greaterThan(0));
      expect(
        id,
        LocalNotificationsService.notificationIdFor('overdue_task_1'),
      );
    });
  });

  group('notification preferences', () {
    test('defaults to a daily 08:00 reminder that is enabled', () {
      const preferences = NotificationPreferences();
      expect(preferences.dailyReminderEnabled, isTrue);
      expect(preferences.hour, 8);
      expect(preferences.minute, 0);
      expect(preferences.label, '08:00');
    });

    test('copyWith preserves untouched values', () {
      const base = NotificationPreferences(dailyReminderEnabled: true);
      final updated = base.copyWith(hour: 21, minute: 5);
      expect(updated.dailyReminderEnabled, isTrue);
      expect(updated.label, '21:05');
    });
  });
}
