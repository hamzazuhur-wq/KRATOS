import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import 'kratos_theme.dart';

/// Item representation for [KratosDropdown].
class KratosDropdownItem<T> {
  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final Color? accentColor;

  const KratosDropdownItem({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.accentColor,
  });
}

class _DropdownResult<T> {
  final T value;
  const _DropdownResult(this.value);
}

/// Black Liquid Glass styled Dropdown button adhering to KRATOS design language.
///
/// Features:
/// - Frosted translucent black surface
/// - Strong backdrop blur
/// - Subtle white glass edge (1px)
/// - Soft inner highlight
/// - Minimal Apple-inspired Liquid Glass aesthetic
/// - Acid/lime accent ONLY for active/selected states (or custom accentColor)
/// - Origin-aware Menu Dropdown transition
class KratosDropdown<T> extends StatefulWidget {
  final T? value;
  final String hint;
  final IconData? prefixIcon;
  final Widget? leading;
  final List<KratosDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool isExpanded;
  final double? height;
  final EdgeInsetsGeometry padding;
  final bool hasError;
  final bool enabled;
  final Color? accentColor;

  const KratosDropdown({
    super.key,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.prefixIcon,
    this.leading,
    this.isExpanded = false,
    this.height = 42,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.hasError = false,
    this.enabled = true,
    this.accentColor,
  });

  @override
  State<KratosDropdown<T>> createState() => _KratosDropdownState<T>();
}

class _KratosDropdownState<T> extends State<KratosDropdown<T>> {
  bool _isHovered = false;
  bool _isOpen = false;

  KratosDropdownItem<T>? get _selectedItem {
    try {
      return widget.items.firstWhere((item) => item.value == widget.value);
    } catch (_) {
      return null;
    }
  }

  void _openMenu() async {
    if (!widget.enabled) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    final buttonRect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    final mediaQuery = MediaQuery.of(context);

    setState(() => _isOpen = true);

    final result = await navigator.push<_DropdownResult<T>>(
      _KratosDropdownRoute<T>(
        buttonRect: buttonRect,
        screenSize: mediaQuery.size,
        screenPadding: mediaQuery.padding,
        items: widget.items,
        selectedValue: widget.value,
        matchWidth: widget.isExpanded,
        accentColor: widget.accentColor,
      ),
    );

    if (mounted) {
      setState(() => _isOpen = false);
      if (result != null) {
        widget.onChanged(result.value);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedItem;
    final hasValue = selected != null;
    final accent = widget.accentColor ?? KratosTheme.acidLime;

    final borderColor = widget.hasError
        ? const Color(0xFFFF5252).withValues(alpha: 0.6)
        : _isOpen
        ? accent.withValues(alpha: 0.6)
        : hasValue
        ? accent.withValues(alpha: 0.35)
        : _isHovered
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.12);

    final content = MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        if (mounted && widget.enabled) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted && widget.enabled) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: widget.enabled ? _openMenu : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          /* TEMP PERFORMANCE TEST — GLASS DISABLED
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AnimatedContainer(
          */
          child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              height: widget.height,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: const Color(0xCC080B08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1.0),
                boxShadow: _isOpen
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.12),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: widget.isExpanded
                    ? MainAxisSize.max
                    : MainAxisSize.min,
                children: [
                  if (selected?.leading != null) ...[
                    selected!.leading!,
                    const SizedBox(width: 8),
                  ] else if (widget.leading != null) ...[
                    widget.leading!,
                    const SizedBox(width: 8),
                  ] else if (widget.prefixIcon != null) ...[
                    Icon(
                      widget.prefixIcon,
                      color: hasValue ? accent : Colors.white38,
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (widget.isExpanded)
                    Expanded(
                      child: Text(
                        hasValue ? selected.label : widget.hint,
                        style: TextStyle(
                          color: hasValue ? Colors.white : Colors.white54,
                          fontSize: 12.5,
                          fontWeight: hasValue
                              ? FontWeight.w600
                              : FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  else
                    Text(
                      hasValue ? selected.label : widget.hint,
                      style: TextStyle(
                        color: hasValue ? Colors.white : Colors.white54,
                        fontSize: 12.5,
                        fontWeight: hasValue
                            ? FontWeight.w600
                            : FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _isOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 160),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: hasValue || _isOpen
                          ? accent
                          : Colors.white54,
                      size: 17,
                    ),
                  ),
                ],
              ),
            ),
          /* TEMP PERFORMANCE TEST — GLASS DISABLED
          ),
          */
        ),
      ),
    );

    return content;
  }
}

/// Black Liquid Glass FormField variant of [KratosDropdown] for forms and dialogs.
class KratosDropdownFormField<T> extends FormField<T> {
  final String hint;
  final String? labelText;
  final List<KratosDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final IconData? prefixIcon;
  final Widget? leading;
  final bool isExpanded;
  final double height;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;

