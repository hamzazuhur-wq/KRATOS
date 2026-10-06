// ignore_for_file: public_member_api_docs
//
// KRATOS Wave 12 — Settings Storybook / Widget Previews Showcase.
// Renders every representative Settings component, control, and state
// across both Dark Mode (master design) and Light Mode (architectural ceramic):
//   1. Settings Section Header & Group Surface
//   2. Settings Interactive Rows (Standard, Subtitle, Value, Disabled)
//   3. Toggle Switch Control & Saving Busy State
//   4. Segmented Control (Appearance Mode Switch)
//   5. Dropdown Selector (Difficulty & Duration Anchors)
//   6. Active / Selected State Card (XP Rule Preview)
//   7. Account & System Information (Monospace Readout)
//   8. Notification Settings Preferences Component
//   9. Destructive Action & Confirmation Dialog Surface
//  10. System Diagnostics & Telemetry Feed
//  11. Empty State, Loading State, and Error Banner

import 'package:flutter/material.dart';

import '../../app/kratos_dropdown.dart';
import '../../app/kratos_theme.dart';
import '../../app/kratos_theme_controller.dart';
import '../../core/telemetry/telemetry_service.dart';
import '../settings/presentation/settings_kit.dart';

class Wave12SettingsStorybookScreen extends StatefulWidget {
  const Wave12SettingsStorybookScreen({super.key});

  @override
  State<Wave12SettingsStorybookScreen> createState() =>
      _Wave12SettingsStorybookScreenState();
}

