// KRATOS Settings Architecture — Central System Configuration Hub.
// Premium Liquid Glass, Dark Volcanic, and Acid Lime design.
// Separates core product sections (Levels, Goals, Life Areas) from system configuration.

import 'package:flutter/material.dart';

import '../../../app/kratos_motion.dart';
import '../../../app/kratos_theme_controller.dart';
import '../../../app/kratos_theme.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? KratosTheme.acidLime : const Color(0xFF4A6B00);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'SETTINGS',
          style: TextStyle(
            color: accentColor,
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
                      color: KratosTheme.acidLime.withValues(alpha: isDark ? 0.12 : 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: KratosTheme.acidLime.withValues(alpha: isDark ? 0.3 : 0.5),
                      ),
                    ),
                    child: Icon(
                      Icons.tune,
                      color: accentColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SYSTEM CONFIGURATION',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage categories, progression rules, data backup, and sync preferences.',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
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

          // Section 1: Appearance (Light / Dark Mode)
          const _SettingsSectionHeader(title: 'APPEARANCE'),
          const SizedBox(height: 8),
          const _ThemeSelectorCard(),
          const SizedBox(height: 16),

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

class _ThemeSelectorCard extends StatelessWidget {
  const _ThemeSelectorCard();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: KratosThemeController.instance,
      builder: (context, _) {
        final controller = KratosThemeController.instance;
        final isDark = controller.isDark;

        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.035)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: _ThemeModeOption(
                  label: 'DARK MODE',
                  icon: Icons.dark_mode_outlined,
                  selected: isDark,
                  onTap: () => controller.setThemeMode(ThemeMode.dark),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ThemeModeOption(
                  label: 'LIGHT MODE',
                  icon: Icons.light_mode_outlined,
                  selected: !isDark,
                  onTap: () => controller.setThemeMode(ThemeMode.light),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeModeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeModeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return KratosPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? (isDark
                  ? KratosTheme.acidLime.withValues(alpha: 0.14)
                  : KratosTheme.acidLime.withValues(alpha: 0.22))
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? KratosTheme.acidLime
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.08)),
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected
                  ? (isDark ? KratosTheme.acidLime : const Color(0xFF4A6B00))
                  : (isDark ? Colors.white54 : Colors.black54),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                letterSpacing: 0.8,
                color: selected
                    ? (isDark ? KratosTheme.acidLime : const Color(0xFF334A00))
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white38 : Colors.black45,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? const Color(0xFFC6F135) : const Color(0xFF4A6B00);

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.035)
            : Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
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
                    color: KratosTheme.acidLime.withValues(alpha: isDark ? 0.1 : 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white30 : Colors.black26,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? const Color(0xFFC6F135) : const Color(0xFF4A6B00);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black12,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                'SYSTEM & IDENTITY',
                style: TextStyle(
                  color: accentColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white38 : Colors.black45,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
