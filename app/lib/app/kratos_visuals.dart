import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'kratos_motion.dart';
import 'kratos_theme.dart';
import 'kratos_card_tokens.dart';

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

/// Position of the directional edge glow line matching KRATOS HTML/CSS spec.
enum KratosEdgeGlowPosition {
  top,
  bottom,
  none,
}

/// KRATOS Premium Liquid Glass Card.
/// Faithful implementation of the HTML/CSS reference specification:
/// - Translucent frosted glass surface (blur 28px) with var(--glass) tint
/// - 135deg linear gradient sheen
/// - Radial top-left corner highlight
/// - Inset 1px top rim highlight
/// - Directional side-edge glow line (.edge) with 3-tier box shadows
/// - Responsive dark/light theme support
class KratosGlassCard extends StatefulWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;
  final bool interactive;
  final bool dashboardGlass;
  final KratosSurfaceVariant variant;
  final bool selected;
  final bool disabled;
  final VoidCallback? onTap;
  final bool showEdgeGlow;
  final KratosEdgeGlowPosition edgeGlowPosition;

  const KratosGlassCard({
    super.key,
    required this.child,
    this.borderRadius,
    this.accentColor,
    this.padding,
    this.interactive = false,
    this.dashboardGlass = true,
    this.variant = KratosSurfaceVariant.normal,
    this.selected = false,
    this.disabled = false,
    this.onTap,
    this.showEdgeGlow = true,
    this.edgeGlowPosition = KratosEdgeGlowPosition.top,
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
    final tokens = theme.extension<KratosCardTokens>() ??
        (isDark ? KratosCardTokens.dark() : KratosCardTokens.light());

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

    final accent = widget.accentColor ?? tokens.accentColor;
    final glowColor = isActive ? accent : (widget.accentColor ?? tokens.glowColor);

    Color baseBorderColor;
    if (isDisabled) {
      baseBorderColor = tokens.borderDisabled;
    } else if (isActive) {
      baseBorderColor = accent.withValues(alpha: isDark ? 0.70 : 0.80);
    } else if (isElevated) {
      baseBorderColor = _hovered
          ? (widget.accentColor ?? tokens.borderElevatedHover)
          : tokens.borderElevated;
    } else {
      baseBorderColor = _hovered
          ? (widget.accentColor ?? tokens.borderHover)
          : tokens.borderNormal;
    }
    final double borderWidth =
        isActive ? tokens.borderWidthActive : tokens.borderWidthNormal;

    List<BoxShadow> shadows;
    if (isDisabled) {
      shadows = tokens.shadowDisabled;
    } else if (isActive) {
      shadows = _hovered ? tokens.shadowActiveHover : tokens.shadowActive;
    } else if (isElevated) {
      shadows = _hovered ? tokens.shadowElevatedHover : tokens.shadowElevated;
    } else {
      shadows = _hovered ? tokens.shadowHover : tokens.shadowNormal;
    }

    Gradient bodyGradient;
    if (isActive) {
      bodyGradient = tokens.backgroundActive;
    } else if (isElevated) {
      bodyGradient = tokens.backgroundElevated;
    } else {
      bodyGradient = tokens.backgroundNormal;
    }

    final Color baseGlassFill = isDisabled
        ? tokens.glassFill.withValues(alpha: tokens.glassFill.a * 0.5)
        : (isActive
            ? Color.alphaBlend(accent.withValues(alpha: 0.06), tokens.glassFill)
            : tokens.glassFill);

    final resolvedRadius =
        widget.borderRadius ?? BorderRadius.circular(tokens.radius);
    final content = Padding(
      padding: widget.padding ?? tokens.defaultPadding,
      child: widget.child,
    );

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget cardWidget = RepaintBoundary(
      child: AnimatedContainer(
        duration: disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: resolvedRadius,
          border: Border.all(
            color: baseBorderColor,
            width: borderWidth,
          ),
          boxShadow: shadows,
        ),
        child: ClipRRect(
          borderRadius: resolvedRadius,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              // Layer 1: Frosted Glass BackdropFilter + Base Tint (var(--glass) + blur(28px))
              Positioned.fill(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(
                    sigmaX: tokens.blurSigma,
                    sigmaY: tokens.blurSigma,
                  ),
                  child: Container(
                    color: baseGlassFill,
                  ),
                ),
              ),

              // Layer 2: 135deg Linear Gradient Sheen (linear-gradient(135deg, #ffffff20, transparent 42%, #ffffff08))
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: bodyGradient,
                    ),
                  ),
                ),
              ),

              // Layer 3: Top-Left Elliptical Radial Sheen (.card:before: radial-gradient(ellipse at 0 0, #ffffff25, transparent 45%))
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.topLeft,
                        radius: 0.9,
                        colors: [
                          tokens.sheenColor
                              .withValues(alpha: tokens.sheenOpacity),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45],
                      ),
                    ),
                  ),
                ),
              ),

              // Layer 4: Inset Top Rim Highlight (inset 0 1px per reference spec)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1.0,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          (isDark
                              ? (isActive
                                  ? const Color(0xFFEEFF08).withValues(alpha: 0.22)
                                  : (isElevated
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.white.withValues(alpha: 0.05)))
                              : (isActive
                                  ? Colors.white.withValues(alpha: 0.72)
                                  : (isElevated
                                      ? Colors.white.withValues(alpha: 0.65)
                                      : Colors.white.withValues(alpha: 0.55)))),
                          (isDark
                              ? (isActive
                                  ? const Color(0xFFEEFF08).withValues(alpha: 0.22)
                                  : (isElevated
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.white.withValues(alpha: 0.05)))
                              : (isActive
                                  ? Colors.white.withValues(alpha: 0.72)
                                  : (isElevated
                                      ? Colors.white.withValues(alpha: 0.65)
                                      : Colors.white.withValues(alpha: 0.55)))),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.06, 0.94, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // Layer 5: Directional Side-Edge Glow (.edge)
              if (widget.showEdgeGlow &&
                  widget.edgeGlowPosition != KratosEdgeGlowPosition.none &&
                  !isDisabled)
                Positioned(
                  top: widget.edgeGlowPosition == KratosEdgeGlowPosition.bottom
                      ? null
                      : 0,
                  bottom: widget.edgeGlowPosition == KratosEdgeGlowPosition.bottom
                      ? 0
                      : null,
                  left: 0,
                  right: 0,
                  height: 2.0,
                  child: IgnorePointer(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final leftPad = widget.edgeGlowPosition ==
                                KratosEdgeGlowPosition.bottom
                            ? width * 0.35
                            : width * 0.09;
                        final rightPad = widget.edgeGlowPosition ==
                                KratosEdgeGlowPosition.bottom
                            ? 0.0
                            : width * 0.15;
                        return Padding(
                          padding: EdgeInsets.only(left: leftPad, right: rightPad),
                          child: Container(
                            height: 2.0,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  glowColor.withValues(alpha: isDark ? 0.90 : 0.80),
                                  Colors.white,
                                  glowColor.withValues(alpha: isDark ? 0.90 : 0.80),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.30, 0.50, 0.70, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: glowColor
                                      .withValues(alpha: isDark ? 0.85 : 0.65),
                                  blurRadius: 9,
                                  spreadRadius: 0,
                                ),
                                BoxShadow(
                                  color: glowColor
                                      .withValues(alpha: isDark ? 0.60 : 0.40),
                                  blurRadius: 24,
                                  spreadRadius: 0,
                                ),
                                BoxShadow(
                                  color: glowColor
                                      .withValues(alpha: isDark ? 0.35 : 0.20),
                                  blurRadius: 38,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              // Layer 6: Content
              DefaultTextStyle.merge(
                style: TextStyle(
                  color: isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextPrimary,
                  fontFamily: 'Roboto',
                ),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: isDark ? const Color(0xFFF3F1E8) : KratosTheme.lightTextSecondary,
                  ),
                  child: content,
                ),
              ),
            ],
          ),
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
            ? (isWeb ? KratosMotion.buttonPressScaleWeb : KratosMotion.buttonPressScaleMobile)
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

