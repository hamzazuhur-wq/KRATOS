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
