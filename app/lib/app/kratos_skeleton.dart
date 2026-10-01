import 'package:flutter/material.dart';

import 'kratos_visuals.dart';

// ============================================================================
// KRATOS GLOBAL SKELETON SHIMMER LOADING SYSTEM
// Inspired by Motion's Skeleton Shimmer (https://motion.dev/examples/react-skeleton-shimmer)
// Dark Volcanic (#0D0D0D) + Liquid Glass + Subdued Acid Lime (#C6F135) Sheen.
// ============================================================================

/// Centralized motion & visual tokens for the KRATOS Skeleton Shimmer engine.
class KratosSkeletonTokens {
  /// Shimmer sweep cycle duration (1500ms matching Motion reference).
  static const Duration shimmerDuration = Duration(milliseconds: 1500);

  /// Reveal handoff crossfade duration (380ms for responsive fluid handoff).
  static const Duration revealDuration = Duration(milliseconds: 380);

  /// Fast exit duration for outgoing skeletons.
  static const Duration exitDuration = Duration(milliseconds: 200);

  /// Handoff easing curve: smooth cubic deceleration curve.
  static const Curve revealCurve = Cubic(0.22, 1.0, 0.36, 1.0);

  /// Base dark volcanic tone for bone placeholders.
  static const Color boneBaseColor = Color(0xFF141814);

  /// Secondary bone surface tone for higher-contrast elements.
  static const Color boneSurfaceColor = Color(0xFF1A201A);

  /// Subtle specular glass highlight for the shimmer sweep.
  static const Color shimmerHighlightColor = Color(0x28FFFFFF);

  /// Soft Acid Lime reflection for the shimmer sweep (subtle & restrained).
  static const Color shimmerAccentColor = Color(0x18C6F135);

  /// Outer border for skeleton cards matching Liquid Glass aesthetics.
  static const Color boneBorderColor = Color(0x14FFFFFF);

  /// Corner radii tokens
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(20));
  static const BorderRadius innerCardRadius = BorderRadius.all(Radius.circular(14));
  static const BorderRadius chipRadius = BorderRadius.all(Radius.circular(16));
  static const BorderRadius pillRadius = BorderRadius.all(Radius.circular(999));
  static const BorderRadius textRadius = BorderRadius.all(Radius.circular(6));
}

/// Standalone or subtree-wide GPU-accelerated shimmer sweep.
///
/// Wraps any skeleton layout with a single, synchronized [ShaderMask] pass
/// that sweeps a Liquid Glass highlight across all child bones in exact unison.
///
/// If `MediaQuery.disableAnimations` is requested, the sweep is halted and renders
/// a static calm bone surface.
class KratosShimmer extends StatefulWidget {
  final Widget child;

  /// Custom sweep duration (defaults to [KratosSkeletonTokens.shimmerDuration]).
  final Duration duration;

  /// Optional base color override.
  final Color? baseColor;

  /// Optional highlight color override.
  final Color? highlightColor;

  const KratosShimmer({
    super.key,
    required this.child,
    this.duration = KratosSkeletonTokens.shimmerDuration,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<KratosShimmer> createState() => _KratosShimmerState();
}

class _KratosShimmerState extends State<KratosShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduced) {
      return widget.child;
    }

