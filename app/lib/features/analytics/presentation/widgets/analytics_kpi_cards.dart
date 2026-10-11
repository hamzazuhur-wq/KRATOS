import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/kratos_theme.dart';
import '../../../../app/kratos_visuals.dart';
import '../../domain/analytics_models.dart';

/// KRATOS Analytics — Wave 03: Top 4 KPI Summary Cards.
///
/// Implements the top KPI summary row matching the master KRATOS visual reference:
/// 1. Total XP Card (Shield/Badge Icon, Big Metric, Trend Delta, Vertical Bar Sparkline)
/// 2. XP Velocity Card (Lightning Icon, Big Metric with 'XP/day', Trend Delta, Smooth Area Sparkline)
/// 3. Completion Rate Card (Check Circle Icon, Big Metric '%', Trend Delta, Radial Progress Ring)
/// 4. Consistency Card (Flame Icon, Big Metric 'days', Trend Delta, Contribution Dot Matrix)
///
/// Responsive Layout:
/// - Desktop (>= 1060px): 4 cards in a single horizontal row
/// - Tablet (640px .. 1059px): 2 x 2 grid
/// - Mobile (< 640px): 1 column of 4 stacked cards
class AnalyticsKpiSummaryRow extends StatelessWidget {
  final AnalyticsSnapshot snapshot;
  final String periodSubtitle;
  final VoidCallback? onConsistencyTap;
  final ValueChanged<String>? onKpiTap;

  const AnalyticsKpiSummaryRow({
    super.key,
    required this.snapshot,
    this.periodSubtitle = 'vs previous 30 days',
    this.onConsistencyTap,
    this.onKpiTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final totalXpCard = _TotalXpCard(
          snapshot: snapshot,
          periodSubtitle: periodSubtitle,
          onTap: () => onKpiTap?.call('total_xp'),
        );
        final velocityCard = _XpVelocityCard(
          snapshot: snapshot,
          periodSubtitle: periodSubtitle,
          onTap: () => onKpiTap?.call('velocity'),
        );
        final completionCard = _CompletionRateCard(
          snapshot: snapshot,
          periodSubtitle: periodSubtitle,
          onTap: () => onKpiTap?.call('completion_rate'),
        );
        final consistencyCard = _ConsistencyCard(
          snapshot: snapshot,
          periodSubtitle: periodSubtitle,
          onTap: () {
            onConsistencyTap?.call();
            onKpiTap?.call('consistency');
          },
        );

        // ── Desktop: 4 Cards in 1 Row (>= 1060px) ───────────────────────────
        if (width >= 1060) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: totalXpCard),
              const SizedBox(width: 14),
              Expanded(child: velocityCard),
              const SizedBox(width: 14),
              Expanded(child: completionCard),
              const SizedBox(width: 14),
              Expanded(child: consistencyCard),
            ],
          );
        }

        // ── Tablet: 2 x 2 Grid (640px - 1059px) ──────────────────────────────
        if (width >= 640) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: totalXpCard),
                  const SizedBox(width: 14),
                  Expanded(child: velocityCard),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: completionCard),
                  const SizedBox(width: 14),
                  Expanded(child: consistencyCard),
                ],
              ),
            ],
          );
        }

        // ── Mobile: 1 Column Stack (< 640px) ─────────────────────────────────
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            totalXpCard,
            const SizedBox(height: 12),
            velocityCard,
            const SizedBox(height: 12),
            completionCard,
            const SizedBox(height: 12),
            consistencyCard,
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BASE LIQUID GLASS KPI CARD SHELL
// ─────────────────────────────────────────────────────────────────────────────

class _KratosKpiCardShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget metricValue;
  final MetricDelta delta;
  final String periodSubtitle;
  final Widget graphic;
  final VoidCallback? onTap;
  final bool showChevron;

  const _KratosKpiCardShell({
    required this.icon,
    required this.title,
    required this.metricValue,
    required this.delta,
    required this.periodSubtitle,
    required this.graphic,
    this.onTap,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isInteractive = onTap != null;

    final titleColor = isDark
        ? Colors.white.withValues(alpha: 0.85)
        : KratosTheme.lightTextSecondary;

    final chevronColor = isDark
        ? Colors.white.withValues(alpha: 0.40)
        : KratosTheme.lightTextMuted;

    final iconBgColor = isDark
        ? const Color(0x22EEFF08)
        : const Color(0x1F658F00);

    final iconColor = isDark
        ? KratosTheme.acidLime
        : KratosTheme.lightAcidLime;

    final limeAccent = isDark
        ? KratosTheme.acidLime
        : KratosTheme.lightAcidLime;

    final isPositive = delta.isPositive;
    final pctString =
        '${isPositive ? '+' : ''}${delta.changePct.abs().toStringAsFixed(1)}%';

    return KratosGlassCard(
      variant: isInteractive ? KratosSurfaceVariant.interactive : KratosSurfaceVariant.normal,
      interactive: isInteractive,
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header Row (Icon + Title + Chevron) ────────────────────────
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: limeAccent.withValues(alpha: isDark ? 0.35 : 0.45),
                    width: 0.8,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: titleColor,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: chevronColor,
                ),
            ],
          ),

          const SizedBox(height: 14),

          // ── Main Metric + Graphic Sparkline ────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left side: Big Metric & Trend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    metricValue,
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 13,
                          color: isPositive
                              ? limeAccent
                              : const Color(0xFFFF5252),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          pctString,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isPositive
                                ? limeAccent
                                : const Color(0xFFFF5252),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      periodSubtitle,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.45)
                            : KratosTheme.lightTextMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Right side: Specialized Sparkline Graphic
              graphic,
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. TOTAL XP CARD
// ─────────────────────────────────────────────────────────────────────────────

