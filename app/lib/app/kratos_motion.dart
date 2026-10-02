import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'kratos_theme.dart';

/// KRATOS Motion Tokens & Utilities — Clean Baseline.
/// Custom animations, blurs, and spring dynamics are neutralized
/// while keeping functional contracts intact.
class KratosMotion {
  static const Duration pageEntranceDuration = Duration(milliseconds: 200);
  static const double pageEntranceDistance = 0.0;
  static const double pageEntranceInitialScale = 1.0;
  static const Curve pageEntranceCurve = Curves.linear;

  static const Duration staggerStepDuration = Duration.zero;
  static const Duration staggerWindowCap = Duration.zero;

  static const Duration numberDuration = Duration.zero;
  static const Curve numberCurve = Curves.linear;

  static const Duration progressDuration = Duration.zero;
  static const Curve progressCurve = Curves.linear;

  static const Duration pressDownDuration = Duration.zero;
  static const Duration pressReleaseDuration = Duration.zero;
  static const double buttonPressScaleWeb = 1.0;
  static const double buttonPressScaleMobile = 1.0;
  static const Curve pressCurve = Curves.linear;
  static const Curve releaseCurve = Curves.linear;

  static const Duration switchDuration = Duration(milliseconds: 150);
  static const Curve switchCurve = Curves.linear;

  static const Duration modalDuration = Duration(milliseconds: 200);
  static const double modalDistance = 0.0;
  static const double modalInitialScale = 1.0;
  static const Curve modalCurve = Curves.linear;

  static const Duration mobileTabDuration = Duration(milliseconds: 150);
  static const Duration mobilePageDuration = Duration(milliseconds: 200);
  static const Duration mobilePageReverseDuration = Duration(milliseconds: 150);
  static const Curve iosSpringCurve = Curves.linear;
  static const Curve iosSpringOvershoot = Curves.linear;

  static const Duration webTabDuration = Duration(milliseconds: 150);
  static const Duration webPageDuration = Duration(milliseconds: 200);
  static const Duration webPageReverseDuration = Duration(milliseconds: 150);
  static const Curve webCurve = Curves.linear;

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

  static Curve get standardCurve => Curves.linear;
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
    if (MediaQuery.of(context).disableAnimations) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: widget.child,
        );
      },
    );
  }
}

/// Clean tab transition replacing custom parallax & scale transitions.
class KratosTabTransition extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final content = IndexedStack(
      index: currentIndex,
      children: children,
    );

    if (onSwipeLeft == null && onSwipeRight == null) {
      return content;
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0.0;
        if (velocity > 280) {
          onSwipeRight?.call();
        } else if (velocity < -280) {
          onSwipeLeft?.call();
        }
      },
      child: content,
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

/// Standard page route with header support.
class KratosPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  static Widget Function(BuildContext context)? globalHeaderBuilder;

  KratosPageRoute({required this.page, super.settings})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              _withGlobalHeader(context, page),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
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

/// Neutral pass-through replacing animated page entrance.
class KratosPageEntrance extends StatelessWidget {
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
  Widget build(BuildContext context) => child;
}

/// Clean container list replacing staggered entrance waves.
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
    if (direction == Axis.vertical) {
      return Column(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: children,
      );
    } else {
      return Row(
        crossAxisAlignment: crossAxisAlignment,
        mainAxisSize: mainAxisSize,
        children: children,
      );
    }
  }
}

/// Direct progress builder without artificial animation delays.
class KratosProgressAnimation extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return builder(context, value.clamp(0.0, 1.0));
  }
}

/// Direct metric formatter without animation counting delays.
class KratosAnimatedMetric extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Text(formatter(value), style: style);
  }
}

/// Direct tactile pressable wrapper.
class KratosPressable extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: behavior,
      onTap: onTap,
      child: child,
    );
  }
}

/// Standard switch replacing custom neon-accented toggle.
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
    return Switch(
      value: value,
      onChanged: onChanged,
    );
  }
}
