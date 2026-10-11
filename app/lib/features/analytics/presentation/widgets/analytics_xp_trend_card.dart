import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/kratos_skeleton.dart';
import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../domain/analytics_models.dart';

/// KRATOS Analytics — Wave 04: XP Trend Time-Series Card.
///
/// Implements the isolated XP Trend section directly below the Wave 03 KPI row.
/// Features:
/// - Wide premium Liquid Glass container (Dark Volcanic / Light Architectural Frost).
/// - Left Summary Panel:
///   * Big current-period XP metric with unit.
///   * Trend delta pill vs previous period (Acid Lime for positive, Coral for negative).
///   * Compact comparison breakdown table: Current XP, Previous XP, Net Change, Daily Avg.
/// - Right Time-Series Chart Panel:
///   * Dual-series line chart with CustomPainter:
///     - Primary (Current Period): Acid Lime (#EEFF08 / #658F00) with vertical area gradient.
///     - Secondary (Previous Period): Neutral slate subdued line (#94A3B8 / white38) for relative comparison.
///   * Zero-baseline rendering with dynamic Y-axis supporting negative XP values.
///   * Responsive date intervals along X-axis with zero label collisions.
///   * Desktop hover + Touch tap interactive tracking with crosshair guide and floating glass tooltip.
///   * Dual-period legend with exact date-range context.
///   * Skeleton loading state and empty state support.
class AnalyticsXpTrendCard extends StatefulWidget {
  final AnalyticsSnapshot snapshot;
  final String periodSubtitle;
  final bool isLoading;
  final VoidCallback? onRetry;
  final ValueChanged<int>? onPointSelected;

  const AnalyticsXpTrendCard({
    super.key,
    required this.snapshot,
    this.periodSubtitle = 'vs previous period',
    this.isLoading = false,
    this.onRetry,
    this.onPointSelected,
  });

  @override
  State<AnalyticsXpTrendCard> createState() => _AnalyticsXpTrendCardState();
}

class _AnalyticsXpTrendCardState extends State<AnalyticsXpTrendCard> {
  int? _hoveredIndex;
  Offset? _hoverLocalPosition;

  void _onHover(int? index, Offset? pos) {
    if (_hoveredIndex != index || _hoverLocalPosition != pos) {
      setState(() {
        _hoveredIndex = index;
        _hoverLocalPosition = pos;
      });
      if (index != null) {
        widget.onPointSelected?.call(index);
      }
    }
  }