    final highlight = widget.highlightColor ?? KratosSkeletonTokens.shimmerHighlightColor;
    final accent = KratosSkeletonTokens.shimmerAccentColor;

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = _controller.value;
        // Sweep across from -1.5 to +2.5 for clean edge bleed
        final startX = -1.5 + (4.0 * progress);

        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(startX, -0.3),
              end: Alignment(startX + 1.2, 0.3),
              colors: [
                Colors.white.withValues(alpha: 0.0),
                highlight.withValues(alpha: 0.15),
                highlight,
                accent,
                highlight.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.25, 0.48, 0.52, 0.75, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

/// Primitive skeleton bone widget matching KRATOS Liquid Glass geometry.
class KratosBone extends StatelessWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final BoxShape shape;
  final Color? color;
  final Border? border;
  final Widget? child;

  const KratosBone({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.margin,
    this.padding,
    this.shape = BoxShape.rectangle,
    this.color,
    this.border,
    this.child,
  });

  /// Circular bone for avatar / status / action icons.
  const KratosBone.circle({
    super.key,
    required double size,
    this.margin,
    this.color,
    this.border,
  })  : width = size,
        height = size,
        borderRadius = null,
        padding = null,
        shape = BoxShape.circle,
        child = null;

  /// Text-line bone with natural typography proportions.
  const KratosBone.text({
    super.key,
    this.width,
    this.height = 12,
    BorderRadius? borderRadius,
    this.margin = EdgeInsets.zero,
    this.color,
  })  : borderRadius = borderRadius ?? KratosSkeletonTokens.textRadius,
        padding = null,
        shape = BoxShape.rectangle,
        border = null,
        child = null;

  /// Pill/chip bone for filter chips & status tags.
  const KratosBone.chip({
    super.key,
    this.width = 76,
    this.height = 30,
    this.margin = const EdgeInsets.only(right: 8),
    this.color,
  })  : borderRadius = KratosSkeletonTokens.pillRadius,
        padding = null,
        shape = BoxShape.rectangle,
        border = null,
        child = null;

  /// Card bone matching [KratosGlassCard] container shape.
  const KratosBone.card({
    super.key,
    this.width,
    this.height,
    this.margin,
    this.padding = const EdgeInsets.all(18),
    BorderRadius? borderRadius,
    this.color,
    this.border,
    this.child,
  })  : borderRadius = borderRadius ?? KratosSkeletonTokens.cardRadius,
        shape = BoxShape.rectangle;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? KratosSkeletonTokens.boneBaseColor;
    final effectiveBorder = border ??
        (shape == BoxShape.circle
            ? Border.all(color: KratosSkeletonTokens.boneBorderColor, width: 0.8)
            : Border.all(color: KratosSkeletonTokens.boneBorderColor, width: 0.8));

    Widget boneBox = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveColor,
        shape: shape,
        borderRadius: shape == BoxShape.circle ? null : (borderRadius ?? KratosSkeletonTokens.textRadius),
        border: effectiveBorder,
      ),
      child: child,
    );

    return boneBox;
  }
}

/// Smooth handoff transition container.
///
/// Crossfades seamlessly between [skeleton] and [child] once data resolves,
/// with a 4px subtle upward glide matching the Motion reference.
///
/// ZERO FLASH: If [loading] is false on initial mount (e.g. data is cached or
/// already present), [child] is displayed immediately without any transition or skeleton paint.
class SkeletonReveal extends StatelessWidget {
  /// Whether the data is actively loading.
  final bool loading;

  /// Geometry-matched skeleton placeholder.
  final Widget skeleton;

  /// Real resolved UI content.
  final Widget child;

  /// Optional custom handoff duration.
  final Duration duration;

  /// Optional custom curve.
  final Curve curve;

  const SkeletonReveal({
    super.key,
    required this.loading,
    required this.skeleton,
    required this.child,
    this.duration = KratosSkeletonTokens.revealDuration,
    this.curve = KratosSkeletonTokens.revealCurve,
  });

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduced) {
      return loading ? skeleton : child;
    }

    return AnimatedSwitcher(
      duration: duration,
      reverseDuration: KratosSkeletonTokens.exitDuration,
      switchInCurve: curve,
      switchOutCurve: Curves.easeInQuad,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      transitionBuilder: (switcherChild, animation) {
        final isIncomingContent = switcherChild.key == const ValueKey('real_content');

        if (isIncomingContent) {
          final offsetAnim = Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: curve));

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: offsetAnim,
              child: switcherChild,
            ),
          );
        }

        // Outgoing skeleton simply fades cleanly
        return FadeTransition(
          opacity: animation,
          child: switcherChild,
        );
      },
      child: loading
          ? KeyedSubtree(
              key: const ValueKey('skeleton_placeholder'),
              child: KratosShimmer(child: skeleton),
            )
          : KeyedSubtree(
              key: const ValueKey('real_content'),
              child: child,
            ),
    );
  }
}

