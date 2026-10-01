// ignore_for_file: public_member_api_docs
//
// Real, system-level notifications for KRATOS.
//
// Delivers alerts to the operating system (notification shade, lock screen and
// iOS notification centre) instead of only rendering them inside the app.
//
// Design notes:
//  * Everything is defensive: on unsupported platforms, in unit tests, or when
//    a plugin channel is unavailable, calls degrade to no-ops instead of
//    crashing a screen.
//  * Two delivery modes:
//      - immediate  → "you slipped on X" alerts computed from real data
//      - scheduled  → a repeating daily reminder at the user's chosen time

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Channel used for everything related to deadlines and slipped commitments.
const _deadlineChannelId = 'kratos_deadlines';
const _deadlineChannelName = 'Deadlines & Slipped Commitments';
const _deadlineChannelDescription =
    'Alerts for work that is due today or that already passed its deadline.';

/// Channel used for the daily planning nudge.
const _dailyChannelId = 'kratos_daily_reminder';
const _dailyChannelName = 'Daily Deadline Check';

/// Stable id for the repeating daily reminder notification.
const kDailyReminderNotificationId = 900001;

class LocalNotificationsService {
  LocalNotificationsService._();
  static final LocalNotificationsService instance =
      LocalNotificationsService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _supported = true;
  String _permission = 'unknown';
  String? _timezoneName;

  String get permission => _permission;
  String? get timezoneName => _timezoneName;
  bool get isSupported => _supported;

  bool get _isDesktopOrMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  /// Initializes the plugin, channels, permission state and timezone database.
  Future<void> initialize() async {
    if (_initialized) return;
    if (!_isDesktopOrMobile) {
      _supported = false;
      _initialized = true;
      return;
    }

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      );

      await _plugin.initialize(
        settings: const InitializationSettings(
          android: androidSettings,
          iOS: darwinSettings,
          macOS: darwinSettings,
        ),
      );

      await _createAndroidChannels();
      await _configureTimezone();
      _permission = _readPermission() ?? 'unknown';
      _initialized = true;
    } catch (error) {
      debugPrint('LocalNotificationsService.initialize failed: $error');
      _supported = false;
      _initialized = true;
    }
  }

  Future<void> _createAndroidChannels() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _deadlineChannelId,
        _deadlineChannelName,
        description: _deadlineChannelDescription,
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _dailyChannelId,
        _dailyChannelName,
        description: 'A single daily nudge to review what is ending today.',
        importance: Importance.defaultImportance,
      ),
    );
  }

  Future<void> _configureTimezone() async {
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      _timezoneName = info.identifier;
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (error) {
      debugPrint('Timezone detection failed, falling back to UTC: $error');
      _timezoneName = 'UTC';
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  /// Requests notification permission from the OS. Returns `granted`, `denied`
  /// or `unsupported`.
  Future<String> requestPermission() async {
    await initialize();
    if (!_supported) return _permission = 'unsupported';

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        final granted = await android?.requestNotificationsPermission();
        _permission = granted == true ? 'granted' : 'denied';
      } else {
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        final granted = await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        _permission = granted == true ? 'granted' : 'denied';
      }
    } catch (error) {
      debugPrint('requestPermission failed: $error');
      _permission = 'denied';
    }
    return _permission;
  }

  String? _readPermission() {
    try {
      if (defaultTargetPlatform != TargetPlatform.android) return 'unknown';
      // Android < 13 always allows notifications; the plugin exposes the real
      // state through the request call, so treat unknown as not-yet-asked.
      return 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  /// Shows a notification immediately.
  Future<bool> show({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();
    if (!_supported) return false;

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _deadlineChannelId,
            _deadlineChannelName,
            channelDescription: _deadlineChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(''),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      return true;
    } catch (error) {
      debugPrint('show notification failed: $error');
      return false;
    }
  }

  /// Schedules a notification that repeats every day at [hour]:[minute].
  Future<bool> scheduleDailyReminder({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await initialize();
    if (!_supported) return false;

    try {
      final scheduled = nextInstanceOf(hour: hour, minute: minute);
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduled,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _dailyChannelId,
            _dailyChannelName,
            channelDescription:
                'A single daily nudge to review what is ending today.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: true,
          ),
        ),
      );
      return true;
    } catch (error) {
      debugPrint('scheduleDailyReminder failed: $error');
      return false;
    }
  }

  Future<void> cancel(int id) async {
    if (!_supported) return;
    try {
      await _plugin.cancel(id: id);
    } catch (error) {
      debugPrint('cancel notification failed: $error');
    }
  }

  /// Computes the next occurrence of [hour]:[minute] in the local timezone.
  ///
  /// Pure function so it can be unit-tested without any plugin channel.
  static tz.TZDateTime nextInstanceOf({
    required int hour,
    required int minute,
    DateTime? from,
  }) {
    final location = tz.local;
    final reference = from == null
        ? tz.TZDateTime.now(location)
        : tz.TZDateTime.from(from, location);
    var scheduled = tz.TZDateTime(
      location,
      reference.year,
      reference.month,
      reference.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(reference)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Stable positive id derived from a string key (for immediate alerts).
  static int notificationIdFor(String key) =>
      key.hashCode & 0x7fffffff;
}
