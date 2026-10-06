import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'kratos_motion.dart';
import 'kratos_theme.dart';

/// Surface variant types for the unified KRATOS Liquid Glass card system.
enum KratosSurfaceVariant {
  /// Standard calm translucent glass with specular reflection rim and gentle depth.
  normal,

  /// Slightly higher prominence with deeper ambient drop shadow.
  elevated,

  /// Active equipment surface with thin Acid/Lime active stroke (#EEFF08) and subtle ambient glow.
  active,

  /// Interactive surface with hover highlight and tactile physics.
  interactive,

  /// Dimmed, muted surface with reduced border contrast and disabled interactions.
  disabled,

  /// Selected state with subtle lime tint and active stroke.
  selected,
}

/// KRATOS Premium Apple-inspired Liquid Glass Card.
/// Multi-layered physical surface with depth shadow, dark translucent glass body,
/// inner reflection sheen, thin specular rim, and interactive tactile response.
class KratosGlassCard extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;
  final bool interactive;
  final bool dashboardGlass;
  final KratosSurfaceVariant variant;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;

  const KratosGlassCard({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.accentColor,
    this.padding,
    this.interactive = false,
    this.dashboardGlass = true,
    this.variant = KratosSurfaceVariant.normal,
    this.selected = false,
    this.disabled = false,
    this.onTap,
  });

  @override
  State<KratosGlassCard> createState() => _KratosGlassCardState();
}

