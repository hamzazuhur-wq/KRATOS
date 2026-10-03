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

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;

    if (isDark) {
      // 1. Deep Black Base (#020302 / #050505) with dark volcanic undertone (#260B06)
      final baseGradient = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.15),
        size.longestSide * 0.85,
        [
          const Color(0xFF070908),
          const Color(0xFF040504),
          KratosTheme.deepBlack,
        ],
        const [0.0, 0.55, 1.0],
      );
      canvas.drawRect(rect, Paint()..shader = baseGradient);

      // Subtle lower volcanic warmth (#260B06 undertone)
      final volcanicAmbient = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.85, size.height * 0.88),
          size.longestSide * 0.55,
          [
            KratosTheme.volcanicRed.withValues(alpha: 0.18),
            Colors.transparent,
          ],
          const [0.0, 1.0],
        );
      canvas.drawRect(rect, volcanicAmbient);

      // 2. Subtle Technical Lattice Grid (64px interval, strokeWidth 0.5)
      final gridPaint = Paint()
        ..color = KratosTheme.electricLime.withValues(alpha: 0.02)
        ..strokeWidth = 0.5;

      const step = 64.0;
      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }

      // 3. KRATOS Crystal / Star Geometric Signature (geometric, minimal, subtle)
      final starPaint = Paint()
        ..color = KratosTheme.electricLime.withValues(alpha: 0.14)
        ..strokeWidth = 0.9;
      final dotPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.32)
        ..style = PaintingStyle.fill;

      // Coordinate anchors at 256px intervals (every 4th grid intersection)
      for (double x = step * 2; x < size.width; x += step * 4) {
        for (double y = step * 2; y < size.height; y += step * 4) {
          canvas.drawLine(Offset(x - 3.0, y), Offset(x + 3.0, y), starPaint);
          canvas.drawLine(Offset(x, y - 3.0), Offset(x, y + 3.0), starPaint);
          canvas.drawCircle(Offset(x, y), 0.7, dotPaint);
        }
      }

      // 4. Subtle Vignette to keep viewport center calm, focused, and high-contrast
      final vignetteRadius = size.longestSide * 0.80;
      final vignettePaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.45),
          vignetteRadius,
          [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.22),
            Colors.black.withValues(alpha: 0.55),
          ],
          const [0.45, 0.78, 1.0],
        );
      canvas.drawRect(rect, vignettePaint);
    } else {
      // Light Mode: Sophisticated Architectural Ceramic Canvas
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

      // Subtle top-center ambient accent glow
      final ambientGlow = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, 0),
          size.width * 0.65,
          [
            KratosTheme.lightAcidLime.withValues(alpha: 0.05),
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
