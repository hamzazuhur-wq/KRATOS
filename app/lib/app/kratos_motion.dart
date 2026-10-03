import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'kratos_theme.dart';

/// KRATOS Motion Tokens & Utilities — Clean Baseline.
/// Custom animations, blurs, and spring dynamics are neutralized
/// while keeping functional contracts intact.
class KratosMotion {
  // Motion curve: Fast start, smooth deceleration, natural settle (Apple-level)
  static const Curve standardCurve = Cubic(0.16, 1.0, 0.3, 1.0);

  // Page Entrance Tokens (Section 2)
  static const Duration pageEntranceDuration = Duration(milliseconds: 500);
  static const double pageEntranceDistance = 24.0;
  static const double pageEntranceInitialScale = 0.985;
  static const Curve pageEntranceCurve = Cubic(0.16, 1.0, 0.3, 1.0);

  // Stagger Tokens (Section 3)
  static const Duration staggerStepDuration = Duration(milliseconds: 35);
  static const Duration staggerWindowCap = Duration(milliseconds: 320);

  // Number / KPI Animation Tokens (Section 4)
  static const Duration numberDuration = Duration(milliseconds: 650);
  static const Curve numberCurve = Cubic(0.16, 1.0, 0.3, 1.0);

  // Progress Animation Tokens (Section 5)
  static const Duration progressDuration = Duration(milliseconds: 750);
  static const Curve progressCurve = Cubic(0.16, 1.0, 0.3, 1.0);

  // Button Press Tokens (Section 6)
  static const Duration pressDownDuration = Duration(milliseconds: 80);
  static const Duration pressReleaseDuration = Duration(milliseconds: 200);
  static const double buttonPressScaleWeb = 0.978;
  static const double buttonPressScaleMobile = 0.968;
  static const Curve pressCurve = Curves.easeOutQuad;
  static const Curve releaseCurve = Cubic(0.25, 1.0, 0.4, 1.0);

  // Switch / Toggle Tokens
  static const Duration switchDuration = Duration(milliseconds: 240);
  static const Curve switchCurve = Cubic(0.2, 0.9, 0.3, 1.0);

  // Modal / Dialog Entrance Tokens (Section 9)
  static const Duration modalDuration = Duration(milliseconds: 450);
  static const Duration modalReverseDuration = Duration(milliseconds: 250);
  static const double modalDistance = 24.0;
  static const double modalInitialScale = 0.975;
  static const Curve modalCurve = Cubic(0.16, 1.0, 0.3, 1.0);

  // Navigation / Tab Switch Timings & Curves (Section 10)
  static const Duration mobileTabDuration = Duration(milliseconds: 300);
  static const Duration mobilePageDuration = Duration(milliseconds: 320);
  static const Duration mobilePageReverseDuration = Duration(milliseconds: 280);
  static const Curve iosSpringCurve = Cubic(0.25, 1.0, 0.4, 1.0);

  static const Duration webTabDuration = Duration(milliseconds: 220);
  static const Duration webPageDuration = Duration(milliseconds: 240);
  static const Duration webPageReverseDuration = Duration(milliseconds: 200);
  static const Curve webCurve = Curves.easeOutCubic;

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
}

/// Neutral text reveal with simple fade.
class KratosTextReveal extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double distance;
  final double blur;

  const KratosTextReveal({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 500),
    this.distance = 0,
    this.blur = 0,
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
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Clean tab transition replacing raw instantaneous snaps with smooth horizontal + fade physics.
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

class _KratosTabTransitionState extends State<KratosTabTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  bool _movingForward = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: KratosMotion.tabDuration,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant KratosTabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _movingForward = widget.currentIndex > oldWidget.currentIndex;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _wrapGestures(Widget child) {
    if (widget.onSwipeLeft == null && widget.onSwipeRight == null) {
      return child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0.0;
        if (velocity > 280) {
          widget.onSwipeRight?.call();
        } else if (velocity < -280) {
          widget.onSwipeLeft?.call();
        }
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final content = IndexedStack(
      index: widget.currentIndex,
      children: widget.children,
    );

    if (disableAnimations) {
      return _wrapGestures(content);
    }

    final dx = _movingForward ? 14.0 : -14.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final val = _animation.value;
        return Opacity(
          opacity: val.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset((1.0 - val) * dx, 0),
            child: child,
          ),
        );
      },
      child: _wrapGestures(content),
    );
  }
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