class _KratosGlassCardState extends State<KratosGlassCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = widget.accentColor ??
        (isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime);

    final isDisabled = widget.disabled || widget.variant == KratosSurfaceVariant.disabled;
    final isActive = !isDisabled &&
        (widget.selected ||
            widget.variant == KratosSurfaceVariant.active ||
            widget.variant == KratosSurfaceVariant.selected);
    final isElevated = widget.variant == KratosSurfaceVariant.elevated;
    final isInteractive = !isDisabled &&
        (widget.interactive ||
            widget.variant == KratosSurfaceVariant.interactive ||
            widget.onTap != null);

    // Border styling
    final Color baseBorderColor;
    final double borderWidth;
    if (isDisabled) {
      baseBorderColor = isDark
          ? Colors.white.withValues(alpha: 0.05)
          : const Color(0x0F0F172A);
      borderWidth = 1.0;
    } else if (isActive) {
      baseBorderColor = accent.withValues(alpha: isDark ? 0.70 : 0.80);
      borderWidth = 1.2;
    } else if (isElevated) {
      baseBorderColor = isDark
          ? (_hovered
              ? accent.withValues(alpha: 0.40)
              : Colors.white.withValues(alpha: 0.14))
          : (_hovered
              ? accent.withValues(alpha: 0.55)
              : KratosTheme.lightBorderGlass);
      borderWidth = 1.0;
    } else {
      baseBorderColor = isDark
          ? (_hovered
              ? accent.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.10))
          : (_hovered
              ? accent.withValues(alpha: 0.50)
              : KratosTheme.lightBorderGlass);
      borderWidth = 1.0;
    }

    // Shadow layering (Layer 1)
    final List<BoxShadow> shadows;
    if (isDisabled) {
      shadows = [
        BoxShadow(
          color: isDark ? Colors.black.withValues(alpha: 0.15) : const Color(0x050F172A),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];
    } else if (isActive) {
      shadows = [
        // Subtle external equipment glow
        BoxShadow(
          color: accent.withValues(alpha: isDark ? (_hovered ? 0.20 : 0.14) : (_hovered ? 0.15 : 0.10)),
          blurRadius: _hovered ? 24 : 18,
          offset: const Offset(0, 4),
        ),
        // Ambient depth
        BoxShadow(
          color: isDark ? Colors.black.withValues(alpha: 0.48) : const Color(0x0E0F172A),
          blurRadius: 22,
          offset: const Offset(0, 6),
        ),
        if (isDark)
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.04),
            blurRadius: 1,
            offset: const Offset(0, 1),
          )
        else
          const BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
      ];
    } else if (isElevated) {
      shadows = [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: _hovered ? 0.60 : 0.50)
              : const Color(0x140F172A),
          blurRadius: _hovered ? 32 : 24,
          offset: const Offset(0, 8),
        ),
        if (isDark)
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.04),
            blurRadius: 1,
            offset: const Offset(0, 1),
          )
        else
          const BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
      ];
    } else {
      shadows = [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: _hovered ? 0.50 : 0.38)
              : const Color(0x0C0F172A),
          blurRadius: _hovered ? 24 : 18,
          offset: const Offset(0, 6),
        ),
        if (isDark)
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.03),
            blurRadius: 1,
            offset: const Offset(0, 1),
          )
        else
          const BoxShadow(
            color: Color(0x05000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
      ];
    }

    // Body gradient (Layer 2)
    final Gradient bodyGradient;
    if (isDark) {
      if (isActive) {
        bodyGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF171B18).withValues(alpha: 0.98),
            const Color(0xFF111412).withValues(alpha: 0.98),
            const Color(0xFF090B09),
          ],
          stops: const [0.0, 0.45, 1.0],
        );
      } else if (isElevated) {
        bodyGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF191D1A).withValues(alpha: 0.98),
            const Color(0xFF121613).withValues(alpha: 0.98),
            const Color(0xFF0B0D0B),
          ],
          stops: const [0.0, 0.45, 1.0],
        );
      } else {
        bodyGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF151816).withValues(alpha: 0.96),
            const Color(0xFF0F1210).withValues(alpha: 0.98),
            const Color(0xFF080A08),
          ],
          stops: const [0.0, 0.45, 1.0],
        );
      }
    } else {
      bodyGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isActive
            ? const [
                Colors.white,
                Color(0xFFF9FDF5),
                Color(0xFFF1F6EC),
              ]
            : const [
                Colors.white,
                Color(0xFFFAFBFC),
                Color(0xFFF2F4F8),
              ],
        stops: const [0.0, 0.50, 1.0],
      );
    }

    final content = Padding(
      padding: widget.padding ?? const EdgeInsets.all(16),
      child: widget.child,
    );

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget cardWidget = AnimatedContainer(
      duration: disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        gradient: bodyGradient,
        border: Border.all(
          color: baseBorderColor,
          width: borderWidth,
        ),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // Layer 3: Inner hairline sheen gradient
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        (isDark ? Colors.white : accent).withValues(
                          alpha: isDark ? 0.025 : 0.04,
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.25],
                    ),
                  ),
                ),
              ),
            ),
            // Layer 5: Top specular reflection line
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 1.2,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        (isDark ? (isActive ? accent : Colors.white) : accent).withValues(
                          alpha: isDark
                              ? (isActive ? 0.35 : 0.18)
                              : (isActive ? 0.40 : 0.25),
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
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
    );

    if (isDisabled) {
      return Opacity(
        opacity: 0.55,
        child: cardWidget,
      );
    }

    if (!isInteractive) {
      return cardWidget;
    }

    final isWeb = KratosMotion.isWebOrDesktop;
    final targetScale = disableAnimations
        ? 1.0
        : (_pressed
            ? (isWeb
                ? KratosMotion.buttonPressScaleWeb
                : KratosMotion.buttonPressScaleMobile)
            : (isWeb && _hovered ? 1.006 : 1.0));

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) {
        if (mounted) setState(() => _hovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _hovered = false);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Listener(
          onPointerDown: (_) {
            if (mounted) setState(() => _pressed = true);
          },
          onPointerUp: (_) {
            if (mounted) setState(() => _pressed = false);
          },
          onPointerCancel: (_) {
            if (mounted) setState(() => _pressed = false);
          },
          child: AnimatedScale(
            scale: targetScale,
            duration: Duration(
              milliseconds: _pressed
                  ? KratosMotion.pressDownDuration.inMilliseconds
                  : KratosMotion.pressReleaseDuration.inMilliseconds,
            ),
            curve: _pressed ? KratosMotion.pressCurve : KratosMotion.releaseCurve,
            child: cardWidget,
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

/// Floating translucent Liquid Glass navigation bar for mobile shell.
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
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: KratosGlassCard(
        variant: KratosSurfaceVariant.elevated,
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
    final accent = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;
    final active = widget.selected;
    final unselectedColor =
        isDark ? Colors.white54 : KratosTheme.lightTextSecondary;

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final isWeb = KratosMotion.isWebOrDesktop;
    final navPressScale = isWeb
        ? KratosMotion.buttonPressScaleWeb
        : KratosMotion.buttonPressScaleMobile;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: disableAnimations ? 1.0 : (_pressed ? navPressScale : 1.0),
          duration: Duration(
            milliseconds: _pressed
                ? KratosMotion.pressDownDuration.inMilliseconds
                : KratosMotion.pressReleaseDuration.inMilliseconds,
          ),
          curve: _pressed ? KratosMotion.pressCurve : KratosMotion.releaseCurve,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: active
                  ? accent.withValues(alpha: isDark ? 0.14 : 0.12)
                  : (_hovered
                      ? (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0x0F0F172A))
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active
                    ? accent.withValues(alpha: isDark ? 0.40 : 0.50)
                    : Colors.transparent,
              ),
              boxShadow: [
                if (active)
                  BoxShadow(
                    color: accent.withValues(alpha: isDark ? 0.10 : 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  active ? widget.item.activeIcon : widget.item.icon,
                  color: active ? accent : unselectedColor,
                  size: 20,
                ),
                const SizedBox(height: 3),
                Text(
                  widget.item.label,
                  style: TextStyle(
                    color: active
                        ? (isDark ? Colors.white : KratosTheme.lightTextPrimary)
                        : unselectedColor,
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w500,
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

/// Instant pass-through sequence for smooth entry.
class KratosOpeningSequence extends StatefulWidget {
  final VoidCallback onFinished;

  const KratosOpeningSequence({super.key, required this.onFinished});

  @override
  State<KratosOpeningSequence> createState() => _KratosOpeningSequenceState();
}

class _KratosOpeningSequenceState extends State<KratosOpeningSequence> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFinished();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Fixed KRATOS Environment with deep black base, dark volcanic undertones,
/// subtle technical lattice grid, and the geometric crystal/star signature.
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

  static const List<Offset> _arrow = [
    Offset(-120, 900),
    Offset(150, 900),
    Offset(585, 505),
    Offset(980, 95),
    Offset(1260, 95),
    Offset(585, 700),
  ];

  static Color _c(int rgb, double alpha, [double mul = 1.0]) =>
      Color(0xFF000000 | rgb).withValues(alpha: alpha * mul);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;

    _paintBase(canvas, size, rect);
    _paintAtmosphere(canvas, size, rect);
    _paintArrow(canvas, size);
    _paintVignette(canvas, size, rect);
  }

  void _ellipseGlow(
    Canvas canvas,
    Rect clip,
    Offset center,
    double rx,
    double ry,
    List<Color> colors,
    List<double> stops,
  ) {
    canvas.save();
    canvas.clipRect(clip);
    canvas.translate(center.dx, center.dy);
    canvas.scale(rx, ry);
    canvas.drawCircle(
      Offset.zero,
      1.0,
      Paint()..shader = ui.Gradient.radial(Offset.zero, 1.0, colors, stops),
    );
    canvas.restore();
  }

  void _paintBase(Canvas canvas, Size size, Rect rect) {
    // linear-gradient(145deg,#030503,#080b08 52%,#050705)
    const sinA = 0.5736; // sin(145deg)
    const cosA = -0.8192; // cos(145deg)
    final len = size.width * sinA + size.height * 0.8192;
    final c = rect.center;
    final dir = const Offset(sinA, -cosA);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          c - dir * (len / 2),
          c + dir * (len / 2),
          isDark ? const [Color(0xFF030503), Color(0xFF080B08), Color(0xFF050705)] : const [Color(0xFFFFFFFF), Color(0xFFF9FAF7), Color(0xFFF1F3ED)],
          const [0.0, 0.52, 1.0],
        ),
    );

    // radial-gradient(ellipse 70% 55% at 78% 12%, rgba(238,255,8,.12), transparent 64%)
    _ellipseGlow(
      canvas,
      rect,
      Offset(size.width * 0.78, size.height * 0.12),
      size.width * 0.70,
      size.height * 0.55,
      [isDark ? _c(0xEEFF08, .12) : _c(0xA8B800, .13), isDark ? const Color(0x00EEFF08) : const Color(0x00A8B800)],
      const [0.0, 0.64],
    );
    // radial-gradient(ellipse 55% 55% at 8% 88%, rgba(98,124,27,.07), transparent 68%)
    _ellipseGlow(
      canvas,
      rect,
      Offset(size.width * 0.08, size.height * 0.88),
      size.width * 0.55,
      size.height * 0.55,
      [_c(0x627C1B, isDark ? .07 : .09), const Color(0x00627C1B)],
      const [0.0, 0.68],
    );
  }

  void _paintAtmosphere(Canvas canvas, Size size, Rect rect) {
    canvas.save();
    canvas.clipRect(rect);
    // .atmosphere: 900px circle, right:-310 top:-330
    final topCenter = Offset(size.width - 140, 120);
    const topR = 450.0 * 1.4142;
    canvas.drawCircle(
      topCenter,
      450,
      Paint()
        ..shader = ui.Gradient.radial(
          topCenter,
          topR,
          [
            _c(isDark ? 0xEEFF08 : 0xA8B800, isDark ? .22 : .16),
            _c(isDark ? 0xADC419 : 0x98AA10, isDark ? .10 : .08),
            _c(0x485E14, .035),
            const Color(0x00485E14),
          ],
          const [0.0, 0.23, 0.48, 0.72],
        ),
    );
    // .atmosphere-bottom: 680px circle, left:-330 bottom:-350
    final botCenter = Offset(10, size.height + 10);
    const botR = 340.0 * 1.4142;
    canvas.drawCircle(
      botCenter,
      340,
      Paint()
        ..shader = ui.Gradient.radial(
          botCenter,
          botR,
          [
            _c(0x97B11D, isDark ? .12 : .10),
            _c(0x475F14, .045),
            const Color(0x00475F14),
          ],
          const [0.0, 0.40, 0.72],
        ),
    );
    canvas.restore();
  }

  ui.Gradient _bb(
    Rect bb,
    Offset from,
    Offset to,
    List<Color> colors,
    List<double> stops,
  ) {
    return ui.Gradient.linear(
      Offset(bb.left + bb.width * from.dx, bb.top + bb.height * from.dy),
      Offset(bb.left + bb.width * to.dx, bb.top + bb.height * to.dy),
      colors,
      stops,
    );
  }

  Path _poly(List<Offset> pts, {required bool close}) {
    final p = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      p.lineTo(o.dx, o.dy);
    }
    if (close) p.close();
    return p;
  }

  void _paintArrow(Canvas canvas, Size size) {
    final compact = size.width <= 760;
    final double w;
    final double h;
    final double left;
    final double top;
    final double opacity;
    final double wideW;
    final double tightW;
    if (compact) {
      w = 820;
      h = 620;
      left = -310;
      top = -120;
      opacity = .66;
      wideW = 64;
      tightW = 20;
    } else {
      final w105 = size.width * 1.05;
      final w80 = size.width * 0.8;
      w = w105 < 1180 ? w105 : 1180;
      h = w80 < 900 ? w80 : 900;
      left = -150;
      top = -250;
      opacity = .88;
      wideW = 82;
      tightW = 25;
    }

    final arrowRect = Rect.fromLTWH(left, top, w, h);
    canvas.save();
    canvas.clipRect(arrowRect); // svg overflow: hidden
    canvas.saveLayer(
      arrowRect,
      Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
    );
    canvas.translate(left, top);
    canvas.scale(w / 1200, h / 900);

    final body = _poly(_arrow, close: true);
    final bodyBox = Rect.fromLTRB(-120, 95, 1260, 900);

    // arrow-glow-wide
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = wideW
        ..color = isDark ? _c(0xEEFF08, .23, .8) : _c(0xA8B800, .20, .8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 42),
    );
    // arrow-glow-tight
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = tightW
        ..color = isDark ? _c(0xEEFF08, .34, .9) : _c(0xA8B800, .26, .9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
    );
    // arrow-body fill
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = _bb(
          bodyBox,
          const Offset(0, 1),
          const Offset(1, 0),
          [
            isDark ? _c(0x101704, .72) : _c(0xFFFFFF, .78),
            isDark ? _c(0x34400A, .58) : _c(0xE2E9C6, .62),
            _c(0xB8CA24, isDark ? .26 : .30),
            isDark ? _c(0xEEFF08, .40) : _c(0xA8B800, .42),
          ],
          const [0.0, 0.34, 0.62, 1.0],
        ),
    );
    // arrow-body stroke
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..color = isDark ? _c(0xEEFF08, .42) : _c(0xA8B800, .55),
    );

    // arrow-face-a
    final faceA = [const Offset(150, 900), const Offset(585, 505), const Offset(585, 700)];
    canvas.drawPath(
      _poly(faceA, close: true),
      Paint()
        ..shader = _bb(
          const Rect.fromLTRB(150, 505, 585, 900),
          const Offset(0, 1),
          const Offset(1, 0),
          [
            isDark ? _c(0x050804, .86, .72) : _c(0xDDE5C0, .80, .72),
            _c(0x9CAC1D, .28, .72),
            _c(0xFFFFFF, isDark ? .32 : .70, .72),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );
    // arrow-face-b
    final faceB = [
      const Offset(585, 505),
      const Offset(980, 95),
      const Offset(1260, 95),
      const Offset(585, 700),
    ];
    canvas.drawPath(
      _poly(faceB, close: true),
      Paint()
        ..shader = _bb(
          const Rect.fromLTRB(585, 95, 1260, 700),
          const Offset(0, 0),
          const Offset(1, 1),
          [
            _c(0xFFFFFF, isDark ? .30 : .75, .56),
            isDark ? _c(0xEEFF08, .22, .56) : _c(0xA8B800, .22, .56),
            isDark ? _c(0x080B03, .82, .56) : _c(0xD3DDB0, .80, .56),
          ],
          const [0.0, 0.38, 1.0],
        ),
    );

    // arrow-facet (2 polylines)
    final facetPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = isDark ? _c(0xFFFFF2, .22) : _c(0x6B7A10, .22);
    canvas.drawPath(
      _poly(const [Offset(150, 900), Offset(585, 505), Offset(980, 95)], close: false),
      facetPaint,
    );
    canvas.drawPath(
      _poly(const [Offset(585, 700), Offset(585, 505), Offset(1260, 95)], close: false),
      facetPaint,
    );

    // arrow-edge
    canvas.drawPath(
      _poly(
        const [Offset(150, 900), Offset(585, 505), Offset(980, 95), Offset(1260, 95)],
        close: false,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = _bb(
          const Rect.fromLTRB(150, 95, 1260, 900),
          const Offset(0, 1),
          const Offset(1, 0),
          [
            _c(0xFFFFFF, isDark ? .12 : .6, .75),
            isDark ? _c(0xEEFF08, .85, .75) : _c(0xA8B800, .9, .75),
            _c(0xFFFFFF, isDark ? .45 : .9, .75),
            isDark ? _c(0xEEFF08, .65, .75) : _c(0xA8B800, .75, .75),
          ],
          const [0.0, 0.38, 0.72, 1.0],
        ),
    );

    // arrow-reflect
    canvas.drawPath(
      _poly(const [Offset(170, 875), Offset(585, 505), Offset(960, 120)], close: false),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = _c(0xFFFFFF, isDark ? .16 : .9, .45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    canvas.restore(); // layer
    canvas.restore(); // clip
  }

  void _paintVignette(Canvas canvas, Size size, Rect rect) {
    // radial-gradient(ellipse at center, transparent 42%, rgba(0,0,0,.32) 100%)
    _ellipseGlow(
      canvas,
      rect,
      rect.center,
      size.width / 2 * 1.4142,
      size.height / 2 * 1.4142,
      [const Color(0x00000000), const Color(0x00000000), isDark ? const Color(0x52000000) : const Color(0x14101810)],
      const [0.0, 0.42, 1.0],
    );
  }

  @override
  bool shouldRepaint(covariant _KratosAtmospherePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

/// Shared Manus design reference: Section Header with eyebrow, Space Grotesk title,
/// optional trailing description/action, and optional rule divider.
class KratosSectionHeader extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? description;
  final Widget? trailing;
  final bool showRule;
  final EdgeInsetsGeometry padding;

  const KratosSectionHeader({
    super.key,
    this.eyebrow,
    required this.title,
    this.description,
    Widget? trailing,
    Widget? action,
    this.showRule = true,
    this.padding = const EdgeInsets.only(bottom: 14),
  }) : trailing = trailing ?? action;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final mutedTextColor = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (eyebrow != null && eyebrow!.isNotEmpty) ...[
                      Text(
                        eyebrow!.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'IBM Plex Mono',
                          fontSize: 10,
                          letterSpacing: 1.8,
                          color: mutedTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                        color: primaryTextColor,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (description != null && description!.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    description!,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: mutedTextColor,
                      height: 1.35,
                    ),
                  ),
                ),
            ],
          ),
          if (showRule) ...[
            const SizedBox(height: 12),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    KratosTheme.electricLime.withValues(alpha: isDark ? 0.24 : 0.16),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared Manus design reference: Precision chip tag (`.chip`).
class KratosChip extends StatelessWidget {
  final String label;
  final Widget? leading;
  final Color? color;
  final VoidCallback? onTap;

  const KratosChip({
    super.key,
    required this.label,
    this.leading,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = color ?? (isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime);

    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.10 : 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withValues(alpha: isDark ? 0.26 : 0.22),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 5),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'IBM Plex Mono',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: accent,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      chip = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: chip,
      );
    }

    return chip;
  }
}

/// Shared Manus design reference: Track progress indicator (`.progress`).
class KratosProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final Color? activeColor;

  const KratosProgressBar({
    super.key,
    double? progress,
    double? value,
    this.height = 5.0,
    Color? activeColor,
    Color? fillColor,
    String? label,
    bool? showPercentage,
  }) : progress = progress ?? value ?? 0.0,
       activeColor = activeColor ?? fillColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = activeColor ?? (isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime);
    final clamped = progress.clamp(0.0, 1.0);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: clamped,
        child: Container(
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

/// Shared Manus design reference: Precision empty state (`.empty-card`).
class KratosEmptyState extends StatelessWidget {
  final IconData icon;
  final String eyebrow;
  final String title;
  final String message;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onAction;

  const KratosEmptyState({
    super.key,
    required this.icon,
    String? eyebrow,
    required this.title,
    String? message,
    String? subtitle,
    this.action,
    this.actionLabel,
    this.onAction,
  }) : eyebrow = eyebrow ?? 'SYSTEM NOTICE',
       message = message ?? subtitle ?? '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary;
    final mutedTextColor = isDark ? const Color(0xFF686D65) : KratosTheme.lightTextSecondary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: KratosTheme.electricLime.withValues(alpha: isDark ? 0.05 : 0.08),
                border: Border.all(
                  color: KratosTheme.electricLime.withValues(alpha: isDark ? 0.34 : 0.30),
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: KratosTheme.electricLime.withValues(alpha: 0.75),
                size: 26,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              eyebrow.toUpperCase(),
              style: TextStyle(
                fontFamily: 'IBM Plex Mono',
                fontSize: 9,
                letterSpacing: 1.4,
                color: mutedTextColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: mutedTextColor,
                  height: 1.4,
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ] else if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add, size: 16),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: KratosTheme.electricLime,
                  foregroundColor: const Color(0xFF020302),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
