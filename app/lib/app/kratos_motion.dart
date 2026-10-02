import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'kratos_theme.dart';

/// KRATOS High-Performance Motion Engine.
/// Designed for ultra-smooth transitions inspired by Apple iOS 18 fluid physics,
/// with optimized timing and curves differentiated between Mobile (touch/springs)
/// and Web/Desktop (pointer/crisp crossfades).
class KratosMotion {
  // Centralized KRATOS Motion Tokens
  // FAST → SMOOTH DECELERATION → NATURAL SETTLE

  // Page Entrance Tokens (Section 3)
  static const Duration pageEntranceDuration = Duration(milliseconds: 500);
  static const double pageEntranceDistance = 24.0;
  static const double pageEntranceInitialScale = 0.985;
  static const Curve pageEntranceCurve = Cubic(0.16, 1.0, 0.3, 1.0); // Fast start, smooth deceleration, natural settle

  // Stagger Tokens (Section 4)
  static const Duration staggerStepDuration = Duration(milliseconds: 35);
  static const Duration staggerWindowCap = Duration(milliseconds: 320);

  // Number Animation Tokens (Section 5)
  static const Duration numberDuration = Duration(milliseconds: 650);
  static const Curve numberCurve = Cubic(0.16, 1.0, 0.3, 1.0);

  // Progress Animation Tokens (Section 6)
  static const Duration progressDuration = Duration(milliseconds: 750);
  static const Curve progressCurve = Cubic(0.16, 1.0, 0.3, 1.0);

  // Button Press Tokens (Section 7)
  static const Duration pressDownDuration = Duration(milliseconds: 80);
  static const Duration pressReleaseDuration = Duration(milliseconds: 200);
  static const double buttonPressScaleWeb = 0.978;
  static const double buttonPressScaleMobile = 0.968;
  static const Curve pressCurve = Curves.easeOutQuad;
  static const Curve releaseCurve = Cubic(0.25, 1.0, 0.4, 1.0);

  // Switch / Toggle Tokens (Section 8)
  static const Duration switchDuration = Duration(milliseconds: 260);
  static const Curve switchCurve = Cubic(0.2, 0.9, 0.3, 1.0);

  // Modal / Dialog Entrance Tokens (Section 9)
  static const Duration modalDuration = Duration(milliseconds: 450);
  static const double modalDistance = 24.0;
  static const double modalInitialScale = 0.975;
  static const Curve modalCurve = Cubic(0.16, 1.0, 0.3, 1.0);

  // Mobile timings & curves (iOS 18 fluid physics)
  static const Duration mobileTabDuration = Duration(milliseconds: 360);
  static const Duration mobilePageDuration = Duration(milliseconds: 380);
  static const Duration mobilePageReverseDuration = Duration(milliseconds: 320);
  static const Curve iosSpringCurve = Cubic(0.25, 1.0, 0.4, 1.0);
  static const Curve iosSpringOvershoot = Cubic(0.34, 1.56, 0.64, 1.0);

  // Web & Desktop timings & curves (Linear/Raycast speed, zero lag)
  static const Duration webTabDuration = Duration(milliseconds: 220);
  static const Duration webPageDuration = Duration(milliseconds: 240);
  static const Duration webPageReverseDuration = Duration(milliseconds: 200);
  static const Curve webCurve = Curves.easeOutCubic;
  static const SpringDescription pageEntrySpring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 34,
  );

  static bool get isWebOrDesktop =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  static Duration get tabDuration =>
      isWebOrDesktop ? webTabDuration : mobileTabDuration;

  static Duration get pageDuration =>
      isWebOrDesktop ? webPageDuration : mobilePageDuration;

  static Duration get pageReverseDuration =>
      isWebOrDesktop ? webPageReverseDuration : mobilePageReverseDuration;

  static Curve get standardCurve => isWebOrDesktop ? webCurve : iosSpringCurve;
}