// ============================================================================
// SPECIALIZED GEOMETRY-MATCHED PAGE & COMPONENT SKELETONS
// ============================================================================

/// Skeleton for [HomeDashboardScreen].
/// Perfectly mirrors: Profile Greeting, Motto line, XpSummaryCard,
/// QuickActionsRow (4 actions), Life Area levels section, Ending Today, and Recent Activity.
class HomeDashboardSkeleton extends StatelessWidget {
  const HomeDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 840;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isWide ? 32 : 18,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Greeting & Personal Caption
              const KratosBone.text(width: 260, height: 22),
              const SizedBox(height: 6),
              const KratosBone.text(width: 190, height: 13),
              const SizedBox(height: 20),

              // 2. XP Summary Card Skeleton
              const XpSummaryCardSkeleton(),
              const SizedBox(height: 18),

              // 3. Quick Actions Row Skeleton
              const QuickActionsSkeleton(),
              const SizedBox(height: 28),

              // 4. Life Area Levels Header
              const Row(
                children: [
                  KratosBone.circle(size: 16),
                  SizedBox(width: 8),
                  KratosBone.text(width: 140, height: 12),
                ],
              ),
              const SizedBox(height: 14),

              // Life Area Level Cards Grid/List
              if (isWide)
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 2.8,
                  children: const [
                    LifeAreaCardSkeleton(),
                    LifeAreaCardSkeleton(),
                    LifeAreaCardSkeleton(),
                    LifeAreaCardSkeleton(),
                  ],
                )
              else
                const Column(
                  children: [
                    LifeAreaCardSkeleton(),
                    SizedBox(height: 12),
                    LifeAreaCardSkeleton(),
                    SizedBox(height: 12),
                    LifeAreaCardSkeleton(),
                  ],
                ),
              const SizedBox(height: 28),

              // 5. Ending Today Section Skeleton
              const Row(
                children: [
                  KratosBone.circle(size: 16),
                  SizedBox(width: 8),
                  KratosBone.text(width: 110, height: 12),
                ],
              ),
              const SizedBox(height: 12),
              const KratosBone.card(
                height: 72,
                child: Row(
                  children: [
                    KratosBone.circle(size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          KratosBone.text(width: 180, height: 13),
                          SizedBox(height: 4),
                          KratosBone.text(width: 100, height: 11),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 6. Recent Activity Section Skeleton
              const Row(
                children: [
                  KratosBone.circle(size: 16),
                  SizedBox(width: 8),
                  KratosBone.text(width: 130, height: 12),
                ],
              ),
              const SizedBox(height: 12),
              const KratosBone.card(
                height: 64,
                child: Row(
                  children: [
                    KratosBone.circle(size: 18),
                    SizedBox(width: 12),
                    Expanded(
                      child: KratosBone.text(width: 160, height: 12),
                    ),
                    KratosBone.chip(width: 50, height: 20),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }
}

/// Geometry-matched skeleton for [XpSummaryCard].
class XpSummaryCardSkeleton extends StatelessWidget {
  const XpSummaryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const KratosBone.card(
      height: 148,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KratosBone.text(width: 68, height: 11),
              Spacer(),
              KratosBone.circle(size: 16),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              KratosBone.text(width: 130, height: 24),
              Spacer(),
              KratosBone.chip(width: 44, height: 20),
            ],
          ),
          SizedBox(height: 12),
          // Progress bar
          KratosBone(
            width: double.infinity,
            height: 6,
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
          SizedBox(height: 10),
          Row(
            children: [
              KratosBone.text(width: 90, height: 10),
              Spacer(),
              KratosBone.text(width: 90, height: 10),
            ],
          ),
        ],
      ),
    );
  }
}

/// Geometry-matched skeleton for [QuickActionsRow].
class QuickActionsSkeleton extends StatelessWidget {
  const QuickActionsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        if (isWide) {
          return const Row(
            children: [
              Expanded(child: KratosBone.card(height: 52)),
              SizedBox(width: 12),
              Expanded(child: KratosBone.card(height: 52)),
              SizedBox(width: 12),
              Expanded(child: KratosBone.card(height: 52)),
              SizedBox(width: 12),
              Expanded(child: KratosBone.card(height: 52)),
            ],
          );
        }

        return const Column(
          children: [
            Row(
              children: [
                Expanded(child: KratosBone.card(height: 52)),
                SizedBox(width: 10),
                Expanded(child: KratosBone.card(height: 52)),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: KratosBone.card(height: 52)),
                SizedBox(width: 10),
                Expanded(child: KratosBone.card(height: 52)),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Geometry-matched skeleton for [LifeAreaLevelCard].
class LifeAreaCardSkeleton extends StatelessWidget {
  const LifeAreaCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const KratosBone.card(
      height: 104,
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: KratosBone.text(width: 120, height: 15)),
              KratosBone.chip(width: 60, height: 20),
            ],
          ),
          SizedBox(height: 10),
          Row(
            children: [
              KratosBone.text(width: 70, height: 12),
              Spacer(),
              KratosBone.text(width: 50, height: 12),
            ],
          ),
          SizedBox(height: 8),
          KratosBone(
            width: double.infinity,
            height: 4,
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for [GoalsScreen].
class GoalsPageSkeleton extends StatelessWidget {
  const GoalsPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Dropdown filter placeholders
        const Row(
          children: [
            Expanded(child: KratosBone.card(height: 42)),
            SizedBox(width: 10),
            Expanded(child: KratosBone.card(height: 42)),
          ],
        ),
        const SizedBox(height: 12),
        // Status filter chips
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              KratosBone.chip(width: 68),
              KratosBone.chip(width: 76),
              KratosBone.chip(width: 80),
              KratosBone.chip(width: 90),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Goal cards
        const GoalCardSkeleton(),
        const SizedBox(height: 12),
        const GoalCardSkeleton(),
        const SizedBox(height: 12),
        const GoalCardSkeleton(),
      ],
    );
  }
}

/// Geometry-matched skeleton for Goal card item.
class GoalCardSkeleton extends StatelessWidget {
  const GoalCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const KratosBone.card(
      height: 128,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KratosBone.circle(size: 20),
              SizedBox(width: 10),
              Expanded(child: KratosBone.text(width: 180, height: 15)),
              KratosBone.chip(width: 54, height: 20),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              KratosBone.chip(width: 70, height: 20),
              SizedBox(width: 8),
              KratosBone.text(width: 80, height: 11),
              Spacer(),
              KratosBone.text(width: 44, height: 11),
            ],
          ),
          SizedBox(height: 10),
          KratosBone(
            width: double.infinity,
            height: 4,
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for [TasksScreen].
class TasksPageSkeleton extends StatelessWidget {
  const TasksPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 110),
      children: [
        // Header
        const Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KratosBone.text(width: 140, height: 20),
                KratosBone.text(width: 220, height: 12),
              ],
            ),
            Spacer(),
            KratosBone.chip(width: 94, height: 34),
          ],
        ),
        const SizedBox(height: 18),
        // Status filter pills
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              KratosBone.chip(width: 72),
              KratosBone.chip(width: 90),
              KratosBone.chip(width: 84),
              KratosBone.chip(width: 60),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Dynamic filters
        const Row(
          children: [
            Expanded(child: KratosBone.card(height: 40)),
            SizedBox(width: 8),
            Expanded(child: KratosBone.card(height: 40)),
          ],
        ),
        const SizedBox(height: 16),
        // Workload summary card
        const KratosBone.card(
          height: 56,
          child: Row(
            children: [
              KratosBone.circle(size: 20),
              SizedBox(width: 12),
              KratosBone.text(width: 140, height: 13),
              Spacer(),
              KratosBone.text(width: 70, height: 13),
            ],
          ),
        ),
        const SizedBox(height: 22),
        // Section title
        const KratosBone.text(width: 90, height: 12),
        const SizedBox(height: 12),
        // Task rows
        const TaskRowSkeleton(),
        const SizedBox(height: 10),
        const TaskRowSkeleton(),
        const SizedBox(height: 10),
        const TaskRowSkeleton(),
        const SizedBox(height: 10),
        const TaskRowSkeleton(),
      ],
    );
  }
}