class _TotalXpCard extends StatelessWidget {
  final AnalyticsSnapshot snapshot;
  final String periodSubtitle;
  final VoidCallback? onTap;

  const _TotalXpCard({
    required this.snapshot,
    required this.periodSubtitle,
    this.onTap,
  });

  String _formatNumber(int n) {
    final str = n.toString();
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
    return buffer.toString().split('').reversed.join('');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;

    // Use daily growth points or mock progression heights
    final points = snapshot.dailyGrowthSeries;
    List<double> barRatios;
    if (points.isNotEmpty) {
      final maxVal = math.max(1, points.map((p) => p.xp).reduce(math.max));
      barRatios = points.take(8).map((p) => (p.xp / maxVal).clamp(0.2, 1.0)).toList();
    } else {
      barRatios = const [0.25, 0.40, 0.55, 0.35, 0.70, 0.60, 0.85, 1.0];
    }

    return _KratosKpiCardShell(
      icon: Icons.shield_outlined,
      title: 'Total XP',
      showChevron: false,
      onTap: onTap,
      metricValue: Text(
        _formatNumber(snapshot.totalXp),
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: primaryTextColor,
          letterSpacing: -0.6,
        ),
      ),
      delta: snapshot.xpDelta,
      periodSubtitle: periodSubtitle,
      graphic: RepaintBoundary(
        child: SizedBox(
          width: 72,
          height: 44,
          child: CustomPaint(
            painter: _BarSparklinePainter(
              ratios: barRatios,
              color: isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime,
            ),
          ),
        ),
      ),
    );
  }
}

class _BarSparklinePainter extends CustomPainter {
  final List<double> ratios;
  final Color color;

  const _BarSparklinePainter({required this.ratios, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (ratios.isEmpty) return;
    final count = ratios.length;
    final barWidth = (size.width / (count * 1.5)).clamp(3.5, 6.5);
    final gap = (size.width - (count * barWidth)) / math.max(1, count - 1);

    for (var i = 0; i < count; i++) {
      final ratio = ratios[i];
      final barHeight = math.max(6.0, size.height * ratio);
      final left = i * (barWidth + gap);
      final top = size.height - barHeight;

      // Color intensity rises towards most recent day
      final opacity = (0.35 + (i / count) * 0.65).clamp(0.25, 1.0);
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, barHeight),
        const Radius.circular(2.5),
      );
      canvas.drawRRect(rrect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BarSparklinePainter old) =>
      old.ratios != ratios || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. XP VELOCITY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _XpVelocityCard extends StatelessWidget {
  final AnalyticsSnapshot snapshot;
  final String periodSubtitle;
  final VoidCallback? onTap;

  const _XpVelocityCard({
    required this.snapshot,
    required this.periodSubtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final unitTextColor = isDark ? Colors.white54 : KratosTheme.lightTextSecondary;

    final velocityVal = snapshot.xpVelocityDelta.current.round();

    final points = snapshot.dailyGrowthSeries;
    List<double> lineRatios;
    if (points.isNotEmpty) {
      final maxVal = math.max(1, points.map((p) => p.xp).reduce(math.max));
      lineRatios = points.take(8).map((p) => (p.xp / maxVal).clamp(0.1, 1.0)).toList();
    } else {
      lineRatios = const [0.2, 0.35, 0.30, 0.55, 0.50, 0.75, 0.68, 0.95];
    }

    return _KratosKpiCardShell(
      icon: Icons.bolt_rounded,
      title: 'XP Velocity',
      showChevron: false,
      onTap: onTap,
      metricValue: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            velocityVal.toString(),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'XP/day',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: unitTextColor,
            ),
          ),
        ],
      ),
      delta: snapshot.xpVelocityDelta,
      periodSubtitle: periodSubtitle,
      graphic: RepaintBoundary(
        child: SizedBox(
          width: 76,
          height: 44,
          child: CustomPaint(
            painter: _CurvedAreaSparklinePainter(
              ratios: lineRatios,
              color: isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime,
            ),
          ),
        ),
      ),
    );
  }
}