/// Transitions.dev-inspired text reveal applied at screen boundaries.
///
/// The child remains unchanged; only its entrance is animated with the
/// source motion tokens: 500ms, 18px lift, 4px blur, and the standard ease.
class KratosTextReveal extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double distance;
  final double blur;

  const KratosTextReveal({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.distance = 18,
    this.blur = 4,
  });

  @override
  State<KratosTextReveal> createState() => _KratosTextRevealState();
}

class _KratosTextRevealState extends State<KratosTextReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..animateWith(SpringSimulation(KratosMotion.pageEntrySpring, 0, 1, 0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    if (disableAnimations) return widget.child;

    final curved = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.22, 1.0, 0.36, 1.0),
    );

    return AnimatedBuilder(
      animation: curved,
      child: widget.child,
      builder: (context, child) {
        final progress = curved.value;
        final offset = widget.distance * (1 - progress);
        final blur = widget.blur * (1 - progress);
        Widget revealed = Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, offset),
            child: Transform.scale(
              scale: 0.988 + (0.012 * progress),
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
        if (blur > 0.05) {
          revealed = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: revealed,
          );
        }
        return revealed;
      },
    );
  }
}

/// Adaptive Tab Transition widget that seamlessly animates switching between
/// main navigation tabs (e.g. in AppShell).
///
/// On Mobile: Directional parallax slide with subtle depth scaling.
/// On Web: Silky smooth scale, slight vertical lift, and crossfade with zero layout shift.
class KratosTabTransition extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;
  final VoidCallback? onSwipeLeft;
  final VoidCallback? onSwipeRight;

  const KratosTabTransition({
    super.key,
    required this.currentIndex,
    required this.children,
    this.onSwipeLeft,
    this.onSwipeRight,
  });

  @override
  State<KratosTabTransition> createState() => _KratosTabTransitionState();
}

class _KratosTabTransitionState extends State<KratosTabTransition> {
  int _previousIndex = 0;
  double _dragDistance = 0.0;

  @override
  void didUpdateWidget(KratosTabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int count = widget.children.length;
    final double direction;
    if (count > 1 && _previousIndex == 0 && widget.currentIndex == count - 1) {
      // Wrapped backward (from 0 to last tab): slides in from left
      direction = -1.0;
    } else if (count > 1 && _previousIndex == count - 1 && widget.currentIndex == 0) {
      // Wrapped forward (from last tab to 0): slides in from right
      direction = 1.0;
    } else {
      direction = widget.currentIndex >= _previousIndex ? 1.0 : -1.0;
    }
    final isWeb = KratosMotion.isWebOrDesktop;

    final content = AnimatedSwitcher(
      duration: KratosMotion.tabDuration,
      switchInCurve: KratosMotion.standardCurve,
      switchOutCurve: isWeb ? Curves.easeInCubic : Curves.easeInQuad,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, animation) {
        final isEntering =
            (child.key as ValueKey<int>?)?.value == widget.currentIndex;

        if (isWeb) {
          // Web: subtle scale + slight vertical lift + clean crossfade
          return KratosTextReveal(
            child: FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: isEntering ? const Offset(0, 0.015) : Offset.zero,
                  end: Offset.zero,
                ).animate(animation),
                child: ScaleTransition(
                  scale: Tween<double>(
                    begin: isEntering ? 0.988 : 1.0,
                    end: isEntering ? 1.0 : 0.995,
                  ).animate(animation),
                  child: child,
                ),
              ),
            ),
          );
        } else {
          // Mobile: Apple iOS-style directional parallax slide
          final slideTween = isEntering
              ? Tween<Offset>(
                  begin: Offset(0.12 * direction, 0),
                  end: Offset.zero,
                )
              : Tween<Offset>(
                  begin: Offset.zero,
                  end: Offset(-0.06 * direction, 0),
                );

          final scaleTween = isEntering
              ? Tween<double>(begin: 0.98, end: 1.0)
              : Tween<double>(begin: 1.0, end: 0.96);

          return KratosTextReveal(
            child: FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: slideTween.animate(animation),
                child: ScaleTransition(
                  scale: scaleTween.animate(animation),
                  child: child,
                ),
              ),
            ),
          );
        }
      },
      child: KeyedSubtree(
        key: ValueKey<int>(widget.currentIndex),
        child: widget.children[widget.currentIndex],
      ),
    );

    if (widget.onSwipeLeft == null && widget.onSwipeRight == null) {
      return content;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _dragDistance = 0.0,
      onHorizontalDragUpdate: (details) {
        _dragDistance += details.primaryDelta ?? 0.0;
      },
      onHorizontalDragEnd: (details) {
        const threshold = 40.0;
        final velocity = details.primaryVelocity ?? 0.0;
        if (_dragDistance > threshold || velocity > 280) {
          // Swiped Right -> user dragged finger to the right (move to previous tab or left tab)
          widget.onSwipeRight?.call();
        } else if (_dragDistance < -threshold || velocity < -280) {
          // Swiped Left -> user dragged finger to the left (move to next tab or right tab)
          widget.onSwipeLeft?.call();
        }
        _dragDistance = 0.0;
      },
      onHorizontalDragCancel: () => _dragDistance = 0.0,
      child: content,
    );
  }
}

