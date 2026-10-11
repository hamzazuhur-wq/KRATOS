import 'package:flutter/material.dart';

import 'kratos_theme.dart';
import 'kratos_motion.dart';
import 'kratos_card_tokens.dart';

enum KratosSurfaceVariant {
  normal,
  elevated,
  active,
  interactive,
  disabled,
  selected,
}

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

  const KratosGlassCard({
    super.key,
    required this.child,
    this.borderRadius,
    this.accentColor,
    this.padding,
    this.interactive = false,
    this.dashboardGlass = false,
    this.variant = KratosSurfaceVariant.normal,
    this.selected = false,
    this.disabled = false,
    this.onTap,
  });

  @override
  State<KratosGlassCard> createState() => _KratosGlassCardState();
}

class _KratosGlassCardState extends State<KratosGlassCard> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<KratosCardTokens>();
    if (tokens == null) {
      return Container(child: widget.child);
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Determine logical states (merging variant and boolean flags)
    final bool isDisabled = widget.disabled || widget.variant == KratosSurfaceVariant.disabled;
    final bool isActive = widget.selected || widget.variant == KratosSurfaceVariant.active || widget.variant == KratosSurfaceVariant.selected;
    final bool isElevated = widget.variant == KratosSurfaceVariant.elevated;
    final bool isInteractive = widget.interactive || widget.variant == KratosSurfaceVariant.interactive || widget.onTap != null;
    
    final accent = widget.accentColor ?? tokens.accentColor;

    // Resolve border color
    Color baseBorderColor;
    if (isDisabled) {
      baseBorderColor = tokens.borderDisabled;
    } else if (isActive) {
      baseBorderColor = tokens.borderActive;
    } else if (isElevated) {
      baseBorderColor = _hovered ? tokens.borderElevatedHover : tokens.borderElevated;
    } else {
      baseBorderColor = _hovered ? tokens.borderHover : tokens.borderNormal;
    }

    // Resolve border width
    final double borderWidth = isActive ? tokens.borderWidthActive : tokens.borderWidthNormal;

    // Resolve shadows
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

    // Resolve body gradient
    Gradient bodyGradient;
    if (isActive) {
      bodyGradient = tokens.backgroundActive;
    } else if (isElevated) {
      bodyGradient = tokens.backgroundElevated;
    } else {
      bodyGradient = tokens.backgroundNormal;
    }

    final resolvedRadius = widget.borderRadius ?? BorderRadius.circular(tokens.radius);
    final content = Padding(
      padding: widget.padding ?? tokens.defaultPadding,
      child: widget.child,
    );

    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Widget cardWidget = AnimatedContainer(
      duration: disableAnimations ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: resolvedRadius,
        gradient: bodyGradient,
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
            // Layer 3: Inner hairline sheen gradient
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        tokens.sheenColor.withValues(alpha: tokens.sheenOpacity),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.25],
                    ),
                  ),
                ),
              ),
            ),
            // Layer 5: Top specular reflection line
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
                        (isActive ? tokens.specularColorActive : tokens.specularColorNormal).withValues(
                          alpha: isActive ? tokens.specularOpacityActive : tokens.specularOpacityNormal,
                        ),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            DefaultTextStyle.merge(
              style: TextStyle(
                color: isDark ? Colors.white : KratosTheme.lightTextPrimary,
                fontFamily: 'Roboto',
              ),
              child: IconTheme.merge(
                data: IconThemeData(
                  color: isDark ? Colors.white70 : KratosTheme.lightTextSecondary,
                ),
                child: content,
              ),
            ),
          ],
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