/// Standard page route with header support and fluid 240ms subtle horizontal slide + fade.
class KratosPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  static Widget Function(BuildContext context)? globalHeaderBuilder;

  KratosPageRoute({required this.page, super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              _withGlobalHeader(context, page),
          transitionDuration: KratosMotion.pageDuration,
          reverseTransitionDuration: KratosMotion.pageReverseDuration,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final disableAnimations =
                MediaQuery.maybeOf(context)?.disableAnimations ?? false;
            if (disableAnimations) return child;

            final curved = CurvedAnimation(
              parent: animation,
              curve: KratosMotion.webCurve,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.03, 0),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        );
}

/// Material-style route with global header support.
class KratosMaterialPageRoute<T> extends MaterialPageRoute<T> {
  KratosMaterialPageRoute({required WidgetBuilder builder, super.settings})
      : super(builder: (context) => _withGlobalHeader(context, builder(context)));
}

/// Neutral card wrapper replacing spring dynamics and glows.
class KratosSpringCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final Color? glowColor;

  const KratosSpringCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      child: child,
    );
  }
}

/// Smooth page entrance transition (Section 2).
/// Initial state: opacity: 0, Y offset: +24px, scale: 0.985
/// Final state: opacity: 1, Y offset: 0, scale: 1.0
/// Timing: 500ms with Apple-calibrated Cubic(0.16, 1.0, 0.3, 1.0)
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
    if (widget.delay > Duration.zero) {
      Future.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    } else {
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
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final val = _animation.value;
        return Opacity(
          opacity: val.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - val) * widget.distance),
            child: Transform.scale(
              scale: widget.initialScale + (1.0 - widget.initialScale) * val,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Staggered container list for repeated content groups (Section 3).
/// Capped at 320ms window to prevent long cascading animations.
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
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final widgets = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (disableAnimations) {
        widgets.add(children[i]);
      } else {
        final delayMs = (i * stepDuration.inMilliseconds)
            .clamp(0, windowCap.inMilliseconds);
        widgets.add(
          KratosPageEntrance(
            duration: const Duration(milliseconds: 380),
            distance: 14.0,
            initialScale: 0.99,
            delay: Duration(milliseconds: delayMs),
            child: children[i],
          ),
        );
      }
    }

    if (direction == Axis.vertical) {
      return Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: widgets,
      );
    } else {
      return Row(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: widgets,
      );
    }
  }
}

/// Calm progress builder with smooth interpolation (Section 5).
class KratosProgressAnimation extends StatefulWidget {
  final double value;
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

/// Smooth numeric interpolation for KPIs and metrics (Section 4).
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
        return Text(widget.formatter(_animation.value), style: widget.style);
      },
    );
  }
}

/// Subtle tactile press wrapper for interactive controls (Section 6).
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

/// Physical switch & toggle motion widget.
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

/// Unified modal/dialog entrance wrapper (Section 9).
/// Preferred entrance: opacity 0 -> 1, Y: +24px -> 0, scale: 0.975 -> 1.0.
class KratosModalEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double distance;
  final double initialScale;
  final Curve curve;

  const KratosModalEntrance({
    super.key,
    required this.child,
    this.duration = KratosMotion.modalDuration,
    this.distance = KratosMotion.modalDistance,
    this.initialScale = KratosMotion.modalInitialScale,
    this.curve = KratosMotion.modalCurve,
  });

  @override
  State<KratosModalEntrance> createState() => _KratosModalEntranceState();
}

class _KratosModalEntranceState extends State<KratosModalEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _controller.forward();
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
      builder: (context, child) {
        final val = _animation.value;
        return Opacity(
          opacity: val.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1.0 - val) * widget.distance),
            child: Transform.scale(
              scale: widget.initialScale +
                  (1.0 - widget.initialScale) * val,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Unified dialog launcher with calibrated Apple-like modal entrance (Section 9).
Future<T?> showKratosDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0x99000000),
  String? barrierLabel,
  bool useRootNavigator = true,
  RouteSettings? routeSettings,
}) {
  final disableAnimations =
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: barrierColor,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    transitionDuration:
        disableAnimations ? Duration.zero : KratosMotion.modalDuration,
    pageBuilder: (context, anim, secAnim) => builder(context),
    transitionBuilder: (context, anim, secAnim, child) {
      if (disableAnimations) return child;
      final curved = CurvedAnimation(
        parent: anim,
        curve: KratosMotion.modalCurve,
        reverseCurve: Curves.easeInCubic,
      );
      final val = curved.value;
      return Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1.0 - val) * KratosMotion.modalDistance),
          child: Transform.scale(
            scale: KratosMotion.modalInitialScale +
                (1.0 - KratosMotion.modalInitialScale) * val,
            child: child,
          ),
        ),
      );
    },
  );
}

