// KRATOS Settings Architecture — Central System Configuration Hub.
// Premium Liquid Glass, Dark Volcanic, and Acid Lime design.
// Separates core product sections (Levels, Goals, Life Areas) from system configuration.

import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';

import '../../../app/active_glass_card.dart';
import '../../../data/drift/app_database.dart';
import '../../backup/presentation/backup_screen.dart';
import '../../categories/presentation/xp_categories_screen.dart';
import '../../maintenance/presentation/diagnostics_screen.dart';
import '../../maintenance/presentation/privacy_policy_screen.dart';
import '../../maintenance/presentation/trash_and_storage_screen.dart';
import '../../notifications/presentation/notification_settings_card.dart';

class SettingsScreen extends StatelessWidget {
  final AppDatabase database;
  final String ownerId;

  const SettingsScreen({
    super.key,
    required this.database,
    required this.ownerId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020302),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            color: Color(0xFFC6F135),
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
            fontSize: 16,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          // Header Banner
          ActiveGlassCard(
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC6F135).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFC6F135).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.tune,
                      color: Color(0xFFC6F135),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SYSTEM CONFIGURATION',
                          style: TextStyle(
                            color: Color(0xFFC6F135),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage categories, progression rules, data backup, and sync preferences.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // XP configuration
          const _SettingsSectionHeader(title: 'XP ENGINE'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.bolt_outlined,
            title: 'XP Engine',
            subtitle: 'Configure Task, Activity, Sub-goal, and Skill XP rules.',
            onTap: () => Navigator.of(context).push(
              KratosMaterialPageRoute<void>(
                builder: (_) => const XpCategoriesScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section: Reminders & Notifications
          const _SettingsSectionHeader(title: 'REMINDERS & NOTIFICATIONS'),
          const SizedBox(height: 8),
          NotificationSettingsCard(database: database, ownerId: ownerId),
          const SizedBox(height: 16),

          // Section 3: Data, Backup & Storage
          const _SettingsSectionHeader(title: 'DATA & STORAGE'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.backup_outlined,
            title: 'Database Backup & Restore',
            subtitle: 'Export and import full JSON snapshot manifests.',
            onTap: () => Navigator.of(context).push(
              KratosMaterialPageRoute<void>(
                builder: (_) => BackupScreen(userId: ownerId, db: database),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.cleaning_services_outlined,
            title: 'Storage & Trash Recovery',
            subtitle:
                'Audit local database health and recover archived tombstones.',
            onTap: () => Navigator.of(context).push(
              KratosMaterialPageRoute<void>(
                builder: (_) =>
                    TrashAndStorageScreen(userId: ownerId, db: database),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 4: Diagnostics & Sync
          const _SettingsSectionHeader(title: 'DIAGNOSTICS & TELEMETRY'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.monitor_heart_outlined,
            title: 'System Diagnostics',
            subtitle:
                'Real-time database latency, sync outbox, and error telemetry.',
            onTap: () => Navigator.of(context).push(
              KratosMaterialPageRoute<void>(
                builder: (_) => const DiagnosticsScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Section 5: Compliance & Legal
          const _SettingsSectionHeader(title: 'PRIVACY & LEGAL'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy & Data Security',
            subtitle: 'Local-first zero-telemetry policy and encrypted sync guarantees.',
            onTap: () => Navigator.of(context).push(
              KratosMaterialPageRoute<void>(
                builder: (_) => const PrivacyPolicyScreen(),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Account Information Card
          _AccountInfoCard(ownerId: ownerId, database: database),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Supporting UI Components
// -----------------------------------------------------------------------------

class _SettingsSectionHeader extends StatelessWidget {
  final String title;

  const _SettingsSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC6F135).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: const Color(0xFFC6F135), size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.white30,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountInfoCard extends StatelessWidget {
  final String ownerId;
  final AppDatabase database;

  const _AccountInfoCard({required this.ownerId, required this.database});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 14, color: Color(0xFFC6F135)),
              SizedBox(width: 6),
              Text(
                'SYSTEM & IDENTITY',
                style: TextStyle(
                  color: Color(0xFFC6F135),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(label: 'Owner ID', value: ownerId),
          const SizedBox(height: 4),
          _InfoRow(
            label: 'Database Schema',
            value: 'v${database.schemaVersion} (Drift SQLite)',
          ),
          const SizedBox(height: 4),
          const _InfoRow(
            label: 'Architecture',
            value: 'Offline-first • HLC CRDT Outbox',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