/// Procedural fine monochromatic noise generator cached once in memory.
/// Avoids regenerating textures per frame and provides GPU-accelerated repeated shader tiling.
class KratosNoiseGenerator {
  static ui.Image? _cachedNoiseImage;
  static bool _isGenerating = false;
  static final List<VoidCallback> _listeners = [];

  static ui.Image? get cachedImage => _cachedNoiseImage;

  static void ensureInitialized() {
    if (_cachedNoiseImage != null || _isGenerating) return;
    _isGenerating = true;

    const int width = 180;
    const int height = 180;
    final Uint8List pixels = Uint8List(width * height * 4);

    // Seeded pseudo-random generator for deterministic, uniform, fine monochromatic noise
    int seed = 1337;
    int nextRandom() {
      seed = (seed * 1664525 + 1013904223) & 0x7FFFFFFF;
      return seed;
    }

    for (int i = 0; i < width * height; i++) {
      final int val = nextRandom() & 0xFF;
      // Restrained subtle alpha
      final int alpha = 18 + (nextRandom() % 24);
      final int offset = i * 4;
      pixels[offset] = val;
      pixels[offset + 1] = val;
      pixels[offset + 2] = val;
      pixels[offset + 3] = alpha;
    }

    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (ui.Image img) {
        _cachedNoiseImage = img;
        _isGenerating = false;
        for (final listener in _listeners) {
          listener();
        }
        _listeners.clear();
      },
    );
  }

  static void addListener(VoidCallback cb) {
    if (_cachedNoiseImage != null) {
      cb();
    } else {
      _listeners.add(cb);
      ensureInitialized();
    }
  }
}

