import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/features/analytics/domain/analytics_models.dart';

void main() {
  group('PositiveTrendDetector Unit Tests', () {
    final defaultRange = AnalyticsDateRange.forPeriod(
      AnalyticsPeriod.thirtyDays,
      now: DateTime(2026, 10, 8),
    );

    AnalyticsSnapshot createBaseSnapshot({
      int totalXp = 1000,
      int previousTotalXp = 0,
      MetricDelta xpDelta = const MetricDelta(
        current: 1000,
        previous: 0,
        changePct: 0,
        isPositive: true,
      ),
      MetricDelta xpVelocityDelta = const MetricDelta(
        current: 33.3,
        previous: 0,
        changePct: 0,
        isPositive: true,
      ),
      MetricDelta completionRateDelta = const MetricDelta(
        current: 75.0,
        previous: 0,
        changePct: 0,
        isPositive: true,
      ),
      MetricDelta consistencyDelta = const MetricDelta(
        current: 80.0,
        previous: 0,
        changePct: 0,
        isPositive: true,
      ),
      FocusTimeSnapshot? focusTime,
      List<AnalyticsLifeAreaMetric> lifeAreas = const [],
      String? lifeAreaId,
    }) {
      return AnalyticsSnapshot(
        range: defaultRange,
        lifeAreaId: lifeAreaId,
        totalXp: totalXp,
        previousTotalXp: previousTotalXp,
        xpDelta: xpDelta,
        positiveXp: totalXp,
        negativeXp: 0,
        xpVelocityDelta: xpVelocityDelta,
        completionRateDelta: completionRateDelta,
        consistencyDelta: consistencyDelta,
        activeGoals: 2,
        completedGoals: 1,
        createdGoals: 3,
        activeProjects: 1,
        completedProjects: 1,
        createdProjects: 2,
        activeTasks: 4,
        completedTasks: 8,
        periodCompletedTasks: 8,
        previousCompletedTasks: 5,
        createdTasks: 10,
        createdDecisions: 0,
        completedDecisions: 0,
        activitiesStarted: 5,
        sessionsCompleted: 5,
        actualMinutes: 120,
        currentStreak: 5,
        longestStreak: 10,
        activeDaysCount: 20,
        xpOverTime: const [],
        previousXpOverTime: const [],
        dailyGrowthSeries: const [],
        xpBySource: const {},
        lifeAreas: lifeAreas,
        goalHealth: const [],
        projectPerformance: const [],
        tasksByPriority: const {},
        tasksByLifeArea: const {},
        activityByDayOfWeek: const {},
        activityByTimeOfDay: const {},
        milestones: const [],
        recentActivity: const [],
        insights: const [],
        topSkills: const [],
        focusTime: focusTime,
      );
    }

    test('Empty and zero data yields NO positive trends', () {
      final snapshot = createBaseSnapshot(
        totalXp: 0,
        previousTotalXp: 0,
        xpDelta: const MetricDelta(
          current: 0,
          previous: 0,
          changePct: 0,
          isPositive: true,
          isNeutral: true,
        ),
        completionRateDelta: const MetricDelta(
          current: 0,
          previous: 0,
          changePct: 0,
          isPositive: true,
          isNeutral: true,
        ),
        consistencyDelta: const MetricDelta(
          current: 0,
          previous: 0,
          changePct: 0,
          isPositive: true,
          isNeutral: true,
        ),
      );

      final trends = PositiveTrendDetector.detect(snapshot);
      expect(trends, isEmpty);
    });

    test('Zero previous period data yields NO positive trends (data sufficiency)', () {
      final snapshot = createBaseSnapshot(
        totalXp: 500,
        previousTotalXp: 0, // No previous data
        xpDelta: const MetricDelta(
          current: 500,
          previous: 0,
          changePct: 100,
          isPositive: true,
        ),
        completionRateDelta: const MetricDelta(
          current: 80,
          previous: 0,
          changePct: 100,
          isPositive: true,
        ),
      );

      final trends = PositiveTrendDetector.detect(snapshot);
      expect(trends, isEmpty);
    });

    test('Negative trend is strictly excluded', () {
      final snapshot = createBaseSnapshot(
        totalXp: 800,
        previousTotalXp: 1200,
        xpDelta: const MetricDelta(
          current: 800,
          previous: 1200,
          changePct: -33.3,
          isPositive: false,
        ),
        completionRateDelta: const MetricDelta(
          current: 40.0,
          previous: 65.0,
          changePct: -38.5,
          isPositive: false,
        ),
      );

      final trends = PositiveTrendDetector.detect(snapshot);
      expect(trends, isEmpty);
    });

    test('Insignificant changes below threshold are discarded (noise filtering)', () {
      final focusSnapshot = FocusTimeSnapshot(
        range: defaultRange,
        totalMs: 120000, // 2 minutes
        sessionCount: 2,
        averageMs: 60000,
        longestMs: 60000,
        previousTotalMs: 60000, // 1 minute (+100%, but only +1 minute!)
        previousSessionCount: 1,
        trendPercent: 100.0,
        daily: const [],
        hourly: const [],
        weekdayTotals: const [],
        weekdayDayCounts: const [],
        weekdayHour: const [],
        peakWindowStartHour: null,
        mostFocusedWeekday: null,
        mostFocusedWeekdayAvgMs: 0,
        topActivities: const [],
      );

      final snapshot = createBaseSnapshot(
        totalXp: 102,
        previousTotalXp: 100, // +2 XP (+2%) -> below 50 XP & 5%
        xpDelta: const MetricDelta(
          current: 102,
          previous: 100,
          changePct: 2.0,
          isPositive: true,
        ),
        focusTime: focusSnapshot,
        completionRateDelta: const MetricDelta(
          current: 51.0,
          previous: 50.0, // +1% pt -> below 3.0 pts threshold
          changePct: 2.0,
          isPositive: true,
        ),
      );

      final trends = PositiveTrendDetector.detect(snapshot);
      expect(trends, isEmpty);
    });

    test('Valid Positive Focus Time trend is detected and formatted correctly', () {
      final focusSnapshot = FocusTimeSnapshot(
        range: defaultRange,
        totalMs: 12 * 3600 * 1000 + 30 * 60 * 1000, // 12h 30m
        sessionCount: 8,
        averageMs: 90 * 60 * 1000,
        longestMs: 180 * 60 * 1000,
        previousTotalMs: 10 * 3600 * 1000 + 5 * 60 * 1000, // 10h 05m
        previousSessionCount: 6,
        trendPercent: 24.0,
        daily: const [],
        hourly: const [],
        weekdayTotals: const [],
        weekdayDayCounts: const [],
        weekdayHour: const [],
        peakWindowStartHour: 10,
        mostFocusedWeekday: 1,
        mostFocusedWeekdayAvgMs: 120 * 60 * 1000,
        topActivities: const [],
      );

      final snapshot = createBaseSnapshot(focusTime: focusSnapshot);
      final trends = PositiveTrendDetector.detect(snapshot);

      expect(trends.any((t) => t.metric == PositiveTrendMetric.focusTime), isTrue);
      final focusTrend = trends.firstWhere((t) => t.metric == PositiveTrendMetric.focusTime);
      expect(focusTrend.title, 'Focus time increased');
      expect(focusTrend.currentValueFormatted, '12h 30m');
      expect(focusTrend.previousValueFormatted, '10h 5m');
      expect(focusTrend.deltaFormatted, '+24%');
      expect(focusTrend.factualDescription, contains('compared with the previous period'));
    });

    test('Valid Positive Total XP trend is detected with factual description', () {
      final snapshot = createBaseSnapshot(
        totalXp: 2360,
        previousTotalXp: 2000,
        xpDelta: const MetricDelta(
          current: 2360,
          previous: 2000,
          changePct: 18.0,
          isPositive: true,
        ),
      );

      final trends = PositiveTrendDetector.detect(snapshot);
      expect(trends.any((t) => t.metric == PositiveTrendMetric.totalXp), isTrue);
      final xpTrend = trends.firstWhere((t) => t.metric == PositiveTrendMetric.totalXp);
      expect(xpTrend.title, 'Total XP increased');
      expect(xpTrend.deltaFormatted, '+18%');
      expect(xpTrend.factualDescription, contains('+360 XP compared with the previous period'));
    });

    test('Completion rate trend enforces percentage-point semantics', () {
      final snapshot = createBaseSnapshot(
        completionRateDelta: const MetricDelta(
          current: 68.0,
          previous: 52.0,
          changePct: 30.76, // Relative change
          isPositive: true,
        ),
      );

      final trends = PositiveTrendDetector.detect(snapshot);
      expect(trends.any((t) => t.metric == PositiveTrendMetric.completionRate), isTrue);
      final completionTrend = trends.firstWhere((t) => t.metric == PositiveTrendMetric.completionRate);
      expect(completionTrend.title, 'Completion rate improved');
      expect(completionTrend.currentValueFormatted, '68%');
      expect(completionTrend.previousValueFormatted, '52%');
      // Must NOT display +31%, must explicitly display percentage points!
      expect(completionTrend.deltaFormatted, '+16% pts');
      expect(completionTrend.factualDescription, contains('+16 percentage points compared with the previous period'));
    });

    test('Consistency trend enforces percentage-point semantics', () {
      final snapshot = createBaseSnapshot(
        consistencyDelta: const MetricDelta(
          current: 78.0,
          previous: 66.0,
          changePct: 18.18,
          isPositive: true,
        ),
      );

      final trends = PositiveTrendDetector.detect(snapshot);
      expect(trends.any((t) => t.metric == PositiveTrendMetric.consistency), isTrue);
      final consistencyTrend = trends.firstWhere((t) => t.metric == PositiveTrendMetric.consistency);
      expect(consistencyTrend.title, 'Consistency improved');
      expect(consistencyTrend.currentValueFormatted, '78%');
      expect(consistencyTrend.deltaFormatted, '+12% pts');
      expect(consistencyTrend.factualDescription, contains('+12 percentage points compared with the previous period'));
    });

    test('Life Area XP trend adheres to Life Area filter', () {
      final lifeAreas = [
        const AnalyticsLifeAreaMetric(
          id: 'la_mind',
          name: 'Knowledge & Mind',
          xp: 1380,
          previousXp: 1000, // +38% growth, +380 XP
          level: 3,
          tier: 'Silver',
          currentStreak: 4,
          longestStreak: 7,
        ),
        const AnalyticsLifeAreaMetric(
          id: 'la_health',
          name: 'Physical Health',
          xp: 900,
          previousXp: 700, // +28% growth, +200 XP
          level: 2,
          tier: 'Bronze',
          currentStreak: 2,
          longestStreak: 5,
        ),
      ];

      // 1. Unfiltered: Both can be candidates
      final unfilteredSnap = createBaseSnapshot(lifeAreas: lifeAreas);
      final allTrends = PositiveTrendDetector.detect(unfilteredSnap);
      expect(allTrends.any((t) => t.relatedLifeAreaId == 'la_mind'), isTrue);

      // 2. Filtered by la_health: MUST NOT include la_mind
      final filteredSnap = createBaseSnapshot(
        lifeAreas: lifeAreas,
        lifeAreaId: 'la_health',
      );
      final filteredTrends = PositiveTrendDetector.detect(filteredSnap);
      expect(filteredTrends.any((t) => t.relatedLifeAreaId == 'la_mind'), isFalse);
      expect(filteredTrends.any((t) => t.relatedLifeAreaId == 'la_health'), isTrue);
    });

    test('Multiple simultaneous positive trends are ranked and capped to maxResults', () {
      final focusSnapshot = FocusTimeSnapshot(
        range: defaultRange,
        totalMs: 20 * 3600 * 1000,
        sessionCount: 15,
        averageMs: 80 * 60 * 1000,
        longestMs: 180 * 60 * 1000,
        previousTotalMs: 10 * 3600 * 1000, // +100%
        previousSessionCount: 8, // +7 sessions
        trendPercent: 100.0,
        daily: const [],
        hourly: const [],
        weekdayTotals: const [],
        weekdayDayCounts: const [],
        weekdayHour: const [],
        peakWindowStartHour: 10,
        mostFocusedWeekday: 2,
        mostFocusedWeekdayAvgMs: 100 * 60 * 1000,
        topActivities: const [],
      );

      final snapshot = createBaseSnapshot(
        totalXp: 3000,
        previousTotalXp: 2000, // +50%
        xpDelta: const MetricDelta(
          current: 3000,
          previous: 2000,
          changePct: 50.0,
          isPositive: true,
        ),
        completionRateDelta: const MetricDelta(
          current: 85.0,
          previous: 60.0, // +25 pts
          changePct: 41.6,
          isPositive: true,
        ),
        consistencyDelta: const MetricDelta(
          current: 90.0,
          previous: 70.0, // +20 pts
          changePct: 28.5,
          isPositive: true,
        ),
        focusTime: focusSnapshot,
      );

      final trends = PositiveTrendDetector.detect(snapshot, maxResults: 3);
      expect(trends.length, equals(3));
      // Verify descending order of significanceScore
      expect(trends[0].significanceScore >= trends[1].significanceScore, isTrue);
      expect(trends[1].significanceScore >= trends[2].significanceScore, isTrue);
    });
  });
}
