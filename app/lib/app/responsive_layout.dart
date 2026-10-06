// ignore_for_file: public_member_api_docs
// Wave 31: ResponsiveLayout — Cross-device adaptive layout engine for Phone, Tablet, and Desktop.
//
// Conforms to Material 3 responsive design specifications while maintaining
// KRATOS Liquid Glass / Dark Volcanic styling.

import 'package:flutter/material.dart';

enum DeviceScreenType {
  compact,  // Phone (< 600dp)
  medium,   // Tablet / Foldable (600dp - 840dp)
  expanded, // Desktop / Wide Web (> 840dp)
}

class ResponsiveBreakpoints {
  static const double compactMax = 600.0;
  static const double mediumMax = 840.0;

  static DeviceScreenType getScreenType(double width) {
    if (width < compactMax) {
      return DeviceScreenType.compact;
    } else if (width <= mediumMax) {
      return DeviceScreenType.medium;
    } else {
      return DeviceScreenType.expanded;
    }
  }

  static bool isCompact(BuildContext context) =>
      MediaQuery.of(context).size.width < compactMax;

  static bool isMedium(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= compactMax && w <= mediumMax;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.of(context).size.width > mediumMax;
}

class ResponsiveScaffold extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final Widget body;

  const ResponsiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final screenType = ResponsiveBreakpoints.getScreenType(width);

    if (screenType == DeviceScreenType.compact) {
      // Mobile: Bottom Navigation Bar
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          backgroundColor: const Color(0xFF141414),
          indicatorColor: const Color(0xFFC6F135).withAlpha(50),
          destinations: destinations,
        ),
      );
    } else {
      // Tablet / Desktop: Navigation Rail
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              backgroundColor: const Color(0xFF141414),
              indicatorColor: const Color(0xFFC6F135).withAlpha(50),
              extended: screenType == DeviceScreenType.expanded,
              destinations: destinations
                  .map((d) => NavigationRailDestination(
                        icon: d.icon,
                        selectedIcon: d.selectedIcon ?? d.icon,
                        label: Text(
                          d.label,
                          style: TextStyle(
                            color: selectedIndex == destinations.indexOf(d)
                                ? const Color(0xFFC6F135)
                                : Colors.white60,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const VerticalDivider(width: 1, color: Colors.white10),
            Expanded(child: body),
          ],
        ),
      );
    }
  }
}
