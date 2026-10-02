import 'package:flutter/material.dart';

/// Shared animated glass treatment for real create/edit surfaces.
/// Decorative animation is pointer-transparent and respects reduced motion.
class ActiveGlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final bool active;

  const ActiveGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.active = true,
  });

  @override
  State<ActiveGlassCard> createState() => _ActiveGlassCardState();
}

class _ActiveGlassCardState extends State<ActiveGlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      // One restrained entrance sweep; keep it finite and short so loading
      // and widget-test settling remain deterministic.
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reducedMotion || !widget.active) {
      _controller.stop();
    } else if (!_controller.isAnimating && !_controller.isCompleted) {
      // A calm one-shot sweep keeps pumpAndSettle/test semantics deterministic
      // while still providing the premium active treatment on open.
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = reducedMotion ? 0.0 : _controller.value;
        final glow = Color.lerp(
              const Color(0xFFC6F135).withValues(alpha: .22),
              const Color(0xFF7CFFB2).withValues(alpha: .42),
              t,
            ) ??
            const Color(0xFFC6F135);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            color: isDark
                ? const Color(0xFF111511).withValues(alpha: .96)
                : Colors.white,
            border: Border.all(
              color: isDark ? glow : const Color(0xFFC6F135).withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? glow.withValues(alpha: .14)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
              ),
            ],
          ),
          padding: widget.padding,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
