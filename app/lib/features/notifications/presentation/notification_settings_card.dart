// ignore_for_file: public_member_api_docs
//
// Settings card: real OS notification controls.
//   * enable/disable the repeating daily deadline check
//   * pick the reminder time
//   * request the OS permission and see the live permission state

import 'package:flutter/material.dart';

import '../../../data/drift/app_database.dart';
import '../data/local_notifications_service.dart';
import '../domain/deadline_notification_scheduler.dart';
import '../domain/notification_preferences.dart';

const _acidLime = Color(0xFFC6F135);

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF141714),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissionGranted = _permission == 'granted';
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F0D).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active_outlined,
                  color: _acidLime, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Phone notifications',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _acidLime,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            permissionGranted
                ? 'Due and overdue work is delivered to your phone notification centre.'
                : 'Grant permission so due and overdue work reaches your phone.',
            style: const TextStyle(color: Colors.white54, fontSize: 11.5),
          ),
          const SizedBox(height: 10),
          Material(
            type: MaterialType.transparency,
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _preferences.dailyReminderEnabled,
              activeThumbColor: _acidLime,
              onChanged: _busy ? null : _setEnabled,
              title: const Text(
                'Daily deadline check',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                'Repeats every day at ${_preferences.label}',
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickTime,
                icon: const Icon(Icons.schedule, size: 15),
                label: Text('Time • ${_preferences.label}'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy || permissionGranted
                      ? null
                      : _requestPermission,
                  icon: Icon(
                    permissionGranted
                        ? Icons.check_circle_outline
                        : Icons.notifications_none,
                    size: 15,
                  ),
                  label: Text(
                    permissionGranted ? 'Permission granted' : 'Allow alerts',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _acidLime,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
