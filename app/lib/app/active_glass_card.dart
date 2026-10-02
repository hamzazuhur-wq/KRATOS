import 'package:flutter/material.dart';

/// Clean neutral card replacing custom neon sweep animated card.
/// Preserves constructor API for full compatibility across features.
class ActiveGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final bool active;

  const ActiveGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: isDark ? const Color(0x1FFFFFFF) : const Color(0x1F000000),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
