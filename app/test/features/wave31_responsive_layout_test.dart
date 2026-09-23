// Wave 31 Unit Tests: Visual Golden UI & Cross-Device Layout Engine
//
// Tests cover:
//   1. Breakpoint classification for compact, medium, and expanded screens
//   2. Threshold edge boundary conditions
//   3. ResponsiveScaffold renders bottomNavigationBar for compact screen widths
//   4. ResponsiveScaffold renders NavigationRail for wide screen widths

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/responsive_layout.dart';

void main() {
  group('ResponsiveBreakpoints', () {
    test('classifies phone widths (< 600dp) as compact', () {
      expect(ResponsiveBreakpoints.getScreenType(360.0), DeviceScreenType.compact);
      expect(ResponsiveBreakpoints.getScreenType(599.0), DeviceScreenType.compact);
    });

    test('classifies tablet widths (600dp - 840dp) as medium', () {
      expect(ResponsiveBreakpoints.getScreenType(600.0), DeviceScreenType.medium);
      expect(ResponsiveBreakpoints.getScreenType(768.0), DeviceScreenType.medium);
      expect(ResponsiveBreakpoints.getScreenType(840.0), DeviceScreenType.medium);
    });

    test('classifies desktop widths (> 840dp) as expanded', () {
      expect(ResponsiveBreakpoints.getScreenType(841.0), DeviceScreenType.expanded);
      expect(ResponsiveBreakpoints.getScreenType(1440.0), DeviceScreenType.expanded);
    });
  });

  group('ResponsiveScaffold Widget', () {
    const destinations = [
      NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.flag), label: 'Goals'),
    ];

    testWidgets('renders bottomNavigationBar on compact mobile view', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveScaffold(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: destinations,
            body: const Center(child: Text('Content')),
          ),
        ),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('renders NavigationRail on expanded desktop view', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: ResponsiveScaffold(
            selectedIndex: 0,
            onDestinationSelected: (_) {},
            destinations: destinations,
            body: const Center(child: Text('Content')),
          ),
        ),
      );

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });
  });
}
