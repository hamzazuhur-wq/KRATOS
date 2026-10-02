import 'package:flutter/material.dart';

import 'kratos_visuals.dart';

/// Active Liquid Glass card for highlighted, active, and edit surfaces.
/// Emphasizes active state with KRATOS electric lime border and subtle ambient depth.
class ActiveGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final bool active;
  final Color? accentColor;
  final VoidCallback? onTap;

  const ActiveGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.active = true,
    this.accentColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return KratosGlassCard(
      variant: active ? KratosSurfaceVariant.active : KratosSurfaceVariant.normal,
      borderRadius: borderRadius,
      padding: padding,
      accentColor: accentColor,
      onTap: onTap,
      child: child,
    );
  }
}
