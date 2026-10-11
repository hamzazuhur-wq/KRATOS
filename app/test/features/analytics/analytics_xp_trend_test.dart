import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kratos_app/app/kratos_theme.dart';
import 'package:kratos_app/features/analytics/data/analytics_mock_data.dart';
import 'package:kratos_app/features/analytics/domain/analytics_models.dart';
import 'package:kratos_app/features/analytics/presentation/analytics_screen.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/analytics_xp_trend_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Analytics XP Trend Card (Wave 04)', () {
    testWidgets('renders XP Trend title, description, and analytical icon', (tester) async {
      final snapshot = AnalyticsMockData.snapshot(
        range: AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpTrendCard(
                snapshot: snapshot,
                periodSubtitle: 'vs previous 30 days',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('XP Trend'), findsOneWidget);
      expect(
        find.text('Track your XP progress over time and see how consistent you are.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.trending_up_rounded), findsOneWidget);
    });

    testWidgets('displays Total XP metric, delta pill, and breakdown metrics', (tester) async {
      final snapshot = AnalyticsMockData.snapshot(
        range: AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpTrendCard(
                snapshot: snapshot,
                periodSubtitle: 'vs previous 30 days',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check for XP units and metric breakdown labels
      expect(find.text('XP'), findsWidgets);
      expect(find.text('Current Period'), findsWidgets);
      expect(find.text('Previous Period'), findsWidgets);
      expect(find.text('Net Change'), findsOneWidget);
      expect(find.text('Daily Average'), findsOneWidget);
    });

    testWidgets('renders cleanly in Light Mode without errors or visual regressions', (tester) async {
      final snapshot = AnalyticsMockData.snapshot(
        range: AnalyticsDateRange.forPeriod(AnalyticsPeriod.sevenDays),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpTrendCard(
                snapshot: snapshot,
                periodSubtitle: 'vs previous 7 days',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('XP Trend'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders empty state when no XP series points are present', (tester) async {
      final emptySnapshot = AnalyticsSnapshot(
        range: AnalyticsDateRange(
          start: DateTime.utc(2026, 9, 1),
          end: DateTime.utc(2026, 9, 8),
        ),
        lifeAreaId: null,
        totalXp: 0,
        previousTotalXp: 0,
        xpDelta: const MetricDelta(current: 0, previous: 0, changePct: 0, isPositive: false, isNeutral: true),
        positiveXp: 0,
        negativeXp: 0,
        xpVelocityDelta: const MetricDelta(current: 0, previous: 0, changePct: 0, isPositive: false, isNeutral: true),
        completionRateDelta: const MetricDelta(current: 0, previous: 0, changePct: 0, isPositive: false, isNeutral: true),
        consistencyDelta: const MetricDelta(current: 0, previous: 0, changePct: 0, isPositive: false, isNeutral: true),
        activeGoals: 0,
        completedGoals: 0,
        activeProjects: 0,
        completedProjects: 0,
        activeTasks: 0,
        completedTasks: 0,
        activitiesStarted: 0,
        sessionsCompleted: 0,
        actualMinutes: 0,
        currentStreak: 0,
        longestStreak: 0,
        xpOverTime: const [],
        previousXpOverTime: const [],
        xpBySource: const {},
        lifeAreas: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpTrendCard(
                snapshot: emptySnapshot,
                periodSubtitle: 'vs previous period',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No XP activity recorded for this period'), findsOneWidget);
      expect(
        find.text('Complete tasks, goals, or sessions to generate time-series analytics.'),
        findsOneWidget,
      );
    });

    testWidgets('adapts responsively across Desktop, Tablet, and Mobile viewports without overflow', (tester) async {
      final snapshot = AnalyticsMockData.snapshot(
        range: AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays),
      );

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
        addTearDown(() => tester.view.resetPhysicalSize());
        addTearDown(() => tester.view.resetDevicePixelRatio());

        await tester.pumpWidget(
          MaterialApp(
            theme: KratosTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: AnalyticsXpTrendCard(
                  snapshot: snapshot,
                  periodSubtitle: 'vs previous 30 days',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('XP Trend'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Overflow on viewport ${vp.width}x${vp.height}');
      }
    });

    testWidgets('interactive hover displays floating tooltip with comparison data', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final snapshot = AnalyticsMockData.snapshot(
        range: AnalyticsDateRange.forPeriod(AnalyticsPeriod.sevenDays),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpTrendCard(
                snapshot: snapshot,
                periodSubtitle: 'vs previous 7 days',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tooltip is not visible before interaction
      expect(find.text('Net Difference:'), findsNothing);

      // Perform a hover gesture on the chart CustomPaint area
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      final chartFinder = find.byType(CustomPaint).last;
      final center = tester.getCenter(chartFinder);

      await gesture.moveTo(center);
      await tester.pumpAndSettle();

      // Tooltip should be visible with comparison breakdown
      expect(find.text('Net Difference:'), findsOneWidget);
      expect(find.text('Current:'), findsOneWidget);
    });

    testWidgets('Negative XP: accommodates negative values, zero baseline, and negative tooltip', (tester) async {
      final negativePoints = [
        AnalyticsPoint(date: DateTime.utc(2026, 9, 1), xp: 200),
        AnalyticsPoint(date: DateTime.utc(2026, 9, 2), xp: -80),
        AnalyticsPoint(date: DateTime.utc(2026, 9, 3), xp: 150),
        AnalyticsPoint(date: DateTime.utc(2026, 9, 4), xp: 300),
      ];
      final prevPoints = [
        AnalyticsPoint(date: DateTime.utc(2026, 8, 25), xp: 180),
        AnalyticsPoint(date: DateTime.utc(2026, 8, 26), xp: 120),
        AnalyticsPoint(date: DateTime.utc(2026, 8, 27), xp: 140),
        AnalyticsPoint(date: DateTime.utc(2026, 8, 28), xp: 250),
      ];

      final snapshot = AnalyticsSnapshot(
        range: AnalyticsDateRange(
          start: DateTime.utc(2026, 9, 1),
          end: DateTime.utc(2026, 9, 4),
        ),
        lifeAreaId: null,
        totalXp: 570,
        previousTotalXp: 690,
        xpDelta: const MetricDelta(current: 570, previous: 690, changePct: -17.4, isPositive: false, isNeutral: false),
        positiveXp: 650,
        negativeXp: 80,
        xpVelocityDelta: const MetricDelta(current: 142.5, previous: 172.5, changePct: -17.4, isPositive: false, isNeutral: false),
        completionRateDelta: const MetricDelta(current: 80, previous: 80, changePct: 0, isPositive: false, isNeutral: true),
        consistencyDelta: const MetricDelta(current: 3, previous: 4, changePct: -25, isPositive: false, isNeutral: false),
        activeGoals: 2,
        completedGoals: 1,
        activeProjects: 1,
        completedProjects: 0,
        activeTasks: 4,
        completedTasks: 3,
        activitiesStarted: 2,
        sessionsCompleted: 2,
        actualMinutes: 90,
        currentStreak: 2,
        longestStreak: 5,
        xpOverTime: negativePoints,
        previousXpOverTime: prevPoints,
        xpBySource: const {'tasks': 650, 'penalties': -80},
        lifeAreas: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpTrendCard(
                snapshot: snapshot,
                periodSubtitle: 'vs previous 4 days',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Penalties stat row is visible
      expect(find.text('Penalties'), findsOneWidget);
      expect(find.text('-80 XP'), findsOneWidget);

      // 2. Hover over index 1 (the negative XP point at -80 XP)
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      final chartFinder = find.byType(CustomPaint).last;
      final topLeft = tester.getTopLeft(chartFinder);
      final size = tester.getSize(chartFinder);

      // Point index 1 is at ~ (38 + 1/3 * (width - 50))
      final chartWidth = size.width - 50.0;
      final targetX = topLeft.dx + 38.0 + (1 / 3) * chartWidth;
      final targetY = topLeft.dy + size.height * 0.5;

      await gesture.moveTo(Offset(targetX, targetY));
      await tester.pumpAndSettle();

      // 3. Tooltip reflects true negative XP value and difference without clamping
      expect(find.text('Current:'), findsOneWidget);
      expect(find.text('-80 XP'), findsNWidgets(2)); // Both Penalties stat row and Tooltip Current value
      expect(find.text('Previous:'), findsOneWidget);
      expect(find.text('120 XP'), findsOneWidget);
      expect(find.text('-200 XP (-166.7%)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AnalyticsScreen integrates XP Trend directly below KPI summary row', (tester) async {
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

      // 1. Heading & Controls
      expect(find.text('Analytics'), findsOneWidget);
      // 2. Wave 03 KPI Cards
      expect(find.text('Total XP'), findsWidgets); // Header & KPI Card
      expect(find.text('XP Velocity'), findsOneWidget);
      // 3. Wave 04 XP Trend Card
      expect(find.text('XP Trend'), findsOneWidget);
      expect(find.byType(AnalyticsXpTrendCard), findsOneWidget);

      // 4. Wave 05 STOP BOUNDARY: Future sections below XP Distribution remain absent
      expect(find.text('XP by Life Area'), findsNothing);
      expect(find.text('Life Area Radar'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
