import 'package:flutter/material.dart';

import 'kratos_theme.dart';

/// Active Liquid Glass card for highlighted, active, and edit surfaces.
/// Emphasizes active state with KRATOS electric lime border and subtle ambient depth.
class ActiveGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final bool active;

  const ActiveGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.active = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? KratosTheme.electricLime : KratosTheme.lightAcidLime;

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF161A17).withValues(alpha: 0.98),
                  const Color(0xFF101311).withValues(alpha: 0.98),
                  const Color(0xFF0A0C0A),
                ],
                stops: const [0.0, 0.45, 1.0],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFFAFBFC),
                  Color(0xFFF2F4F8),
                ],
                stops: [0.0, 0.50, 1.0],
              ),
        border: Border.all(
          color: active
              ? accent.withValues(alpha: isDark ? 0.65 : 0.75)
              : (isDark ? Colors.white.withValues(alpha: 0.10) : KratosTheme.lightBorderGlass),
          width: 1.2,
        ),
        boxShadow: [
          if (active)
            BoxShadow(
              color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : const Color(0x0C0F172A),
            blurRadius: 20,
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
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // Top specular rim
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
                        accent.withValues(alpha: isDark ? 0.35 : 0.45),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: padding,
              child: DefaultTextStyle.merge(
                style: TextStyle(
                  color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                  fontFamily: 'Roboto',
                ),
                child: IconTheme.merge(
                  data: IconThemeData(
                    color: isDark ? Colors.white70 : KratosTheme.lightTextSecondary,
                  ),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
