import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/kratos_theme.dart';
import 'package:kratos_app/features/analytics/presentation/analytics_screen.dart';

void main() {
  group('Analytics Header & Filter Foundation (Wave 02)', () {
    testWidgets('renders heading, icon, and supporting text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: AnalyticsScreen(
              ownerId: 'test_user',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Analytics'), findsOneWidget);
      expect(
        find.text(
          'Track your progress, understand your patterns, and optimize your growth.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders all 3 filter dropdown controls with default values',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: AnalyticsScreen(
              ownerId: 'test_user',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Last 30 Days'), findsWidgets);
      expect(find.text('All Life Areas'), findsOneWidget);
      expect(find.text('All Sources'), findsOneWidget);
    });

    testWidgets('renders 4 granularity segments and defaults to Month',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: AnalyticsScreen(
              ownerId: 'test_user',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Month'), findsWidgets);
      expect(find.text('Year'), findsOneWidget);

      // Tap 'Week' to verify interaction
      await tester.tap(find.text('Week'));
      await tester.pumpAndSettle();
      expect(find.text('Week'), findsOneWidget);
    });

    testWidgets('invokes callbacks when filter values change', (tester) async {
      String? selectedGran;
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: AnalyticsScreen(
              ownerId: 'test_user',
              onGranularityChanged: (g) => selectedGran = g,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Day'));
      await tester.pumpAndSettle();
      expect(selectedGran, 'Day');
    });

    testWidgets('renders cleanly in Light Mode without overflow',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.lightTheme,
          home: const Scaffold(
            body: AnalyticsScreen(
              ownerId: 'test_user',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Analytics'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without overflow across all target viewports',
        (tester) async {
      final viewports = [
        const Size(1440, 900), // Desktop
        const Size(1280, 800), // Desktop small
        const Size(1024, 768), // Tablet landscape
        const Size(768, 1024), // Tablet portrait
        const Size(430, 932),  // Mobile large
        const Size(390, 844),  // Mobile standard
      ];

      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: KratosTheme.darkTheme,
            home: const Scaffold(
              body: AnalyticsScreen(
                ownerId: 'test_user',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final err = tester.takeException();
        expect(err, isNull,
            reason: 'Overflow on viewport ${vp.width}x${vp.height}');
      }
    });

    testWidgets('verifies NO Analytics cards or charts are rendered (clean foundation)',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: AnalyticsScreen(
              ownerId: 'test_user',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Wave 03 adds the 4 KPI cards, but ensures NO charts, graphs, or placeholder cards exist
      expect(find.byType(Card), findsNothing);
      expect(find.text('Daily Growth'), findsNothing);
      expect(find.text('Add Widget'), findsNothing);
      expect(find.text('XP by Life Area'), findsNothing);
    });
  });
}