  KratosDropdownFormField({
    super.key,
    super.initialValue,
    required this.hint,
    this.labelText,
    required this.items,
    this.onChanged,
    this.prefixIcon,
    this.leading,
    this.isExpanded = true,
    this.height = 42,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
    this.accentColor,
    super.onSaved,
    super.validator,
    super.autovalidateMode,
  }) : super(
         builder: (FormFieldState<T> state) {
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             mainAxisSize: MainAxisSize.min,
             children: [
               if (labelText != null) ...[
                 Text(
                   labelText,
                   style: const TextStyle(
                     color: Colors.white54,
                     fontSize: 11,
                     fontWeight: FontWeight.w700,
                     letterSpacing: 0.8,
                   ),
                 ),
                 const SizedBox(height: 6),
               ],
               KratosDropdown<T>(
                 value: state.value,
                 hint: hint,
                 items: items,
                 prefixIcon: prefixIcon,
                 leading: leading,
                 isExpanded: isExpanded,
                 height: height,
                 padding: padding,
                 accentColor: accentColor,
                 hasError: state.hasError,
                 onChanged: (val) {
                   state.didChange(val);
                   if (onChanged != null) {
                     onChanged(val);
                   }
                 },
               ),
               if (state.hasError && state.errorText != null) ...[
                 const SizedBox(height: 5),
                 Padding(
                   padding: const EdgeInsets.only(left: 4),
                   child: Text(
                     state.errorText!,
                     style: const TextStyle(
                       color: Color(0xFFFF5252),
                       fontSize: 11,
                       fontWeight: FontWeight.w500,
                     ),
                   ),
                 ),
               ],
             ],
           );
         },
       );
}

/// Abstract entry for [KratosPopupMenuButton].
abstract class KratosPopupMenuEntry<T> {
  const KratosPopupMenuEntry();
}

/// A horizontal divider inside a [KratosPopupMenuButton].
class KratosPopupMenuDivider<T> extends KratosPopupMenuEntry<T> {
  const KratosPopupMenuDivider();
}

/// An interactive item inside a [KratosPopupMenuButton].
class KratosPopupMenuItem<T> extends KratosPopupMenuEntry<T> {
  final T value;
  final Widget child;
  final bool enabled;

  const KratosPopupMenuItem({
    required this.value,
    required this.child,
    this.enabled = true,
  });
}

/// Black Liquid Glass PopupMenuButton for action/kebab menus across KRATOS.
///
/// Features origin-aware open/close transitions matching transitions.dev
/// "Dropdown menu morph".
class KratosPopupMenuButton<T> extends StatefulWidget {
  final Widget? icon;
  final Widget? child;
  final List<KratosPopupMenuEntry<T>> Function(BuildContext) itemBuilder;
  final ValueChanged<T>? onSelected;
  final EdgeInsetsGeometry padding;
  final String? tooltip;
  final bool enabled;

  const KratosPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.icon,
    this.child,
    this.padding = const EdgeInsets.all(8.0),
    this.tooltip = 'More options',
    this.enabled = true,
  });

  @override
  State<KratosPopupMenuButton<T>> createState() =>
      _KratosPopupMenuButtonState<T>();
}

class _KratosPopupMenuButtonState<T> extends State<KratosPopupMenuButton<T>> {
  bool _isOpen = false;

  void _openMenu() async {
    if (!widget.enabled) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    final buttonRect = renderBox.localToGlobal(Offset.zero) & renderBox.size;
    final mediaQuery = MediaQuery.of(context);
    final entries = widget.itemBuilder(context);

    if (entries.isEmpty) return;

    setState(() => _isOpen = true);

    final result = await navigator.push<_DropdownResult<T>>(
      _KratosDropdownRoute<T>(
        buttonRect: buttonRect,
        screenSize: mediaQuery.size,
        screenPadding: mediaQuery.padding,
        menuEntries: entries,
        matchWidth: false,
        minWidth: 160.0,
      ),
    );

    if (mounted) {
      setState(() => _isOpen = false);
      if (result != null) {
        widget.onSelected?.call(result.value);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.child != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.enabled ? _openMenu : null,
        child: widget.child,
      );
    }

    return IconButton(
      icon:
          widget.icon ??
          Icon(
            Icons.more_vert,
            color: _isOpen ? Colors.white : Colors.white54,
            size: 20,
          ),
      padding: widget.padding,
      tooltip: widget.tooltip,
      visualDensity: VisualDensity.compact,
      onPressed: widget.enabled ? _openMenu : null,
    );
  }
}