/// Universal iOS-style Page Route with high-performance transitions.
class KratosPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  static Widget Function(BuildContext context)? globalHeaderBuilder;

  KratosPageRoute({required this.page, super.settings})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: KratosMotion.pageDuration,
        reverseTransitionDuration: KratosMotion.pageReverseDuration,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final isWeb = KratosMotion.isWebOrDesktop;
          final routePage = _withGlobalHeader(context, child);
          final revealedChild = KratosTextReveal(child: routePage);

          if (isWeb) {
            // Web: silky smooth zoom-fade with fast response
            final curved = CurvedAnimation(
              parent: animation,
              curve: KratosMotion.webCurve,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.975, end: 1.0).animate(curved),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.02),
                    end: Offset.zero,
                  ).animate(curved),
                  child: revealedChild,
                ),
              ),
            );
          } else {
            // Mobile: Apple iOS layered stack slide with secondary push depth
            final primaryCurved = CurvedAnimation(
              parent: animation,
              curve: KratosMotion.iosSpringCurve,
              reverseCurve: Curves.easeInCubic,
            );

            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(primaryCurved),
              child: revealedChild,
            );
          }
        },
      );
}

/// Material-style route with the same persistent authenticated header as
/// [KratosPageRoute], preserving the platform's default route transition.
class KratosMaterialPageRoute<T> extends MaterialPageRoute<T> {
  KratosMaterialPageRoute({required WidgetBuilder builder, super.settings})
    : super(builder: (context) => _withGlobalHeader(context, builder(context)));
}

Widget _withGlobalHeader(BuildContext context, Widget child) {
  final headerBuilder = KratosPageRoute.globalHeaderBuilder;
  if (headerBuilder == null) return child;
  return Column(
    children: [
      SizedBox(height: 64, child: headerBuilder(context)),
      Expanded(child: child),
    ],
  );
}

/// Tactile spring-interactive card wrapper inspired by iOS 3D touch & spring physics.
/// Compresses elastically when tapped and provides visual feedback.
class KratosSpringCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color? glowColor;

  const KratosSpringCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.glowColor,
  });

  @override
  State<KratosSpringCard> createState() => _KratosSpringCardState();
}

