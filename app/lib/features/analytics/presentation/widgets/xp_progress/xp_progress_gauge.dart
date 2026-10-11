import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../../app/kratos_theme.dart';
import 'kratos_crystal_emblem.dart';

/// Production 270-degree XP Progress Gauge rendered using pure CustomPainter.
///
/// Adheres strictly to Section 11 & 12:
/// - Semi-circular ~270-degree arc (starts at 135°, sweeps 270° clockwise to 45°)
/// - Outer technical boundary track
/// - Background track: #202326 (Dark) / #D8DADB (Light)
/// - Precision inner radial tick notches (15° intervals)
/// - Active progress arc with SweepGradient (White to #EEFF08)
/// - Soft radial endpoint glow + illuminated round endpoint indicator
/// - Center stack with vector crystal emblem, level, XP fraction, large acid lime %, and subtitle.
class XpProgressGauge extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final String levelText;
  final String xpFractionText;
  final String percentText;
  final String subtitleText;
  final bool isDark;
  final Color? accentColor;
  final bool isAllLifeAreas;

  const XpProgressGauge({
    super.key,
    required this.progress,
    required this.levelText,
    required this.xpFractionText,
    required this.percentText,
    required this.subtitleText,
    required this.isDark,
    this.accentColor,
    this.isAllLifeAreas = false,
  });

  @override
  Widget build(BuildContext context) {
    final lime = accentColor ?? (isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime);
    final primaryText = isDark ? Colors.white : KratosTheme.lightTextPrimary;
    final secondaryText = isDark ? const Color(0xFFA7A7A7) : KratosTheme.lightTextSecondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsively adapt gauge diameter to available width
        final maxW = constraints.maxWidth;
        final diameter = maxW.clamp(210.0, 310.0);
        final height = diameter * 0.95;

        return SizedBox(
          width: diameter,
          height: height,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Custom Arc Painting
              RepaintBoundary(
                child: CustomPaint(
                  size: Size(diameter, height),
                  painter: _GaugePainter(
                    progress: progress.clamp(0.0, 1.0),
                    accentColor: lime,
                    isDark: isDark,
                  ),
                ),
              ),

              // 2. Centered Metric Content
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(top: diameter * 0.06),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Geometric Crystal / Emblem
                        KratosCrystalEmblem(
                          size: diameter > 260 ? 28.0 : 24.0,
                          isActive: true,
                          accentColor: lime,
                        ),
                        const SizedBox(height: 5),

                        // Level Roman Label
                        Text(
                          levelText.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'IBM Plex Mono',
                            fontSize: diameter > 260 ? 11.5 : 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                            color: secondaryText,
                          ),
                        ),
                        const SizedBox(height: 3),

                        // XP Fraction
                        Text(
                          xpFractionText,
                          style: TextStyle(
                            fontSize: diameter > 260 ? 15.5 : 14.0,
                            fontWeight: FontWeight.w700,
                            color: primaryText,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),

                        // Large Acid Lime %
                        Text(
                          percentText,
                          style: TextStyle(
                            fontSize: diameter > 260 ? 36.0 : 30.0,
                            fontWeight: FontWeight.w800,
                            color: lime,
                            letterSpacing: -1.0,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),

                        // Subtitle remaining / context
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            subtitleText,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: diameter > 260 ? 11.5 : 10.5,
                              fontWeight: FontWeight.w500,
                              color: secondaryText.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final bool isDark;

  const _GaugePainter({
    required this.progress,
    required this.accentColor,
    required this.isDark,
  });

  // 270-degree arc: starts at 135° (3π/4) and sweeps 270° (3π/2)
  static const double _startAngle = 135.0 * (math.pi / 180.0);
  static const double _sweepAngle = 270.0 * (math.pi / 180.0);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final cx = size.width / 2.0;
    final cy = (size.height / 2.0) + (size.height * 0.02);
    final center = Offset(cx, cy);

    final radius = (size.width / 2.0) - (size.width * 0.08);
    final trackWidth = math.max(14.0, size.width * 0.068);

    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // ── 1. Outer Technical Hairline Ring ──────────────────────────────────────
    final outerRingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0x180F172A);

    final outerRect = Rect.fromCircle(
      center: center,
      radius: radius + (trackWidth / 2.0) + 7.0,
    );
    canvas.drawArc(outerRect, _startAngle, _sweepAngle, false, outerRingPaint);

    // ── 2. Subtle Radial Ticks Along Outer Rim ────────────────────────────────
    final tickCount = 19;
    final tickStep = _sweepAngle / (tickCount - 1);
    final tickPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.14)
          : const Color(0x280F172A)
      ..strokeWidth = 1.0;

    for (var i = 0; i < tickCount; i++) {
      final angle = _startAngle + (i * tickStep);
      final p1 = Offset(
        cx + (radius + (trackWidth / 2.0) + 2.0) * math.cos(angle),
        cy + (radius + (trackWidth / 2.0) + 2.0) * math.sin(angle),
      );
      final p2 = Offset(
        cx + (radius + (trackWidth / 2.0) + 6.0) * math.cos(angle),
        cy + (radius + (trackWidth / 2.0) + 6.0) * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // ── 3. Base Inactive Track ────────────────────────────────────────────────
    final trackColor = isDark ? const Color(0xFF202326) : const Color(0xFFD8DADB);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;

    canvas.drawArc(arcRect, _startAngle, _sweepAngle, false, trackPaint);

    // ── 4. Active Progress Arc (SweepGradient) ────────────────────────────────
    if (progress > 0.001) {
      final progressSweep = _sweepAngle * progress;

      final gradient = SweepGradient(
        startAngle: _startAngle,
        endAngle: _startAngle + _sweepAngle,
        colors: isDark
            ? [
                const Color(0xFFE8E8E8),
                accentColor,
              ]
            : [
                const Color(0xFF888888),
                accentColor,
              ],
        stops: const [0.0, 1.0],
      );

      final activePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = trackWidth
        ..strokeCap = StrokeCap.round
        ..shader = gradient.createShader(arcRect);

      canvas.drawArc(arcRect, _startAngle, progressSweep, false, activePaint);

      // ── 5. Active Endpoint Glow & Cap Indicator ───────────────────────────
      final endAngle = _startAngle + progressSweep;
      final endPoint = Offset(
        cx + radius * math.cos(endAngle),
        cy + radius * math.sin(endAngle),
      );

      // Soft glow halo
      if (isDark) {
        final glowPaint = Paint()
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0)
          ..color = accentColor.withValues(alpha: 0.38);
        canvas.drawCircle(endPoint, trackWidth * 0.55, glowPaint);
      }

      // Small glowing center indicator point at the tip
      final indicatorPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = isDark ? Colors.white : const Color(0xFF0F172A);
      canvas.drawCircle(endPoint, math.max(2.4, trackWidth * 0.18), indicatorPaint);

      final indicatorBorder = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = accentColor;
      canvas.drawCircle(endPoint, math.max(2.4, trackWidth * 0.18), indicatorBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress ||
      old.accentColor != accentColor ||
      old.isDark != isDark;
}
