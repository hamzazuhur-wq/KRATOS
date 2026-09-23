// ignore_for_file: public_member_api_docs
// Wave 30: DiagnosticsScreen — Liquid Glass real-time performance and error viewer.

import 'package:flutter/material.dart';
import '../../../core/telemetry/telemetry_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final TelemetryService _telemetry = TelemetryService();

  @override
  Widget build(BuildContext context) {
    final events = _telemetry.recentEvents;
    final avgDbLatency = _telemetry.getAverageLatencyMs('db_query');

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'System Diagnostics',
          style: TextStyle(
            color: Color(0xFFC6F135),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFC6F135)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white54),
            tooltip: 'Clear Logs',
            onPressed: () {
              setState(() => _telemetry.clear());
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Performance Metrics Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.speed_rounded, color: Color(0xFFC6F135), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Engine Performance',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Avg SQLite Query Latency', style: TextStyle(color: Colors.white60, fontSize: 13)),
                      Text(
                        '${avgDbLatency.toStringAsFixed(1)} ms',
                        style: const TextStyle(color: Color(0xFFC6F135), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Buffer Events', style: TextStyle(color: Colors.white60, fontSize: 13)),
                      Text(
                        '${events.length} / 100',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Live Event Stream
            const Text(
              'Telemetry Feed',
              style: TextStyle(
                color: Color(0xFFC6F135),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),

            if (events.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('No recent telemetry events recorded.', style: TextStyle(color: Colors.white38, fontSize: 13)),
              )
            else
              ...events.map((event) {
                final color = event.level == LogLevel.error
                    ? Colors.redAccent
                    : event.level == LogLevel.warning
                        ? Colors.orangeAccent
                        : const Color(0xFFC6F135);

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          event.name,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        event.level.name.toUpperCase(),
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