class _KratosSpringCardState extends State<KratosSpringCard> {
  bool _pressed = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isWeb = KratosMotion.isWebOrDesktop;
    final pressedScale = isWeb ? 0.985 : 0.965;
    final hoveredScale = isWeb ? 1.012 : 1.0;
    final glow = widget.glowColor ?? KratosTheme.acidLime;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? pressedScale : (_hovered ? hoveredScale : 1.0),
          duration: Duration(milliseconds: _pressed ? 100 : 240),
          curve: _pressed ? Curves.easeOutQuad : KratosMotion.iosSpringCurve,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: _pressed
                  ? [
                      BoxShadow(
                        color: glow.withValues(alpha: 0.25),
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ]
                  : (_hovered
                        ? [
                            BoxShadow(
                              color: glow.withValues(alpha: 0.14),
                              blurRadius: 14,
                            ),
                          ]
                        : null),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Coordinated Page Entrance animation widget (Section 3 & 4).
///
/// Features:
/// - Y offset: +24px -> 0px
/// - Opacity: 0 -> 1
/// - Scale: 0.985 -> 1.0
/// - FAST → DECELERATE → SETTLE curve (Cubic(0.16, 1.0, 0.3, 1.0))
/// - Respects MediaQuery.disableAnimations (reduced motion)
/// - One-shot execution: animates once on entry and STOPS completely.
class KratosPageEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double distance;
  final double initialScale;
  final Duration delay;

  const KratosPageEntrance({
    super.key,
    required this.child,
    this.duration = KratosMotion.pageEntranceDuration,
    this.distance = KratosMotion.pageEntranceDistance,
    this.initialScale = KratosMotion.pageEntranceInitialScale,
    this.delay = Duration.zero,
  });

  @override
  State<KratosPageEntrance> createState() => _KratosPageEntranceState();
}

class _KratosPageEntranceState extends State<KratosPageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: KratosMotion.pageEntranceCurve,
    );
    _play();
  }

  Future<void> _play() async {
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
    }
    if (mounted) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) return widget.child;

    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final progress = _animation.value;
        final offset = widget.distance * (1.0 - progress);
        final scale = widget.initialScale + ((1.0 - widget.initialScale) * progress);

        return Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, offset),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Helper that wraps children in a coordinated staggered entrance wave (Section 4).
///
/// Features:
/// - Stagger: ~35ms between children
/// - Total window cap: 320ms so large lists feel like ONE coordinated wave
/// - Each child enters with KratosPageEntrance
class KratosStaggerList extends StatelessWidget {
  final List<Widget> children;
  final Duration stepDuration;
  final Duration windowCap;
  final Axis direction;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisSize mainAxisSize;

  const KratosStaggerList({
    super.key,
    required this.children,
    this.stepDuration = KratosMotion.staggerStepDuration,
    this.windowCap = KratosMotion.staggerWindowCap,
    this.direction = Axis.vertical,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.min,
  });

  @override
  Widget build(BuildContext context) {
    final count = children.length;
    final maxSteps = (windowCap.inMilliseconds / stepDuration.inMilliseconds).floor();

    final animatedChildren = <Widget>[];
    for (var i = 0; i < count; i++) {
      final stepIndex = i < maxSteps ? i : maxSteps;
      final delay = stepDuration * stepIndex;
      animatedChildren.add(
        KratosPageEntrance(
          delay: delay,
          child: children[i],
        ),
      );
    }

    if (direction == Axis.vertical) {
      return Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: animatedChildren,
      );
    } else {
      return Row(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: animatedChildren,
      );
    }
  }
}

/// Smooth progress animation widget (Section 6).
///
/// Animates from previous value to new value over ~750ms with natural deceleration.
/// Does not animate continuously; stops once settled.
class KratosProgressAnimation extends StatefulWidget {
  final double value; // 0.0 to 1.0
  final Widget Function(BuildContext context, double animatedValue) builder;
  final Duration duration;
  final Curve curve;

  const KratosProgressAnimation({
    super.key,
    required this.value,
    required this.builder,
    this.duration = KratosMotion.progressDuration,
    this.curve = KratosMotion.progressCurve,
  });

  @override
  State<KratosProgressAnimation> createState() => _KratosProgressAnimationState();
}