/// Geometry-matched skeleton for Task list item.
class TaskRowSkeleton extends StatelessWidget {
  const TaskRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const KratosBone.card(
      height: 72,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          KratosBone.circle(size: 22),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                KratosBone.text(width: 160, height: 14),
                SizedBox(height: 6),
                Row(
                  children: [
                    KratosBone.chip(width: 58, height: 16),
                    SizedBox(width: 6),
                    KratosBone.text(width: 64, height: 10),
                  ],
                ),
              ],
            ),
          ),
          KratosBone.chip(width: 48, height: 22),
        ],
      ),
    );
  }
}

/// Skeleton for [ProjectsScreen].
class ProjectsPageSkeleton extends StatelessWidget {
  const ProjectsPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Search bar
        const KratosBone.card(height: 44),
        const SizedBox(height: 12),
        // Status filters
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              KratosBone.chip(width: 68),
              KratosBone.chip(width: 76),
              KratosBone.chip(width: 84),
              KratosBone.chip(width: 72),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Project cards
        const ProjectCardSkeleton(),
        const SizedBox(height: 12),
        const ProjectCardSkeleton(),
        const SizedBox(height: 12),
        const ProjectCardSkeleton(),
      ],
    );
  }
}

/// Geometry-matched skeleton for Project card.
class ProjectCardSkeleton extends StatelessWidget {
  const ProjectCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const KratosBone.card(
      height: 136,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KratosBone.circle(size: 24),
              SizedBox(width: 10),
              Expanded(child: KratosBone.text(width: 150, height: 15)),
              KratosBone.chip(width: 60, height: 20),
            ],
          ),
          SizedBox(height: 10),
          KratosBone.text(width: 220, height: 11),
          SizedBox(height: 12),
          Row(
            children: [
              KratosBone.text(width: 70, height: 11),
              Spacer(),
              KratosBone.text(width: 50, height: 11),
            ],
          ),
          SizedBox(height: 6),
          KratosBone(
            width: double.infinity,
            height: 4,
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for [ActivitiesScreen].
class ActivitiesPageSkeleton extends StatelessWidget {
  const ActivitiesPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Filter bar
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              KratosBone.chip(width: 110, height: 36),
              SizedBox(width: 8),
              KratosBone.chip(width: 90, height: 36),
              SizedBox(width: 8),
              KratosBone.chip(width: 90, height: 36),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // Activity cards
        const ActivityCardSkeleton(),
        const SizedBox(height: 12),
        const ActivityCardSkeleton(),
        const SizedBox(height: 12),
        const ActivityCardSkeleton(),
        const SizedBox(height: 12),
        const ActivityCardSkeleton(),
      ],
    );
  }
}

