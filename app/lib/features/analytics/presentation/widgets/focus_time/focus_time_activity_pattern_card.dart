import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../app/kratos_theme.dart';
import '../../../../../app/kratos_visuals.dart';
import '../../../domain/analytics_models.dart';
import 'focus_time_formatters.dart';

enum ActivityPatternGranularity {
  daily('Daily'),
  weekly('Weekly'),
  monthly('Monthly');

  final String label;
  const ActivityPatternGranularity(this.label);
}

/// Activity Pattern Card matching the visual reference:
/// - "Activity Pattern" title
/// - Granularity segmented control: Daily | Weekly | Monthly
/// - Vertical bar chart with gradient fill and rounded tops
/// - Time-axis markers (12 AM, 6 AM, 12 PM, 6 PM, 12 AM)
/// - Interactive tooltip popover displaying duration and timestamp
class FocusTimeActivityPatternCard extends StatefulWidget {
  final FocusTimeSnapshot snapshot;

  const FocusTimeActivityPatternCard({
    super.key,
    required this.snapshot,
  });

  @override
  State<FocusTimeActivityPatternCard> createState() =>
      _FocusTimeActivityPatternCardState();
}

class _FocusTimeActivityPatternCardState
    extends State<FocusTimeActivityPatternCard> {
  ActivityPatternGranularity _granularity = ActivityPatternGranularity.daily;
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
        ? Colors.white.withValues(alpha: 0.35)
        : KratosTheme.lightTextMuted;
    final limeAccent = isDark ? KratosTheme.acidLime : KratosTheme.classicAcidLime;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        return KratosGlassCard(
          padding: EdgeInsets.all(isMobile ? 18 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header: Title + Granularity Segments ──
              if (isMobile) ...[
                Text(
                  'Activity Pattern',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSegmentedControl(isDark, limeAccent, primaryTextColor),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Activity Pattern',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: primaryTextColor,
                      ),
                    ),
                    _buildSegmentedControl(isDark, limeAccent, primaryTextColor),
                  ],
                ),
              ],

              const SizedBox(height: 28),

              // ── Chart Area ──
              SizedBox(
                height: 190,
                child: _buildChart(
                  isDark: isDark,
                  limeAccent: limeAccent,
                  primaryTextColor: primaryTextColor,
                  secondaryTextColor: secondaryTextColor,
                  mutedTextColor: mutedTextColor,
                ),
              ),

              const SizedBox(height: 10),

              // ── Horizontal Axis Labels ──
              _buildAxisLabels(mutedTextColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSegmentedControl(
    bool isDark,
    Color limeAccent,
    Color primaryTextColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0x1AFFFFFF) : const Color(0x0F0F172A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0x26FFFFFF) : const Color(0x1A0F172A),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final g in ActivityPatternGranularity.values)
            InkWell(
              onTap: () => setState(() => _granularity = g),
              borderRadius: BorderRadius.circular(7),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _granularity == g
                      ? (isDark ? limeAccent : const Color(0xFFD4F842))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  g.label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: _granularity == g ? FontWeight.w700 : FontWeight.w500,
                    color: _granularity == g
                        ? const Color(0xFF0F1115)
                        : (isDark ? Colors.white70 : KratosTheme.lightTextSecondary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChart({
    required bool isDark,
    required Color limeAccent,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color mutedTextColor,
  }) {
    final List<int> values;
    final List<String> labels;

    switch (_granularity) {
      case ActivityPatternGranularity.daily:
        values = widget.snapshot.hourly;
        labels = List.generate(24, (h) => FocusTimeFormatters.formatHour12(h));
        break;
      case ActivityPatternGranularity.weekly:
        values = widget.snapshot.weekdayTotals;
        labels = List.generate(7, (w) => FocusTimeFormatters.weekdayShort(w));
        break;
      case ActivityPatternGranularity.monthly:
        values = widget.snapshot.daily.map((d) => d.ms).toList();
        labels = widget.snapshot.daily.map((d) => '${d.day.day}').toList();
        break;
    }

    final maxVal = values.fold<int>(0, (m, v) => math.max(m, v));
    final effectiveMax = maxVal > 0 ? maxVal : 1;

    // Pick a default highlighted bar if none hovered (e.g. peak hour around 12 PM in daily view)
    final activeHighlightIndex = _hoveredIndex ??
        (_granularity == ActivityPatternGranularity.daily
            ? (widget.snapshot.peakWindowStartHour ?? 12)
            : (_granularity == ActivityPatternGranularity.weekly
                ? (widget.snapshot.mostFocusedWeekday ?? 1)
                : (values.isNotEmpty ? values.indexOf(maxVal) : 0)));

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = values.length;
        if (count == 0) return const SizedBox.shrink();

        final barSpacing = count > 15 ? 4.0 : 8.0;
        final totalSpacing = (count - 1) * barSpacing;
        final barWidth = ((width - totalSpacing) / count).clamp(4.0, 36.0);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Horizontal grid lines
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildGridLine(isDark),
                _buildGridLine(isDark),
                _buildGridLine(isDark),
                _buildGridLine(isDark),
              ],
            ),

            // Bars Row
            Positioned.fill(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < count; i++)
                    _buildBarItem(
                      index: i,
                      value: values[i],
                      maxVal: effectiveMax,
                      barWidth: barWidth,
                      isHighlighted: i == activeHighlightIndex,
                      isDark: isDark,
                      limeAccent: limeAccent,
                    ),
                ],
              ),
            ),

            // Tooltip popup above the highlighted bar
            if (activeHighlightIndex >= 0 && activeHighlightIndex < count)
              _buildTooltipPopover(
                index: activeHighlightIndex,
                value: values[activeHighlightIndex],
                label: labels[activeHighlightIndex],
                count: count,
                width: width,
                maxVal: effectiveMax,
                isDark: isDark,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
              ),
          ],
        );
      },
    );
  }

  Widget _buildGridLine(bool isDark) {
    return Container(
      height: 1,
      color: isDark ? const Color(0x14FFFFFF) : const Color(0x0F0F172A),
    );
  }

  Widget _buildBarItem({
    required int index,
    required int value,
    required int maxVal,
    required double barWidth,
    required bool isHighlighted,
    required bool isDark,
    required Color limeAccent,
  }) {
    final ratio = (value / maxVal).clamp(0.04, 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _hoveredIndex = index),
        child: Container(
          width: barWidth,
          height: 150 * ratio,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                isHighlighted
                    ? limeAccent
                    : limeAccent.withValues(alpha: isDark ? 0.65 : 0.55),
                isHighlighted
                    ? limeAccent.withValues(alpha: isDark ? 0.35 : 0.30)
                    : limeAccent.withValues(alpha: isDark ? 0.12 : 0.10),
              ],
            ),
            boxShadow: isHighlighted
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
      ),
    );
  }

  Widget _buildTooltipPopover({
    required int index,
    required int value,
    required String label,
    required int count,
    required double width,
    required int maxVal,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final ratio = (value / maxVal).clamp(0.04, 1.0);
    final barHeight = 150 * ratio;
    final barCenterX = (index + 0.5) * (width / count);

    // Keep tooltip inside horizontal bounds
    final tooltipWidth = 85.0;
    final leftPos = (barCenterX - tooltipWidth / 2).clamp(0.0, width - tooltipWidth);

    final durText = FocusTimeFormatters.formatDurationHhMm(value);
    final subText = _granularity == ActivityPatternGranularity.daily
        ? label
        : (_granularity == ActivityPatternGranularity.weekly
            ? FocusTimeFormatters.weekdayShort(index)
            : 'Day $label');

    return Positioned(
      left: leftPos,
      bottom: barHeight + 14,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2228) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0x40FFFFFF) : const Color(0x300F172A),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  durText,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
                Text(
                  subText,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          // Tooltip down arrow / pin
          CustomPaint(
            size: const Size(10, 5),
            painter: _TooltipArrowPainter(
              color: isDark ? const Color(0xFF1E2228) : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAxisLabels(Color mutedTextColor) {
    if (_granularity == ActivityPatternGranularity.daily) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text('12 AM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          Text('6 AM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          Text('12 PM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          Text('6 PM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
          Text('12 AM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
        ].map((w) => DefaultTextStyle(
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: mutedTextColor),
          child: w,
        )).toList(),
      );
    } else if (_granularity == ActivityPatternGranularity.weekly) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 7; i++)
            Text(
              FocusTimeFormatters.weekdayShort(i),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: mutedTextColor,
              ),
            ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Day 1', style: TextStyle(fontSize: 11, color: mutedTextColor)),
          Text('Day 15', style: TextStyle(fontSize: 11, color: mutedTextColor)),
          Text('Day 30', style: TextStyle(fontSize: 11, color: mutedTextColor)),
        ],
      );
    }
  }
}

class _TooltipArrowPainter extends CustomPainter {
  final Color color;
  const _TooltipArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TooltipArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}
