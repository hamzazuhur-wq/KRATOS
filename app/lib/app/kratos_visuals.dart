import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'kratos_theme.dart';

/// Dynamic KRATOS material. It is intentionally not an opaque card:
/// bounded backdrop blur + translucent tint + refraction-like moving sheen
/// + specular edge light + interactive pointer/press response.
class KratosGlassCard extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;
  final bool interactive;
  final bool dashboardGlass;

  const KratosGlassCard({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.accentColor,
    this.padding,
    this.interactive = false,
    this.dashboardGlass = true,
  });

  @override
  State<KratosGlassCard> createState() => _KratosGlassCardState();
}

class _KratosGlassCardState extends State<KratosGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sheen;
  bool _hovered = false;
  bool _pressed = false;
  Offset _pointer = const Offset(0.18, 0.12);

  @override
  void initState() {
    super.initState();
    _sheen = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.dashboardGlass ? 20 : 7),
    );
    // TEMP PERFORMANCE TEST — MOTION DISABLED
    // final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
    //   'Test',
    // );
    // if (!isTest) {
    //   _sheen.repeat();
    // }
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor ?? KratosTheme.acidLime;
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final content = Padding(
      padding: widget.padding ?? const EdgeInsets.all(20),
      child: widget.child,
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pointer = const Offset(0.18, 0.12);
      }),
      onHover: (event) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        final local = box.globalToLocal(event.position);
        setState(
          () => _pointer = Offset(
            (local.dx / box.size.width).clamp(0.0, 1.0),
            (local.dy / box.size.height).clamp(0.0, 1.0),
          ),
        );
      },
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: widget.interactive
              ? (_pressed ? 0.98 : (_hovered ? 1.01 : 1))
              : 1.0,
          duration: Duration(milliseconds: _pressed ? 100 : 240),
          curve: _pressed
              ? Curves.easeOutQuad
              : const Cubic(0.25, 1.0, 0.4, 1.0),
          child: AnimatedBuilder(
            animation: _sheen,
            builder: (context, _) {
              final drift = reduced
                  ? 0.0
                  : math.sin(_sheen.value * math.pi * 2) * 0.10;
              final light = Alignment(
                (_pointer.dx * 2 - 1) + drift,
                _pointer.dy * 2 - 1,
              );
              final interactiveAlpha = widget.dashboardGlass
                  ? (_hovered ? 0.09 : 0.035)
                  : (_hovered ? 0.09 : 0.06);
              final borderAlpha = _pressed ? 0.46 : (_hovered ? 0.34 : 0.22);

              final isDark = Theme.of(context).brightness == Brightness.dark;
              return ClipRRect(
                borderRadius: widget.borderRadius,
                child: Container(
                    decoration: BoxDecoration(
                      color: widget.dashboardGlass
                          ? (isDark ? const Color(0xFF111412) : Colors.white)
                          : (isDark
                              ? const Color(0xFF131614).withValues(alpha: 0.94)
                              : Colors.white),
                      gradient: widget.dashboardGlass
                          ? (isDark
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFF171B18).withValues(alpha: 0.96),
                                    const Color(0xFF111412).withValues(alpha: 0.98),
                                    const Color(0xFF0C0E0D),
                                  ],
                                  stops: const [0, 0.45, 1],
                                )
                              : LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white,
                                    const Color(0xFFFBFBFD),
                                    const Color(0xFFF2F4F8),
                                  ],
                                  stops: const [0, 0.5, 1],
                                ))
                          : null,
                      borderRadius: widget.borderRadius,
                      border: Border.all(
                        color: widget.dashboardGlass
                            ? (isDark
                                ? (_hovered
                                    ? accent.withValues(alpha: 0.35)
                                    : Colors.white.withValues(alpha: 0.12))
                                : (_hovered
                                    ? accent.withValues(alpha: 0.50)
                                    : const Color(0x1F0F172A)))
                            : (isDark
                                ? accent.withValues(alpha: borderAlpha)
                                : const Color(0x1F0F172A)),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(
                                  alpha: _hovered ? 0.45 : (widget.dashboardGlass ? 0.28 : 0.40),
                                )
                              : const Color(0x0A0F172A),
                          blurRadius: widget.dashboardGlass ? 20 : 28,
                          offset: const Offset(0, 8),
                        ),
                        if (isDark)
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.03),
                            blurRadius: 1,
                            offset: const Offset(0, 1),
                          )
                        else
                          const BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                      ],
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Stack(
                        fit: StackFit.passthrough,
                        children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: widget.borderRadius,
                                gradient: RadialGradient(
                                  center: light,
                                  radius: 1.05,
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: interactiveAlpha,
                                    ),
                                    accent.withValues(
                                      alpha: widget.dashboardGlass
                                          ? 0.016
                                          : 0.03,
                                    ),
                                    Colors.transparent,
                                  ],
                                  stops: const [0, 0.24, 0.82],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: widget.borderRadius,
                                gradient: LinearGradient(
                                  begin: const Alignment(-0.9, -1),
                                  end: const Alignment(0.85, 0.9),
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: widget.dashboardGlass
                                          ? 0.065
                                          : 0.12,
                                    ),
                                    Colors.transparent,
                                    accent.withValues(
                                      alpha: widget.dashboardGlass
                                          ? 0.02
                                          : 0.035,
                                    ),
                                  ],
                                  stops: const [0, 0.27, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (widget.dashboardGlass && isDark)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: widget.borderRadius,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        DefaultTextStyle.merge(
                          style: TextStyle(
                            color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                            fontFamily: 'Roboto',
                          ),
                          child: IconTheme.merge(
                            data: IconThemeData(
                              color: isDark ? Colors.white70 : KratosTheme.lightTextSecondary,
                            ),
                            child: content,
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                /* TEMP PERFORMANCE TEST — GLASS DISABLED
                ),
                */
              );
            },
          ),
        ),
      ),
    );
  }
}

class KratosNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const KratosNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Floating translucent navigation material with hover, press, and active glow.
class KratosGlassBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<KratosNavItem> items;

  const KratosGlassBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: KratosGlassCard(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++)
              Expanded(
                child: _KratosNavButton(
                  item: items[index],
                  selected: currentIndex == index,
                  onTap: () => onTap(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Short command-center opening sequence shown when the authenticated shell
/// first appears. Each glyph flips into place in order, then the blurred side
/// panels peel away to reveal the live dashboard underneath.
class KratosOpeningSequence extends StatefulWidget {
  final VoidCallback onFinished;

  const KratosOpeningSequence({super.key, required this.onFinished});

  @override
  State<KratosOpeningSequence> createState() => _KratosOpeningSequenceState();
}

class _KratosOpeningSequenceState extends State<KratosOpeningSequence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _phrase = 'LEVEL UP YOUR LIFE';

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 4000),
          )
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed && mounted) {
              widget.onFinished();
            }
          })
          ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _letterProgress(double value, int index) {
    final delay = (index * 0.045).clamp(0.0, 0.58);
    return ((value - delay) / 0.42).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduced) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished();
      });
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final value = Curves.easeOutCubic.transform(_controller.value);
          final exit = ((value - 0.92) / 0.08).clamp(0.0, 1.0);
          /* TEMP PERFORMANCE TEST — GLASS DISABLED
          final blur = 18 * (1 - Curves.easeInOutCubic.transform(exit));
          */
          final veil = 0.92 * (1 - Curves.easeInCubic.transform(exit));
          final sideTravel = MediaQuery.sizeOf(context).width * 0.52;

          return IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                /* TEMP PERFORMANCE TEST — GLASS DISABLED
                BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: blur,
                    sigmaY: blur * 0.55,
                  ),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: veil),
                  ),
                ),
                */
                ColoredBox(
                  color: Colors.black.withValues(alpha: veil),
                ),
                Transform.translate(
                  offset: Offset(-sideTravel * exit, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: 0.52,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.76 * (1 - exit)),
                              Colors.black.withValues(alpha: 0.16 * (1 - exit)),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(sideTravel * exit, 0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.52,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              Colors.black.withValues(alpha: 0.76 * (1 - exit)),
                              Colors.black.withValues(alpha: 0.16 * (1 - exit)),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: FractionallySizedBox(
                    widthFactor: 0.70,
                    child: Opacity(
                      opacity: (1 - exit).clamp(0.0, 1.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var index = 0; index < _phrase.length; index++)
                              _buildGlyph(_phrase[index], index, value, exit),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlyph(String glyph, int index, double value, double exit) {
    if (glyph == ' ') return const SizedBox(width: 24);
    final progress = _letterProgress(value, index);
    final neon = KratosTheme.acidLime;
    final opacity = (progress * (1 - exit)).clamp(0.0, 1.0);
    final blurSigma = (1 - progress) * 7.5 + (exit * 1.5);

    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      child: Opacity(
        opacity: opacity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text(
            glyph,
            style: TextStyle(
              color: neon,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              decoration: TextDecoration.none,
              decorationThickness: 0,
              shadows: [
                Shadow(color: neon.withValues(alpha: 0.92), blurRadius: 8),
                Shadow(color: neon.withValues(alpha: 0.52), blurRadius: 28),
                Shadow(color: neon.withValues(alpha: 0.24), blurRadius: 58),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KratosNavButton extends StatefulWidget {
  final KratosNavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _KratosNavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_KratosNavButton> createState() => _KratosNavButtonState();
}

class _KratosNavButtonState extends State<_KratosNavButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lime = isDark ? KratosTheme.acidLime : KratosTheme.lightAcidLime;
    final active = widget.selected;
    final unselectedColor =
        isDark ? Colors.white54 : KratosTheme.lightTextSecondary;
    final selectedTextColor =
        isDark ? Colors.white : KratosTheme.lightTextPrimary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: active || _hovered
                ? lime.withValues(alpha: active ? (isDark ? 0.12 : 0.16) : 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: active
                  ? lime.withValues(alpha: isDark ? 0.32 : 0.45)
                  : Colors.transparent,
            ),
            boxShadow: active || _pressed
                ? [
                    BoxShadow(
                      color: lime.withValues(
                        alpha: _pressed
                            ? 0.30
                            : (isDark ? 0.12 : 0.08),
                      ),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: AnimatedScale(
            scale: _pressed ? 0.90 : (_hovered ? 1.06 : 1),
            duration: const Duration(milliseconds: 150),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active ? widget.item.activeIcon : widget.item.icon,
                  color: active ? lime : unselectedColor,
                  size: 20,
                ),
                const SizedBox(height: 3),
                Text(
                  widget.item.label,
                  style: TextStyle(
                    color: active ? selectedTextColor : unselectedColor,
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Static technical atmosphere with crystal/star KRATOS signature.
/// Fully deterministic and GPU-cached with zero per-frame CPU overhead.
class KratosEnvironment extends StatelessWidget {
  const KratosEnvironment({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _KratosAtmospherePainter(isDark: isDark),
          isComplex: true,
          willChange: false,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _KratosAtmospherePainter extends CustomPainter {
  final bool isDark;

  const _KratosAtmospherePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;

    if (isDark) {
      // 1. Dark Volcanic Deep Base with central ambient radial gradient
      final baseGradient = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.18),
        size.longestSide * 0.85,
        [
          const Color(0xFF141815),
          const Color(0xFF0D0F0D),
          const Color(0xFF070807),
        ],
        const [0.0, 0.55, 1.0],
      );
      canvas.drawRect(rect, Paint()..shader = baseGradient);

      // 2. Subtle Static Technical Grid (64px interval)
      final gridPaint = Paint()
        ..color = const Color(0xFFC6F135).withValues(alpha: 0.02)
        ..strokeWidth = 0.5;

      const step = 64.0;
      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }

      // 3. Crystal / Star KRATOS signature coordinates
      final starPaint = Paint()
        ..color = const Color(0xFFC6F135).withValues(alpha: 0.16)
        ..strokeWidth = 1.0;
      final dotPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.38)
        ..style = PaintingStyle.fill;

      for (double x = step * 2; x < size.width; x += step * 4) {
        for (double y = step * 2; y < size.height; y += step * 4) {
          canvas.drawLine(Offset(x - 3.5, y), Offset(x + 3.5, y), starPaint);
          canvas.drawLine(Offset(x, y - 3.5), Offset(x, y + 3.5), starPaint);
          canvas.drawCircle(Offset(x, y), 0.75, dotPaint);
        }
      }

      // 4. Subtle Vignette to keep content areas calm and readable
      final vignetteRadius = size.longestSide * 0.78;
      final vignettePaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.48),
          vignetteRadius,
          [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.25),
            Colors.black.withValues(alpha: 0.50),
          ],
          const [0.45, 0.8, 1.0],
        );
      canvas.drawRect(rect, vignettePaint);
    } else {
      // Light Mode: Sophisticated Off-White / Architectural Ceramic Canvas
      final lightGradient = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [
          const Color(0xFFF9FAFB),
          const Color(0xFFF3F4F6),
          const Color(0xFFE5E7EB),
        ],
        const [0.0, 0.45, 1.0],
      );
      canvas.drawRect(rect, Paint()..shader = lightGradient);

      // Soft top-center ambient accent glow (KRATOS Acid Lime identity)
      final ambientGlow = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, 0),
          size.width * 0.65,
          [
            const Color(0xFFC6F135).withValues(alpha: 0.05),
            Colors.transparent,
          ],
          const [0.0, 1.0],
        );
      canvas.drawRect(rect, ambientGlow);

      // Crisp Technical Lattice Grid
      final lightGridPaint = Paint()
        ..color = const Color(0xFF0F172A).withValues(alpha: 0.025)
        ..strokeWidth = 0.5;

      const step = 64.0;
      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), lightGridPaint);
      }
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), lightGridPaint);
      }

      // Technical Crystal Anchor Points
      final crossPaint = Paint()
        ..color = const Color(0xFF0F172A).withValues(alpha: 0.08)
        ..strokeWidth = 0.8;
      final centerDotPaint = Paint()
        ..color = const Color(0xFF4B5563).withValues(alpha: 0.16)
        ..style = PaintingStyle.fill;

      for (double x = step * 2; x < size.width; x += step * 4) {
        for (double y = step * 2; y < size.height; y += step * 4) {
          canvas.drawLine(Offset(x - 2.5, y), Offset(x + 2.5, y), crossPaint);
          canvas.drawLine(Offset(x, y - 2.5), Offset(x, y + 2.5), crossPaint);
          canvas.drawCircle(Offset(x, y), 0.6, centerDotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _KratosAtmospherePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

/* TEMP PERFORMANCE TEST — DECORATIVE AMBIENT PAINTER DISABLED
class _KratosEnvironmentPainter extends CustomPainter {
  final double phase;
  const _KratosEnvironmentPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = KratosTheme.volcanic);
    if (size.isEmpty) return;

    // A few broad, separated waves create the original spacious energy field:
    // visible gaps, one saturated central current, and no repeated hairlines.
    for (var index = 0; index < 4; index++) {
      _paintEnergyStream(canvas, size, index: index, phase: phase);
    }

    // Keep a quiet dark pocket behind page content so the atmosphere remains
    // a backdrop, not a competing focal point.
    final vignetteRadius = math.max(size.width, size.height) * 0.78;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.48),
      vignetteRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.48),
          vignetteRadius,
          [
            const Color(0xFF030403).withValues(alpha: 0.25),
            const Color(0xFF030403).withValues(alpha: 0.12),
            const Color(0xFF030403).withValues(alpha: 0.0),
          ],
          const [0.0, 0.56, 1.0],
        ),
    );
  }

  void _paintEnergyStream(
    Canvas canvas,
    Size size, {
    required int index,
    required double phase,
  }) {
    final t = phase * math.pi * 2;
    final baseY = size.height * (0.17 + index * 0.22);
    final points = <Offset>[];
    for (var point = 0; point < 9; point++) {
      final u = point / 8;
      final x = size.width * (-0.30 + u * 1.60);
      final drift =
          math.sin(t * 0.62 + index * 0.91 + u * math.pi * 1.35) *
          size.height *
          0.105;
      final nervous =
          math.sin(t * 0.31 + index * 2.7 + u * 5.2) * size.height * 0.038;
      points.add(Offset(x, baseY + drift + nervous));
    }

    Path buildPath() {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (var point = 1; point < points.length - 1; point++) {
        final current = points[point];
        final next = points[point + 1];
        final midpoint = Offset(
          (current.dx + next.dx) / 2,
          (current.dy + next.dy) / 2,
        );
        path.quadraticBezierTo(
          current.dx,
          current.dy,
          midpoint.dx,
          midpoint.dy,
        );
      }
      final penultimate = points[points.length - 2];
      final last = points.last;
      path.quadraticBezierTo(penultimate.dx, penultimate.dy, last.dx, last.dy);
      return path;
    }

    final path = buildPath();
    final color = index.isEven ? KratosTheme.acidLime : const Color(0xFFE4F83A);
    final saturation = index == 1 ? 1.55 : (index == 2 ? 1.12 : 0.72);
    final layers = <({double blur, double alpha, double width})>[
      (blur: 70, alpha: 0.075 * saturation, width: 150),
      (blur: 34, alpha: 0.12 * saturation, width: 92),
      (blur: 14, alpha: 0.17 * saturation, width: 44),
      (blur: 6, alpha: 0.10 * saturation, width: 18),
    ];
    for (final layer in layers) {
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: layer.alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = layer.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, layer.blur),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _KratosEnvironmentPainter oldDelegate) =>
      oldDelegate.phase != phase;
}
*/
