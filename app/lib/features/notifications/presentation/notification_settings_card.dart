// ignore_for_file: public_member_api_docs
//
// Settings card: real OS notification controls.
//   * enable/disable the repeating daily deadline check
//   * pick the reminder time
//   * request the OS permission and see the live permission state
//
// Wave 12: presentation-only restyle (Settings kit). Preferences, scheduler
// and permission logic are unchanged.

import 'package:flutter/material.dart';

import '../../../data/drift/app_database.dart';
import '../../settings/presentation/settings_kit.dart';
import '../data/local_notifications_service.dart';
import '../domain/deadline_notification_scheduler.dart';
import '../domain/notification_preferences.dart';

class NotificationSettingsCard extends StatefulWidget {
  final AppDatabase database;
  final String ownerId;

  const NotificationSettingsCard({
    super.key,
    required this.database,
    required this.ownerId,
  });

  @override
  State<NotificationSettingsCard> createState() =>
      _NotificationSettingsCardState();
}

class _NotificationSettingsCardState extends State<NotificationSettingsCard> {
  late final DeadlineNotificationScheduler _scheduler;
  NotificationPreferences _preferences = const NotificationPreferences();
  String _permission = 'unknown';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _scheduler = DeadlineNotificationScheduler(widget.database);
    _load();
  }

  Future<void> _load() async {
    final preferences = await NotificationPreferences.load();
    final service = LocalNotificationsService.instance;
    await service.initialize();
    if (!mounted) return;
    setState(() {
      _preferences = preferences;
      _permission = service.permission;
    });
  }

  Future<void> _setEnabled(bool enabled) async {
    final updated = _preferences.copyWith(dailyReminderEnabled: enabled);
    setState(() {
      _preferences = updated;
      _busy = true;
    });
    await _scheduler.updatePreferences(updated);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(enabled ? 'Daily reminder scheduled.' : 'Daily reminder disabled.');
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _preferences.hour,
        minute: _preferences.minute,
      ),
      helpText: 'DAILY DEADLINE CHECK',
    );
    if (picked == null) return;
    final updated = _preferences.copyWith(
      hour: picked.hour,
      minute: picked.minute,
    );
    setState(() {
      _preferences = updated;
      _busy = true;
    });
    await _scheduler.updatePreferences(updated);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack('Reminder time set to ${updated.label}.');
  }

  Future<void> _requestPermission() async {
    setState(() => _busy = true);
    final permission = await _scheduler.requestPermission();
    if (!mounted) return;
    setState(() {
      _permission = permission;
      _busy = false;
    });
    _snack(
      permission == 'granted'
          ? 'Notifications enabled on this device.'
          : 'Notifications were not granted. Enable them from system settings.',
    );
  }

  void _snack(String message) {
    // Colours come from the active theme's SnackBarTheme (Dark / Light).
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissionGranted = _permission == 'granted';
    return SettingsGroup(
      children: [
        SettingsRow(
          icon: Icons.notifications_active_outlined,
          title: 'Phone notifications',
          subtitle: permissionGranted
              ? 'Due and overdue work is delivered to your phone notification centre.'
              : 'Grant permission so due and overdue work reaches your phone.',
          trailing: SettingsStatusPill(
            label: permissionGranted ? 'Granted' : 'Off',
            tone: permissionGranted ? SettingsTone.success : SettingsTone.warning,
          ),
        ),
        SettingsToggleRow(
          icon: Icons.event_repeat_outlined,
          title: 'Daily deadline check',
          subtitle: 'Repeats every day at ${_preferences.label}',
          value: _preferences.dailyReminderEnabled,
          busy: _busy,
          onChanged: _busy ? null : _setEnabled,
        ),
        SettingsRow(
          icon: Icons.schedule,
          title: 'Reminder time',
          value: _preferences.label,
          enabled: !_busy,
          onTap: _busy ? null : _pickTime,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SettingsButton(
            label: permissionGranted ? 'Permission granted' : 'Allow alerts',
            icon: permissionGranted
                ? Icons.check_circle_outline
                : Icons.notifications_none,
            loading: false,
            onPressed: _busy || permissionGranted ? null : _requestPermission,
          ),
        ),
      ],
    );
  }
}
