import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../app/kratos_theme.dart';
import '../../../../../app/kratos_visuals.dart';
import '../../../domain/analytics_models.dart';
import 'focus_time_formatters.dart';

/// Top Hero card for Focus Time matching master visual reference:
/// - Stopwatch icon in electric lime container
/// - "Focus Time", "Turn your attention into progress."
/// - Big duration readout + trend percentage badge
/// - 3 metric pill tiles (Sessions, Avg. Session, Longest)
/// - Circular Goal Progress gauge (78%)
class FocusTimeHeroCard extends StatelessWidget {
  final FocusTimeSnapshot snapshot;
  final String periodLabel;
  final String periodSubtitle;
  final double goalTargetHours;
  final VoidCallback? onDateRangeTap;

  const FocusTimeHeroCard({
    super.key,
    required this.snapshot,
    this.periodLabel = 'This Week',
    this.periodSubtitle = 'vs last week',
    this.goalTargetHours = 16.0,
    this.onDateRangeTap,
  });

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

    final borderColor = isDark ? const Color(0x26FFFFFF) : const Color(0x1F0F172A);

    // Goal progress calculation (hours focused / goal target hours)
    final actualHours = snapshot.totalMs / (1000.0 * 3600.0);
    final goalProgress = (actualHours / goalTargetHours).clamp(0.0, 1.0);
    final goalPercent = (goalProgress * 100).round();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        return KratosGlassCard(
          padding: EdgeInsets.all(isMobile ? 18 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Header Row: Icon + Title + Subtitle + Date Picker Pill ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lime stopwatch icon box
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0x2EEFFF08)
                          : const Color(0x2284CC16),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? const Color(0x4DEEFF08)
                            : const Color(0x5584CC16),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.timer_rounded,
                        color: limeAccent,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title + Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Focus Time',
                          style: TextStyle(
                            fontSize: isMobile ? 19 : 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Turn your attention into progress.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Date range selector pill
                  InkWell(
                    onTap: onDateRangeTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0x1AFFFFFF)
                            : const Color(0x0F0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? const Color(0x26FFFFFF)
                              : const Color(0x1F0F172A),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: secondaryTextColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            periodLabel,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: secondaryTextColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Middle Section: Big Readout + Trend + Ring Gauge ──
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBigMetricRow(
                      primaryTextColor: primaryTextColor,
                      limeAccent: limeAccent,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: _GoalProgressGauge(
                        percent: goalPercent,
                        progress: goalProgress,
                        isDark: isDark,
                        limeAccent: limeAccent,
                        primaryTextColor: primaryTextColor,
                        mutedTextColor: mutedTextColor,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildBigMetricRow(
                        primaryTextColor: primaryTextColor,
                        limeAccent: limeAccent,
                        secondaryTextColor: secondaryTextColor,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 24),
                    _GoalProgressGauge(
                      percent: goalPercent,
                      progress: goalProgress,
                      isDark: isDark,
                      limeAccent: limeAccent,
                      primaryTextColor: primaryTextColor,
                      mutedTextColor: mutedTextColor,
                    ),
                  ],
                ),

              const SizedBox(height: 20),

              // ── Bottom Section: 3 Metric Badges ──
              _buildMetricBadgesRow(
                isMobile: isMobile,
                isDark: isDark,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                borderColor: borderColor,
                limeAccent: limeAccent,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBigMetricRow({
    required Color primaryTextColor,
    required Color limeAccent,
    required Color secondaryTextColor,
    required bool isDark,
  }) {
    final formattedTotal = FocusTimeFormatters.formatDurationHhMm(snapshot.totalMs);
    final trendVal = snapshot.trendPercent;
    final isPos = trendVal != null && trendVal >= 0;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 14,
      runSpacing: 4,
      children: [
        Text(
          formattedTotal,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: primaryTextColor,
          ),
        ),
        if (trendVal != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPos ? Icons.north_rounded : Icons.south_rounded,
                size: 14,
                color: isPos
                    ? limeAccent
                    : (isDark ? Colors.redAccent : Colors.red),
              ),
              const SizedBox(width: 3),
              Text(
                '${trendVal.abs().toStringAsFixed(0)}% ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isPos
                      ? limeAccent
                      : (isDark ? Colors.redAccent : Colors.red),
                ),
              ),
              Text(
                periodSubtitle,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMetricBadgesRow({
    required bool isMobile,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color borderColor,
    required Color limeAccent,
  }) {
    final tileBg = isDark ? const Color(0x12FFFFFF) : const Color(0x080F172A);

    final tiles = [
      _MetricBadgeItem(
        value: '${snapshot.sessionCount}',
        label: 'Sessions',
        icon: Icons.auto_graph_rounded,
        tileBg: tileBg,
        borderColor: borderColor,
        primaryTextColor: primaryTextColor,
        secondaryTextColor: secondaryTextColor,
        iconColor: limeAccent,
      ),
      _MetricBadgeItem(
        value: FocusTimeFormatters.formatDurationHhMm(snapshot.averageMs),
        label: 'Avg. Session',
        icon: Icons.timer_outlined,
        tileBg: tileBg,
        borderColor: borderColor,
        primaryTextColor: primaryTextColor,
        secondaryTextColor: secondaryTextColor,
        iconColor: limeAccent,
      ),
      _MetricBadgeItem(
        value: FocusTimeFormatters.formatDurationHhMm(snapshot.longestMs),
        label: 'Longest',
        icon: Icons.star_outline_rounded,
        tileBg: tileBg,
        borderColor: borderColor,
        primaryTextColor: primaryTextColor,
        secondaryTextColor: secondaryTextColor,
        iconColor: limeAccent,
      ),
    ];

    if (isMobile) {
      return Column(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            tiles[i],
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: tiles[i]),
        ],
      ],
    );
  }
}

class _MetricBadgeItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color tileBg;
  final Color borderColor;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color iconColor;

  const _MetricBadgeItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.tileBg,
    required this.borderColor,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
          Icon(icon, size: 18, color: iconColor),
        ],
      ),
    );
  }
}

/// Circular Progress Gauge matching the visual reference (78% Goal Progress).
class _GoalProgressGauge extends StatelessWidget {
  final int percent;
  final double progress;
  final bool isDark;
  final Color limeAccent;
  final Color primaryTextColor;
  final Color mutedTextColor;

  const _GoalProgressGauge({
    required this.percent,
    required this.progress,
    required this.isDark,
    required this.limeAccent,
    required this.primaryTextColor,
    required this.mutedTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: CustomPaint(
            painter: _RingProgressPainter(
              progress: progress,
              arcColor: limeAccent,
              trackColor: isDark
                  ? const Color(0x1FFFFFFF)
                  : const Color(0x1F0F172A),
              strokeWidth: 8.5,
            ),
            child: Center(
              child: Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: primaryTextColor,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Goal Progress',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: mutedTextColor,
          ),
        ),
      ],
    );
  }
}

class _RingProgressPainter extends CustomPainter {
  final double progress;
  final Color arcColor;
  final Color trackColor;
  final double strokeWidth;

  const _RingProgressPainter({
    required this.progress,
    required this.arcColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0) return;

    // Active arc
    final arcPaint = Paint()
      ..color = arcColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.arcColor != arcColor ||
        oldDelegate.trackColor != trackColor;
  }
}
