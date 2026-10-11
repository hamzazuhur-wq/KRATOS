import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/app/kratos_theme.dart';
import 'package:kratos_app/features/analytics/data/analytics_mock_data.dart';
import 'package:kratos_app/features/analytics/domain/analytics_models.dart';
import 'package:kratos_app/features/analytics/presentation/analytics_screen.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/analytics_kpi_cards.dart';

void main() {
  group('Analytics Top 4 KPI Summary Cards (Wave 03)', () {
    late AnalyticsSnapshot testSnapshot;

    setUp(() {
      testSnapshot = AnalyticsMockData.snapshot(
        range: AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays),
      );
    });

    testWidgets('renders all 4 KPI cards with titles, icons, and values', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsKpiSummaryRow(snapshot: testSnapshot),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card 1: Total XP
      expect(find.text('Total XP'), findsOneWidget);
      expect(find.text('11,584'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);

      // Card 2: XP Velocity
      expect(find.text('XP Velocity'), findsOneWidget);
      expect(find.text('386'), findsOneWidget);
      expect(find.text('XP/day'), findsOneWidget);
      expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

      // Card 3: Completion Rate
      expect(find.text('Completion Rate'), findsOneWidget);
      expect(find.text('78%'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);

      // Card 4: Consistency
      expect(find.text('Consistency'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.text('days'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_outlined), findsOneWidget);
    });

    testWidgets('displays delta badge pills with trend directions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsKpiSummaryRow(snapshot: testSnapshot),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check deltas and comparison subtitles
      expect(find.text('vs previous 30 days'), findsNWidgets(4));
      expect(find.text('+13.6%'), findsNWidgets(2));
      expect(find.text('+6.1%'), findsOneWidget);
      expect(find.text('+10.0%'), findsOneWidget);
    });

    testWidgets('chevron right is ONLY present on the Consistency card (cards 1-3 have no arrows)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsKpiSummaryRow(snapshot: testSnapshot),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only ONE chevron right icon across the 4 cards (on Consistency)
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    });

    testWidgets('only Consistency card triggers detail; cards 1-3 are display-only', (tester) async {
      var consistencyTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsKpiSummaryRow(
                snapshot: testSnapshot,
                onConsistencyTap: () => consistencyTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Total XP'));
      await tester.pumpAndSettle();
      expect(consistencyTapped, isFalse);

      await tester.tap(find.text('XP Velocity'));
      await tester.pumpAndSettle();
      expect(consistencyTapped, isFalse);

      await tester.tap(find.text('Completion Rate'));
      await tester.pumpAndSettle();
      expect(consistencyTapped, isFalse);

      await tester.tap(find.text('Consistency'));
      await tester.pumpAndSettle();
      expect(consistencyTapped, isTrue);
    });

    testWidgets('renders cleanly in Light Theme without layout errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsKpiSummaryRow(snapshot: testSnapshot),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total XP'), findsOneWidget);
      expect(find.text('XP Velocity'), findsOneWidget);
      expect(find.text('Completion Rate'), findsOneWidget);
      expect(find.text('Consistency'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('adapts responsively across Desktop, Tablet, and Mobile viewports', (tester) async {
      final viewports = [
        const Size(1440, 900), // Desktop
        const Size(1024, 768), // Large tablet
        const Size(768, 1024), // Medium tablet
        const Size(390, 844),  // Mobile phone
      ];

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: KratosTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: AnalyticsKpiSummaryRow(snapshot: testSnapshot),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Total XP'), findsOneWidget, reason: 'Failed on viewport $size');
        expect(find.text('XP Velocity'), findsOneWidget, reason: 'Failed on viewport $size');
        expect(find.text('Completion Rate'), findsOneWidget, reason: 'Failed on viewport $size');
        expect(find.text('Consistency'), findsOneWidget, reason: 'Failed on viewport $size');
        expect(tester.takeException(), isNull, reason: 'Overflow exception on viewport $size');
      }
    });

    testWidgets('integrated inside AnalyticsScreen and honors Wave 03 stop boundary', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: AnalyticsScreen(ownerId: 'test_user'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Header is present
      expect(find.text('Analytics'), findsOneWidget);
      // 2. Controls are present
      expect(find.text('Last 30 Days'), findsWidgets);
      // 3. All 4 KPI cards are present
      expect(find.text('Total XP'), findsWidgets);
      expect(find.text('XP Velocity'), findsOneWidget);
      expect(find.text('Completion Rate'), findsOneWidget);
      expect(find.text('Consistency'), findsOneWidget);

      // 4. Wave 03 STOP BOUNDARY: No charts, graphs, or placeholder cards below
      expect(find.text('Daily Growth'), findsNothing);
      expect(find.text('Add Widget'), findsNothing);
      expect(find.text('XP by Life Area'), findsNothing);
      expect(find.text('Recent Logs'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('integrated AnalyticsScreen opens Consistency floating detail and dismisses on close', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: AnalyticsScreen(ownerId: 'test_user'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Consistency & Streak Detail'), findsNothing);

      // Tap consistency card
      await tester.tap(find.text('Consistency'));
      await tester.pumpAndSettle();

      expect(find.text('Consistency & Streak Detail'), findsOneWidget);
      expect(find.text('Active Days'), findsOneWidget);
      expect(find.text('Current Streak'), findsOneWidget);
      expect(find.text('Longest Streak'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Consistency & Streak Detail'), findsNothing);
    });

    testWidgets('changing date range filter dynamically updates comparison subtitle and recalculates values', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: AnalyticsScreen(ownerId: 'test_user'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AnalyticsKpiSummaryRow),
          matching: find.text('vs previous 30 days'),
        ),
        findsNWidgets(4),
      );

      // Open Date Range dropdown
      await tester.tap(find.text('Last 30 Days').first);
      await tester.pumpAndSettle();

      // Select Last 7 Days
      await tester.tap(find.text('Last 7 Days').last);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AnalyticsKpiSummaryRow),
          matching: find.text('vs previous 7 days'),
        ),
        findsNWidgets(4),
      );
    });
  });
}
