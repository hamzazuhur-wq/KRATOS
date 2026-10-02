import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/kratos_motion.dart';
import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../domain/home_models.dart';

class XpSummaryCard extends StatelessWidget {
  final HomeAggregateProgression progression;

  const XpSummaryCard({super.key, required this.progression});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? const Color(0xFFC6F135) : KratosTheme.lightAcidLime;
    final labelColor = isDark ? Colors.white54 : KratosTheme.lightTextSecondary;
    final primaryTextColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final mutedTextColor = isDark ? Colors.white38 : KratosTheme.lightTextMuted;

    final formatter = NumberFormat('#,###');
    final formattedMin = formatter.format(progression.minRangeXp);
    final formattedMax = formatter.format(progression.maxRangeXp);

    return SizedBox(
      width: double.infinity,
      child: KratosGlassCard(
        variant: KratosSurfaceVariant.elevated,
        dashboardGlass: true,
        accentColor: lime,
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Label
              Row(
                children: [
                  Text(
                    'TOTAL XP',
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.trending_up, color: lime, size: 16),
                ],
              ),
              const SizedBox(height: 10),

              // Total and Percentage Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  KratosAnimatedMetric(
                    value: progression.totalXp,
                    formatter: (v) => '${formatter.format(v.round())} XP',
                    style: TextStyle(
                      color: primaryTextColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  KratosAnimatedMetric(
                    value: progression.progressPct,
                    formatter: (v) => '${v.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: lime,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress Bar with natural deceleration
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 7,
                  width: double.infinity,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0x14000000),
                  child: KratosProgressAnimation(
                    value: (progression.progressPct / 100.0).clamp(0.0, 1.0),
                    builder: (context, animatedFactor) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: animatedFactor,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? const [Color(0xFF8AE02B), Color(0xFFC6F135)]
                                : const [Color(0xFF6B9900), Color(0xFF8AE02B)],
                          ),
                          boxShadow: isDark
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFC6F135)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ]
                              : null,
                        ),
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
                    style: TextStyle(
                      color: mutedTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: isDark ? Colors.white12 : const Color(0x14000000),
                    ),
                  ),
                  Text(
                    formattedMax,
                    style: TextStyle(
                      color: mutedTextColor,
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
