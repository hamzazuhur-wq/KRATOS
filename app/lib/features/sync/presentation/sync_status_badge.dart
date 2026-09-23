// Wave 16: Sync Status Badge Widget — Liquid Glass aesthetic.
// Renders real-time outbox sync connection state and pending item count.

import 'package:flutter/material.dart';
import '../domain/sync_models.dart';

class SyncStatusBadge extends StatelessWidget {
  final SyncConnectionState state;
  final int pendingCount;
  final VoidCallback? onTap;

  const SyncStatusBadge({
    super.key,
    required this.state,
    this.pendingCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (color, label, icon) = switch (state) {
      SyncConnectionState.online => (
          const Color(0xFFC6F135),
          'SYNCED',
          Icons.cloud_done_outlined,
        ),
      SyncConnectionState.syncing => (
          const Color(0xFF00BCD4),
          'SYNCING',
          Icons.sync,
        ),
      SyncConnectionState.offline => (
          const Color(0xFFFF9500),
          'OFFLINE',
          Icons.cloud_off_outlined,
        ),
      SyncConnectionState.error => (
          const Color(0xFFFF3B30),
          'ERROR',
          Icons.error_outline,
        ),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              pendingCount > 0 ? '$label ($pendingCount)' : label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
