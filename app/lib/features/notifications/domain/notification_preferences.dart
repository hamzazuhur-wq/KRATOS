// ignore_for_file: public_member_api_docs
//
// Notification preferences (local, device-scoped).
//
// Kept in SharedPreferences because these are UI/device concerns, not domain
// data that must sync across devices.

import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  static const _enabledKey = 'kratos.notifications.dailyReminder.enabled';
  static const _hourKey = 'kratos.notifications.dailyReminder.hour';
  static const _minuteKey = 'kratos.notifications.dailyReminder.minute';

  /// Default daily check time: 08:00 local.
  static const defaultHour = 8;
  static const defaultMinute = 0;

  const NotificationPreferences({
    this.dailyReminderEnabled = true,
    this.hour = defaultHour,
    this.minute = defaultMinute,
  });

  final bool dailyReminderEnabled;
  final int hour;
  final int minute;

  /// Reads the stored preferences, falling back to defaults when unavailable.
  static Future<NotificationPreferences> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return NotificationPreferences(
        dailyReminderEnabled: prefs.getBool(_enabledKey) ?? true,
        hour: prefs.getInt(_hourKey) ?? defaultHour,
        minute: prefs.getInt(_minuteKey) ?? defaultMinute,
      );
    } catch (_) {
      return const NotificationPreferences();
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, dailyReminderEnabled);
      await prefs.setInt(_hourKey, hour);
      await prefs.setInt(_minuteKey, minute);
    } catch (_) {
      // Persisting preferences is best-effort.
    }
  }

  NotificationPreferences copyWith({
    bool? dailyReminderEnabled,
    int? hour,
    int? minute,
  }) => NotificationPreferences(
    dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
  );

  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
