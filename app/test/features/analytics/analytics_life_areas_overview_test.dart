import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kratos_app/app/kratos_theme.dart';
import 'package:kratos_app/features/analytics/domain/analytics_models.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/analytics_life_areas_overview_card.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/life_areas_overview/life_areas_radar_chart.dart';
import 'package:kratos_app/features/analytics/presentation/widgets/life_areas_overview/life_areas_radar_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleMetrics = [
    const AnalyticsLifeAreaMetric(
      id: 'la_health',
      name: 'Health',
      xp: 6800,
      level: 4,
      tier: 'Crystal',
      currentStreak: 12,
      longestStreak: 24,
      progress: 0.68,
      activityCount: 34,
      completionCount: 28,
      trendPct: 8.5,
    ),
    const AnalyticsLifeAreaMetric(
      id: 'la_wealth',
      name: 'Wealth',
      xp: 4200,
      level: 3,
      tier: 'Gold',
      currentStreak: 8,
      longestStreak: 15,
      progress: 0.42,
      activityCount: 22,
      completionCount: 16,
      trendPct: -3.2,
    ),
    const AnalyticsLifeAreaMetric(
      id: 'la_relationships',
      name: 'Relationships',
      xp: 3200,
      level: 2,
      tier: 'Silver',
      currentStreak: 5,
      longestStreak: 10,
      progress: 0.32,
      activityCount: 18,
      completionCount: 12,
      trendPct: 2.1,
    ),
    const AnalyticsLifeAreaMetric(
      id: 'la_knowledge',
      name: 'Knowledge',
      xp: 7600,
      level: 5,
      tier: 'Diamond',
      currentStreak: 18,
      longestStreak: 30,
      progress: 0.76,
      activityCount: 45,
      completionCount: 38,
      trendPct: 12.4,
    ),
    const AnalyticsLifeAreaMetric(
      id: 'la_creativity',
      name: 'Creativity',
      xp: 5400,
      level: 3,
      tier: 'Gold',
      currentStreak: 9,
      longestStreak: 14,
      progress: 0.54,
      activityCount: 26,
      completionCount: 20,
      trendPct: 5.6,
    ),
  ];

  AnalyticsSnapshot buildSnapshot(List<AnalyticsLifeAreaMetric> areas) {
    return AnalyticsSnapshot(
      range: AnalyticsDateRange.forPeriod(AnalyticsPeriod.thirtyDays),
      lifeAreaId: null,
      totalXp: areas.fold(0, (acc, a) => acc + a.xp),
      previousTotalXp: (areas.fold(0, (acc, a) => acc + a.xp) * 0.88).round(),
      xpDelta: const MetricDelta(
        current: 27200,
        previous: 24000,
        changePct: 13.3,
        isPositive: true,
      ),
      positiveXp: 27200,
      negativeXp: 0,
      xpVelocityDelta: const MetricDelta(
        current: 906,
        previous: 800,
        changePct: 13.25,
        isPositive: true,
      ),
      completionRateDelta: const MetricDelta(
        current: 82,
        previous: 76,
        changePct: 7.8,
        isPositive: true,
      ),
      consistencyDelta: const MetricDelta(
        current: 91,
        previous: 85,
        changePct: 7.0,
        isPositive: true,
      ),
      activeGoals: 8,
      completedGoals: 4,
      activeProjects: 5,
      completedProjects: 3,
      activeTasks: 14,
      completedTasks: 42,
      activitiesStarted: 35,
      sessionsCompleted: 28,
      actualMinutes: 1450,
      currentStreak: 14,
      longestStreak: 30,
      xpOverTime: const [],
      xpBySource: const {},
      lifeAreas: areas,
    );
  }

  group('Wave 07: Life Areas Radar & Overview', () {
    test(
      'RadarLifeAreaEntry model clamps progress and maps metrics accurately',
      () {
        final entry = RadarLifeAreaEntry.fromMetric(sampleMetrics[0]);
        expect(entry.id, 'la_health');
        expect(entry.name, 'Health');
        expect(entry.displayPct, 68);
        expect(entry.normalizedProgress, 0.68);
        expect(entry.xp, 6800);
        expect(entry.level, 4);
        expect(entry.tier, 'Crystal');

        // Test extreme clamping
        const extreme = AnalyticsLifeAreaMetric(
          id: 'la_ext',
          name: 'Extreme',
          xp: 100,
          level: 1,
          tier: 'Bronze',
          currentStreak: 0,
          longestStreak: 0,
          progress: 1.5,
        );
        final clamped = RadarLifeAreaEntry.fromMetric(extreme);
        expect(clamped.normalizedProgress, 1.0);
        expect(clamped.displayPct, 100);
      },
    );

    testWidgets('renders Life Areas Overview card with header and 5 domains', (
      tester,
    ) async {
      final snapshot = buildSnapshot(sampleMetrics);

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsLifeAreasOverviewCard(
                snapshot: snapshot,
                periodSubtitle: 'Last 30 Days',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Life Areas Overview'), findsOneWidget);
      expect(
        find.text('Your balanced growth across all life areas'),
        findsOneWidget,
      );
      expect(find.text('Health'), findsAtLeastNWidgets(1));
      expect(find.text('Wealth'), findsAtLeastNWidgets(1));
      expect(find.text('Relationships'), findsAtLeastNWidgets(1));
      expect(find.text('Knowledge'), findsAtLeastNWidgets(1));
      expect(find.text('Creativity'), findsAtLeastNWidgets(1));
      expect(find.text('68%'), findsAtLeastNWidgets(1));
      expect(find.text('42%'), findsAtLeastNWidgets(1));
    });

    testWidgets('animates polygon vertices when values change over time', (
      tester,
    ) async {
      final initialSnapshot = buildSnapshot(sampleMetrics);

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsLifeAreasOverviewCard(
                snapshot: initialSnapshot,
                periodSubtitle: 'Last 30 Days',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // Update values (Day 2 change)
      final updatedMetrics = [
        sampleMetrics[0].copyWith(progress: 0.72),
        sampleMetrics[1].copyWith(progress: 0.35),
        sampleMetrics[2].copyWith(progress: 0.42),
        sampleMetrics[3].copyWith(progress: 0.86),
        sampleMetrics[4].copyWith(progress: 0.64),
      ];
      final updatedSnapshot = buildSnapshot(updatedMetrics);

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsLifeAreasOverviewCard(
                snapshot: updatedSnapshot,
                periodSubtitle: 'Last 30 Days',
              ),
            ),
          ),
        ),
      );

      // Verify mid-flight animation
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.byType(LifeAreasRadarChart), findsOneWidget);

      // Complete transition
      await tester.pumpAndSettle();
      expect(find.text('72%'), findsAtLeastNWidgets(1));
      expect(find.text('86%'), findsAtLeastNWidgets(1));
    });

    testWidgets('supports large count strategy (> 7 life areas)', (
      tester,
    ) async {
      final largeCountMetrics = [
        ...sampleMetrics,
        const AnalyticsLifeAreaMetric(
          id: 'la_inner_peace',
          name: 'Inner Peace',
          xp: 4900,
          level: 3,
          tier: 'Gold',
          currentStreak: 7,
          longestStreak: 12,
          progress: 0.49,
        ),
        const AnalyticsLifeAreaMetric(
          id: 'la_productivity',
          name: 'Productivity',
          xp: 6200,
          level: 4,
          tier: 'Crystal',
          currentStreak: 11,
          longestStreak: 20,
          progress: 0.62,
        ),
        const AnalyticsLifeAreaMetric(
          id: 'la_social',
          name: 'Social Impact',
          xp: 2800,
          level: 2,
          tier: 'Silver',
          currentStreak: 4,
          longestStreak: 8,
          progress: 0.28,
        ),
      ];
      final largeSnapshot = buildSnapshot(largeCountMetrics);

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsLifeAreasOverviewCard(
                snapshot: largeSnapshot,
                periodSubtitle: 'Last 30 Days',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top 7 notice banner is displayed
      expect(
        find.text('Displaying top 7 of 8 life areas on radar'),
        findsOneWidget,
      );
      // All 8 areas remain accessible in list
      expect(find.text('Inner Peace'), findsOneWidget);
      expect(find.text('Productivity'), findsOneWidget);
      expect(find.text('Social Impact'), findsOneWidget);
    });

    testWidgets('renders empty state when life areas list is empty', (
      tester,
    ) async {
      final emptySnapshot = buildSnapshot([]);

      await tester.pumpWidget(
        MaterialApp(
          theme: KratosTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AnalyticsLifeAreasOverviewCard(
                snapshot: emptySnapshot,
                periodSubtitle: 'Last 30 Days',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Life Areas Overview Data'), findsOneWidget);
    });

    testWidgets(
      'renders cleanly on mobile viewport 430x932 without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: KratosTheme.darkTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnalyticsLifeAreasOverviewCard(
                  snapshot: buildSnapshot(sampleMetrics),
                  periodSubtitle: 'Last 30 Days',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}

extension on AnalyticsLifeAreaMetric {
  AnalyticsLifeAreaMetric copyWith({double? progress}) {
    return AnalyticsLifeAreaMetric(
      id: id,
      name: name,
      xp: xp,
      previousXp: previousXp,
      level: level,
      tier: tier,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      progress: progress ?? this.progress,
      activityCount: activityCount,
      completionCount: completionCount,
      trendPct: trendPct,
      color: color,
    );
  }
}
