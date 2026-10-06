// ignore_for_file: public_member_api_docs
// Wave 30: DiagnosticsScreen — real-time performance and error viewer.
// Wave 12: Settings entry-point restyle only (Wave 17 owns the full Sync/System State).

import 'package:flutter/material.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../settings/presentation/settings_kit.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final TelemetryService _telemetry = TelemetryService();

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    final events = _telemetry.recentEvents;
    final avgDbLatency = _telemetry.getAverageLatencyMs('db_query');

    return SettingsPage(
      title: 'System Diagnostics',
      actions: [
        IconButton(
          icon: Icon(Icons.delete_sweep_rounded, color: t.secondary),
          tooltip: 'Clear Logs',
          onPressed: () {
            setState(() => _telemetry.clear());
          },
        ),
      ],
      children: [
        SettingsSection(
          title: 'Engine Performance',
          children: [
            SettingsInfoRow(
              label: 'Avg SQLite Query Latency',
              value: '${avgDbLatency.toStringAsFixed(1)} ms',
            ),
            SettingsInfoRow(
              label: 'Total Buffer Events',
              value: '${events.length} / 100',
            ),
          ],
        ),
        const SizedBox(height: 26),
        const SettingsSectionHeader(title: 'Telemetry Feed'),
        SettingsGroup(
          dividerIndent: 16,
          children: events.isEmpty
              ? const [
                  SettingsEmptyBlock(
                    icon: Icons.monitor_heart_outlined,
                    message: 'No recent telemetry events recorded.',
                  ),
                ]
              : [
                  for (final event in events)
                    _EventRow(
                      name: event.name,
                      level: event.level,
                    ),
                ],
        ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  final String name;
  final LogLevel level;
  const _EventRow({required this.name, required this.level});

  @override
  Widget build(BuildContext context) {
    final t = SettingsTokens.of(context);
    final tone = level == LogLevel.error
        ? SettingsTone.danger
        : level == LogLevel.warning
            ? SettingsTone.warning
            : SettingsTone.normal;
    final color = switch (tone) {
      SettingsTone.danger => t.danger,
      SettingsTone.warning => t.warning,
      _ => t.accentText,
    };
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
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SettingsStatusPill(label: level.name, tone: tone),
        ],
      ),
    );
  }
}