  void _onExit() {
    if (_hoveredIndex != null || _hoverLocalPosition != null) {
      setState(() {
        _hoveredIndex = null;
        _hoverLocalPosition = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark
        ? const Color(0xE6141814)
        : const Color(0xF5FFFFFF);

    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0x1F0F172A);

    final primaryTextColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondaryTextColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : KratosTheme.lightTextSecondary;
    final limeAccent = isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime;

    if (widget.isLoading) {
      return _buildSkeleton(context, cardBg, borderColor);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth;
        final isCompact = cardWidth < 840;
        final isMobile = cardWidth < 580;

        return KratosGlassCard(
          borderRadius: BorderRadius.circular(18),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 22,
            vertical: isMobile ? 16 : 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header Row ────────────────────────────────────────────────
              _buildHeader(
                context,
                isDark: isDark,
                primaryColor: primaryTextColor,
                secondaryColor: secondaryTextColor,
                limeAccent: limeAccent,
                isMobile: isMobile,
              ),

              SizedBox(height: isMobile ? 16 : 20),

              // ── Main Content: Left Summary + Right Time-Series Chart ──────
              if (widget.snapshot.xpOverTime.isEmpty)
                _buildEmptyState(context, secondaryTextColor)
              else if (isCompact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _XpTrendSummaryPanel(
                      snapshot: widget.snapshot,
                      periodSubtitle: widget.periodSubtitle,
                      isDark: isDark,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      limeAccent: limeAccent,
                      isHorizontal: !isMobile,
                    ),
                    const SizedBox(height: 18),
                    Divider(
                      color: borderColor,
                      height: 1,
                      thickness: 1,
                    ),
                    const SizedBox(height: 16),
                    _XpTrendChartPanel(
                      snapshot: widget.snapshot,
                      isDark: isDark,
                      limeAccent: limeAccent,
                      primaryTextColor: primaryTextColor,
                      secondaryTextColor: secondaryTextColor,
                      hoveredIndex: _hoveredIndex,
                      hoverPosition: _hoverLocalPosition,
                      onHover: _onHover,
                      onExit: _onExit,
                      chartHeight: isMobile ? 240.0 : 270.0,
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Summary Panel (~270px)
                    SizedBox(
                      width: 270,
                      child: _XpTrendSummaryPanel(
                        snapshot: widget.snapshot,
                        periodSubtitle: widget.periodSubtitle,
                        isDark: isDark,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        limeAccent: limeAccent,
                        isHorizontal: false,
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Vertical Divider
                    Container(
                      width: 1,
                      height: 280,
                      color: borderColor,
                    ),
                    const SizedBox(width: 20),
                    // Right Time-Series Chart Panel
                    Expanded(
                      child: _XpTrendChartPanel(
                        snapshot: widget.snapshot,
                        isDark: isDark,
                        limeAccent: limeAccent,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        hoveredIndex: _hoveredIndex,
                        hoverPosition: _hoverLocalPosition,
                        onHover: _onHover,
                        onExit: _onExit,
                        chartHeight: 280.0,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required bool isDark,
    required Color primaryColor,
    required Color secondaryColor,
    required Color limeAccent,
    required bool isMobile,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Analytical Icon Badge
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isDark ? const Color(0x22C6F135) : const Color(0x184E7100),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: limeAccent.withValues(alpha: isDark ? 0.35 : 0.45),
              width: 0.8,
            ),
          ),
          child: Icon(
            Icons.trending_up_rounded,
            size: 19,
            color: limeAccent,
          ),
        ),
        const SizedBox(width: 12),
        // Title & Description
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'XP Trend',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Track your XP progress over time and see how consistent you are.',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w400,
                  color: secondaryColor,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        if (!isMobile) ...[
          const SizedBox(width: 12),
          // Subdued Date Range Badge Pill
          _buildRangePill(isDark, secondaryColor),
        ],
      ],
    );
  }

  Widget _buildRangePill(bool isDark, Color textColor) {
    final range = widget.snapshot.range;
    final startStr = _formatShortDate(range.start);
    final endStr = _formatShortDate(range.end.subtract(const Duration(days: 1)));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0x0C0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0x140F172A),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.date_range_outlined,
            size: 13,
            color: textColor,
          ),
          const SizedBox(width: 5),
          Text(
            '$startStr – $endStr',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Color textColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.show_chart_rounded, size: 40, color: textColor.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'No XP activity recorded for this period',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Complete tasks, goals, or sessions to generate time-series analytics.',
            style: TextStyle(
              fontSize: 12,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context, Color cardBg, Color borderColor) {
    return SizedBox(
      height: 360,
      child: const KratosGlassCard(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        padding: EdgeInsets.all(22),
        child: KratosShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: KratosSkeletonTokens.boneBaseColor,
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 16,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: KratosSkeletonTokens.boneBaseColor,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    SizedBox(
                      width: 220,
                      height: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: KratosSkeletonTokens.boneBaseColor,
                          borderRadius: BorderRadius.all(Radius.circular(4)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Spacer(),
            SizedBox(
              width: double.infinity,
              height: 220,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: KratosSkeletonTokens.boneBaseColor,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

// ─────────────────────────────────────────────────────────────────────────────
// LEFT SUMMARY PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _XpTrendSummaryPanel extends StatelessWidget {
  final AnalyticsSnapshot snapshot;
  final String periodSubtitle;
  final bool isDark;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color limeAccent;
  final bool isHorizontal;

  const _XpTrendSummaryPanel({
    required this.snapshot,
    required this.periodSubtitle,
    required this.isDark,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.limeAccent,
    required this.isHorizontal,
  });

  String _formatNumber(int n) {
    final isNegative = n < 0;
    final absN = n.abs();
    final str = absN.toString();
    final buffer = StringBuffer();
    var count = 0;
    for (var i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count == 3 && i > 0) {
        buffer.write(',');
        count = 0;
      }
    }
    final formatted = buffer.toString().split('').reversed.join('');
    return isNegative ? '-$formatted' : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final delta = snapshot.xpDelta;
    final isPositive = delta.isPositive;
    final isNeutral = delta.isNeutral;
    final pctString = isNeutral
        ? '0.0%'
        : '${isPositive ? '+' : ''}${delta.changePct.toStringAsFixed(1)}%';

    final deltaColor = isNeutral
        ? secondaryTextColor
        : (isPositive ? limeAccent : const Color(0xFFFF5252));

    final netChange = snapshot.totalXp - snapshot.previousTotalXp;
    final days = math.max(1, snapshot.range.dayCount);
    final dailyAvg = snapshot.totalXp / days;

    final bigMetric = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _formatNumber(snapshot.totalXp),
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'XP',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: limeAccent,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Delta Badge Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: deltaColor.withValues(alpha: isDark ? 0.15 : 0.10),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: deltaColor.withValues(alpha: isDark ? 0.35 : 0.30),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isNeutral
                    ? Icons.remove_rounded
                    : (isPositive
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded),
                size: 13,
                color: deltaColor,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '$pctString $periodSubtitle',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: deltaColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final breakdownRows = [
      _buildStatRow('Current Period', '${_formatNumber(snapshot.totalXp)} XP', primaryTextColor),
      _buildStatRow('Previous Period', '${_formatNumber(snapshot.previousTotalXp)} XP', secondaryTextColor),
      _buildStatRow(
        'Net Change',
        '${netChange >= 0 ? '+' : ''}${_formatNumber(netChange)} XP',
        netChange >= 0 ? limeAccent : const Color(0xFFFF5252),
      ),
      _buildStatRow('Daily Average', '${dailyAvg.toStringAsFixed(1)} XP/d', secondaryTextColor),
      if (snapshot.negativeXp > 0)
        _buildStatRow('Penalties', '-${_formatNumber(snapshot.negativeXp)} XP', const Color(0xFFFF5252)),
    ];

    if (isHorizontal) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: bigMetric),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: breakdownRows,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bigMetric,
        const SizedBox(height: 18),
        ...breakdownRows,
      ],
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RIGHT TIME-SERIES CHART PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _XpTrendChartPanel extends StatelessWidget {
  final AnalyticsSnapshot snapshot;
  final bool isDark;
  final Color limeAccent;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final int? hoveredIndex;
  final Offset? hoverPosition;
  final void Function(int?, Offset?) onHover;
  final VoidCallback onExit;
  final double chartHeight;

  const _XpTrendChartPanel({
    required this.snapshot,
    required this.isDark,
    required this.limeAccent,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.hoveredIndex,
    required this.hoverPosition,
    required this.onHover,
    required this.onExit,
    required this.chartHeight,
  });

  @override
  Widget build(BuildContext context) {
    final currentSeries = snapshot.xpOverTime;
    final previousSeries = snapshot.previousXpOverTime;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Legend Bar ───────────────────────────────────────────────────────
        _buildLegendBar(context),
        const SizedBox(height: 12),

        // ── Interactive Chart Canvas ─────────────────────────────────────────
        SizedBox(
          height: chartHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;

              return MouseRegion(
                cursor: SystemMouseCursors.precise,
                onHover: (event) {
                  _processPointer(event.localPosition, w, currentSeries.length);
                },
                onExit: (_) => onExit(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (details) {
                    _processPointer(details.localPosition, w, currentSeries.length);
                  },
                  onPanUpdate: (details) {
                    _processPointer(details.localPosition, w, currentSeries.length);
                  },
                  onTapUp: (details) {
                    _processPointer(details.localPosition, w, currentSeries.length);
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      RepaintBoundary(
                        child: CustomPaint(
                          size: Size(w, h),
                          painter: _XpTrendChartPainter(
                            currentSeries: currentSeries,
                            previousSeries: previousSeries,
                            isDark: isDark,
                            limeAccent: limeAccent,
                            textColor: secondaryTextColor,
                            hoveredIndex: hoveredIndex,
                          ),
                        ),
                      ),
                      // Tooltip Overlay
                      if (hoveredIndex != null &&
                          hoveredIndex! >= 0 &&
                          hoveredIndex! < currentSeries.length)
                        _buildFloatingTooltip(
                          context,
                          index: hoveredIndex!,
                          totalWidth: w,
                          totalHeight: h,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _processPointer(Offset localPos, double totalWidth, int count) {
    if (count <= 0) return;
    const leftMargin = 38.0;
    const rightMargin = 12.0;
    final chartWidth = totalWidth - leftMargin - rightMargin;
    if (chartWidth <= 0) return;

    final clampedX = (localPos.dx - leftMargin).clamp(0.0, chartWidth);
    final ratio = clampedX / chartWidth;
    final index = (ratio * (count - 1)).round().clamp(0, count - 1);
    onHover(index, localPos);
  }

  Widget _buildLegendBar(BuildContext context) {
    final range = snapshot.range;
    final prevRange = range.previousRange;
    final isNarrow = MediaQuery.of(context).size.width < 640;

    final currentLabel = isNarrow
        ? 'Current Period'
        : 'Current Period (${_formatShortDate(range.start)} – ${_formatShortDate(range.end.subtract(const Duration(days: 1)))})';
    final prevLabel = isNarrow
        ? 'Previous Period'
        : 'Previous Period (${_formatShortDate(prevRange.start)} – ${_formatShortDate(prevRange.end.subtract(const Duration(days: 1)))})';

    return Wrap(
      spacing: 16,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Current Legend Item
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 3,
              decoration: BoxDecoration(
                color: limeAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: limeAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                currentLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // Previous Legend Item
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 2,
              decoration: BoxDecoration(
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  width: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                prevLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: secondaryTextColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFloatingTooltip(
    BuildContext context, {
    required int index,
    required double totalWidth,
    required double totalHeight,
  }) {
    final currentPoint = snapshot.xpOverTime[index];
    final prevPoint = (snapshot.previousXpOverTime.isNotEmpty &&
            index < snapshot.previousXpOverTime.length)
        ? snapshot.previousXpOverTime[index]
        : null;

    final currXp = currentPoint.xp;
    final prevXp = prevPoint?.xp ?? 0;
    final diff = currXp - prevXp;
    final diffPct = prevXp > 0
        ? ((diff / prevXp) * 100).toStringAsFixed(1)
        : (currXp > 0 ? '+100.0' : '0.0');

    final dateStr = _formatMediumDate(currentPoint.date);
    final prevDateStr =
        prevPoint != null ? _formatMediumDate(prevPoint.date) : null;

    const leftMargin = 38.0;
    const rightMargin = 12.0;
    final chartWidth = totalWidth - leftMargin - rightMargin;
    final count = snapshot.xpOverTime.length;
    final xPos = leftMargin + (count > 1 ? (index / (count - 1)) * chartWidth : 0.0);

    // Position tooltip: avoid overflowing right edge
    const tooltipWidth = 230.0;
    var tooltipLeft = xPos - (tooltipWidth / 2);
    if (tooltipLeft < 10) tooltipLeft = 10;
    if (tooltipLeft + tooltipWidth > totalWidth - 10) {
      tooltipLeft = totalWidth - tooltipWidth - 10;
    }

    final tooltipBg = isDark
        ? const Color(0xF21C221C)
        : const Color(0xF8FFFFFF);

    final tooltipBorder = isDark
        ? Colors.white.withValues(alpha: 0.20)
        : const Color(0x300F172A);

    return Positioned(
      left: tooltipLeft,
      top: 8,
      child: IgnorePointer(
        child: Container(
          width: tooltipWidth,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tooltipBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tooltipBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date Header
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              if (prevDateStr != null) ...[
                Text(
                  'vs $prevDateStr',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: secondaryTextColor,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              // Current Period Metric
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: limeAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Current:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$currXp XP',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: limeAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              // Previous Period Metric
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        width: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Previous:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    prevPoint != null ? '$prevXp XP' : 'N/A',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Divider(
                color: isDark ? Colors.white12 : const Color(0x180F172A),
                height: 1,
              ),
              const SizedBox(height: 5),
              // Difference & % Growth
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Net Difference:',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${diff >= 0 ? '+' : ''}$diff XP ($diffPct%)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: diff >= 0 ? limeAccent : const Color(0xFFFF5252),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTER FOR DUAL-SERIES LINE CHART
// ─────────────────────────────────────────────────────────────────────────────

class _XpTrendChartPainter extends CustomPainter {
  final List<AnalyticsPoint> currentSeries;
  final List<AnalyticsPoint> previousSeries;
  final bool isDark;
  final Color limeAccent;
  final Color textColor;
  final int? hoveredIndex;

  _XpTrendChartPainter({
    required this.currentSeries,
    required this.previousSeries,
    required this.isDark,
    required this.limeAccent,
    required this.textColor,
    required this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (currentSeries.isEmpty) return;

    const leftMargin = 38.0;
    const rightMargin = 12.0;
    const topMargin = 14.0;
    const bottomMargin = 26.0;

    final chartWidth = size.width - leftMargin - rightMargin;
    final chartHeight = size.height - topMargin - bottomMargin;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    // ── 1. Calculate Min and Max Values ──────────────────────────────────────
    var minVal = 0;
    var maxVal = 100;

    for (final p in currentSeries) {
      if (p.xp < minVal) minVal = p.xp;
      if (p.xp > maxVal) maxVal = p.xp;
    }
    for (final p in previousSeries) {
      if (p.xp < minVal) minVal = p.xp;
      if (p.xp > maxVal) maxVal = p.xp;
    }

    // Add 12% headroom ceiling so peaks don't stick to the top
    final rangeSpan = maxVal - minVal;
    final ceilingPadding = (rangeSpan * 0.12).ceil();
    maxVal += ceilingPadding > 0 ? ceilingPadding : 20;

    final valueSpan = (maxVal - minVal) > 0 ? (maxVal - minVal) : 1;

    double getY(double val) {
      final ratio = (val - minVal) / valueSpan;
      return topMargin + chartHeight - (ratio * chartHeight);
    }

    double getX(int index, int totalCount) {
      if (totalCount <= 1) return leftMargin + (chartWidth / 2);
      return leftMargin + (index / (totalCount - 1)) * chartWidth;
    }

    // ── 2. Draw Horizontal Gridlines & Y-Axis Labels ─────────────────────────
    const gridCount = 4;
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0x140F172A)
      ..strokeWidth = 1.0;

    for (var i = 0; i <= gridCount; i++) {
      final ratio = i / gridCount;
      final val = minVal + (ratio * valueSpan);
      final y = topMargin + chartHeight - (ratio * chartHeight);

      // Grid line
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(size.width - rightMargin, y),
        gridPaint,
      );

      // Y-axis label
      final label = _formatYAxisNumber(val.round());
      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor.withValues(alpha: 0.7),
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(leftMargin - textPainter.width - 6, y - (textPainter.height / 2)),
      );
    }

    // Explicit 0 XP baseline line if minVal < 0
    if (minVal < 0) {
      final zeroY = getY(0.0);
      final zeroPaint = Paint()
        ..color = isDark ? Colors.white.withValues(alpha: 0.20) : const Color(0x300F172A)
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(leftMargin, zeroY),
        Offset(size.width - rightMargin, zeroY),
        zeroPaint,
      );
    }

    // ── 3. Draw Previous Period Secondary Series ─────────────────────────────
    if (previousSeries.isNotEmpty) {
      final prevPaint = Paint()
        ..color = isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF94A3B8)
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;

      final prevCount = previousSeries.length;
      final currCount = currentSeries.length;

      // Connect previous series points mapped to the same relative X coordinate
      final prevPath = Path();
      for (var i = 0; i < currCount; i++) {
        final prevIdx = prevCount > 1
            ? (i * (prevCount - 1) / (currCount - 1)).round().clamp(0, prevCount - 1)
            : 0;
        final pt = previousSeries[prevIdx];
        final x = getX(i, currCount);
        final y = getY(pt.xp.toDouble());

        if (i == 0) {
          prevPath.moveTo(x, y);
        } else {
          prevPath.lineTo(x, y);
        }
      }
      canvas.drawPath(prevPath, prevPaint);
    }

    // ── 4. Draw Current Period Primary Series (Line + Gradient Area) ─────────
    final currCount = currentSeries.length;
    final currPath = Path();
    final areaPath = Path();

    final zeroBaseY = getY(0.0).clamp(topMargin, topMargin + chartHeight);

    areaPath.moveTo(getX(0, currCount), zeroBaseY);

    for (var i = 0; i < currCount; i++) {
      final pt = currentSeries[i];
      final x = getX(i, currCount);
      final y = getY(pt.xp.toDouble());

      if (i == 0) {
        currPath.moveTo(x, y);
        areaPath.lineTo(x, y);
      } else {
        // Smooth bezier interpolation
        final prevX = getX(i - 1, currCount);
        final prevY = getY(currentSeries[i - 1].xp.toDouble());
        final midX = (prevX + x) / 2;

        currPath.cubicTo(midX, prevY, midX, y, x, y);
        areaPath.cubicTo(midX, prevY, midX, y, x, y);
      }
    }

    // Complete the area fill path down to zero baseline
    areaPath.lineTo(getX(currCount - 1, currCount), zeroBaseY);
    areaPath.close();

    // Area gradient fill
    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          limeAccent.withValues(alpha: isDark ? 0.22 : 0.16),
          limeAccent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(leftMargin, topMargin, chartWidth, chartHeight))
      ..style = PaintingStyle.fill;

    canvas.drawPath(areaPath, areaPaint);

    // Primary stroke line
    final currPaint = Paint()
      ..color = limeAccent
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(currPath, currPaint);

    // ── 5. Draw Data Markers for Small Ranges (7D) ───────────────────────────
    if (currCount <= 14) {
      final dotPaint = Paint()
        ..color = limeAccent
        ..style = PaintingStyle.fill;
      final dotBorderPaint = Paint()
        ..color = isDark ? const Color(0xFF141814) : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      for (var i = 0; i < currCount; i++) {
        final x = getX(i, currCount);
        final y = getY(currentSeries[i].xp.toDouble());
        canvas.drawCircle(Offset(x, y), 3.0, dotPaint);
        canvas.drawCircle(Offset(x, y), 3.0, dotBorderPaint);
      }
    }

    // ── 6. Draw X-Axis Date Labels ───────────────────────────────────────────
    _paintXAxisLabels(canvas, size, leftMargin, chartWidth, topMargin, chartHeight, currCount);

    // ── 7. Draw Hover Crosshair and Active Dots ──────────────────────────────
    if (hoveredIndex != null && hoveredIndex! >= 0 && hoveredIndex! < currCount) {
      final idx = hoveredIndex!;
      final hx = getX(idx, currCount);
      final hyCurrent = getY(currentSeries[idx].xp.toDouble());

      // Vertical guideline
      final crosshairPaint = Paint()
        ..color = isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0x400F172A)
        ..strokeWidth = 1.0;

      // Draw dashed crosshair line
      const dashH = 4.0;
      const dashGap = 3.0;
      var curY = topMargin;
      while (curY < topMargin + chartHeight) {
        canvas.drawLine(
          Offset(hx, curY),
          Offset(hx, math.min(curY + dashH, topMargin + chartHeight)),
          crosshairPaint,
        );
        curY += dashH + dashGap;
      }

      // Previous point dot highlight
      if (previousSeries.isNotEmpty) {
        final prevIdx = previousSeries.length > 1
            ? (idx * (previousSeries.length - 1) / (currCount - 1))
                .round()
                .clamp(0, previousSeries.length - 1)
            : 0;
        final hyPrev = getY(previousSeries[prevIdx].xp.toDouble());

        final prevDotPaint = Paint()
          ..color = isDark ? Colors.white70 : const Color(0xFF64748B)
          ..style = PaintingStyle.fill;
        final prevDotOutline = Paint()
          ..color = isDark ? const Color(0xFF141814) : Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

        canvas.drawCircle(Offset(hx, hyPrev), 4.0, prevDotPaint);
        canvas.drawCircle(Offset(hx, hyPrev), 4.0, prevDotOutline);
      }

      // Current point glowing dot highlight
      final haloPaint = Paint()
        ..color = limeAccent.withValues(alpha: 0.28)
        ..style = PaintingStyle.fill;
      final activeDotPaint = Paint()
        ..color = limeAccent
        ..style = PaintingStyle.fill;
      final whiteCenterPaint = Paint()
        ..color = isDark ? const Color(0xFF141814) : Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(hx, hyCurrent), 7.0, haloPaint);
      canvas.drawCircle(Offset(hx, hyCurrent), 4.5, activeDotPaint);
      canvas.drawCircle(Offset(hx, hyCurrent), 2.0, whiteCenterPaint);
    }
  }

  void _paintXAxisLabels(
    Canvas canvas,
    Size size,
    double leftMargin,
    double chartWidth,
    double topMargin,
    double chartHeight,
    int count,
  ) {
    if (count <= 0) return;
    final yPos = topMargin + chartHeight + 6.0;

    // Use equidistant divisions based on available width to guarantee zero collisions
    final divisions = (chartWidth / 68.0).clamp(3.0, 6.0).floor();

    for (var d = 0; d <= divisions; d++) {
      final i = count > 1 ? (d * (count - 1) / divisions).round().clamp(0, count - 1) : 0;
      final pt = currentSeries[i];
      final x = leftMargin + (count > 1 ? (i / (count - 1)) * chartWidth : 0.0);
      final label = count <= 7 ? _formatDayOfWeek(pt.date) : _formatShortDate(pt.date);

      final textSpan = TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor.withValues(alpha: 0.75),
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      // Center text under point, clamping at margins
      var labelX = x - (textPainter.width / 2);
      if (labelX < leftMargin) labelX = leftMargin;
      if (labelX + textPainter.width > size.width - 4) {
        labelX = size.width - textPainter.width - 4;
      }

      textPainter.paint(canvas, Offset(labelX, yPos));
    }
  }

  String _formatYAxisNumber(int val) {
    if (val.abs() >= 1000) {
      final kVal = (val / 1000.0).toStringAsFixed(1);
      return '${kVal.endsWith(".0") ? kVal.substring(0, kVal.length - 2) : kVal}K';
    }
    return val.toString();
  }

  @override
  bool shouldRepaint(covariant _XpTrendChartPainter old) {
    return old.currentSeries != currentSeries ||
        old.previousSeries != previousSeries ||
        old.isDark != isDark ||
        old.limeAccent != limeAccent ||
        old.hoveredIndex != hoveredIndex;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE FORMATTING HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _formatShortDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[d.month - 1]} ${d.day}';
}

String _formatMediumDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String _formatDayOfWeek(DateTime d) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[d.weekday - 1];
}
