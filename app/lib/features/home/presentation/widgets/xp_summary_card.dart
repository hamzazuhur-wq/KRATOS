import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/kratos_visuals.dart';
import '../../domain/home_models.dart';

class XpSummaryCard extends StatelessWidget {
  final HomeAggregateProgression progression;

  const XpSummaryCard({super.key, required this.progression});

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###');
    final formattedTotal = formatter.format(progression.totalXp);
    final formattedMin = formatter.format(progression.minRangeXp);
    final formattedMax = formatter.format(progression.maxRangeXp);
    final pctString = '${progression.progressPct.toStringAsFixed(0)}%';

    return SizedBox(
      width: double.infinity,
      child: KratosGlassCard(
        dashboardGlass: true,
        accentColor: const Color(0xFFC6F135),
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Label
              const Row(
                children: [
                  Text(
                    'TOTAL XP',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.trending_up, color: Color(0xFFC6F135), size: 16),
                ],
              ),
              const SizedBox(height: 10),

              // Total and Percentage Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '$formattedTotal XP',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    pctString,
                    style: const TextStyle(
                      color: Color(0xFFC6F135),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 7,
                  width: double.infinity,
                  color: Colors.white.withValues(alpha: 0.08),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (progression.progressPct / 100.0).clamp(
                      0.0,
                      1.0,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8AE02B), Color(0xFFC6F135)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFC6F135)
                                .withValues(alpha: 0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Range indicators: Min ───────────── Max
              Row(
                children: [
                  Text(
                    formattedMin,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: Colors.white12,
                    ),
                  ),
                  Text(
                    formattedMax,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
  }
}
