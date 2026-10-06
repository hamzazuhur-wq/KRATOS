// ignore_for_file: public_member_api_docs
// Wave 26: TrashAndStorageScreen — maintenance and trash recovery.
// Wave 12: Settings entry-point restyle only (Settings kit). Wave 15 owns the
// full Archive / Trash / Restore experience.

import 'package:flutter/material.dart';
import '../domain/janitor_service.dart';
import '../../../data/drift/app_database.dart';
import '../../settings/presentation/settings_kit.dart';

class TrashAndStorageScreen extends StatefulWidget {
  final String userId;
  final AppDatabase db;

  const TrashAndStorageScreen({
    super.key,
    required this.userId,
    required this.db,
  });

  @override
  State<TrashAndStorageScreen> createState() => _TrashAndStorageScreenState();
}

class _TrashAndStorageScreenState extends State<TrashAndStorageScreen> {
  late final JanitorService _janitor;
  bool _loading = true;
  StorageAuditReport? _report;
  List<TrashItem> _trashItems = [];

  @override
  void initState() {
    super.initState();
    _janitor = JanitorService(db: widget.db);
    _loadData();
  }

  Future<void> _loadData() async {
    final report = await _janitor.auditStorageHealth(widget.userId);
    final trash = await _janitor.listTrashItems(widget.userId);
    if (mounted) {
      setState(() {
        _report = report;
        _trashItems = trash;
        _loading = false;
      });
    }
  }

  Future<void> _restoreItem(TrashItem item) async {
    final success = await _janitor.restoreEntity(
      entityKind: item.entityKind,
      entityId: item.id,
      versionHlc: DateTime.now().toUtc().toIso8601String(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Restored "${item.title}" successfully!' : 'Could not restore expired item.',
          ),
        ),
      );
      _loadData();
    }
  }

  Future<void> _runJanitorClean() async {
    final purged = await _janitor.purgeExpiredLocalTrash(widget.userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Janitor cleanup completed: $purged expired items purged.'),
        ),
      );
      _loadData();
    }
  }

  IconData _iconFor(TrashItem item) => item.entityKind == 'goal'
      ? Icons.flag_rounded
      : item.entityKind == 'task'
          ? Icons.check_box_rounded
          : Icons.notes_rounded;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SettingsPage(
        title: 'Storage & Trash Janitor',
        children: [SettingsLoadingBlock()],
      );
    }

    final t = SettingsTokens.of(context);
    final report = _report;

    return SettingsPage(
      title: 'Storage & Trash Janitor',
      children: [
        if (report != null) ...[
          SettingsSection(
            title: 'Storage health',
            children: [
              SettingsRow(
                icon: report.isClockHealthy
                    ? Icons.check_circle_rounded
                    : Icons.warning_rounded,
                tone: report.isClockHealthy
                    ? SettingsTone.success
                    : SettingsTone.warning,
                title: 'System & HLC Clock Health',
                subtitle:
                    'Clock Skew: ${report.clockSkewSeconds}s (${report.isClockHealthy ? "Normal drift within bounds" : "Exceeds tolerance"})',
                trailing: SettingsStatusPill(
                  label: report.isClockHealthy ? 'Healthy' : 'Skewed',
                  tone: report.isClockHealthy
                      ? SettingsTone.success
                      : SettingsTone.warning,
                ),
              ),
              SettingsInfoRow(
                label: 'Active Entities',
                mono: false,
                value:
                    '${report.totalLifeAreas} Life Areas, ${report.totalGoals} Goals, ${report.totalTasks} Tasks, ${report.totalNotes} Notes',
              ),
            ],
          ),
          const SizedBox(height: 26),
        ],
        SettingsSectionHeader(
          title: 'Trash Bin (${_trashItems.length})',
          trailing: SettingsButton(
            label: 'Clean Expired',
            icon: Icons.cleaning_services_rounded,
            compact: true,
            expand: false,
            variant: SettingsButtonVariant.destructive,
            onPressed: _runJanitorClean,
          ),
        ),
        SettingsGroup(
          children: _trashItems.isEmpty
              ? const [
                  SettingsEmptyBlock(
                    icon: Icons.delete_outline,
                    message: 'Trash is empty. No items pending deletion.',
                  ),
                ]
              : [
                  for (final item in _trashItems)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          SettingsIconTile(icon: _iconFor(item)),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: TextStyle(
                                    fontFamily: 'Space Grotesk',
                                    color: t.text,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${item.daysRemaining} days remaining until auto-purge',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    color: t.warning,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          SettingsButton(
                            label: 'Restore',
                            compact: true,
                            expand: false,
                            onPressed: () => _restoreItem(item),
                          ),
                        ],
                      ),
                    ),
                ],
        ),
      ],
    );
  }
}
