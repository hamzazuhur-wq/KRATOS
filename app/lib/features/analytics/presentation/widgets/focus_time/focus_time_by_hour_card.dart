import 'package:flutter/material.dart';

import '../../../../../app/kratos_theme.dart';
import '../../../../../app/kratos_visuals.dart';
import '../../../domain/analytics_models.dart';
import 'focus_time_formatters.dart';

/// "Focus by Hour" 7x24 heatmap card matching visual reference:
/// - 7 rows (Mon through Sun)
/// - 24 columns (hours 0..23)
/// - Bottom axis indicators: 6am, 12pm, 6pm, 12am
/// - Glowing rounded rectangular intensity tiles
class FocusTimeByHourCard extends StatefulWidget {
  final FocusTimeSnapshot snapshot;

  const FocusTimeByHourCard({
    super.key,
    required this.snapshot,
  });

  @override
  State<FocusTimeByHourCard> createState() => _FocusTimeByHourCardState();
}

class _FocusTimeByHourCardState extends State<FocusTimeByHourCard> {
  int? _hoveredWeekday;
  int? _hoveredHour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryTextColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final mutedTextColor = isDark
        ? Colors.white.withValues(alpha: 0.40)
        : KratosTheme.lightTextMuted;
    final limeAccent = isDark ? KratosTheme.acidLime : KratosTheme.classicAcidLime;

    final matrix = widget.snapshot.weekdayHour; // 7 rows x 24 cols
    var maxVal = 0;
    for (final row in matrix) {
      for (final v in row) {
        if (v > maxVal) maxVal = v;
      }
    }
    final effectiveMax = maxVal > 0 ? maxVal : 1;

    return KratosGlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Title ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Focus by Hour',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: primaryTextColor,
                ),
              ),
              if (_hoveredWeekday != null && _hoveredHour != null)
                Text(
                  '${FocusTimeFormatters.weekdayShort(_hoveredWeekday!)} ${FocusTimeFormatters.formatHour12(_hoveredHour!)}: ${FocusTimeFormatters.formatDurationHhMm(matrix[_hoveredWeekday!][_hoveredHour!])}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: limeAccent,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // ── 7x24 Matrix Grid ──
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              // Space for weekday labels (approx 36px)
              const labelWidth = 34.0;
              final gridWidth = width - labelWidth;
              const cols = 24;
              const spacing = 2.5;
              final cellWidth = ((gridWidth - ((cols - 1) * spacing)) / cols).clamp(4.0, 18.0);
              const cellHeight = 13.0;

              return Column(
                children: [
                  for (var w = 0; w < 7; w++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          // Weekday label
                          SizedBox(
                            width: labelWidth,
                            child: Text(
                              FocusTimeFormatters.weekdayShort(w),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: mutedTextColor,
                              ),
                            ),
                          ),
                          // 24 Cells
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                for (var h = 0; h < 24; h++)
                                  _buildHeatmapCell(
                                    weekday: w,
                                    hour: h,
                                    value: matrix[w][h],
                                    maxVal: effectiveMax,
                                    cellWidth: cellWidth,
                                    cellHeight: cellHeight,
                                    isDark: isDark,
                                    limeAccent: limeAccent,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 10),

                  // ── Bottom Axis Labels (6am, 12pm, 6pm, 12am) ──
                  Padding(
                    padding: const EdgeInsets.only(left: labelWidth),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('6am', style: TextStyle(fontSize: 10.5, color: mutedTextColor)),
                        Text('12pm', style: TextStyle(fontSize: 10.5, color: mutedTextColor)),
                        Text('6pm', style: TextStyle(fontSize: 10.5, color: mutedTextColor)),
                        Text('12am', style: TextStyle(fontSize: 10.5, color: mutedTextColor)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapCell({
    required int weekday,
    required int hour,
    required int value,
    required int maxVal,
    required double cellWidth,
    required double cellHeight,
    required bool isDark,
    required Color limeAccent,
  }) {
    final isHovered = _hoveredWeekday == weekday && _hoveredHour == hour;
    final ratio = value > 0 ? (value / maxVal).clamp(0.20, 1.0) : 0.0;

    final Color cellColor;
    if (value == 0) {
      cellColor = isDark ? const Color(0x18FFFFFF) : const Color(0x0F0F172A);
    } else {
      cellColor = limeAccent.withValues(alpha: isDark ? (0.25 + 0.75 * ratio) : (0.35 + 0.65 * ratio));
    }

    return MouseRegion(
      onEnter: (_) => setState(() {
        _hoveredWeekday = weekday;
        _hoveredHour = hour;
      }),
      onExit: (_) => setState(() {
        _hoveredWeekday = null;
        _hoveredHour = null;
      }),
      child: Tooltip(
        message: '${FocusTimeFormatters.weekdayFull(weekday)} ${FocusTimeFormatters.formatHour12(hour)}: ${FocusTimeFormatters.formatDurationHhMm(value)}',
        waitDuration: const Duration(milliseconds: 300),
        child: Container(
          width: cellWidth,
          height: cellHeight,
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(3),
            border: isHovered
                ? Border.all(color: Colors.white, width: 1.0)
                : null,
            boxShadow: isHovered || ratio > 0.8
                ? [
                    BoxShadow(
                      color: limeAccent.withValues(alpha: isHovered ? 0.6 : 0.25),
                      blurRadius: isHovered ? 6 : 3,
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