/// Global KRATOS Glass Environment recreating the reference visual direction:
/// - Deep black (#070908) and warm off-white (#E9E9E3) themes.
/// - 4 large, overlapping, curved translucent glass ribbons with 165°/160° gradients and specular edge reflections.
/// - Multi-layered atmospheric lighting concentrated at opposing corners.
/// - Fine monochromatic procedural grain texture.
/// - Subtle vertical sinusoidal ambient motion across ribbons.
class KratosEnvironment extends StatefulWidget {
  final Widget? child;

  const KratosEnvironment({super.key, this.child});

  @override
  State<KratosEnvironment> createState() => _KratosEnvironmentState();
}

class _KratosEnvironmentState extends State<KratosEnvironment>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 120),
    )..repeat();
    KratosNoiseGenerator.ensureInitialized();
    KratosNoiseGenerator.addListener(_onNoiseLoaded);
  }

  void _onNoiseLoaded() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final backgroundWidget = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _KratosGlassRibbonPainter(
              isDark: isDark,
              timeSeconds:
                  disableAnimations ? 0.0 : _controller.value * 120.0,
              noiseImage: KratosNoiseGenerator.cachedImage,
            ),
            isComplex: true,
            willChange: !disableAnimations,
            child: const SizedBox.expand(),
          );
        },
      ),
    );

    if (widget.child == null) {
      return IgnorePointer(child: backgroundWidget);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: backgroundWidget),
        widget.child!,
      ],
    );
  }
}

class _KratosGlassRibbonPainter extends CustomPainter {
  final bool isDark;
  final double timeSeconds;
  final ui.Image? noiseImage;

