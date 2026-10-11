import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kratos_app/app/kratos_theme.dart';
import 'package:kratos_app/features/analytics/data/analytics_mock_data.dart';
import 'package:kratos_app/features/analytics/domain/analytics_models.dart';
import 'package:kratos_app/features/analytics/presentation/analytics_screen.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/analytics_xp_distribution_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Analytics XP Distribution Card (Wave 05)', () {
    testWidgets('renders XP Distribution title and description', (tester) async {
      final snapshot = AnalyticsMockData.snapshot(
        range: AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpDistributionCard(
                snapshot: snapshot,
                periodSubtitle: 'vs previous 30 days',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('XP Distribution'), findsOneWidget);
      expect(
        find.text('See where your XP comes from and which activities contribute the most.'),
        findsOneWidget,
      );
      expect(find.text('Source'), findsOneWidget);
      expect(find.text('Percentage'), findsOneWidget);
    });

    testWidgets('displays Positive XP and Negative XP cards with real values', (tester) async {
      final snapshot = AnalyticsSnapshot(
        range: AnalyticsDateRange(
          start: DateTime.utc(2026, 9, 1),
          end: DateTime.utc(2026, 10, 1),
        ),
        lifeAreaId: null,
        totalXp: 4000,
        positiveXp: 4200,
        negativeXp: 200,
        xpDelta: const MetricDelta(current: 4000, previous: 3500, changePct: 14.3, isPositive: true),
        xpVelocityDelta: const MetricDelta(current: 133, previous: 116, changePct: 14.3, isPositive: true),
        completionRateDelta: const MetricDelta(current: 80, previous: 75, changePct: 6.7, isPositive: true),
        consistencyDelta: const MetricDelta(current: 90, previous: 85, changePct: 5.9, isPositive: true),
        activeGoals: 2,
        completedGoals: 1,
        activeProjects: 1,
        completedProjects: 1,
        activeTasks: 5,
        completedTasks: 15,
        activitiesStarted: 10,
        sessionsCompleted: 8,
        actualMinutes: 400,
        currentStreak: 5,
        longestStreak: 10,
        xpOverTime: const [],
        xpBySource: const {
          'Tasks': 2500,
          'Goals': 1500,
        },
        lifeAreas: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpDistributionCard(
                snapshot: snapshot,
                periodSubtitle: 'vs previous period',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Positive XP'), findsOneWidget);
      expect(find.text('Negative XP'), findsOneWidget);
      expect(find.text('4,200'), findsOneWidget);
      expect(find.text('-200'), findsOneWidget);
    });

    testWidgets('sorts sources descending by XP contribution', (tester) async {
      final snapshot = AnalyticsSnapshot(
        range: AnalyticsDateRange(
          start: DateTime.utc(2026, 9, 1),
          end: DateTime.utc(2026, 10, 1),
        ),
        lifeAreaId: null,
        totalXp: 3000,
        positiveXp: 3000,
        negativeXp: 0,
        xpDelta: const MetricDelta(current: 3000, previous: 2000, changePct: 50, isPositive: true),
        xpVelocityDelta: const MetricDelta(current: 100, previous: 66, changePct: 50, isPositive: true),
        completionRateDelta: const MetricDelta(current: 80, previous: 80, changePct: 0, isPositive: true),
        consistencyDelta: const MetricDelta(current: 90, previous: 90, changePct: 0, isPositive: true),
        activeGoals: 1,
        completedGoals: 1,
        activeProjects: 1,
        completedProjects: 0,
        activeTasks: 2,
        completedTasks: 5,
        activitiesStarted: 5,
        sessionsCompleted: 4,
        actualMinutes: 200,
        currentStreak: 3,
        longestStreak: 5,
        xpOverTime: const [],
        xpBySource: const {
          'Goals': 500,
          'Tasks': 2000,
          'Projects': 500,
        },
        lifeAreas: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpDistributionCard(
                snapshot: snapshot,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tasks (2000 XP) must be ranked first
      final tasksFinder = find.text('Tasks');
      final goalsFinder = find.text('Goals');
      expect(tasksFinder, findsOneWidget);
      expect(goalsFinder, findsOneWidget);

      final tasksY = tester.getTopLeft(tasksFinder).dy;
      final goalsY = tester.getTopLeft(goalsFinder).dy;
      expect(tasksY < goalsY, isTrue, reason: 'Tasks (2000 XP) should appear above Goals (500 XP)');
    });

    testWidgets('handles unknown source types safely without dropping them', (tester) async {
      final snapshot = AnalyticsSnapshot(
        range: AnalyticsDateRange(
          start: DateTime.utc(2026, 9, 1),
          end: DateTime.utc(2026, 10, 1),
        ),
        lifeAreaId: null,
        totalXp: 1500,
        positiveXp: 1500,
        negativeXp: 0,
        xpDelta: const MetricDelta(current: 1500, previous: 1000, changePct: 50, isPositive: true),
        xpVelocityDelta: const MetricDelta(current: 50, previous: 33, changePct: 50, isPositive: true),
        completionRateDelta: const MetricDelta(current: 80, previous: 80, changePct: 0, isPositive: true),
        consistencyDelta: const MetricDelta(current: 90, previous: 90, changePct: 0, isPositive: true),
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
        xpBySource: const {
          'mysterious_quest': 1500,
        },
        lifeAreas: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpDistributionCard(
                snapshot: snapshot,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Display label is capitalized safely
      expect(find.text('Mysterious_quest'), findsOneWidget);
      expect(find.text('1,500 XP'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('handles zero XP empty state without division by zero', (tester) async {
      final emptySnapshot = AnalyticsSnapshot(
        range: AnalyticsDateRange(
          start: DateTime.utc(2026, 9, 1),
          end: DateTime.utc(2026, 10, 1),
        ),
        lifeAreaId: null,
        totalXp: 0,
        positiveXp: 0,
        negativeXp: 0,
        xpDelta: const MetricDelta(current: 0, previous: 0, changePct: 0, isPositive: true, isNeutral: true),
        xpVelocityDelta: const MetricDelta(current: 0, previous: 0, changePct: 0, isPositive: true, isNeutral: true),
        completionRateDelta: const MetricDelta(current: 0, previous: 0, changePct: 0, isPositive: true, isNeutral: true),
        consistencyDelta: const MetricDelta(current: 0, previous: 0, changePct: 0, isPositive: true, isNeutral: true),
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
        xpBySource: const {},
        lifeAreas: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpDistributionCard(
                snapshot: emptySnapshot,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0'), findsWidgets);
      expect(find.text('Total XP'), findsOneWidget);
      expect(find.text('No XP activity recorded for this period.'), findsWidgets);
      expect(tester.takeException(), isNull);
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
              child: AnalyticsXpDistributionCard(
                snapshot: snapshot,
                periodSubtitle: 'vs previous 7 days',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('XP Distribution'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders loading skeleton when isLoading is true', (tester) async {
      final snapshot = AnalyticsMockData.snapshot(
        range: AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpDistributionCard(
                snapshot: snapshot,
                isLoading: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Title should not be rendered in skeleton state
      expect(find.text('XP Distribution'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('adapts responsively across Desktop, Tablet, and Mobile viewports without overflow', (tester) async {
      final snapshot = AnalyticsMockData.snapshot(
        range: AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays),
      );

      final viewports = [
        const Size(1440, 900),
        const Size(1024, 768),
        const Size(768, 1024),
        const Size(430, 932),
        const Size(390, 844),
      ];

      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          MaterialApp(
            theme: KratosTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: AnalyticsXpDistributionCard(
                  snapshot: snapshot,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('XP Distribution'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('tapping source row triggers interaction and highlighting callback', (tester) async {
      final snapshot = AnalyticsMockData.snapshot(
        range: AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays),
      );

      String? selectedSource;

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsXpDistributionCard(
                snapshot: snapshot,
                onSourceSelected: (src) => selectedSource = src,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tasksFinder = find.text('Tasks');
      expect(tasksFinder, findsOneWidget);

      await tester.tap(tasksFinder);
      await tester.pumpAndSettle();

      expect(selectedSource, equals('Tasks'));
    });

    testWidgets('changing date range filter dynamically updates XP Distribution', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: const Scaffold(
            body: AnalyticsScreen(
              initialPeriod: AnalyticsPeriod.sevenDays,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('XP Distribution'), findsOneWidget);
      expect(find.text('XP Trend'), findsOneWidget);

      // Open Date selector pill
      final datePillFinder = find.text('Last 7 Days').first;
      expect(datePillFinder, findsOneWidget);
      await tester.tap(datePillFinder);
      await tester.pumpAndSettle();

      // Select Last 30 Days
      final option30Days = find.text('Last 30 Days').last;
      expect(option30Days, findsOneWidget);
      await tester.tap(option30Days);
      await tester.pumpAndSettle();

      expect(find.text('Last 30 Days'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