/// Custom PopupRoute rendering the Black Liquid Glass dropdown menu.
///
/// Implements origin-aware open/close transitions matching transitions.dev
/// "Dropdown menu morph":
/// - Open duration: 250ms (--duration-fast)
/// - Close duration: 150ms (--duration-quick)
/// - Cubic easing: cubic-bezier(0.22, 1, 0.36, 1)
/// - Pre-scale: 0.97 -> 1.0 on open, closing scale: 1.0 -> 0.99
/// - Translation offset: -6px / +6px -> 0px on open, 0px -> -3px / +3px on close
/// - Settle blur: 2.0px -> 0px on open, 0px -> 1.5px on close
/// - Trigger-to-menu morph: trigger width/height/radius expands into the menu
/// - Reduced motion support via disableAnimations
class _KratosDropdownRoute<T> extends PopupRoute<_DropdownResult<T>> {
  final Rect buttonRect;
  final Size screenSize;
  final EdgeInsets screenPadding;
  final List<KratosDropdownItem<T>>? items;
  final List<KratosPopupMenuEntry<T>>? menuEntries;
  final T? selectedValue;
  final bool matchWidth;
  final double minWidth;
  final Color? accentColor;

  _KratosDropdownRoute({
    required this.buttonRect,
    required this.screenSize,
    required this.screenPadding,
    this.items,
    this.menuEntries,
    this.selectedValue,
    required this.matchWidth,
    this.minWidth = 200.0,
    this.accentColor,
  });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 150);

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Handled directly on the menu container in buildPage to guarantee
    // precise origin-anchored scaling and translation relative to the trigger.
    return child;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    const double maxMenuHeight = 280.0;
    const double menuMargin = 6.0;

    final spaceBelow =
        screenSize.height - screenPadding.bottom - buttonRect.bottom - 8;
    final spaceAbove = buttonRect.top - screenPadding.top - 8;
    final opensDown = spaceBelow >= 160 || spaceBelow >= spaceAbove;

    final availableHeight = opensDown ? spaceBelow : spaceAbove;
    final actualMaxHeight = math.min(
      maxMenuHeight,
      math.max(120.0, availableHeight - menuMargin),
    );

    double targetWidth = matchWidth
        ? buttonRect.width
        : math.max(buttonRect.width, minWidth);
    targetWidth = math.min(targetWidth, screenSize.width - 24.0);

    double left = buttonRect.left;
    if (left + targetWidth > screenSize.width - 12.0) {
      left = math.max(12.0, screenSize.width - targetWidth - 12.0);
    }
    if (left < 12.0) {
      left = 12.0;
    }

    // Origin calculation: anchor precisely to trigger button center horizontally,
    // and top or bottom edge vertically based on placement direction.
    final triggerCenterX = buttonRect.center.dx;
    final relativeX = ((triggerCenterX - left) / targetWidth).clamp(0.0, 1.0);
    final alignmentX = (relativeX * 2.0) - 1.0;
    final alignmentY = opensDown ? -1.0 : 1.0;
    final origin = Alignment(alignmentX, alignmentY);

    final disableAnimations = MediaQuery.of(context).disableAnimations;

    Widget menu = Container(
      width: targetWidth,
      decoration: BoxDecoration(
        color: const Color(0xEB060806), // Frosted translucent deep black
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.75),
            blurRadius: 28,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.04),
            blurRadius: 1,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        /* TEMP PERFORMANCE TEST — GLASS DISABLED
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: ConstrainedBox(
        */
        child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: actualMaxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (items != null)
                    ...items!.map((item) {
                      final isSelected = item.value == selectedValue;
                      return _KratosDropdownItemWidget<T>(
                        item: item,
                        isSelected: isSelected,
                        defaultAccent: accentColor ?? KratosTheme.acidLime,
                      );
                    }),
                  if (menuEntries != null)
                    ...menuEntries!.map((entry) {
                      if (entry is KratosPopupMenuDivider<T>) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          child: Container(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        );
                      }
                      if (entry is KratosPopupMenuItem<T>) {
                        return _KratosPopupItemWidget<T>(entry: entry);
                      }
                      return const SizedBox.shrink();
                    }),
                ],
              ),
            ),
          ),
        /* TEMP PERFORMANCE TEST — GLASS DISABLED
        ),
        */
      ),
    );

    Widget animatedMenu = AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        if (disableAnimations) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: child,
          );
        }

        const curve = Cubic(0.22, 1.0, 0.36, 1.0);
        final isReverse = animation.status == AnimationStatus.reverse;

        double scale;
        double translateY;
        double opacity;
        double blur;
        double morphProgress;

        if (isReverse) {
          // Closing: animation.value 1.0 -> 0.0, closeProgress 0.0 -> 1.0
          final closeProgress = (1.0 - animation.value).clamp(0.0, 1.0);
          final t = curve.transform(closeProgress);
          morphProgress = 1.0 - t;

          // Closing scale: 1.0 -> 0.99
          scale = 1.0 - (0.01 * t);
          // Closing translation offset: 0px -> -3px / +3px back toward trigger
          translateY = (opensDown ? -3.0 : 3.0) * t;
          // Opacity: 1.0 -> 0.0
          opacity = (1.0 - t).clamp(0.0, 1.0);
          // Settle blur: 0px -> 1.5px
          blur = 1.5 * t;
        } else {
          // Opening: animation.value 0.0 -> 1.0, openProgress 0.0 -> 1.0
          final openProgress = animation.value.clamp(0.0, 1.0);
          final t = curve.transform(openProgress);
          morphProgress = t;

          // Pre-scale: 0.97 -> 1.0
          scale = 0.97 + (0.03 * t);
          // Small translation offset: -6px (down) / +6px (up) -> 0px
          translateY = (opensDown ? -6.0 : 6.0) * (1.0 - t);
          // Opacity: 0.0 -> 1.0
          opacity = t;
          // Settle blur: 2.0px -> 0px
          blur = 2.0 * (1.0 - t);
        }

        final morphWidthScale = lerpDouble(
          (buttonRect.width / targetWidth).clamp(0.01, 1.0),
          1.0,
          morphProgress,
        )!;
        final morphHeightScale = lerpDouble(0.46, 1.0, morphProgress)!;
        final morphRadius = lerpDouble(12.0, 16.0, morphProgress)!;

        Widget transformed = Transform.translate(
          offset: Offset(0, translateY),
          child: Transform(
            alignment: origin,
            transform: Matrix4.diagonal3Values(
              morphWidthScale * scale,
              morphHeightScale * scale,
              1.0,
            ),
            child: Opacity(
              opacity: opacity,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(morphRadius),
                child: child,
              ),
            ),
          ),
        );

        if (blur > 0.05) {
          transformed = ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: transformed,
          );
        }

        return transformed;
      },
      child: menu,
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        if (disableAnimations) return child!;

        const curve = Cubic(0.22, 1.0, 0.36, 1.0);
        final isReverse = animation.status == AnimationStatus.reverse;
        final rawProgress = isReverse
            ? (1.0 - animation.value).clamp(0.0, 1.0)
            : animation.value.clamp(0.0, 1.0);
        final progress = curve.transform(rawProgress);
        final currentLeft = lerpDouble(buttonRect.left, left, progress)!;
        final currentOffset = lerpDouble(0.0, menuMargin, progress)!;

        return Stack(
          children: [
            Positioned(
              left: currentLeft,
              top: opensDown ? buttonRect.bottom + currentOffset : null,
              bottom: !opensDown
                  ? (screenSize.height - buttonRect.top + currentOffset)
                  : null,
              child: Material(color: Colors.transparent, child: child),
            ),
          ],
        );
      },
      child: animatedMenu,
    );
  }
}

