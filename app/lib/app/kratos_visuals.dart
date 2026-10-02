import 'package:flutter/material.dart';

/// Visually neutral container replacing previous custom glass/sheen implementation.
/// Preserves constructor API for full backward compatibility across screens.
class KratosGlassCard extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final Color? accentColor;
  final EdgeInsetsGeometry? padding;
  final bool interactive;
  final bool dashboardGlass;

  const KratosGlassCard({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.accentColor,
    this.padding,
    this.interactive = false,
    this.dashboardGlass = true,
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
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class KratosNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const KratosNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Standard bottom navigation bar replacing custom floating glass material.
class KratosGlassBottomBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<KratosNavItem> items;

  const KratosGlassBottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      destinations: [
        for (final item in items)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.activeIcon),
            label: item.label,
          ),
      ],
    );
  }
}

/// Neutral pass-through replacing 4-second opening sequence.
class KratosOpeningSequence extends StatefulWidget {
  final VoidCallback onFinished;

  const KratosOpeningSequence({super.key, required this.onFinished});

  @override
  State<KratosOpeningSequence> createState() => _KratosOpeningSequenceState();
}

class _KratosOpeningSequenceState extends State<KratosOpeningSequence> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFinished();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/// Visually neutral environment replacing custom atmosphere/crystals/grids.
class KratosEnvironment extends StatelessWidget {
  const KratosEnvironment({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}