/// Geometry-matched skeleton for Activity item card.
class ActivityCardSkeleton extends StatelessWidget {
  const ActivityCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const KratosBone.card(
      height: 92,
      child: Row(
        children: [
          KratosBone.circle(size: 36),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                KratosBone.text(width: 160, height: 14),
                SizedBox(height: 6),
                Row(
                  children: [
                    KratosBone.chip(width: 60, height: 18),
                    SizedBox(width: 6),
                    KratosBone.text(width: 80, height: 11),
                  ],
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              KratosBone.chip(width: 50, height: 22),
              SizedBox(height: 6),
              KratosBone.text(width: 36, height: 10),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton for [LevelsDashboardScreen].
class LevelsDashboardSkeleton extends StatelessWidget {
  const LevelsDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
      children: [
        const KratosBone.text(width: 180, height: 11),
        const SizedBox(height: 14),
        // Overall Progression Card Bone
        const KratosBone.card(height: 188),
        const SizedBox(height: 28),
        // Life Area Distribution Header Row Bone
        const Row(
          children: [
            KratosBone.text(width: 160, height: 11),
            Spacer(),
            KratosBone.text(width: 48, height: 11),
          ],
        ),
        const SizedBox(height: 14),
        // Life Area Distribution Card Bones
        const KratosBone.card(height: 94),
        const SizedBox(height: 12),
        const KratosBone.card(height: 94),
        const SizedBox(height: 12),
        const KratosBone.card(height: 94),
      ],
    );
  }
}

/// Skeleton for [SkillsRegistryScreen].
class SkillsPageSkeleton extends StatelessWidget {
  const SkillsPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        const KratosBone.text(width: 220, height: 13),
        const SizedBox(height: 18),
        // Metric chips row
        const Row(
          children: [
            Expanded(child: KratosBone.card(height: 52)),
            SizedBox(width: 10),
            Expanded(child: KratosBone.card(height: 52)),
          ],
        ),
        const SizedBox(height: 14),
        // Search bar
        const KratosBone.card(height: 44),
        const SizedBox(height: 12),
        // Group chips
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              KratosBone.chip(width: 84),
              KratosBone.chip(width: 90),
              KratosBone.chip(width: 80),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Skill cards
        const SkillCardSkeleton(),
        const SizedBox(height: 12),
        const SkillCardSkeleton(),
        const SizedBox(height: 12),
        const SkillCardSkeleton(),
        const SizedBox(height: 12),
        const SkillCardSkeleton(),
      ],
    );
  }
}

