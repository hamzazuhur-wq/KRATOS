import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:kratos_app/app/kratos_theme.dart';
import 'package:kratos_app/features/analytics/domain/analytics_models.dart';

/// KRATOS Analytics — Wave 08: Skill XP Trend Sparkline Chart.
///
/// Features:
/// - CustomPainter-rendered smooth sparkline with vertical gradient area fill
/// - Current period activity curve in primary accent (Acid Lime / Cyan)
/// - Previous period baseline curve in subtle dashed/faded tone for comparison
/// - Handles single-point, flatline, empty, and irregular time series safely
/// - High data density with responsive scaling for mobile, tablet, and desktop
class SkillTrendChart extends StatelessWidget {
  final List<AnalyticsPoint> currentSeries;
  final List<AnalyticsPoint> previousSeries;
  final Color? accentColor;
  final double height;
  final String? periodLabel;

  const SkillTrendChart({
    super.key,
    required this.currentSeries,
    this.previousSeries = const [],
    this.accentColor,
    this.height = 110,
    this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = accentColor ?? (isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime);

    if (currentSeries.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No trend data recorded for this period',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _SkillTrendPainter(
              current: currentSeries,
              previous: previousSeries,
              accentColor: color,
              isDark: isDark,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${currentSeries.first.date.month}/${currentSeries.first.date.day}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                letterSpacing: 0.3,
              ),
            ),
            if (periodLabel != null)
              Text(
                periodLabel!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : KratosTheme.lightTextSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            Text(
              '${currentSeries.last.date.month}/${currentSeries.last.date.day}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white38 : KratosTheme.lightTextMuted,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SkillTrendPainter extends CustomPainter {
  final List<AnalyticsPoint> current;
  final List<AnalyticsPoint> previous;
  final Color accentColor;
  final bool isDark;

  _SkillTrendPainter({
    required this.current,
    required this.previous,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (current.isEmpty || size.width <= 0 || size.height <= 0) return;

    final padding = const EdgeInsets.only(top: 8, bottom: 8, left: 4, right: 4);
    final drawW = size.width - padding.horizontal;
    final drawH = size.height - padding.vertical;

    // Find global min and max across both series to ensure accurate relative scaling
    var minY = double.infinity;
    var maxY = -double.infinity;

    for (final p in current) {
      final y = p.xp.toDouble();
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    for (final p in previous) {
      final y = p.xp.toDouble();
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    if (minY == double.infinity) minY = 0.0;
    if (maxY == -double.infinity || maxY == minY) {
      // Flatline or single value: give headroom
      maxY = minY + (minY == 0 ? 10.0 : minY * 0.25);
      minY = math.max(0.0, minY - (minY == 0 ? 0.0 : minY * 0.1));
    } else {
      // Add a 10% vertical padding so lines don't clamp strictly at top/bottom border
      final span = maxY - minY;
      maxY += span * 0.1;
      minY = math.max(0.0, minY - span * 0.05);
    }

    final rangeY = (maxY - minY) > 0 ? (maxY - minY) : 1.0;

    // 1. Draw subtle horizontal grid baselines (25%, 50%, 75%)
    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 1; i <= 3; i++) {
      final yPos = padding.top + drawH * (i / 4.0);
      canvas.drawLine(
        Offset(padding.left, yPos),
        Offset(size.width - padding.right, yPos),
        gridPaint,
      );
    }

    // 2. Render Previous Period Baseline if available
    if (previous.length >= 2) {
      final prevPaint = Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.22)
            : KratosTheme.lightTextMuted.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final prevPath = _buildSmoothPath(previous, drawW, drawH, padding, minY, rangeY);
      _drawDashedPath(canvas, prevPath, prevPaint);
    }

    // 3. Render Current Period Area Gradient Fill & Stroke
    final currentPath = _buildSmoothPath(current, drawW, drawH, padding, minY, rangeY);

    // Area Fill
    final fillPath = Path.from(currentPath)
      ..lineTo(padding.left + drawW, size.height - padding.bottom)
      ..lineTo(padding.left, size.height - padding.bottom)
      ..close();

    final fillGradient = ui.Gradient.linear(
      Offset(0, padding.top),
      Offset(0, size.height - padding.bottom),
      [
        accentColor.withValues(alpha: isDark ? 0.32 : 0.24),
        accentColor.withValues(alpha: isDark ? 0.08 : 0.05),
        accentColor.withValues(alpha: 0.0),
      ],
      const [0.0, 0.6, 1.0],
    );

    final fillPaint = Paint()
      ..shader = fillGradient
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Glow effect (dark mode only)
    if (isDark) {
      final glowPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
      canvas.drawPath(currentPath, glowPaint);
    }

    // Primary Stroke
    final strokePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(currentPath, strokePaint);

    // 4. Endpoint Indicator dot
    if (current.isNotEmpty) {
      final lastIdx = current.length - 1;
      final denom = math.max(1, current.length - 1);
      final x = padding.left + (lastIdx / denom) * drawW;
      final yNorm = (current.last.xp - minY) / rangeY;
      final y = size.height - padding.bottom - (yNorm.clamp(0.0, 1.0) * drawH);

      final outerDot = Paint()
        ..color = isDark ? const Color(0xFF0D100E) : Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 5.0, outerDot);

      final innerDot = Paint()
        ..color = accentColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 3.2, innerDot);
    }
  }

  Path _buildSmoothPath(
    List<AnalyticsPoint> points,
    double drawW,
    double drawH,
    EdgeInsets padding,
    double minY,
    double rangeY,
  ) {
    final path = Path();
    if (points.isEmpty) return path;

    final n = points.length;
    final denom = math.max(1, n - 1);

    Offset getOffset(int i) {
      final x = padding.left + (i / denom) * drawW;
      final yNorm = (points[i].xp - minY) / rangeY;
      final y = (padding.top + drawH) - (yNorm.clamp(0.0, 1.0) * drawH);
      return Offset(x, y);
    }

    if (n == 1) {
      final p0 = getOffset(0);
      path.moveTo(padding.left, p0.dy);
      path.lineTo(padding.left + drawW, p0.dy);
      return path;
    }

    path.moveTo(getOffset(0).dx, getOffset(0).dy);

    for (var i = 0; i < n - 1; i++) {
      final p0 = getOffset(i);
      final p1 = getOffset(i + 1);

      // Monotone cubic bezier control points for smooth natural curve
      final controlX1 = p0.dx + (p1.dx - p0.dx) / 2.0;
      final controlY1 = p0.dy;
      final controlX2 = p0.dx + (p1.dx - p0.dx) / 2.0;
      final controlY2 = p1.dy;

      path.cubicTo(controlX1, controlY1, controlX2, controlY2, p1.dx, p1.dy);
    }

    return path;
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashWidth, metric.length - distance);
        final extract = metric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SkillTrendPainter oldDelegate) {
    return oldDelegate.current != current ||
        oldDelegate.previous != previous ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isDark != isDark;
  }
}