class _KratosPopupItemWidget<T> extends StatefulWidget {
  final KratosPopupMenuItem<T> entry;

  const _KratosPopupItemWidget({super.key, required this.entry});

  @override
  State<_KratosPopupItemWidget<T>> createState() =>
      _KratosPopupItemWidgetState<T>();
}

class _KratosPopupItemWidgetState<T> extends State<_KratosPopupItemWidget<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final isEnabled = entry.enabled;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (isEnabled) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (isEnabled) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isEnabled
            ? () {
                Navigator.of(context).pop(_DropdownResult(entry.value));
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered && isEnabled
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Opacity(
            opacity: isEnabled ? 1.0 : 0.4,
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              child: entry.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _KratosDropdownItemWidget<T> extends StatefulWidget {
  final KratosDropdownItem<T> item;
  final bool isSelected;
  final Color defaultAccent;

  const _KratosDropdownItemWidget({
    required this.item,
    required this.isSelected,
    this.defaultAccent = KratosTheme.acidLime,
  });

  @override
  State<_KratosDropdownItemWidget<T>> createState() =>
      _KratosDropdownItemWidgetState<T>();
}

class _KratosDropdownItemWidgetState<T>
    extends State<_KratosDropdownItemWidget<T>> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;
    final accent = widget.item.accentColor ?? widget.defaultAccent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.of(context).pop(_DropdownResult(widget.item.value));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.12)
                : _isHovered
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(
                    color: accent.withValues(alpha: 0.25),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              if (widget.item.leading != null) ...[
                widget.item.leading!,
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.item.label,
                      style: TextStyle(
                        color: isSelected
                            ? accent
                            : Colors.white.withValues(alpha: 0.9),
                        fontSize: 12.5,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.item.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.item.subtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 10.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_rounded,
                  color: accent,
                  size: 15,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
