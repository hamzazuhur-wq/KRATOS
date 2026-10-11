import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../../app/kratos_theme.dart';
import 'life_areas_radar_models.dart';

/// Interactive, animated native Flutter Radar / Spider Chart for KRATOS Life Areas.
///
/// Features:
/// - Dynamic N-vertex polygon geometry (no hardcoded axes count or coordinates)
/// - Physical coordinate interpolation between old and new datasets (lerp)
/// - Concentric polygon grid levels (20%, 40%, 60%, 80%, 100%)
/// - Distinct axis lines & responsive outer vertex labels
/// - Acid Lime (#EEFF08) stroke & subtle translucent fill
/// - Responsive polar coordinate hit testing (tap & hover)
/// - Accessibility semantics summary
/// - Reduced-motion safety (instant snap when disabled)
class LifeAreasRadarChart extends StatefulWidget {
  final List<RadarLifeAreaEntry> entries;
  final String? selectedId;
  final String? hoveredId;
  final ValueChanged<String?>? onSelected;
  final ValueChanged<String?>? onHovered;
  final double minHeight;

  const LifeAreasRadarChart({
    super.key,
    required this.entries,
    this.selectedId,
    this.hoveredId,
    this.onSelected,
    this.onHovered,
    this.minHeight = 320,
  });

  @override
  State<LifeAreasRadarChart> createState() => _LifeAreasRadarChartState();
}

