import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../../app/kratos_theme.dart';

/// Clean, high-performance geometric vector Crystal emblem rendered via CustomPainter.
///
/// Adheres strictly to Section 13:
/// - Layered polygons: outer diamond, inner diamond, core diamond, 4 directional facets
/// - Multi-angle specular lighting: top-left specular highlight, directional reflection
/// - Restrained KRATOS Acid Lime (#EEFF08) glow for active state
/// - Subdued metallic silver/gray for completed or neutral state
/// - Micro-lock glyph for locked future milestones
/// - Zero raster images, zero PNGs, pure GPU-cached vector geometry.
class KratosCrystalEmblem extends StatelessWidget {
  final double size;
  final bool isActive;
  final bool isCompleted;
  final bool isLocked;
  final Color? accentColor;

  const KratosCrystalEmblem({
    super.key,
    this.size = 32.0,
    this.isActive = false,
    this.isCompleted = false,
    this.isLocked = false,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = accentColor ?? (isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime);

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          size: Size(size, size),
          painter: _CrystalEmblemPainter(
            isActive: isActive,
            isCompleted: isCompleted,
            isLocked: isLocked,
            accentColor: lime,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

class _CrystalEmblemPainter extends CustomPainter {
  final bool isActive;
  final bool isCompleted;
  final bool isLocked;
  final Color accentColor;
  final bool isDark;

  const _CrystalEmblemPainter({
    required this.isActive,
    required this.isCompleted,
    required this.isLocked,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final cx = size.width / 2.0;
    final cy = size.height / 2.0;
    final r = math.min(size.width, size.height) / 2.0;

    // Diamond aspect scale (slightly taller than wide for athletic crystal silhouette)
    final roY = r * 0.94;
    final roX = r * 0.82;

    // Outer diamond vertices
    final ot = Offset(cx, cy - roY);
    final or = Offset(cx + roX, cy);
    final ob = Offset(cx, cy + roY);
    final ol = Offset(cx - roX, cy);

    // Inner diamond vertices (scale ~0.54)
    final riY = roY * 0.54;
    final riX = roX * 0.54;
    final it = Offset(cx, cy - riY);
    final ir = Offset(cx + riX, cy);
    final ib = Offset(cx, cy + riY);
    final il = Offset(cx - riX, cy);

    // Core diamond vertices (scale ~0.22)
    final rcY = roY * 0.22;
    final rcX = roX * 0.22;
    final ct = Offset(cx, cy - rcY);
    final cr = Offset(cx + rcX, cy);
    final cb = Offset(cx, cy + rcY);
    final cl = Offset(cx - rcX, cy);

    if (isLocked) {
      _paintLockedDiamond(canvas, ot, or, ob, ol, cx, cy, r);
      return;
    }

    // ── 1. Outer Facet Polygons with Specular Lighting ────────────────────────
    // Facet 1: Top-Left (Primary light source highlight)
    final pTopLeft = Path()..moveTo(ot.dx, ot.dy)..lineTo(it.dx, it.dy)..lineTo(il.dx, il.dy)..lineTo(ol.dx, ol.dy)..close();
    // Facet 2: Top-Right (Secondary reflection)
    final pTopRight = Path()..moveTo(ot.dx, ot.dy)..lineTo(or.dx, or.dy)..lineTo(ir.dx, ir.dy)..lineTo(it.dx, it.dy)..close();
    // Facet 3: Bottom-Right (Shadow quadrant)
    final pBottomRight = Path()..moveTo(or.dx, or.dy)..lineTo(ob.dx, ob.dy)..lineTo(ib.dx, ib.dy)..lineTo(ir.dx, ir.dy)..close();
    // Facet 4: Bottom-Left (Fill reflection)
    final pBottomLeft = Path()..moveTo(ol.dx, ol.dy)..lineTo(il.dx, il.dy)..lineTo(ib.dx, ib.dy)..lineTo(ob.dx, ob.dy)..close();

    final alphaMul = isActive ? 1.0 : (isCompleted ? 0.75 : 0.40);

    // Base facet fills
    canvas.drawPath(
      pTopLeft,
      Paint()
        ..color = (isActive
            ? accentColor.withValues(alpha: 0.35 * alphaMul)
            : (isDark ? Colors.white.withValues(alpha: 0.38 * alphaMul) : const Color(0x380F172A)))
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      pTopRight,
      Paint()
        ..color = (isActive
            ? accentColor.withValues(alpha: 0.22 * alphaMul)
            : (isDark ? Colors.white.withValues(alpha: 0.22 * alphaMul) : const Color(0x220F172A)))
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      pBottomRight,
      Paint()
        ..color = (isActive
            ? accentColor.withValues(alpha: 0.12 * alphaMul)
            : (isDark ? Colors.white.withValues(alpha: 0.08 * alphaMul) : const Color(0x100F172A)))
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      pBottomLeft,
      Paint()
        ..color = (isActive
            ? accentColor.withValues(alpha: 0.18 * alphaMul)
            : (isDark ? Colors.white.withValues(alpha: 0.16 * alphaMul) : const Color(0x180F172A)))
        ..style = PaintingStyle.fill,
    );

    // ── 2. Inner Bridge Facets ────────────────────────────────────────────────
    final pInnerTop = Path()..moveTo(it.dx, it.dy)..lineTo(ir.dx, ir.dy)..lineTo(cr.dx, cr.dy)..lineTo(ct.dx, ct.dy)..close();
    final pInnerLeft = Path()..moveTo(it.dx, it.dy)..lineTo(ct.dx, ct.dy)..lineTo(cl.dx, cl.dy)..lineTo(il.dx, il.dy)..close();
    final pInnerBottom = Path()..moveTo(il.dx, il.dy)..lineTo(cl.dx, cl.dy)..lineTo(cb.dx, cb.dy)..lineTo(ib.dx, ib.dy)..close();
    final pInnerRight = Path()..moveTo(ir.dx, ir.dy)..lineTo(ib.dx, ib.dy)..lineTo(cb.dx, cb.dy)..lineTo(cr.dx, cr.dy)..close();

    canvas.drawPath(
      pInnerTop,
      Paint()..color = (isDark ? Colors.white.withValues(alpha: 0.28 * alphaMul) : const Color(0x250F172A)),
    );
    canvas.drawPath(
      pInnerLeft,
      Paint()..color = (isDark ? Colors.white.withValues(alpha: 0.34 * alphaMul) : const Color(0x300F172A)),
    );
    canvas.drawPath(
      pInnerBottom,
      Paint()..color = (isDark ? Colors.white.withValues(alpha: 0.12 * alphaMul) : const Color(0x120F172A)),
    );
    canvas.drawPath(
      pInnerRight,
      Paint()..color = (isDark ? Colors.white.withValues(alpha: 0.18 * alphaMul) : const Color(0x1A0F172A)),
    );

    // ── 3. Central Core Diamond (Gleaming Nucleus) ───────────────────────────
    final pCore = Path()..moveTo(ct.dx, ct.dy)..lineTo(cr.dx, cr.dy)..lineTo(cb.dx, cb.dy)..lineTo(cl.dx, cl.dy)..close();
    canvas.drawPath(
      pCore,
      Paint()
        ..color = (isActive
            ? accentColor.withValues(alpha: 0.85)
            : (isDark ? Colors.white.withValues(alpha: 0.65) : const Color(0x700F172A)))
        ..style = PaintingStyle.fill,
    );

    // ── 4. Wireframe Facet Lines & Outer Bevel ────────────────────────────────
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.9, size.width * 0.035)
      ..strokeCap = StrokeCap.round
      ..color = isActive
          ? accentColor.withValues(alpha: 0.95)
          : (isDark
              ? Colors.white.withValues(alpha: isCompleted ? 0.70 : 0.35)
              : const Color(0x550F172A));

    // Outer boundary
    final outerPath = Path()..moveTo(ot.dx, ot.dy)..lineTo(or.dx, or.dy)..lineTo(ob.dx, ob.dy)..lineTo(ol.dx, ol.dy)..close();
    canvas.drawPath(outerPath, strokePaint);

    // Inner diamond wireframe
    final innerWire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.65, size.width * 0.024)
      ..color = isActive
          ? accentColor.withValues(alpha: 0.60)
          : (isDark ? Colors.white.withValues(alpha: 0.30) : const Color(0x300F172A));

    final innerPath = Path()..moveTo(it.dx, it.dy)..lineTo(ir.dx, ir.dy)..lineTo(ib.dx, ib.dy)..lineTo(il.dx, il.dy)..close();
    canvas.drawPath(innerPath, innerWire);

    // Radial facet spokes (ot->it, or->ir, ob->ib, ol->il)
    canvas.drawLine(ot, it, innerWire);
    canvas.drawLine(or, ir, innerWire);
    canvas.drawLine(ob, ib, innerWire);
    canvas.drawLine(ol, il, innerWire);

    // Subtle bloom for active state
    if (isActive && isDark) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
        ..color = accentColor.withValues(alpha: 0.35);
      canvas.drawPath(outerPath, glowPaint);
    }
  }

  void _paintLockedDiamond(
    Canvas canvas,
    Offset ot,
    Offset or,
    Offset ob,
    Offset ol,
    double cx,
    double cy,
    double r,
  ) {
    final outerPath = Path()..moveTo(ot.dx, ot.dy)..lineTo(or.dx, or.dy)..lineTo(ob.dx, ob.dy)..lineTo(ol.dx, ol.dy)..close();

    // Subtle dark translucent fill
    canvas.drawPath(
      outerPath,
      Paint()
        ..color = isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0x0C0F172A)
        ..style = PaintingStyle.fill,
    );

    // Subdued outline
    canvas.drawPath(
      outerPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = isDark ? Colors.white.withValues(alpha: 0.18) : const Color(0x250F172A),
    );

    // Clean micro padlock icon in center
    final lockPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.40) : const Color(0x500F172A)
      ..style = PaintingStyle.fill;

    final bodyW = r * 0.42;
    final bodyH = r * 0.34;
    final bodyRect = Rect.fromCenter(
      center: Offset(cx, cy + (r * 0.08)),
      width: bodyW,
      height: bodyH,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, Radius.circular(bodyW * 0.22)),
      lockPaint,
    );

    // Shackle
    final shacklePaint = Paint()
      ..color = lockPaint.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.1, r * 0.10)
      ..strokeCap = StrokeCap.round;

    final shackleR = bodyW * 0.32;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy - (r * 0.04)), radius: shackleR),
      math.pi,
      math.pi,
      false,
      shacklePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CrystalEmblemPainter old) =>
      old.isActive != isActive ||
      old.isCompleted != isCompleted ||
      old.isLocked != isLocked ||
      old.accentColor != accentColor ||
      old.isDark != isDark;
}
