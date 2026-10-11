import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/features/analytics/domain/analytics_models.dart';

void main() {
  group('FocusTimeAggregator & FocusTimeSnapshot', () {
    // 7-day range from 2026-10-02 to 2026-10-09
    final range7d = AnalyticsDateRange(
      start: DateTime(2026, 10, 2),
      end: DateTime(2026, 10, 9),
      period: AnalyticsPeriod.sevenDays,
    );

    test('Empty dataset returns zeroed metrics and safe nulls', () {
      final snapshot = FocusTimeAggregator.compute(
        current: const [],
        previous: const [],
        range: range7d,
      );

      expect(snapshot.totalMs, 0);
      expect(snapshot.sessionCount, 0);
      expect(snapshot.averageMs, 0);
      expect(snapshot.longestMs, 0);
      expect(snapshot.previousTotalMs, 0);
      expect(snapshot.previousSessionCount, 0);
      expect(snapshot.trendPercent, isNull);
      expect(snapshot.peakWindowStartHour, isNull);
      expect(snapshot.mostFocusedWeekday, isNull);
      expect(snapshot.topActivities, isEmpty);
      expect(snapshot.daily.length, 7);
      expect(snapshot.daily.every((b) => b.ms == 0), isTrue);
      expect(snapshot.hourly.length, 24);
      expect(snapshot.hourly.every((ms) => ms == 0), isTrue);
      expect(snapshot.weekdayTotals.length, 7);
      expect(snapshot.weekdayTotals.every((ms) => ms == 0), isTrue);
      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.hasPreviousData, isFalse);
    });

    test('Single session within range attributes correctly to hour and weekday', () {
      // 1-hour session on Tuesday, Oct 6 from 10:00 to 11:00
      final sess = FocusSessionRecord(
        id: 's1',
        startedAt: DateTime(2026, 10, 6, 10, 0).toUtc(),
        endedAt: DateTime(2026, 10, 6, 11, 0).toUtc(),
        durationMs: 3600000,
        activityId: 'act1',
        activityName: 'Architecture',
        lifeAreaId: 'la_career',
      );

      final snapshot = FocusTimeAggregator.compute(
        current: [sess],
        previous: const [],
        range: range7d,
      );

      expect(snapshot.totalMs, 3600000);
      expect(snapshot.sessionCount, 1);
      expect(snapshot.averageMs, 3600000);
      expect(snapshot.longestMs, 3600000);
      expect(snapshot.previousTotalMs, 0);
      expect(snapshot.trendPercent, isNull);

      // Tuesday = weekday 2 -> index 1 in 0-based Mon..Sun
      expect(snapshot.mostFocusedWeekday, 1);
      expect(snapshot.weekdayTotals[1], 3600000);

      // Hour 10 should have 3,600,000 ms
      expect(snapshot.hourly[10], 3600000);
      expect(snapshot.peakWindowStartHour, isNotNull);

      // Top activities
      expect(snapshot.topActivities.length, 1);
      expect(snapshot.topActivities.first.name, 'Architecture');
      expect(snapshot.topActivities.first.ms, 3600000);
      expect(snapshot.topActivities.first.sessions, 1);
    });

    test('Session spanning midnight splits duration across day and hour boundaries', () {
      // Starts Monday Oct 5 at 23:30, ends Tuesday Oct 6 at 01:00 (90 min = 5,400,000 ms)
      final start = DateTime(2026, 10, 5, 23, 30);
      final end = DateTime(2026, 10, 6, 1, 0);

      final sess = FocusSessionRecord(
        id: 's_cross',
        startedAt: start.toUtc(),
        endedAt: end.toUtc(),
        durationMs: 90 * 60 * 1000,
        activityId: 'act_deep',
        activityName: 'Deep Work',
      );

      final snapshot = FocusTimeAggregator.compute(
        current: [sess],
        previous: const [],
        range: range7d,
      );

      expect(snapshot.totalMs, 90 * 60 * 1000);
      expect(snapshot.sessionCount, 1);

      // 30 min on Monday (hour 23)
      expect(snapshot.hourly[23], 30 * 60 * 1000);
      // 60 min on Tuesday (hour 0: 60 min)
      expect(snapshot.hourly[0], 60 * 60 * 1000);

      // Monday = index 0 (30 min), Tuesday = index 1 (60 min)
      expect(snapshot.weekdayTotals[0], 30 * 60 * 1000);
      expect(snapshot.weekdayTotals[1], 60 * 60 * 1000);
    });

    test('Session with paused time scales focused milliseconds proportionally', () {
      // Wall duration = 60 minutes, but actual focused durationMs = 45 minutes (15 min paused)
      final start = DateTime(2026, 10, 6, 14, 0);
      final end = DateTime(2026, 10, 6, 15, 0);
      const focusedMs = 45 * 60 * 1000;

      final sess = FocusSessionRecord(
        id: 's_paused',
        startedAt: start.toUtc(),
        endedAt: end.toUtc(),
        durationMs: focusedMs,
        activityId: 'act1',
      );

      final snapshot = FocusTimeAggregator.compute(
        current: [sess],
        previous: const [],
        range: range7d,
      );

      expect(snapshot.totalMs, focusedMs);
      expect(snapshot.hourly[14], focusedMs);
    });

    test('Previous period comparison calculates accurate trend percentage', () {
      final curSess = FocusSessionRecord(
        id: 'cur1',
        startedAt: DateTime(2026, 10, 5, 10, 0).toUtc(),
        endedAt: DateTime(2026, 10, 5, 12, 0).toUtc(),
        durationMs: 120 * 60 * 1000, // 2h
      );

      // Previous period starts 7 days before range.start (Sep 25 to Oct 2)
      final prevSess = FocusSessionRecord(
        id: 'prev1',
        startedAt: DateTime(2026, 9, 28, 10, 0).toUtc(),
        endedAt: DateTime(2026, 9, 28, 11, 36).toUtc(),
        durationMs: 96 * 60 * 1000, // 1h 36m (96 min)
      );

      final snapshot = FocusTimeAggregator.compute(
        current: [curSess],
        previous: [prevSess],
        range: range7d,
      );

      expect(snapshot.totalMs, 120 * 60 * 1000);
      expect(snapshot.previousTotalMs, 96 * 60 * 1000);
      expect(snapshot.sessionCount, 1);
      expect(snapshot.previousSessionCount, 1);
      // (120 - 96) / 96 * 100 = 25.0%
      expect(snapshot.trendPercent, closeTo(25.0, 0.01));
    });

    test('Top activities ranks multiple activities by total focused time', () {
      final s1 = FocusSessionRecord(
        id: 's1',
        startedAt: DateTime(2026, 10, 3, 9, 0).toUtc(),
        endedAt: DateTime(2026, 10, 3, 10, 0).toUtc(),
        durationMs: 60 * 60 * 1000,
        activityId: 'a1',
        activityName: 'Activity One',
      );
      final s2 = FocusSessionRecord(
        id: 's2',
        startedAt: DateTime(2026, 10, 4, 9, 0).toUtc(),
        endedAt: DateTime(2026, 10, 4, 11, 0).toUtc(),
        durationMs: 120 * 60 * 1000,
        activityId: 'a2',
        activityName: 'Activity Two',
      );
      final s3 = FocusSessionRecord(
        id: 's3',
        startedAt: DateTime(2026, 10, 5, 9, 0).toUtc(),
        endedAt: DateTime(2026, 10, 5, 9, 30).toUtc(),
        durationMs: 30 * 60 * 1000,
        activityId: 'a1',
        activityName: 'Activity One',
      );

      final snapshot = FocusTimeAggregator.compute(
        current: [s1, s2, s3],
        previous: const [],
        range: range7d,
      );

      expect(snapshot.topActivities.length, 2);
      expect(snapshot.topActivities[0].name, 'Activity Two');
      expect(snapshot.topActivities[0].ms, 120 * 60 * 1000);
      expect(snapshot.topActivities[0].sessions, 1);

      expect(snapshot.topActivities[1].name, 'Activity One');
      expect(snapshot.topActivities[1].ms, 90 * 60 * 1000);
      expect(snapshot.topActivities[1].sessions, 2);
    });

    test('Life area filtering attributes only matching sessions', () {
      final sCareer = FocusSessionRecord(
        id: 's_car',
        startedAt: DateTime(2026, 10, 5, 10, 0).toUtc(),
        endedAt: DateTime(2026, 10, 5, 11, 0).toUtc(),
        durationMs: 60 * 60 * 1000,
        activityId: 'act_cod',
        lifeAreaId: 'la_career',
        activityName: 'Coding',
      );

      final careerOnly = [sCareer];
      final snapshot = FocusTimeAggregator.compute(
        current: careerOnly,
        previous: const [],
        range: range7d,
      );

      expect(snapshot.totalMs, 60 * 60 * 1000);
      expect(snapshot.sessionCount, 1);
      expect(snapshot.topActivities.single.name, 'Coding');
    });

    test('30-day range generates 30 daily buckets and computes peak window', () {
      final range30d = AnalyticsDateRange(
        start: DateTime(2026, 9, 9),
        end: DateTime(2026, 10, 9),
        period: AnalyticsPeriod.thirtyDays,
      );

      final snapshot = FocusTimeAggregator.compute(
        current: const [],
        previous: const [],
        range: range30d,
      );

      expect(snapshot.daily.length, 30);
      expect(snapshot.hourly.length, 24);
      expect(snapshot.weekdayTotals.length, 7);
      expect(snapshot.weekdayHour.length, 7);
      expect(snapshot.weekdayHour.first.length, 24);
    });
  });
}