class _LifeAreasRadarChartState extends State<LifeAreasRadarChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  late List<double> _oldValues;
  late List<double> _targetValues;
  late List<String> _trackedIds;

  Offset? _pointerPosition;
  String? _localHoveredId;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _trackedIds = widget.entries.map((e) => e.id).toList();
    _targetValues = widget.entries.map((e) => e.normalizedProgress).toList();
    // Initial entry: animate from 0.0 to targetValues for a graceful initial reveal
    _oldValues = List<double>.filled(_targetValues.length, 0.0);

    _controller.forward(from: 0.0);
  }

  @override
  void didUpdateWidget(LifeAreasRadarChart oldWidget) {
    super.didUpdateWidget(oldWidget);

    final newIds = widget.entries.map((e) => e.id).toList();
    final newValues = widget.entries.map((e) => e.normalizedProgress).toList();

    // Check if the current animation is running or completed to capture current snapshot
    final currentInterpolated = _calculateCurrentInterpolatedValues();

    bool sameSet = _trackedIds.length == newIds.length;
    if (sameSet) {
      for (var i = 0; i < newIds.length; i++) {
        if (_trackedIds[i] != newIds[i]) {
          sameSet = false;
          break;
        }
      }
    }

    if (sameSet) {
      // Same Life Areas: animate physical vertices from current position to new targets
      _oldValues = List<double>.from(currentInterpolated);
      _targetValues = List<double>.from(newValues);
      _trackedIds = List<String>.from(newIds);
    } else {
      // Life Area set changed: build transition mapping matching IDs
      final mappedOld = <double>[];
      for (final entry in widget.entries) {
        final existingIndex = _trackedIds.indexOf(entry.id);
        if (existingIndex >= 0 && existingIndex < currentInterpolated.length) {
          mappedOld.add(currentInterpolated[existingIndex]);
        } else {
          mappedOld.add(0.0); // Animate brand new areas smoothly from center
        }
      }
      _oldValues = mappedOld;
      _targetValues = List<double>.from(newValues);
      _trackedIds = List<String>.from(newIds);
    }

    final disableMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableMotion) {
      _controller.value = 1.0;
    } else {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<double> _calculateCurrentInterpolatedValues() {
    final t = _animation.value;
    if (_oldValues.length != _targetValues.length) {
      return List<double>.from(_targetValues);
    }
    return List.generate(
      _targetValues.length,
      (i) =>
          ui.lerpDouble(_oldValues[i], _targetValues[i], t) ?? _targetValues[i],
    );
  }

  void _handlePointerMove(Offset localPos, Size size) {
    _pointerPosition = localPos;
    final hitId = _hitTestLifeArea(localPos, size);
    if (_localHoveredId != hitId) {
      setState(() => _localHoveredId = hitId);
      widget.onHovered?.call(hitId);
    }
  }

  void _handlePointerExit() {
    if (_pointerPosition != null || _localHoveredId != null) {
      setState(() {
        _pointerPosition = null;
        _localHoveredId = null;
      });
      widget.onHovered?.call(null);
    }
  }

  void _handleTap(Offset localPos, Size size) {
    final hitId = _hitTestLifeArea(localPos, size);
    if (hitId != null) {
      if (widget.selectedId == hitId) {
        widget.onSelected?.call(null); // Toggle off if already selected
      } else {
        widget.onSelected?.call(hitId);
      }
    }
  }

  String? _hitTestLifeArea(Offset localPos, Size size) {
    if (widget.entries.length < 3) return null;

    final center = Offset(size.width / 2, size.height / 2);
    final count = widget.entries.length;
    final labelMargin = _computeLabelMargin(size.width);
    final maxRadius = math.min(
      (size.width - 2 * labelMargin) / 2,
      (size.height - 2 * labelMargin) / 2,
    );
    if (maxRadius <= 10) return null;

    final interpolated = _calculateCurrentInterpolatedValues();
    const startAngle = -math.pi / 2;

    // 1. Proximity check against vertices (exact data points)
    for (var i = 0; i < count; i++) {
      final angle = startAngle + i * (2 * math.pi / count);
      final r = maxRadius * interpolated[i];
      final vertex = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if ((localPos - vertex).distance <= 24.0) {
        return widget.entries[i].id;
      }
    }

    // 2. Proximity check against outer label/perimeter vertices
    for (var i = 0; i < count; i++) {
      final angle = startAngle + i * (2 * math.pi / count);
      final outerVertex = Offset(
        center.dx + maxRadius * math.cos(angle),
        center.dy + maxRadius * math.sin(angle),
      );
      if ((localPos - outerVertex).distance <= 28.0) {
        return widget.entries[i].id;
      }
    }

    // 3. Polar angle quadrant hit test within chart boundary
    final delta = localPos - center;
    final touchDist = delta.distance;
    if (touchDist > 12.0 && touchDist <= maxRadius * 1.15) {
      var touchAngle = math.atan2(delta.dy, delta.dx);
      // Normalize angle to [0, 2pi) starting from startAngle
      var diffAngle = (touchAngle - startAngle) % (2 * math.pi);
      if (diffAngle < 0) diffAngle += 2 * math.pi;

      final slice = (2 * math.pi) / count;
      final nearestIndex = ((diffAngle + slice / 2) ~/ slice) % count;
      return widget.entries[nearestIndex].id;
    }

    return null;
  }

  double _computeLabelMargin(double width) {
    if (width < 380) return 46.0;
    if (width < 600) return 56.0;
    return 64.0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.length < 3) {
      return _buildMinimalEntriesFallback(context);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeHoverId = widget.hoveredId ?? _localHoveredId;
    final activeSelectedId = widget.selectedId;

    // Build accessibility description
    final semanticsLabel = StringBuffer(
      'Life Areas Balance Radar Chart. Showing ${widget.entries.length} life areas. ',
    );
    for (final e in widget.entries) {
      semanticsLabel.write('${e.name}: ${e.displayPct} percent. ');
    }

    return Semantics(
      label: semanticsLabel.toString(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartWidth = constraints.maxWidth;
          final chartHeight = math
              .max(widget.minHeight, chartWidth * 0.72)
              .clamp(280.0, 440.0);
          final size = Size(chartWidth, chartHeight);

          return MouseRegion(
            onHover: (event) => _handlePointerMove(event.localPosition, size),
            onExit: (_) => _handlePointerExit(),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTapDown: (details) => _handleTap(details.localPosition, size),
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, _) {
                  final interpolated = _calculateCurrentInterpolatedValues();
                  return CustomPaint(
                    size: size,
                    painter: LifeAreasRadarPainter(
                      entries: widget.entries,
                      interpolatedValues: interpolated,
                      selectedId: activeSelectedId,
                      hoveredId: activeHoverId,
                      isDark: isDark,
                      labelMargin: _computeLabelMargin(chartWidth),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMinimalEntriesFallback(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 220,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pie_chart_outline_rounded,
            size: 38,
            color: isDark ? Colors.white38 : Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(
            widget.entries.isEmpty
                ? 'No Life Areas to project on radar'
                : 'At least 3 Life Areas are required for radial projection',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : KratosTheme.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter rendering the dynamic concentric grid, axes, labels, and animated data polygon.
class LifeAreasRadarPainter extends CustomPainter {
  final List<RadarLifeAreaEntry> entries;
  final List<double> interpolatedValues;
  final String? selectedId;
  final String? hoveredId;
  final bool isDark;
  final double labelMargin;

  const LifeAreasRadarPainter({
    required this.entries,
    required this.interpolatedValues,
    required this.selectedId,
    required this.hoveredId,
    required this.isDark,
    required this.labelMargin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = entries.length;
    if (count < 3) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(
      (size.width - 2 * labelMargin) / 2,
      (size.height - 2 * labelMargin) / 2,
    );
    if (maxRadius <= 10) return;

    const startAngle = -math.pi / 2;
    final angleStep = (2 * math.pi) / count;

    // Palette tokens
    final gridLineColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0x180F172A);
    final outerRingColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : const Color(0x280F172A);
    final axisLineColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0x1A0F172A);
    final limeAccent = isDark
        ? KratosTheme.acidLime
        : KratosTheme.lightAcidLime;

    // ── 1. Concentric Regular Polygon Grids (20%, 40%, 60%, 80%, 100%) ──
    const levels = [0.20, 0.40, 0.60, 0.80, 1.00];
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var lIdx = 0; lIdx < levels.length; lIdx++) {
      final level = levels[lIdx];
      final r = maxRadius * level;
      final isOuter = lIdx == levels.length - 1;

      gridPaint.color = isOuter ? outerRingColor : gridLineColor;
      gridPaint.strokeWidth = isOuter ? 1.2 : 0.8;

      final gridPath = Path();
      for (var i = 0; i < count; i++) {
        final angle = startAngle + i * angleStep;
        final pt = Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );
        if (i == 0) {
          gridPath.moveTo(pt.dx, pt.dy);
        } else {
          gridPath.lineTo(pt.dx, pt.dy);
        }
      }
      gridPath.close();
      canvas.drawPath(gridPath, gridPaint);
    }

    // ── 2. Radial Axis Lines from Center to Perimeter ──────────────────
    final axisPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = axisLineColor;

    for (var i = 0; i < count; i++) {
      final entry = entries[i];
      final isCurrentHighlighted =
          entry.id == selectedId || entry.id == hoveredId;

      final angle = startAngle + i * angleStep;
      final outerPt = Offset(
        center.dx + maxRadius * math.cos(angle),
        center.dy + maxRadius * math.sin(angle),
      );

      if (isCurrentHighlighted) {
        final highlightAxisPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = limeAccent.withValues(alpha: isDark ? 0.60 : 0.75);
        canvas.drawLine(center, outerPt, highlightAxisPaint);
      } else {
        canvas.drawLine(center, outerPt, axisPaint);
      }
    }

    // ── 3. Data Polygon: Fill & Stroke with Interpolated Values ────────
    final dataPoints = <Offset>[];
    for (var i = 0; i < count; i++) {
      final val = (i < interpolatedValues.length ? interpolatedValues[i] : 0.0)
          .clamp(0.0, 1.0);
      final angle = startAngle + i * angleStep;
      final r = maxRadius * val;
      dataPoints.add(
        Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        ),
      );
    }

    if (dataPoints.isNotEmpty) {
      final dataPath = Path()..moveTo(dataPoints[0].dx, dataPoints[0].dy);
      for (var i = 1; i < dataPoints.length; i++) {
        dataPath.lineTo(dataPoints[i].dx, dataPoints[i].dy);
      }
      dataPath.close();

      // Translucent Lime Fill
      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = limeAccent.withValues(alpha: isDark ? 0.14 : 0.16);
      canvas.drawPath(dataPath, fillPaint);

      // Delicate Glow / Stroke
      final strokePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = limeAccent;
      canvas.drawPath(dataPath, strokePaint);
    }

    // ── 4. Vertex Markers (Small circular nodes on the polygon) ─────────
    for (var i = 0; i < dataPoints.length; i++) {
      final entry = entries[i];
      final pt = dataPoints[i];
      final isCurrentHighlighted =
          entry.id == selectedId || entry.id == hoveredId;

      if (isCurrentHighlighted) {
        // Glowing halo for selected/hovered vertex
        final haloPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = limeAccent.withValues(alpha: isDark ? 0.28 : 0.22);
        canvas.drawCircle(pt, 9.0, haloPaint);

        final vertexBorderPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = isDark ? Colors.black : Colors.white;
        canvas.drawCircle(pt, 5.5, vertexBorderPaint);

        final vertexCorePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = limeAccent;
        canvas.drawCircle(pt, 4.5, vertexCorePaint);
      } else {
        // Standard vertex marker
        final corePaint = Paint()
          ..style = PaintingStyle.fill
          ..color = limeAccent;
        canvas.drawCircle(pt, 3.6, corePaint);

        final ringPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0
          ..color = isDark ? const Color(0xFF0A0C0A) : Colors.white;
        canvas.drawCircle(pt, 3.6, ringPaint);
      }
    }

    // ── 5. Perimeter Axis Labels (Life Area Name & Percentage) ─────────
    for (var i = 0; i < count; i++) {
      final entry = entries[i];
      final isCurrentHighlighted =
          entry.id == selectedId || entry.id == hoveredId;
      final angle = startAngle + i * angleStep;

      // Position slightly outside outer grid
      final labelDist = maxRadius + 14.0;
      final anchor = Offset(
        center.dx + labelDist * math.cos(angle),
        center.dy + labelDist * math.sin(angle),
      );

      _paintAxisLabel(
        canvas: canvas,
        anchor: anchor,
        angle: angle,
        name: entry.name,
        pct: '${entry.displayPct}%',
        isHighlighted: isCurrentHighlighted,
        isDark: isDark,
        limeAccent: limeAccent,
      );
    }
  }

  void _paintAxisLabel({
    required Canvas canvas,
    required Offset anchor,
    required double angle,
    required String name,
    required String pct,
    required bool isHighlighted,
    required bool isDark,
    required Color limeAccent,
  }) {
    final titleColor = isHighlighted
        ? limeAccent
        : (isDark
              ? Colors.white.withValues(alpha: 0.90)
              : KratosTheme.lightTextPrimary);

    final pctColor = isHighlighted
        ? limeAccent
        : (isDark
              ? Colors.white.withValues(alpha: 0.60)
              : KratosTheme.lightTextSecondary);

    final titleSpan = TextSpan(
      text: name,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
        color: titleColor,
        letterSpacing: -0.1,
        fontFamily: 'Geist',
      ),
    );

    final pctSpan = TextSpan(
      text: '\n$pct',
      style: TextStyle(
        fontSize: 11.0,
        fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
        color: pctColor,
        fontFamily: 'GeistMono',
      ),
    );

    final textPainter = TextPainter(
      text: TextSpan(children: [titleSpan, pctSpan]),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    // Align label intelligently based on polar angle quadrant
    final cosVal = math.cos(angle);
    final sinVal = math.sin(angle);

    double posX;
    double posY;

    if (cosVal.abs() < 0.25) {
      // Near top or bottom vertical pole
      posX = anchor.dx - textPainter.width / 2;
      posY = sinVal < 0 ? anchor.dy - textPainter.height - 2 : anchor.dy + 2;
    } else if (cosVal > 0) {
      // Right hemisphere
      posX = anchor.dx + 4;
      posY = anchor.dy - textPainter.height / 2;
    } else {
      // Left hemisphere
      posX = anchor.dx - textPainter.width - 4;
      posY = anchor.dy - textPainter.height / 2;
    }

    textPainter.paint(canvas, Offset(posX, posY));
  }

  @override
  bool shouldRepaint(covariant LifeAreasRadarPainter oldDelegate) {
    if (oldDelegate.isDark != isDark ||
        oldDelegate.selectedId != selectedId ||
        oldDelegate.hoveredId != hoveredId ||
        oldDelegate.labelMargin != labelMargin ||
        oldDelegate.entries.length != entries.length) {
      return true;
    }
    for (var i = 0; i < interpolatedValues.length; i++) {
      if ((oldDelegate.interpolatedValues[i] - interpolatedValues[i]).abs() >
          0.0001) {
        return true;
      }
    }
    return false;
  }
}
