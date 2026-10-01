// ignore_for_file: public_member_api_docs
// Wave 26: TrashAndStorageScreen — Liquid Glass maintenance and trash recovery.

import 'package:flutter/material.dart';
import '../domain/janitor_service.dart';
import '../../../data/drift/app_database.dart';

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
          backgroundColor: success ? const Color(0xFFC6F135) : Colors.redAccent,
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
          backgroundColor: const Color(0xFFC6F135),
        ),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Storage & Trash Janitor',
          style: TextStyle(
            color: Color(0xFFC6F135),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFC6F135)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC6F135)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Health Card
                  if (_report != null) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withAlpha(20)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _report!.isClockHealthy
                                    ? Icons.check_circle_rounded
                                    : Icons.warning_rounded,
                                color: _report!.isClockHealthy
                                    ? const Color(0xFFC6F135)
                                    : Colors.orange,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'System & HLC Clock Health',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Clock Skew: ${_report!.clockSkewSeconds}s (${_report!.isClockHealthy ? "Normal drift within bounds" : "Exceeds tolerance"})',
                            style: const TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Active Entities: ${_report!.totalLifeAreas} Life Areas, ${_report!.totalGoals} Goals, ${_report!.totalTasks} Tasks, ${_report!.totalNotes} Notes',
                            style: const TextStyle(color: Color(0x66FFFFFF), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Trash Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Trash Bin (${_trashItems.length})',
                        style: const TextStyle(
                          color: Color(0xFFC6F135),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _runJanitorClean,
                        icon: const Icon(Icons.cleaning_services_rounded, size: 16, color: Color(0xFFC6F135)),
                        label: const Text('Clean Expired', style: TextStyle(color: Color(0xFFC6F135), fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_trashItems.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Trash is empty. No items pending deletion.',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    )
                  else
                    ..._trashItems.map((item) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withAlpha(12)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.entityKind == 'goal'
                                    ? Icons.flag_rounded
                                    : item.entityKind == 'task'
                                        ? Icons.check_box_rounded
                                        : Icons.notes_rounded,
                                color: Colors.white54,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '${item.daysRemaining} days remaining until auto-purge',
                                      style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC6F135),
                                  foregroundColor: const Color(0xFF0D0D0D),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                ),
                                onPressed: () => _restoreItem(item),
                                child: const Text('Restore', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
