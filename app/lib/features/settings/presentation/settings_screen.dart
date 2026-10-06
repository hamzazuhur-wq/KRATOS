// KRATOS Settings Architecture — Central System Configuration Hub.
// Premium Liquid Glass, Dark Volcanic, and Acid Lime design (Wave 12 visuals).
// Separates core product sections (Levels, Goals, Life Areas) from system configuration.

import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';
import '../../../app/kratos_theme_controller.dart';
import '../../../data/drift/app_database.dart';
import '../../backup/presentation/backup_screen.dart';
import '../../categories/presentation/xp_categories_screen.dart';
import '../../maintenance/presentation/diagnostics_screen.dart';
import '../../maintenance/presentation/privacy_policy_screen.dart';
import '../../maintenance/presentation/trash_and_storage_screen.dart';
import '../../notifications/presentation/notification_settings_card.dart';
import 'settings_kit.dart';

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
    final t = SettingsTokens.of(context);

    return SettingsPage(
      title: 'Settings',
      children: [
        // Intro
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SYSTEM CONFIGURATION',
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  color: t.accentText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage categories, progression rules, data backup, and sync preferences.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: t.secondary,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),

        // Appearance (Light / Dark Mode)
        const SettingsSectionHeader(title: 'Appearance'),
        const _ThemeSelectorGroup(),
        const SizedBox(height: 26),

        // XP configuration
        const SettingsSectionHeader(title: 'XP Engine'),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.bolt_outlined,
              title: 'XP Engine',
              subtitle: 'Configure Task, Activity, Sub-goal, and Skill XP rules.',
              onTap: () => Navigator.of(context).push(
                KratosMaterialPageRoute<void>(
                  builder: (_) => const XpCategoriesScreen(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),

        // Reminders & Notifications
        const SettingsSectionHeader(title: 'Reminders & Notifications'),
        NotificationSettingsCard(database: database, ownerId: ownerId),
        const SizedBox(height: 26),

        // Data, Backup & Storage
        const SettingsSectionHeader(title: 'Data & Storage'),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.backup_outlined,
              title: 'Database Backup & Restore',
              subtitle: 'Export and import full JSON snapshot manifests.',
              onTap: () => Navigator.of(context).push(
                KratosMaterialPageRoute<void>(
                  builder: (_) => BackupScreen(userId: ownerId, db: database),
                ),
              ),
            ),
            SettingsRow(
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
          ],
        ),
        const SizedBox(height: 26),

        // Diagnostics & Sync
        const SettingsSectionHeader(title: 'Diagnostics & Telemetry'),
        SettingsGroup(
          children: [
            SettingsRow(
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
          ],
        ),
        const SizedBox(height: 26),

        // Compliance & Legal
        const SettingsSectionHeader(title: 'Privacy & Legal'),
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy Policy & Data Security',
              subtitle:
                  'Local-first zero-telemetry policy and encrypted sync guarantees.',
              onTap: () => Navigator.of(context).push(
                KratosMaterialPageRoute<void>(
                  builder: (_) => const PrivacyPolicyScreen(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),

        // Account information
        const SettingsSectionHeader(title: 'System & Identity'),
        SettingsGroup(
          children: [
            SettingsInfoRow(label: 'Owner ID', value: ownerId),
            SettingsInfoRow(
              label: 'Database Schema',
              value: 'v${database.schemaVersion} (Drift SQLite)',
            ),
            const SettingsInfoRow(
              label: 'Architecture',
              value: 'Offline-first • HLC CRDT Outbox',
            ),
          ],
        ),
      ],
    );
  }
}

/// Appearance row: current value + the two-option mode selector.
class _ThemeSelectorGroup extends StatelessWidget {
  const _ThemeSelectorGroup();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: KratosThemeController.instance,
      builder: (context, _) {
        final controller = KratosThemeController.instance;
        final mode = controller.isDark ? ThemeMode.dark : ThemeMode.light;

        return SettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SettingsIconTile(
                        icon: controller.isDark
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Color mode',
                              style: TextStyle(
                                fontFamily: 'Space Grotesk',
                                color: SettingsTokens.of(context).text,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              controller.isDark ? 'Dark mode active' : 'Light mode active',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                color: SettingsTokens.of(context).secondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SettingsSegmented<ThemeMode>(
                    value: mode,
                    onChanged: controller.setThemeMode,
                    segments: const [
                      SettingsSegment(
                        value: ThemeMode.dark,
                        label: 'DARK MODE',
                        icon: Icons.dark_mode_outlined,
                      ),
                      SettingsSegment(
                        value: ThemeMode.light,
                        label: 'LIGHT MODE',
                        icon: Icons.light_mode_outlined,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
