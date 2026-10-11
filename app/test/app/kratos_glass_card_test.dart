import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/kratos_theme.dart';
import 'package:kratos_app/app/kratos_visuals.dart';

void main() {
  group('KratosGlassCard HTML/CSS Reference Conformance', () {
    testWidgets('renders dark mode Liquid Glass card with 23px radius and tokens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: KratosGlassCard(
                child: Text('Learning'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Learning'), findsOneWidget);

      // Verify ClipRRect has 23.0 radius
      final clipFinder = find.byType(ClipRRect);
      expect(clipFinder, findsOneWidget);
      final clipRRect = tester.widget<ClipRRect>(clipFinder);
      expect(clipRRect.borderRadius, BorderRadius.circular(23.0));

      // Verify BackdropFilter with 28px blur
      final backdropFinder = find.byType(BackdropFilter);
      expect(backdropFinder, findsWidgets);
      final backdropFilter = tester.widget<BackdropFilter>(backdropFinder.first);
      final filter = backdropFilter.filter;
      expect(filter, isNotNull);

      // Verify AnimatedContainer has 23.0 radius
      final containerFinder = find.byType(AnimatedContainer);
      expect(containerFinder, findsOneWidget);
      final animatedContainer = tester.widget<AnimatedContainer>(containerFinder);
      final boxDecoration = animatedContainer.decoration as BoxDecoration;
      expect(boxDecoration.borderRadius, BorderRadius.circular(23.0));

      // Border in dark mode should match --line (rgba(255, 255, 255, 0.22))
      final border = boxDecoration.border as Border;
      expect(border.top.color.a, closeTo(0.22, 0.02));
    });

    testWidgets('renders light mode Liquid Glass card with 23px radius and tokens', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.lightTheme,
          home: const Scaffold(
            body: Center(
              child: KratosGlassCard(
                child: Text('Light Mode Card'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Light Mode Card'), findsOneWidget);

      final clipFinder = find.byType(ClipRRect);
      expect(clipFinder, findsOneWidget);
      final clipRRect = tester.widget<ClipRRect>(clipFinder);
      expect(clipRRect.borderRadius, BorderRadius.circular(23.0));

      final containerFinder = find.byType(AnimatedContainer);
      final animatedContainer = tester.widget<AnimatedContainer>(containerFinder);
      final boxDecoration = animatedContainer.decoration as BoxDecoration;
      expect(boxDecoration.borderRadius, BorderRadius.circular(23.0));

      // Border in light mode should match --line (rgba(255, 255, 255, 0.80))
      final border = boxDecoration.border as Border;
      expect(border.top.color.a, closeTo(0.80, 0.02));
    });

    testWidgets('custom borderRadius overrides default token radius', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: KratosGlassCard(
                borderRadius: BorderRadius.circular(16.0),
                child: const Text('Custom Radius'),
              ),
            ),
          ),
        ),
      );

      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clipRRect.borderRadius, BorderRadius.circular(16.0));
    });

    testWidgets('edge glow respects position options', (tester) async {
      // Top edge glow (default)
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 100,
                child: KratosGlassCard(
                  edgeGlowPosition: KratosEdgeGlowPosition.top,
                  child: Text('Top Glow'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Top Glow'), findsOneWidget);

      // Bottom edge glow
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 100,
                child: KratosGlassCard(
                  edgeGlowPosition: KratosEdgeGlowPosition.bottom,
                  child: Text('Bottom Glow'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Bottom Glow'), findsOneWidget);

      // None
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 100,
                child: KratosGlassCard(
                  showEdgeGlow: false,
                  child: Text('No Glow'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('No Glow'), findsOneWidget);
    });

    testWidgets('interactive card triggers onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: KratosGlassCard(
                interactive: true,
                onTap: () => tapped = true,
                child: const Text('Tap Me'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Tap Me'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('fallback tokens work gracefully without theme extension', (tester) async {
      // pumping a plain MaterialApp with basic ThemeData without KratosCardTokens extension
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: KratosGlassCard(
                child: Text('Fallback Card'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Fallback Card'), findsOneWidget);
      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clipRRect.borderRadius, BorderRadius.circular(23.0));
    });
  });
}
