import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/features/analytics/domain/analytics_models.dart';
import 'package:kratos_app/features/analytics/presentation/insights_screen.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/analytics_insights_card.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/focus_time/focus_time_activity_pattern_card.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/focus_time/focus_time_by_day_card.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/focus_time/focus_time_by_hour_card.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/focus_time/focus_time_hero_card.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/focus_time/focus_time_insights_card.dart';

void main() {
  group('AnalyticsInsightsCard Widget Tests', () {
    final range = AnalyticsDateRange.forPeriod(
      AnalyticsPeriod.thirtyDays,
      now: DateTime(2026, 10, 8),
    );

    AnalyticsSnapshot createSnapshotWithTrends(List<PositiveTrendInsight> trends) {
      return AnalyticsSnapshot(
        range: range,
        lifeAreaId: null,
        totalXp: 3000,
        previousTotalXp: 2000,
        xpDelta: const MetricDelta(
          current: 3000,
          previous: 2000,
          changePct: 50.0,
          isPositive: true,
        ),
        positiveXp: 3000,
        negativeXp: 0,
        xpVelocityDelta: const MetricDelta(
          current: 100,
          previous: 70,
          changePct: 42.8,
          isPositive: true,
        ),
        completionRateDelta: const MetricDelta(
          current: 78.0,
          previous: 62.0,
          changePct: 25.8,
          isPositive: true,
        ),
        consistencyDelta: const MetricDelta(
          current: 85.0,
          previous: 72.0,
          changePct: 18.0,
          isPositive: true,
        ),
        activeGoals: 2,
        completedGoals: 1,
        activeProjects: 1,
        completedProjects: 1,
        activeTasks: 3,
        completedTasks: 12,
        activitiesStarted: 5,
        sessionsCompleted: 8,
        actualMinutes: 450,
        currentStreak: 6,
        longestStreak: 12,
        xpOverTime: const [],
        xpBySource: const {},
        lifeAreas: const [],
        positiveTrends: trends,
      );
    }

    final sampleTrends = [
      const PositiveTrendInsight(
        metric: PositiveTrendMetric.focusTime,
        title: 'Focus time increased',
        currentValueFormatted: '12h 45m',
        previousValueFormatted: '10h 15m',
        deltaFormatted: '+24%',
        deltaValue: 8820000,
        percentageChange: 24.0,
        comparisonPeriodLabel: 'vs last week',
        factualDescription: '+2h 30m compared with the previous period.',
        iconIdentifier: 'timer',
        significanceScore: 90.0,
      ),
      const PositiveTrendInsight(
        metric: PositiveTrendMetric.totalXp,
        title: 'Total XP increased',
        currentValueFormatted: '2,360 XP',
        previousValueFormatted: '2,000 XP',
        deltaFormatted: '+18%',
        deltaValue: 360,
        percentageChange: 18.0,
        comparisonPeriodLabel: 'vs last week',
        factualDescription: '+360 XP compared with the previous period.',
        iconIdentifier: 'bolt',
        significanceScore: 80.0,
      ),
      const PositiveTrendInsight(
        metric: PositiveTrendMetric.completionRate,
        title: 'Completion rate improved',
        currentValueFormatted: '68%',
        previousValueFormatted: '52%',
        deltaFormatted: '+16% pts',
        deltaValue: 16.0,
        percentageChange: 16.0,
        comparisonPeriodLabel: 'vs last week',
        factualDescription: '+16 percentage points compared with the previous period.',
        iconIdentifier: 'check_circle',
        significanceScore: 64.0,
      ),
    ];

    testWidgets('Renders header title, subtitle, lightbulb icon, and positive trend cards in Dark Mode', (tester) async {
      final snapshot = createSnapshotWithTrends(sampleTrends);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsInsightsCard(snapshot: snapshot),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Smart insights from your data.'), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb_outline_rounded), findsOneWidget);

      // Verify the 3 positive trends render
      expect(find.text('Focus time increased'), findsOneWidget);
      expect(find.text('12h 45m'), findsOneWidget);
      expect(find.text('+24%'), findsOneWidget);

      expect(find.text('Total XP increased'), findsOneWidget);
      expect(find.text('2,360 XP'), findsOneWidget);
      expect(find.text('+18%'), findsOneWidget);

      expect(find.text('Completion rate improved'), findsOneWidget);
      expect(find.text('68%'), findsOneWidget);
      expect(find.text('+16% pts'), findsOneWidget);
    });

    testWidgets('Renders cleanly in Light Mode with high contrast typography and subtle styling', (tester) async {
      final snapshot = createSnapshotWithTrends(sampleTrends);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(useMaterial3: true),
          home: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: SingleChildScrollView(
              child: AnalyticsInsightsCard(snapshot: snapshot),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('Focus time increased'), findsOneWidget);
      expect(find.text('+2h 30m compared with the previous period.'), findsOneWidget);
    });

    testWidgets('Renders clean empty state when no positive trends exist', (tester) async {
      final emptySnapshot = createSnapshotWithTrends(const []);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: AnalyticsInsightsCard(snapshot: emptySnapshot),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Insights'), findsOneWidget);
      expect(find.text('No significant positive trends yet.'), findsOneWidget);
      expect(
        find.text('Keep using KRATOS and trends will appear as enough data accumulates.'),
        findsOneWidget,
      );
      // "View All" button should NOT be rendered when empty
      expect(find.text('View All'), findsNothing);
    });

    testWidgets('Adapts responsively to mobile viewport (390x844) without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final snapshot = createSnapshotWithTrends(sampleTrends);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsInsightsCard(snapshot: snapshot),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Focus time increased'), findsOneWidget);
      expect(find.text('Total XP increased'), findsOneWidget);
      expect(find.text('Completion rate improved'), findsOneWidget);
    });

    testWidgets('Adapts responsively to tablet viewport (768x1024) without overflow', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final snapshot = createSnapshotWithTrends(sampleTrends);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsInsightsCard(snapshot: snapshot),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Focus time increased'), findsOneWidget);
    });

    testWidgets('Adapts responsively to desktop viewport (1280x800) without overflow', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final snapshot = createSnapshotWithTrends(sampleTrends);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsInsightsCard(snapshot: snapshot),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Focus time increased'), findsOneWidget);
    });

    testWidgets('View All expands beyond top 3 when 4 or more trends exist', (tester) async {
      final extraTrend = const PositiveTrendInsight(
        metric: PositiveTrendMetric.consistency,
        title: 'Consistency improved',
        currentValueFormatted: '85%',
        previousValueFormatted: '72%',
        deltaFormatted: '+13% pts',
        deltaValue: 13.0,
        percentageChange: 13.0,
        comparisonPeriodLabel: 'vs last week',
        factualDescription: '+13 percentage points compared with the previous period.',
        iconIdentifier: 'calendar',
        significanceScore: 52.0,
      );

      final fourTrends = [...sampleTrends, extraTrend];
      final snapshot = createSnapshotWithTrends(fourTrends);

      bool callbackInvoked = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsInsightsCard(
                snapshot: snapshot,
                onViewAllTap: () => callbackInvoked = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top 3 rendered initially, 4th hidden
      expect(find.text('Consistency improved'), findsNothing);
      expect(find.text('View All'), findsOneWidget);

      // Tap View All invokes callback
      await tester.tap(find.text('View All'));
      await tester.pumpAndSettle();
      expect(callbackInvoked, isTrue);
    });

    testWidgets('Tapping View All opens full InsightsScreen and back button pops back', (tester) async {
      final extraTrend = const PositiveTrendInsight(
        metric: PositiveTrendMetric.consistency,
        title: 'Consistency improved',
        currentValueFormatted: '75%',
        previousValueFormatted: '62%',
        deltaFormatted: '+13% pts',
        deltaValue: 13.0,
        percentageChange: 13.0,
        comparisonPeriodLabel: 'vs last week',
        factualDescription: '+13 percentage points compared with the previous period.',
        iconIdentifier: 'calendar',
        significanceScore: 52.0,
      );

      final fourTrends = [...sampleTrends, extraTrend];
      final snapshot = createSnapshotWithTrends(fourTrends);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsInsightsCard(snapshot: snapshot),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap View All without custom callback (uses default navigation)
      await tester.tap(find.text('View All'));
      await tester.pumpAndSettle();

      // Verify InsightsScreen is pushed and renders reference layout
      expect(find.byType(InsightsScreen), findsOneWidget);
      expect(find.byType(FocusTimeHeroCard), findsOneWidget);
      expect(find.byType(FocusTimeActivityPatternCard), findsOneWidget);
      expect(find.byType(FocusTimeByDayCard), findsOneWidget);
      expect(find.byType(FocusTimeByHourCard), findsOneWidget);
      expect(find.byType(FocusTimeInsightsCard), findsOneWidget);

      // Tap Back button on InsightsScreen
      await tester.tap(find.byKey(const ValueKey('insights_back_button')));
      await tester.pumpAndSettle();

      // Popped back to dashboard preview
      expect(find.byType(InsightsScreen), findsNothing);
      expect(find.byType(AnalyticsInsightsCard), findsOneWidget);
      // Still only top 3 on dashboard preview
      expect(find.text('Consistency improved'), findsNothing);
    });

    testWidgets('InsightsScreen renders gracefully with zero/empty snapshot', (tester) async {
      final emptySnapshot = createSnapshotWithTrends(const []);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: InsightsScreen(snapshot: emptySnapshot),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InsightsScreen), findsOneWidget);
      expect(find.byType(FocusTimeHeroCard), findsOneWidget);
      expect(find.byType(FocusTimeInsightsCard), findsOneWidget);
    });

    testWidgets('InsightsScreen adapts responsively to mobile, tablet, and desktop viewports', (tester) async {
      final snapshot = createSnapshotWithTrends(sampleTrends);

      final viewports = [
        const Size(390, 844),   // Mobile
        const Size(768, 1024),  // Tablet
        const Size(1440, 900),  // Desktop
      ];

      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: InsightsScreen(snapshot: snapshot),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(InsightsScreen), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Error on viewport ${vp.width}x${vp.height}');
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
