import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../app/kratos_theme.dart';
import '../../../../../app/kratos_visuals.dart';
import '../../../domain/analytics_models.dart';
import 'focus_time_formatters.dart';

/// "Focus by Day" card matching visual reference:
/// - "Focus by Day", subtitle: "Total focus time"
/// - 7 vertical bars (Mon through Sun) with rounded tops
/// - Exact duration label displayed above each bar (e.g. "2h 32m", "1h 45m")
/// - Weekday label at bottom
class FocusTimeByDayCard extends StatefulWidget {
  final FocusTimeSnapshot snapshot;

  const FocusTimeByDayCard({
    super.key,
    required this.snapshot,
  });

  @override
  State<FocusTimeByDayCard> createState() => _FocusTimeByDayCardState();
}

class _FocusTimeByDayCardState extends State<FocusTimeByDayCard> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : KratosTheme.lightTextSecondary;
    final mutedTextColor = isDark
        ? Colors.white.withValues(alpha: 0.40)
        : KratosTheme.lightTextMuted;
    final limeAccent = isDark ? KratosTheme.acidLime : KratosTheme.classicAcidLime;

    final totals = widget.snapshot.weekdayTotals;
    final maxVal = totals.fold<int>(0, (m, v) => math.max(m, v));
    final effectiveMax = maxVal > 0 ? maxVal : 1;

    return KratosGlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Title & Subtitle ──
          Text(
            'Focus by Day',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Total focus time',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: secondaryTextColor,
            ),
          ),

          const SizedBox(height: 24),

          // ── 7-Day Bar Chart Area ──
          SizedBox(
            height: 180,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final barWidth = ((width / 7) * 0.55).clamp(8.0, 36.0);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: _buildDayColumn(
                          index: i,
                          value: totals[i],
                          maxVal: effectiveMax,
                          barWidth: barWidth,
                          isMax: totals[i] == maxVal && maxVal > 0,
                          isHovered: _hoveredIndex == i,
                          limeAccent: limeAccent,
                          primaryTextColor: primaryTextColor,
                          mutedTextColor: mutedTextColor,
                          isDark: isDark,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayColumn({
    required int index,
    required int value,
    required int maxVal,
    required double barWidth,
    required bool isMax,
    required bool isHovered,
    required Color limeAccent,
    required Color primaryTextColor,
    required Color mutedTextColor,
    required bool isDark,
  }) {
    final ratio = (value / maxVal).clamp(0.06, 1.0);
    final barHeight = 110 * ratio;
    final durLabel = FocusTimeFormatters.formatDurationHhMm(value);
    final dayLabel = FocusTimeFormatters.weekdayShort(index);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Duration label above bar
          SizedBox(
            height: 22,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    durLabel,
                    style: TextStyle(
                      fontSize: isMax || isHovered ? 11.5 : 10.5,
                      fontWeight: isMax || isHovered ? FontWeight.w700 : FontWeight.w500,
                      color: isMax || isHovered ? primaryTextColor : mutedTextColor,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // The vertical bar
          Container(
            width: barWidth,
            height: barHeight,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  isMax || isHovered
                      ? limeAccent
                      : limeAccent.withValues(alpha: isDark ? 0.70 : 0.60),
                  isMax || isHovered
                      ? limeAccent.withValues(alpha: isDark ? 0.40 : 0.35)
                      : limeAccent.withValues(alpha: isDark ? 0.15 : 0.10),
                ],
              ),
              boxShadow: isMax || isHovered
                  ? [
                      BoxShadow(
                        color: limeAccent.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ]
                  : null,
            ),
          ),

          const SizedBox(height: 10),

          // Weekday label below bar
          Text(
            dayLabel,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isMax || isHovered ? FontWeight.w700 : FontWeight.w500,
              color: isMax || isHovered ? primaryTextColor : mutedTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