class _CurvedAreaSparklinePainter extends CustomPainter {
  final List<double> ratios;
  final Color color;

  const _CurvedAreaSparklinePainter({required this.ratios, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (ratios.length < 2) return;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (ratios.length - 1);
    final pts = <Offset>[];
    for (var i = 0; i < ratios.length; i++) {
      final x = i * stepX;
      final y = size.height - (ratios[i] * (size.height - 8)) - 4;
      pts.add(Offset(x, y));
    }

    path.moveTo(pts[0].dx, pts[0].dy);
    fillPath.moveTo(pts[0].dx, size.height);
    fillPath.lineTo(pts[0].dx, pts[0].dy);

    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final ctrl1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final ctrl2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, p1.dx, p1.dy);
      fillPath.cubicTo(ctrl1.dx, ctrl1.dy, ctrl2.dx, ctrl2.dy, p1.dx, p1.dy);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Subtle area gradient fill
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.35),
        color.withValues(alpha: 0.02),
      ],
    );
    final fillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Smooth stroke
    final strokePaint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _CurvedAreaSparklinePainter old) =>
      old.ratios != ratios || old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. COMPLETION RATE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _CompletionRateCard extends StatelessWidget {
  final AnalyticsSnapshot snapshot;
  final String periodSubtitle;
  final VoidCallback? onTap;

  const _CompletionRateCard({
    required this.snapshot,
    required this.periodSubtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;

    final rateVal = snapshot.completionRateDelta.current.round();

    return _KratosKpiCardShell(
      icon: Icons.check_circle_outline_rounded,
      title: 'Completion Rate',
      showChevron: false,
      onTap: onTap,
      metricValue: Text(
        '$rateVal%',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: primaryTextColor,
          letterSpacing: -0.6,
        ),
      ),
      delta: snapshot.completionRateDelta,
      periodSubtitle: periodSubtitle,
      graphic: RepaintBoundary(
        child: SizedBox(
          width: 50,
          height: 48,
          child: CustomPaint(
            painter: _RadialRingPainter(
              progress: (rateVal / 100.0).clamp(0.0, 1.0),
              color: isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime,
              isDark: isDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadialRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isDark;

  const _RadialRingPainter({
    required this.progress,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - 4.5;
    const strokeWidth = 5.2;

    // Background track
    final trackPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.12)
          : const Color(0x1F0F172A)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    // Active progress arc
    final sweepAngle = 2 * math.pi * progress;
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialRingPainter old) =>
      old.progress != progress || old.color != color || old.isDark != isDark;
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. CONSISTENCY CARD
// ─────────────────────────────────────────────────────────────────────────────

class _ConsistencyCard extends StatelessWidget {
  final AnalyticsSnapshot snapshot;
  final String periodSubtitle;
  final VoidCallback? onTap;

  const _ConsistencyCard({
    required this.snapshot,
    required this.periodSubtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final unitTextColor = isDark ? Colors.white54 : KratosTheme.lightTextSecondary;

    final displayVal = snapshot.activeDaysCount > 0
        ? snapshot.activeDaysCount
        : (snapshot.currentStreak > 0 ? snapshot.currentStreak : 0);

    return _KratosKpiCardShell(
      icon: Icons.local_fire_department_outlined,
      title: 'Consistency',
      showChevron: true,
      onTap: onTap,
      metricValue: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            displayVal.toString(),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'days',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: unitTextColor,
            ),
          ),
        ],
      ),
      delta: snapshot.consistencyDelta,
      periodSubtitle: periodSubtitle,
      graphic: RepaintBoundary(
        child: SizedBox(
          width: 68,
          height: 44,
          child: CustomPaint(
            painter: _DotGridPainter(
              color: isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime,
              isDark: isDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  const _DotGridPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    const rows = 4;
    const cols = 6;
    const dotRadius = 2.4;

    final cellW = size.width / cols;
    final cellH = size.height / rows;

    // Pattern matching contribution activity
    final pattern = [
      [0.2, 0.4, 0.8, 1.0, 0.8, 0.3],
      [0.3, 0.7, 1.0, 1.0, 0.9, 0.4],
      [0.1, 0.8, 0.9, 1.0, 1.0, 0.5],
      [0.4, 0.9, 1.0, 0.8, 0.6, 0.2],
    ];

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cx = (c * cellW) + (cellW / 2);
        final cy = (r * cellH) + (cellH / 2);
        final weight = pattern[r][c];

        final paint = Paint()
          ..color = weight > 0.4
              ? color.withValues(alpha: weight.clamp(0.3, 1.0))
              : (isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : const Color(0x240F172A))
          ..style = PaintingStyle.fill;

        canvas.drawCircle(Offset(cx, cy), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotGridPainter old) =>
      old.color != color || old.isDark != isDark;
}