class _KratosProgressAnimationState extends State<KratosProgressAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  double _lastValue = 0.0;

  @override
  void initState() {
    super.initState();
    _lastValue = widget.value.clamp(0.0, 1.0);
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0.0, end: _lastValue).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(KratosProgressAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final target = widget.value.clamp(0.0, 1.0);
      _animation = Tween<double>(begin: _animation.value, end: target).animate(
        CurvedAnimation(parent: _controller, curve: widget.curve),
      );
      _controller.forward(from: 0.0);
    }
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      return widget.builder(context, widget.value.clamp(0.0, 1.0));
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) => widget.builder(context, _animation.value),
    );
  }
}

/// Smooth number animation for XP, streaks, levels, and progress counters (Section 5).
///
/// Animates numeric value change from previous to target over ~650ms.
/// Maintains a single Text widget with full string formatting (e.g. "5,000 XP"),
/// preserving exact widget tree searchability while rendering smooth counting motion.
class KratosAnimatedMetric extends StatefulWidget {
  final num value;
  final String Function(num animatedValue) formatter;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  const KratosAnimatedMetric({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = KratosMotion.numberDuration,
    this.curve = KratosMotion.numberCurve,
  });

  @override
  State<KratosAnimatedMetric> createState() => _KratosAnimatedMetricState();
}

class _KratosAnimatedMetricState extends State<KratosAnimatedMetric>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  num _lastValue = 0;

  @override
  void initState() {
    super.initState();
    _lastValue = widget.value;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: 0.0, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant KratosAnimatedMetric oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _lastValue = oldWidget.value;
      _animation = Tween<double>(
        begin: _lastValue.toDouble(),
        end: widget.value.toDouble(),
      ).animate(
        CurvedAnimation(parent: _controller, curve: widget.curve),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      return Text(widget.formatter(widget.value), style: widget.style);
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final currentVal = _animation.value;
        return Text(widget.formatter(currentVal), style: widget.style);
      },
    );
  }
}


/// Tactile button press wrapper (Section 7).
///
/// Applies subtle scale on press:
/// - 1.0 -> 0.968–0.978 on press
/// - Returns to 1.0 on release
/// - Immediate tactile feel without bounce or design changes
class KratosPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final HitTestBehavior behavior;

  const KratosPressable({
    super.key,
    required this.child,
    this.onTap,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<KratosPressable> createState() => _KratosPressableState();
}

class _KratosPressableState extends State<KratosPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      return GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap,
        child: widget.child,
      );
    }

    final isWeb = KratosMotion.isWebOrDesktop;
    final pressedScale =
        isWeb ? KratosMotion.buttonPressScaleWeb : KratosMotion.buttonPressScaleMobile;

    return GestureDetector(
      behavior: widget.behavior,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? pressedScale : 1.0,
        duration: _pressed
            ? KratosMotion.pressDownDuration
            : KratosMotion.pressReleaseDuration,
        curve: _pressed ? KratosMotion.pressCurve : KratosMotion.releaseCurve,
        child: widget.child,
      ),
    );
  }
}

/// Physical switch & toggle motion widget (Section 8).
///
/// Preserves exact existing KRATOS switch appearance while animating
/// the thumb smoothly with natural physical spring-deceleration curve.
class KratosPhysicalSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;
  final Color inactiveColor;

  const KratosPhysicalSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor = KratosTheme.acidLime,
    this.inactiveColor = const Color(0x33FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return GestureDetector(
      onTap: enabled ? () => onChanged!(!value) : null,
      child: AnimatedContainer(
        duration: disableAnimations ? Duration.zero : KratosMotion.switchDuration,
        curve: KratosMotion.switchCurve,
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: value
              ? activeColor.withValues(alpha: 0.25)
              : inactiveColor,
          border: Border.all(
            color: value
                ? activeColor.withValues(alpha: 0.8)
                : Colors.white24,
            width: 1,
          ),
        ),
        child: AnimatedAlign(
          duration: disableAnimations ? Duration.zero : KratosMotion.switchDuration,
          curve: KratosMotion.switchCurve,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? activeColor : Colors.white70,
              boxShadow: value
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