/// Geometry-matched skeleton for Skill item.
class SkillCardSkeleton extends StatelessWidget {
  const SkillCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const KratosBone.card(
      height: 84,
      child: Row(
        children: [
          KratosBone.circle(size: 34),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                KratosBone.text(width: 140, height: 14),
                SizedBox(height: 6),
                KratosBone.text(width: 90, height: 11),
              ],
            ),
          ),
          KratosBone.chip(width: 60, height: 24),
        ],
      ),
    );
  }
}

/// Skeleton for [XpDashboardScreen].
class XpDashboardSkeleton extends StatelessWidget {
  const XpDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Hero XP card
        const KratosBone.card(
          height: 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KratosBone.text(width: 90, height: 11),
              SizedBox(height: 14),
              Row(
                children: [
                  KratosBone.text(width: 140, height: 26),
                  Spacer(),
                  KratosBone.chip(width: 70, height: 22),
                ],
              ),
              SizedBox(height: 14),
              KratosBone.text(width: 180, height: 11),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const KratosBone.text(width: 100, height: 11),
        const SizedBox(height: 10),
        // Last 7 days sparkline placeholder
        const KratosBone.card(height: 120),
        const SizedBox(height: 20),
        const KratosBone.text(width: 130, height: 11),
        const SizedBox(height: 10),
        // Life Area breakdown
        const KratosBone.card(
          height: 110,
          child: Column(
            children: [
              KratosBone.text(width: double.infinity, height: 12),
              SizedBox(height: 10),
              KratosBone.text(width: double.infinity, height: 12),
              SizedBox(height: 10),
              KratosBone.text(width: double.infinity, height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

/// Skeleton for [LifeAreasScreen].
class LifeAreasPageSkeleton extends StatelessWidget {
  const LifeAreasPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        // Hero Vision Card
        const KratosBone.card(
          height: 76,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              KratosBone.circle(size: 32),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    KratosBone.text(width: 160, height: 14),
                    SizedBox(height: 4),
                    KratosBone.text(width: 100, height: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const LifeAreaCardSkeleton(),
        const SizedBox(height: 12),
        const LifeAreaCardSkeleton(),
        const SizedBox(height: 12),
        const LifeAreaCardSkeleton(),
      ],
    );
  }
}

/// Skeleton for [AnalyticsScreen].
class AnalyticsPageSkeleton extends StatelessWidget {
  const AnalyticsPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Filter bar
        const SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              KratosBone.chip(width: 74),
              KratosBone.chip(width: 74),
              KratosBone.chip(width: 74),
              KratosBone.chip(width: 80),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const KratosBone.text(width: 110, height: 12),
        const SizedBox(height: 10),
        // Metrics 2x2 grid
        const Row(
          children: [
            Expanded(child: KratosBone.card(height: 70)),
            SizedBox(width: 10),
            Expanded(child: KratosBone.card(height: 70)),
          ],
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Expanded(child: KratosBone.card(height: 70)),
            SizedBox(width: 10),
            Expanded(child: KratosBone.card(height: 70)),
          ],
        ),
        const SizedBox(height: 20),
        const KratosBone.text(width: 130, height: 12),
        const SizedBox(height: 10),
        const KratosBone.card(height: 140),
      ],
    );
  }
}

/// Generic Detail Screen skeleton for Goal/Project/Activity detail views.
class GenericDetailSkeleton extends StatelessWidget {
  const GenericDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const KratosBone.card(
          height: 130,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KratosBone.text(width: 200, height: 18),
              SizedBox(height: 10),
              KratosBone.text(width: double.infinity, height: 12),
              SizedBox(height: 6),
              KratosBone.text(width: 160, height: 12),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Expanded(child: KratosBone.card(height: 44)),
            SizedBox(width: 10),
            Expanded(child: KratosBone.card(height: 44)),
            SizedBox(width: 10),
            Expanded(child: KratosBone.card(height: 44)),
          ],
        ),
        const SizedBox(height: 18),
        const KratosBone.card(
          height: 140,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KratosBone.text(width: 120, height: 14),
              SizedBox(height: 14),
              KratosBone.text(width: double.infinity, height: 11),
              SizedBox(height: 8),
              KratosBone.text(width: double.infinity, height: 11),
              SizedBox(height: 8),
              KratosBone.text(width: 220, height: 11),
            ],
          ),
        ),
      ],
    );
/*
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          const KratosBone.card(
            height: 130,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                KratosBone.text(width: 200, height: 18),
                SizedBox(height: 10),
                KratosBone.text(width: double.infinity, height: 12),
                SizedBox(height: 6),
                KratosBone.text(width: 160, height: 12),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Actions bar
          const Row(
            children: [
              Expanded(child: KratosBone.card(height: 44)),
              SizedBox(width: 10),
              Expanded(child: KratosBone.card(height: 44)),
              SizedBox(width: 10),
              Expanded(child: KratosBone.card(height: 44)),
            ],
          ),
          const SizedBox(height: 18),
          // Content block
          const Expanded(
            child: KratosBone.card(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KratosBone.text(width: 120, height: 14),
                  SizedBox(height: 14),
                  KratosBone.text(width: double.infinity, height: 11),
                  SizedBox(height: 8),
                  KratosBone.text(width: double.infinity, height: 11),
                  SizedBox(height: 8),
                  KratosBone.text(width: 220, height: 11),
                ],
              ),
            ),
          ),
        ],
      ),
    );
*/
  }
}