  const _KratosGlassRibbonPainter({
    required this.isDark,
    required this.timeSeconds,
    this.noiseImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;

    _paintBaseAndAtmosphere(canvas, size, rect);
    _paintGlassRibbons(canvas, size, rect);
    _paintNoise(canvas, rect);
    _paintVignette(canvas, size, rect);
  }

  void _paintBaseAndAtmosphere(Canvas canvas, Size size, Rect rect) {
    // 1. Base canvas gradient: linear-gradient(145deg, #030503, #080b08 52%, #050705)
    final baseGradient = isDark
        ? const LinearGradient(
            begin: Alignment(-0.82, -0.57),
            end: Alignment(0.82, 0.57),
            colors: [
              Color(0xFF030503),
              Color(0xFF080B08),
              Color(0xFF050705),
            ],
            stops: [0.0, 0.52, 1.0],
          )
        : const LinearGradient(
            begin: Alignment(-0.82, -0.57),
            end: Alignment(0.82, 0.57),
            colors: [
              Color(0xFFF1F3ED),
              Color(0xFFE9E9E3),
              Color(0xFFE7ECE4),
            ],
            stops: [0.0, 0.52, 1.0],
          );

    canvas.drawRect(
      rect,
      Paint()..shader = baseGradient.createShader(rect),
    );

    // 2. Opposing Corner Ambient Glow 1: Top-Right (ellipse 70% 55% at 78% 12%)
    _drawRadialEllipticalGlow(
      canvas: canvas,
      center: Offset(size.width * 0.78, size.height * 0.12),
      radiusX: size.width * 0.70,
      radiusY: size.height * 0.55,
      colors: isDark
          ? [
              const Color(0xFFEEFF08).withValues(alpha: 0.12),
              Colors.transparent,
            ]
          : [
              const Color(0xFFA8B800).withValues(alpha: 0.09),
              Colors.transparent,
            ],
      stops: const [0.0, 0.64],
    );

    // 3. Atmosphere Top-Right Circle (.atmosphere: 900x900 right:-310px top:-330px blur:58px)
    _drawRadialEllipticalGlow(
      canvas: canvas,
      center: Offset(size.width * 0.95, size.height * 0.05),
      radiusX: size.width * 0.65,
      radiusY: size.width * 0.65,
      colors: isDark
          ? [
              const Color(0xFFEEFF08).withValues(alpha: 0.22),
              const Color(0xFFADC419).withValues(alpha: 0.10),
              const Color(0xFF485E14).withValues(alpha: 0.035),
              Colors.transparent,
            ]
          : [
              const Color(0xFFA8B800).withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.55),
              const Color(0xFFE7ECE4).withValues(alpha: 0.15),
              Colors.transparent,
            ],
      stops: const [0.0, 0.23, 0.48, 0.72],
    );

    // 4. Opposing Corner Ambient Glow 2: Bottom-Left (ellipse 55% 55% at 8% 88%)
    _drawRadialEllipticalGlow(
      canvas: canvas,
      center: Offset(size.width * 0.08, size.height * 0.88),
      radiusX: size.width * 0.55,
      radiusY: size.height * 0.55,
      colors: isDark
          ? [
              const Color(0xFF627C1B).withValues(alpha: 0.07),
              Colors.transparent,
            ]
          : [
              const Color(0xFF718000).withValues(alpha: 0.05),
              Colors.transparent,
            ],
      stops: const [0.0, 0.68],
    );

    // 5. Atmosphere Bottom-Left Circle (.atmosphere-bottom: 680x680 left:-330px bottom:-350px blur:50px)
    _drawRadialEllipticalGlow(
      canvas: canvas,
      center: Offset(size.width * 0.05, size.height * 0.95),
      radiusX: size.width * 0.55,
      radiusY: size.width * 0.55,
      colors: isDark
          ? [
              const Color(0xFF97B11D).withValues(alpha: 0.12),
              const Color(0xFF475F14).withValues(alpha: 0.045),
              Colors.transparent,
            ]
          : [
              const Color(0xFFA8B800).withValues(alpha: 0.07),
              const Color(0xFFE7ECE4).withValues(alpha: 0.35),
              Colors.transparent,
            ],
      stops: const [0.0, 0.40, 0.72],
    );
  }

