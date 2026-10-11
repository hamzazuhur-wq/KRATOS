import 'package:flutter/material.dart';

import '../../../../../app/kratos_theme.dart';
import '../../../../../app/kratos_visuals.dart';
import '../../../domain/analytics_models.dart';

/// Middle-Right 3-Column Key Metric Tiles (Section 16).
///
/// Columns:
/// 1. Current XP (with period delta)
/// 2. XP to Next Level (with % remaining)
/// 3. Total XP (with context subtitle)
class XpProgressMetrics extends StatelessWidget {
  final int currentXp;
  final MetricDelta periodDelta;
  final String periodComparisonLabel;
  final int remainingXp;
  final double progressPercent;
  final int totalHistoricalXp;
  final String lifeAreaName;
  final bool isAllLifeAreas;
  final bool isDark;
  final Color? accentColor;

  const XpProgressMetrics({
    super.key,
    required this.currentXp,
    required this.periodDelta,
    required this.periodComparisonLabel,
    required this.remainingXp,
    required this.progressPercent,
    required this.totalHistoricalXp,
    required this.lifeAreaName,
    required this.isAllLifeAreas,
    required this.isDark,
    this.accentColor,
  });

  String _formatNumber(int n) {
    final s = n.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      buffer.write(s[i]);
      final remaining = s.length - 1 - i;
      if (remaining > 0 && remaining % 3 == 0) buffer.write(',');
    }
    return '${n < 0 ? '-' : ''}$buffer';
  }

  @override
  Widget build(BuildContext context) {
    final lime = accentColor ?? (isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime);
    final primary = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondary = isDark ? const Color(0xFFA7A7A7) : KratosTheme.lightTextSecondary;
    final dividerColor = isDark ? const Color(0x1AFFFFFF) : const Color(0x1F0F172A);

    final isPositive = periodDelta.isPositive;
    final deltaStr =
        '${isPositive ? '+' : ''}${periodDelta.changePct.abs().toStringAsFixed(1)}%';

    final remainingPercent = (100.0 - progressPercent).clamp(0.0, 100.0).round();

    return KratosGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 420;

          if (isCompact) {
            // Stacked column on very narrow views
            return Column(
              children: [
                _buildTile(
                  icon: Icons.star_rounded,
                  title: isAllLifeAreas ? 'Period XP' : 'Current XP',
                  value: '${_formatNumber(currentXp)} XP',
                  footer: Row(
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 12,
                        color: isPositive ? lime : const Color(0xFFFF5252),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        deltaStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPositive ? lime : const Color(0xFFFF5252),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          periodComparisonLabel,
                          style: TextStyle(fontSize: 10.5, color: secondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  primary: primary,
                  secondary: secondary,
                  lime: lime,
                ),
                Divider(color: dividerColor, height: 18),
                _buildTile(
                  icon: Icons.bolt_rounded,
                  title: isAllLifeAreas ? 'Remaining Target' : 'XP to Next Level',
                  value: '${_formatNumber(remainingXp)} XP',
                  footer: Text(
                    '$remainingPercent% remaining',
                    style: TextStyle(fontSize: 11, color: secondary),
                  ),
                  primary: primary,
                  secondary: secondary,
                  lime: lime,
                ),
                Divider(color: dividerColor, height: 18),
                _buildTile(
                  icon: Icons.bar_chart_rounded,
                  title: 'Total XP',
                  value: '${_formatNumber(totalHistoricalXp)} XP',
                  footer: Text(
                    isAllLifeAreas ? 'Across all Life Areas' : 'in $lifeAreaName',
                    style: TextStyle(fontSize: 11, color: secondary),
                  ),
                  primary: primary,
                  secondary: secondary,
                  lime: lime,
                ),
              ],
            );
          }

          // 3-Column horizontal row
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Current XP
              Expanded(
                child: _buildTile(
                  icon: Icons.star_rounded,
                  title: isAllLifeAreas ? 'Period XP' : 'Current XP',
                  value: '${_formatNumber(currentXp)} XP',
                  footer: Row(
                    children: [
                      Icon(
                        isPositive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 12,
                        color: isPositive ? lime : const Color(0xFFFF5252),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        deltaStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPositive ? lime : const Color(0xFFFF5252),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          periodComparisonLabel,
                          style: TextStyle(fontSize: 10.5, color: secondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  primary: primary,
                  secondary: secondary,
                  lime: lime,
                ),
              ),

              // Vertical Divider 1
              Container(
                width: 1,
                height: 64,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: dividerColor,
              ),

              // Column 2: XP to Next Level
              Expanded(
                child: _buildTile(
                  icon: Icons.bolt_rounded,
                  title: isAllLifeAreas ? 'Remaining Target' : 'XP to Next Level',
                  value: '${_formatNumber(remainingXp)} XP',
                  footer: Text(
                    '$remainingPercent% remaining',
                    style: TextStyle(fontSize: 11, color: secondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  primary: primary,
                  secondary: secondary,
                  lime: lime,
                ),
              ),

              // Vertical Divider 2
              Container(
                width: 1,
                height: 64,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: dividerColor,
              ),

              // Column 3: Total XP
              Expanded(
                child: _buildTile(
                  icon: Icons.bar_chart_rounded,
                  title: 'Total XP',
                  value: '${_formatNumber(totalHistoricalXp)} XP',
                  footer: Text(
                    isAllLifeAreas ? 'Across all Life Areas' : 'in $lifeAreaName',
                    style: TextStyle(fontSize: 11, color: secondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  primary: primary,
                  secondary: secondary,
                  lime: lime,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String value,
    required Widget footer,
    required Color primary,
    required Color secondary,
    required Color lime,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isDark ? const Color(0x22FFFFFF) : const Color(0x140F172A),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 13, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: secondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: primary,
            letterSpacing: -0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        footer,
      ],
    );
  }
}