class _Wave12SettingsStorybookScreenState
    extends State<Wave12SettingsStorybookScreen> {
  bool _sampleToggle = true;
  final bool _sampleBusyToggle = false;
  int _sampleDifficulty = 7;
  int _sampleDurationMinutes = 60;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor =
        isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final limeColor =
        isDark ? const Color(0xFFEEFF08) : KratosTheme.lightAcidLime;
    final t = SettingsTokens.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: limeColor.withValues(alpha: isDark ? 0.12 : 0.10),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: limeColor.withValues(alpha: isDark ? 0.35 : 0.40),
                ),
              ),
              child: Text(
                'WAVE 12',
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  color: limeColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'SETTINGS SHOWCASE · DUAL MODE',
              style: TextStyle(
                fontFamily: 'IBM Plex Mono',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: limeColor,
              size: 20,
            ),
            onPressed: () {
              final newMode = isDark ? ThemeMode.light : ThemeMode.dark;
              KratosThemeController.instance.setThemeMode(newMode);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 780),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
            children: [
              // 1. Overview Header
              _buildSectionBanner(
                number: '01',
                title: 'SETTINGS SECTION & GROUP SURFACE',
                description:
                    'Unified scannable hierarchy with IBM Plex Mono eyebrow, Space Grotesk labels, and subtle hairlines.',
              ),
              SettingsGroup(
                children: [
                  SettingsRow(
                    icon: Icons.tune,
                    title: 'System Preferences',
                    subtitle: 'Core operational parameters and display settings.',
                    value: 'CONFIGURED',
                    onTap: () {},
                  ),
                  SettingsRow(
                    icon: Icons.shield_outlined,
                    title: 'Security & Access Guarantees',
                    subtitle: 'Local-first zero-telemetry policy active.',
                    value: 'ENFORCED',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 2. Interactive Rows & State Variants
              _buildSectionBanner(
                number: '02',
                title: 'ROW INTERACTION & STATE VARIANTS',
                description:
                    'Normal, subtitle, value badge, disabled state, and chevron indicators.',
              ),
              SettingsGroup(
                children: [
                  SettingsRow(
                    icon: Icons.bolt_outlined,
                    title: 'Normal Interactive Row',
                    subtitle: 'Clickable with hover highlight and press physics.',
                    onTap: () {},
                  ),
                  SettingsRow(
                    icon: Icons.lock_clock_outlined,
                    title: 'Disabled Setting Row',
                    subtitle: 'Dimmed styling and blocked interaction when unavailable.',
                    enabled: false,
                    value: 'LOCKED',
                    onTap: null,
                  ),
                  SettingsRow(
                    icon: Icons.check_circle_outline,
                    tone: SettingsTone.success,
                    title: 'Active State Row',
                    subtitle: 'Emphasized with semantic KRATOS lime accent.',
                    value: 'VERIFIED',
                    onTap: () {},
                  ),
                  SettingsRow(
                    icon: Icons.warning_amber_rounded,
                    tone: SettingsTone.warning,
                    title: 'Attention Required Row',
                    subtitle: 'Restrained amber indicator for warnings.',
                    value: 'PENDING',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 3. Toggle & Segmented Controls
              _buildSectionBanner(
                number: '03',
                title: 'CONTROLS: TOGGLES, BUSY & SEGMENTED',
                description:
                    'Dual theme switch, reactive switches, and loading spinner in row.',
              ),
              SettingsGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            SettingsIconTile(
                              icon: isDark
                                  ? Icons.dark_mode_outlined
                                  : Icons.light_mode_outlined,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Appearance Mode',
                                    style: TextStyle(
                                      fontFamily: 'Space Grotesk',
                                      color: t.text,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isDark ? 'Dark Volcanic (Master)' : 'Architectural Ceramic',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: t.secondary,
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
                          value: isDark ? ThemeMode.dark : ThemeMode.light,
                          onChanged: (mode) {
                            KratosThemeController.instance.setThemeMode(mode);
                          },
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
                  SettingsToggleRow(
                    icon: Icons.notifications_active_outlined,
                    title: 'Active Switch Control',
                    subtitle: 'Reactive toggle using KRATOS lime for active state.',
                    value: _sampleToggle,
                    onChanged: (val) => setState(() => _sampleToggle = val),
                  ),
                  SettingsToggleRow(
                    icon: Icons.sync,
                    title: 'Saving / In-flight Switch',
                    subtitle: 'Indicates background persistence or validation.',
                    value: _sampleBusyToggle,
                    busy: true,
                    onChanged: null,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 4. Selectors & Dropdowns (XP Rules)
              _buildSectionBanner(
                number: '04',
                title: 'SELECTORS & DROPDOWNS (XP RULE PREVIEW)',
                description:
                    'Origin-aware menu dropdowns for difficulty and session duration anchors.',
              ),
              SettingsGroup(
                padding: const EdgeInsets.all(18),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'TASK & ACTIVITY XP RULE',
                          style: TextStyle(
                            fontFamily: 'Space Grotesk',
                            color: t.accentText,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SettingsStatusPill(label: 'MAX 200 XP'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'DIFFICULTY',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: t.secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: KratosDropdown<int>(
                          value: _sampleDifficulty,
                          hint: 'Select difficulty',
                          isExpanded: true,
                          items: [
                            for (var i = 1; i <= 10; i++)
                              KratosDropdownItem(value: i, label: '$i / 10'),
                          ],
                          onChanged: (v) {
                            if (v != null) setState(() => _sampleDifficulty = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${(_sampleDifficulty * 20)} XP',
                        style: TextStyle(
                          fontFamily: 'Space Grotesk',
                          color: t.accentText,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'DURATION',
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          color: t.secondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: KratosDropdown<int>(
                          value: _sampleDurationMinutes,
                          hint: 'Duration',
                          isExpanded: true,
                          items: const [
                            KratosDropdownItem(value: 15, label: '15 min'),
                            KratosDropdownItem(value: 30, label: '30 min'),
                            KratosDropdownItem(value: 60, label: '60 min'),
                            KratosDropdownItem(value: 120, label: '120 min'),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _sampleDurationMinutes = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 5. Account & Monospace Information
              _buildSectionBanner(
                number: '05',
                title: 'ACCOUNT & IDENTITY READOUT',
                description:
                    'Drift SQLite schema version, offline-first HLC outbox identity.',
              ),
              SettingsGroup(
                children: const [
                  SettingsInfoRow(
                    label: 'Owner Identity',
                    value: 'usr-kratos-master-789',
                  ),
                  SettingsInfoRow(
                    label: 'SQLite Database',
                    value: 'v3 (Drift SQLite • WASM)',
                  ),
                  SettingsInfoRow(
                    label: 'Sync Architecture',
                    value: 'Offline-first • HLC CRDT Outbox',
                  ),
                  SettingsInfoRow(
                    label: 'Active Environment',
                    value: 'Production Local Cluster',
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 6. Destructive Action & Dialog Surface
              _buildSectionBanner(
                number: '06',
                title: 'DESTRUCTIVE ACTIONS & CONFIRMATION SURFACES',
                description:
                    'Restrained danger semantic tones without neon glow or dramatic bloom.',
              ),
              SettingsGroup(
                children: [
                  SettingsRow(
                    icon: Icons.delete_outline,
                    tone: SettingsTone.danger,
                    title: 'Purge Expired Trash Items',
                    subtitle: 'Permanently removes tombstones older than 30 days.',
                    value: '3 PENDING',
                    onTap: () => _showSampleDeleteDialog(context),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SettingsButtonRow(
                      children: [
                        SettingsButton(
                          label: 'Trigger Confirmation Modal',
                          icon: Icons.warning_amber_rounded,
                          variant: SettingsButtonVariant.destructive,
                          onPressed: () => _showSampleDeleteDialog(context),
                        ),
                        SettingsButton(
                          label: 'Secondary Action',
                          icon: Icons.refresh,
                          variant: SettingsButtonVariant.secondary,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 7. Diagnostics Feed & Telemetry States
              _buildSectionBanner(
                number: '07',
                title: 'DIAGNOSTICS & SYNC TELEMETRY FEED',
                description:
                    'Real-time buffer events, log level badges, and engine metrics.',
              ),
              SettingsGroup(
                dividerIndent: 16,
                children: const [
                  SettingsInfoRow(
                    label: 'Average Query Latency',
                    value: '1.4 ms',
                  ),
                  SettingsInfoRow(
                    label: 'Outbox Drain Queue',
                    value: '0 pending ops',
                  ),
                  _SampleEventRow(
                    name: 'hlc_clock_sync_verified',
                    level: LogLevel.info,
                  ),
                  _SampleEventRow(
                    name: 'sqlite_vacuum_clean_completed',
                    level: LogLevel.info,
                  ),
                  _SampleEventRow(
                    name: 'realtime_channel_idle_ping',
                    level: LogLevel.warning,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // 8. Empty, Loading, and Feedback States
              _buildSectionBanner(
                number: '08',
                title: 'EMPTY, LOADING & ERROR FEEDBACK',
                description:
                    'Zero-item fallback, spinner indicator, and structured feedback banners.',
              ),
              const SettingsBanner(
                tone: SettingsTone.success,
                message: 'All settings and category rule versions are in sync with storage.',
              ),
              const SizedBox(height: 12),
              const SettingsBanner(
                tone: SettingsTone.warning,
                message: 'XP ledger records are immutable and cannot be edited retrospectively.',
              ),
              const SizedBox(height: 12),
              const SettingsBanner(
                tone: SettingsTone.danger,
                message: 'Failed to communicate with sync endpoint: Connection timeout (5000ms).',
              ),
              const SizedBox(height: 16),
              const SettingsGroup(
                children: [
                  SettingsEmptyBlock(
                    icon: Icons.category_outlined,
                    message: 'No custom categories created yet. Default system categories active.',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const SettingsGroup(
                children: [
                  SettingsLoadingBlock(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSampleDeleteDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => SettingsDialog(
        eyebrow: 'DESTRUCTIVE ACTION',
        title: 'Permanently Purge Trash?',
        actions: [
          SettingsButton(
            label: 'Cancel',
            expand: false,
            compact: true,
            variant: SettingsButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          SettingsButton(
            label: 'Confirm Purge',
            icon: Icons.delete_forever,
            expand: false,
            compact: true,
            variant: SettingsButtonVariant.destructive,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
        child: Text(
          'This will permanently delete all tombstoned entities older than 30 days from your device SQLite database. This operation cannot be undone.',
          style: TextStyle(
            fontFamily: 'Inter',
            color: SettingsTokens.of(ctx).secondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionBanner({
    required String number,
    required String title,
    required String description,
  }) {
    final t = SettingsTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                number,
                style: TextStyle(
                  fontFamily: 'IBM Plex Mono',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: t.accentText,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 3,
                height: 11,
                decoration: BoxDecoration(
                  color: t.accentText,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'IBM Plex Mono',
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                    color: t.muted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontFamily: 'Inter',
              color: t.secondary,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _SampleEventRow extends StatelessWidget {
  final String name;
  final LogLevel level;
  const _SampleEventRow({required this.name, required this.level});

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    final color = level == LogLevel.warning ? t.warning : t.accentText;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontFamily: 'IBM Plex Mono',
                color: t.text,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SettingsStatusPill(
            label: level.name,
            tone: level == LogLevel.warning
                ? SettingsTone.warning
                : SettingsTone.normal,
          ),
        ],
      ),
    );
  }
}