  void _drawRadialEllipticalGlow({
    required Canvas canvas,
    required Offset center,
    required double radiusX,
    required double radiusY,
    required List<Color> colors,
    required List<double> stops,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, radiusY / radiusX);
    canvas.drawCircle(
      Offset.zero,
      radiusX,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          radiusX,
          colors,
          stops,
        ),
    );
    canvas.restore();
  }

  void _drawSingleRibbon({
    required Canvas canvas,
    required double cx,
    required double cy,
    required double width,
    required double height,
    required double angleRad,
    required double waveOffset,
    required double sheenX,
    required double sheenY,
  }) {
    canvas.save();
    canvas.translate(cx, cy + waveOffset);
    canvas.rotate(angleRad);

    final localRect = Rect.fromCenter(
      center: Offset.zero,
      width: width,
      height: height,
    );
    final ribbonPath = Path()..addOval(localRect);

    // 1. Soft outer ambient glow / shadow
    canvas.drawPath(
      ribbonPath,
      Paint()
        ..style = PaintingStyle.fill
        ..color = isDark
            ? const Color(0xFFEEFF08).withValues(alpha: 0.045)
            : const Color(0xFFC8D78C).withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
    );

    // 2. Translucent glass fill with exact 165°/160° linear gradient stops from reference (#kratos-body)
    final fillColors = isDark
        ? const [
            Color(0xB8101704), // #101704 (0.72)
            Color(0x9434400A), // #34400A (0.58)
            Color(0x42B8CA24), // #B8CA24 (0.26)
            Color(0x66EEFF08), // #EEFF08 (0.40)
          ]
        : const [
            Color(0xB8F1F3ED), // #F1F3ED (0.72)
            Color(0x94E7ECE4), // #E7ECE4 (0.58)
            Color(0x5CD6DECE), // #D6DECE (0.36)
            Color(0x40A8B800), // #A8B800 (0.25)
          ];

    canvas.drawPath(
      ribbonPath,
      Paint()
        ..style = PaintingStyle.fill
        ..shader = ui.Gradient.linear(
          Offset(-width * 0.42, -height * 0.42),
          Offset(width * 0.42, height * 0.42),
          fillColors,
          const [0.0, 0.34, 0.62, 1.0],
        ),
    );

    // 3. Hairline glass stroke / border from reference (#kratos-edge)
    final strokeColors = isDark
        ? const [
            Color(0x1FFFFFFF), // #FFFFFF (0.12)
            Color(0xD9EEFF08), // #EEFF08 (0.85)
            Color(0x73FFFFFF), // #FFFFFF (0.45)
            Color(0xA6EEFF08), // #EEFF08 (0.65)
          ]
        : const [
            Color(0x73FFFFFF),
            Color(0xB3A8B800),
            Color(0x8CFFFFFF),
            Color(0x80A8B800),
          ];

    canvas.drawPath(
      ribbonPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..shader = ui.Gradient.linear(
          Offset(-width * 0.45, -height * 0.45),
          Offset(width * 0.45, height * 0.45),
          strokeColors,
          const [0.0, 0.38, 0.72, 1.0],
        ),
    );

    // 4. Inset specular reflection along upper curve
    canvas.save();
    canvas.clipPath(ribbonPath);
    final innerRect = Rect.fromCenter(
      center: Offset(sheenX, -height * 0.03 + sheenY),
      width: width * 0.985,
      height: height * 0.97,
    );
    canvas.drawOval(
      innerRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..shader = ui.Gradient.linear(
          Offset(-width * 0.30, -height * 0.45),
          Offset(width * 0.30, -height * 0.10),
          [
            Colors.transparent,
            Colors.white.withValues(alpha: isDark ? 0.22 : 0.50),
            (isDark ? const Color(0xFFEEFF08) : const Color(0xFFA8B800))
                .withValues(alpha: isDark ? 0.18 : 0.35),
            Colors.transparent,
          ],
          const [0.0, 0.30, 0.70, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.restore();

    canvas.restore();
  }

  void _paintArrowWatermark(Canvas canvas, Size size) {
    final scale = math.max(size.width / 1200.0, size.height / 900.0);
    canvas.save();
    canvas.translate(-150.0 * scale, -250.0 * scale);
    canvas.scale(scale, scale);

    final pBody = Path()
      ..moveTo(-120, 900)
      ..lineTo(150, 900)
      ..lineTo(585, 505)
      ..lineTo(980, 95)
      ..lineTo(1260, 95)
      ..lineTo(585, 700)
      ..close();

    final pFaceA = Path()
      ..moveTo(150, 900)
      ..lineTo(585, 505)
      ..lineTo(585, 700)
      ..close();

    final pFaceB = Path()
      ..moveTo(585, 505)
      ..lineTo(980, 95)
      ..lineTo(1260, 95)
      ..lineTo(585, 700)
      ..close();

    final pFacet1 = Path()
      ..moveTo(150, 900)
      ..lineTo(585, 505)
      ..lineTo(980, 95);

    final pFacet2 = Path()
      ..moveTo(585, 700)
      ..lineTo(585, 505)
      ..lineTo(1260, 95);

    final pEdge = Path()
      ..moveTo(150, 900)
      ..lineTo(585, 505)
      ..lineTo(980, 95)
      ..lineTo(1260, 95);

    final pReflect = Path()
      ..moveTo(170, 875)
      ..lineTo(585, 505)
      ..lineTo(960, 120);

    // Arrow body fill shader (<linearGradient id="kratos-body" x1="0" y1="1" x2="1" y2="0">)
    final bodyPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        const Offset(0, 900),
        const Offset(1200, 0),
        isDark
            ? const [
                Color(0xB8101704), // #101704 (0.72)
                Color(0x9434400A), // #34400A (0.58)
                Color(0x42B8CA24), // #B8CA24 (0.26)
                Color(0x66EEFF08), // #EEFF08 (0.40)
              ]
            : const [
                Color(0xB8F1F3ED),
                Color(0x94E7ECE4),
                Color(0x5CD6DECE),
                Color(0x40A8B800),
              ],
        const [0.0, 0.34, 0.62, 1.0],
      );

    // Arrow body stroke
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..color = isDark
          ? const Color(0xFFEEFF08).withValues(alpha: 0.42)
          : const Color(0xFFA8B800).withValues(alpha: 0.35);

    canvas.drawPath(pBody, bodyPaint);
    canvas.drawPath(pBody, strokePaint);

    // Arrow Face A (<linearGradient id="kratos-face-a" x1="0" y1="1" x2="1" y2="0">)
    final faceAPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        const Offset(150, 900),
        const Offset(585, 505),
        isDark
            ? [
                const Color(0xFF050804).withValues(alpha: 0.86 * 0.72),
                const Color(0xFF9CAC1D).withValues(alpha: 0.28 * 0.72),
                const Color(0xFFFFFFFF).withValues(alpha: 0.32 * 0.72),
              ]
            : [
                const Color(0xFFF1F3ED).withValues(alpha: 0.86 * 0.72),
                const Color(0xFFA8B800).withValues(alpha: 0.28 * 0.72),
                const Color(0xFFFFFFFF).withValues(alpha: 0.32 * 0.72),
              ],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawPath(pFaceA, faceAPaint);

    // Arrow Face B (<linearGradient id="kratos-face-b" x1="0" y1="0" x2="1" y2="1">)
    final faceBPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        const Offset(585, 95),
        const Offset(1260, 700),
        isDark
            ? [
                const Color(0xFFFFFFFF).withValues(alpha: 0.30 * 0.56),
                const Color(0xFFEEFF08).withValues(alpha: 0.22 * 0.56),
                const Color(0xFF080B03).withValues(alpha: 0.82 * 0.56),
              ]
            : [
                const Color(0xFFFFFFFF).withValues(alpha: 0.30 * 0.56),
                const Color(0xFFA8B800).withValues(alpha: 0.22 * 0.56),
                const Color(0xFFE7ECE4).withValues(alpha: 0.82 * 0.56),
              ],
        const [0.0, 0.38, 1.0],
      );
    canvas.drawPath(pFaceB, faceBPaint);

    // Arrow Facets
    final facetPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = isDark
          ? const Color(0xFFFFFFF2).withValues(alpha: 0.22)
          : const Color(0xFFFFFFFF).withValues(alpha: 0.40);
    canvas.drawPath(pFacet1, facetPaint);
    canvas.drawPath(pFacet2, facetPaint);

    // Arrow Edge (<linearGradient id="kratos-edge" x1="0" y1="1" x2="1" y2="0">)
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        const Offset(150, 900),
        const Offset(1260, 95),
        isDark
            ? [
                const Color(0xFFFFFFFF).withValues(alpha: 0.12 * 0.75),
                const Color(0xFFEEFF08).withValues(alpha: 0.85 * 0.75),
                const Color(0xFFFFFFFF).withValues(alpha: 0.45 * 0.75),
                const Color(0xFFEEFF08).withValues(alpha: 0.65 * 0.75),
              ]
            : [
                const Color(0xFFFFFFFF).withValues(alpha: 0.25 * 0.75),
                const Color(0xFFA8B800).withValues(alpha: 0.85 * 0.75),
                const Color(0xFFFFFFFF).withValues(alpha: 0.45 * 0.75),
                const Color(0xFFA8B800).withValues(alpha: 0.65 * 0.75),
              ],
        const [0.0, 0.38, 0.72, 1.0],
      );
    canvas.drawPath(pEdge, edgePaint);

    // Arrow Reflect Line
    final reflectPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..color = Colors.white.withValues(alpha: isDark ? 0.16 * 0.45 : 0.28 * 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawPath(pReflect, reflectPaint);

    canvas.restore();
  }

  void _paintGlassRibbons(Canvas canvas, Size size, Rect rect) {
    // 1. Signature KRATOS Arrow Watermark from reference HTML SVG
    _paintArrowWatermark(canvas, size);

    final w = size.width;
    final h = size.height;

    // Ribbon 1: -28 deg (-0.4887 rad), center (0.475*w, 0.20*h), size 1.45*w x 0.38*h
    _drawSingleRibbon(
      canvas: canvas,
      cx: w * 0.475,
      cy: h * 0.20,
      width: w * 1.45,
      height: h * 0.38,
      angleRad: -28.0 * math.pi / 180.0,
      waveOffset: 12.0 * math.sin(2 * math.pi * timeSeconds / 20.0),
      sheenX: 0,
      sheenY: 0,
    );

    // Ribbon 2: 34 deg (0.5934 rad), center (0.77*w, 0.39*h), size 1.30*w x 0.32*h
    _drawSingleRibbon(
      canvas: canvas,
      cx: w * 0.77,
      cy: h * 0.39,
      width: w * 1.30,
      height: h * 0.32,
      angleRad: 34.0 * math.pi / 180.0,
      waveOffset: 10.0 * math.sin(2 * math.pi * (timeSeconds / 26.0 + 0.25)),
      sheenX: 0,
      sheenY: 0,
    );

    // Ribbon 3: -34 deg (-0.5934 rad), center (0.37*w, 0.645*h), size 1.50*w x 0.37*h
    _drawSingleRibbon(
      canvas: canvas,
      cx: w * 0.37,
      cy: h * 0.645,
      width: w * 1.50,
      height: h * 0.37,
      angleRad: -34.0 * math.pi / 180.0,
      waveOffset: 14.0 * math.sin(2 * math.pi * (timeSeconds / 29.0 + 0.50)),
      sheenX: 0,
      sheenY: 0,
    );

    // Ribbon 4: 31 deg (0.5411 rad), center (0.755*w, 0.84*h), size 1.35*w x 0.30*h
    _drawSingleRibbon(
      canvas: canvas,
      cx: w * 0.755,
      cy: h * 0.84,
      width: w * 1.35,
      height: h * 0.30,
      angleRad: 31.0 * math.pi / 180.0,
      waveOffset: 11.0 * math.sin(2 * math.pi * (timeSeconds / 24.0 + 0.75)),
      sheenX: 0,
      sheenY: 0,
    );
  }

  void _paintNoise(Canvas canvas, Rect rect) {
    final image = noiseImage;
    if (image == null) return;

    final shader = ImageShader(
      image,
      TileMode.repeated,
      TileMode.repeated,
      Matrix4.identity().storage,
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = shader
        ..blendMode = isDark ? BlendMode.softLight : BlendMode.multiply
        ..color = Color.fromRGBO(255, 255, 255, isDark ? 0.22 : 0.14),
    );
  }

  void _paintVignette(Canvas canvas, Size size, Rect rect) {
    // Reference: .vignette{position:absolute;inset:0;background:radial-gradient(ellipse at center,transparent 42%,rgba(0,0,0,.32) 100%)}
    _drawRadialEllipticalGlow(
      canvas: canvas,
      center: rect.center,
      radiusX: size.width * 0.75,
      radiusY: size.height * 0.75,
      colors: isDark
          ? const [
              Color(0x00000000),
              Color(0x00000000),
              Color(0x52000000), // rgba(0, 0, 0, 0.32)
            ]
          : const [
              Color(0x00000000),
              Color(0x00000000),
              Color(0x14000000), // rgba(0, 0, 0, 0.08)
            ],
      stops: const [0.0, 0.42, 1.0],
    );
  }

  @override
  bool shouldRepaint(covariant _KratosGlassRibbonPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.timeSeconds != timeSeconds ||
      oldDelegate.noiseImage != noiseImage;
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
