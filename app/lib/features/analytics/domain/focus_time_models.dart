// ignore_for_file: public_member_api_docs
// Focus Time analytics — models and PURE aggregation.
//
// Source of truth = persisted Session rows (durationMs). Nothing here reads
// XP, activity_events, UI timers or cached aggregates. The aggregator takes
// plain records so every metric is unit-testable (midnight/DST/empty/large).

import 'package:flutter/foundation.dart';

import 'analytics_models.dart';

/// One finalized session, as read from Drift. Times are UTC instants.
@immutable
class FocusSessionRecord {
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationMs;
  final String? lifeAreaId;
  final String? activityId;
  final String? activityName;
  final String? taskId;
  final String? projectId;
  final String? goalId;
  final String source;

  const FocusSessionRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.durationMs,
    this.lifeAreaId,
    this.activityId,
    this.activityName,
    this.taskId,
    this.projectId,
    this.goalId,
    this.source = 'timer',
  });
}

@immutable
class FocusDayBucket {
  /// Local calendar day (midnight, local time).
  final DateTime day;
  final int ms;
  const FocusDayBucket(this.day, this.ms);
}

@immutable
class FocusContextTotal {
  final String id;
  final String name;
  final int ms;
  final int sessions;
  const FocusContextTotal({
    required this.id,
    required this.name,
    required this.ms,
    required this.sessions,
  });
}

/// A derived pattern discovered from real session/focus analytics data.
/// Does not repeat metrics already visible as raw numbers; communicates derived insights.
@immutable
class DerivedFocusInsight {
  final String id;
  final String title;
  final String valueFormatted;
  final String subtitle;
  final String iconIdentifier;
  final double significanceScore;

  const DerivedFocusInsight({
    required this.id,
    required this.title,
    required this.valueFormatted,
    required this.subtitle,
    required this.iconIdentifier,
    required this.significanceScore,
  });
}

@immutable
class FocusTimeSnapshot {
  final AnalyticsDateRange range;
  final int totalMs;
  final int sessionCount;
  final int averageMs;
  final int longestMs;
  final int previousTotalMs;
  final int previousSessionCount;

  /// Percentage change vs previous period; null when the previous period has no data.
  final double? trendPercent;
  final List<FocusDayBucket> daily;

  /// 24 entries: focus ms per local hour-of-day across the range.
  final List<int> hourly;

  /// 7 entries (Mon=0 .. Sun=6): focus ms per weekday across the range.
  final List<int> weekdayTotals;

  /// 7 entries: how many calendar days of each weekday fall inside the range.
  final List<int> weekdayDayCounts;

  /// 7 x 24 matrix (weekday x hour) in ms.
  final List<List<int>> weekdayHour;

  /// Start hour (0-23) of the most productive 2-hour window, null when empty.
  final int? peakWindowStartHour;

  /// Most focused weekday by average ms per occurrence (Mon=0), null when empty.
  final int? mostFocusedWeekday;
  final int mostFocusedWeekdayAvgMs;
  final List<FocusContextTotal> topActivities;

  /// Objectively derived focus patterns (Deep Work Share, Concentration, Routine, etc.)
  final List<DerivedFocusInsight> derivedInsights;

  const FocusTimeSnapshot({
    required this.range,
    required this.totalMs,
    required this.sessionCount,
    required this.averageMs,
    required this.longestMs,
    required this.previousTotalMs,
    required this.previousSessionCount,
    required this.trendPercent,
    required this.daily,
    required this.hourly,
    required this.weekdayTotals,
    required this.weekdayDayCounts,
    required this.weekdayHour,
    required this.peakWindowStartHour,
    required this.mostFocusedWeekday,
    required this.mostFocusedWeekdayAvgMs,
    required this.topActivities,
    this.derivedInsights = const [],
  });

  bool get isEmpty => sessionCount == 0;
  bool get hasPreviousData => previousSessionCount > 0;
  List<DerivedFocusInsight> get previewInsights => derivedInsights.take(3).toList();
  bool get hasMoreInsights => derivedInsights.length > 3;

  factory FocusTimeSnapshot.empty(AnalyticsDateRange range) =>
      FocusTimeAggregator.compute(
        current: const [],
        previous: const [],
        range: range,
      );
}

class FocusTimeAggregator {
  FocusTimeAggregator._();

  static bool _inRange(DateTime utcInstant, DateTime start, DateTime end) {
    final l = utcInstant.toLocal();
    return !l.isBefore(start) && l.isBefore(end);
  }

  /// Previous period = same length, immediately before [range].
  static AnalyticsDateRange previousRange(AnalyticsDateRange range) {
    var days = 0;
    for (var d = range.start; d.isBefore(range.end);
        d = DateTime(d.year, d.month, d.day + 1)) {
      days++;
    }
    final prevStart = DateTime(
      range.start.year,
      range.start.month,
      range.start.day - days,
    );
    return AnalyticsDateRange(start: prevStart, end: range.start);
  }

  static FocusTimeSnapshot compute({
    required List<FocusSessionRecord> current,
    required List<FocusSessionRecord> previous,
    required AnalyticsDateRange range,
  }) {
    final start = range.start;
    final end = range.end;
    final prev = previousRange(range);

    // Sessions are attributed to the period they START in (whole-session
    // metrics); the hour/day distribution splits across boundaries below.
    final cur = [
      for (final s in current)
        if (_inRange(s.startedAt, start, end)) s,
    ];
    final prv = [
      for (final s in previous)
        if (_inRange(s.startedAt, prev.start, prev.end)) s,
    ];

    final total = cur.fold<int>(0, (a, s) => a + s.durationMs);
    final prevTotal = prv.fold<int>(0, (a, s) => a + s.durationMs);
    final longest = cur.fold<int>(0, (a, s) => s.durationMs > a ? s.durationMs : a);
    final avg = cur.isEmpty ? 0 : (total / cur.length).round();
    final trend = prv.isEmpty || prevTotal == 0
        ? null
        : (total - prevTotal) / prevTotal * 100.0;

    // Day list (DST-safe calendar iteration).
    final days = <DateTime>[];
    for (var d = DateTime(start.year, start.month, start.day);
        d.isBefore(end);
        d = DateTime(d.year, d.month, d.day + 1)) {
      days.add(d);
    }
    final dayIndex = {for (var i = 0; i < days.length; i++) _key(days[i]): i};
    final dailyAcc = List<double>.filled(days.length, 0);
    final hourlyAcc = List<double>.filled(24, 0);
    final matrixAcc = List.generate(7, (_) => List<double>.filled(24, 0));

    void add(DateTime at, double ms) {
      if (at.isBefore(start) || !at.isBefore(end)) return;
      final di = dayIndex[_key(at)];
      if (di != null) dailyAcc[di] += ms;
      hourlyAcc[at.hour] += ms;
      matrixAcc[at.weekday - 1][at.hour] += ms;
    }

    for (final s in cur) {
      final a = s.startedAt.toLocal();
      final b = s.endedAt.toLocal();
      final wall = b.difference(a).inMilliseconds;
      if (wall <= 0 || s.durationMs <= 0) {
        add(a, s.durationMs.toDouble());
        continue;
      }
      // Focused ms are spread over the wall interval proportionally
      // (paused time is not attributed to any hour/day).
      final scale = s.durationMs / wall;
      var c = a;
      while (c.isBefore(b)) {
        var next = DateTime(c.year, c.month, c.day, c.hour + 1);
        if (!next.isAfter(c)) next = c.add(const Duration(hours: 1));
        final stop = next.isBefore(b) ? next : b;
        add(c, stop.difference(c).inMilliseconds * scale);
        c = stop;
      }
    }

    final daily = [
      for (var i = 0; i < days.length; i++)
        FocusDayBucket(days[i], dailyAcc[i].round()),
    ];
    final hourly = [for (final v in hourlyAcc) v.round()];
    final matrix = [
      for (final row in matrixAcc) [for (final v in row) v.round()],
    ];
    final weekdayTotals = [
      for (final row in matrix) row.fold<int>(0, (a, v) => a + v),
    ];
    final weekdayCounts = List<int>.filled(7, 0);
    for (final d in days) {
      weekdayCounts[d.weekday - 1]++;
    }

    int? peakStart;
    if (total > 0) {
      var best = -1;
      for (var h = 0; h < 23; h++) {
        final v = hourly[h] + hourly[h + 1];
        if (v > best) {
          best = v;
          peakStart = h;
        }
      }
    }

    int? bestDay;
    var bestAvg = 0;
    for (var i = 0; i < 7; i++) {
      if (weekdayCounts[i] == 0) continue;
      final a = (weekdayTotals[i] / weekdayCounts[i]).round();
      if (a > bestAvg) {
        bestAvg = a;
        bestDay = i;
      }
    }

    final byActivity = <String, (String, int, int)>{};
    for (final s in cur) {
      final id = s.activityId;
      if (id == null) continue;
      final p = byActivity[id];
      byActivity[id] = (
        s.activityName ?? p?.$1 ?? 'Activity',
        (p?.$2 ?? 0) + s.durationMs,
        (p?.$3 ?? 0) + 1,
      );
    }
    final top = [
      for (final e in byActivity.entries)
        FocusContextTotal(
          id: e.key,
          name: e.value.$1,
          ms: e.value.$2,
          sessions: e.value.$3,
        ),
    ]..sort((a, b) => b.ms.compareTo(a.ms));

    // ── Derived Focus Insights Computation ─────────────────────────────────
    final derived = <DerivedFocusInsight>[];

    // 1. Deep Work Share: sum(sessions >= 45m) / total focus duration
    if (total > 0 && cur.isNotEmpty) {
      final deepWorkMs = cur
          .where((s) => s.durationMs >= 45 * 60 * 1000)
          .fold<int>(0, (a, s) => a + s.durationMs);
      final sharePct = (deepWorkMs / total * 100.0).round();
      if (cur.length >= 2 || total >= 45 * 60 * 1000) {
        derived.add(
          DerivedFocusInsight(
            id: 'deep_work_share',
            title: 'Deep Work Share',
            valueFormatted: '$sharePct%',
            subtitle: '$sharePct% of your focus came from sessions longer than 45 minutes.',
            iconIdentifier: 'brain',
            significanceScore: 85.0,
          ),
        );
      }
    }

    // 2. Focus Concentration: strongest 2-hour window / total focus
    if (total > 0 && peakStart != null) {
      final peakWindowMs = hourly[peakStart] + hourly[(peakStart + 1) % 24];
      if (peakWindowMs > 0) {
        final concPct = (peakWindowMs / total * 100.0).round();
        derived.add(
          DerivedFocusInsight(
            id: 'focus_concentration',
            title: 'Focus Concentration',
            valueFormatted: '$concPct%',
            subtitle: 'Your top 2-hour window contains $concPct% of your focus time.',
            iconIdentifier: 'target',
            significanceScore: 80.0,
          ),
        );
      }
    }

    // 3. Strongest Routine: Recurring focus pattern across weekdays
    if (total > 0) {
      var bestRoutineDays = <int>[];
      var bestRoutineHour = -1;
      var bestRoutineScore = 0;

      for (var h = 0; h < 23; h++) {
        final activeDays = <int>[];
        var totalWindowMs = 0;
        for (var w = 0; w < 7; w++) {
          final wMs = matrix[w][h] + matrix[w][h + 1];
          if (wMs >= 15 * 60 * 1000) {
            activeDays.add(w);
            totalWindowMs += wMs;
          }
        }
        if (activeDays.length >= 2 && totalWindowMs > bestRoutineScore) {
          bestRoutineScore = totalWindowMs;
          bestRoutineDays = activeDays;
          bestRoutineHour = h;
        }
      }

      if (bestRoutineDays.length >= 2 && bestRoutineHour >= 0) {
        String daysLabel;
        if (bestRoutineDays.length >= 5 && bestRoutineDays.first == 0 && bestRoutineDays.last == 4) {
          daysLabel = 'Mon – Fri';
        } else if (bestRoutineDays.length == 3 && bestRoutineDays[0] == 1 && bestRoutineDays[1] == 2 && bestRoutineDays[2] == 3) {
          daysLabel = 'Tue – Thu';
        } else if (bestRoutineDays.length == 3 && bestRoutineDays[0] == 0 && bestRoutineDays[1] == 1 && bestRoutineDays[2] == 2) {
          daysLabel = 'Mon – Wed';
        } else if (bestRoutineDays.length == 2 && (bestRoutineDays[1] - bestRoutineDays[0]) == 1) {
          daysLabel = '${_weekdaysShort[bestRoutineDays[0]]} – ${_weekdaysShort[bestRoutineDays[1]]}';
        } else {
          daysLabel = bestRoutineDays.map((w) => _weekdaysShort[w]).join(', ');
        }

        final timeLabel = _formatHourWindow(bestRoutineHour);
        derived.add(
          DerivedFocusInsight(
            id: 'strongest_routine',
            title: 'Strongest Routine',
            valueFormatted: daysLabel,
            subtitle: '$timeLabel · Your most consistent focus window.',
            iconIdentifier: 'calendar_sync',
            significanceScore: 75.0,
          ),
        );
      }
    }

    // 4. Peak Focus Time (visual reference match)
    if (total > 0 && peakStart != null) {
      derived.add(
        DerivedFocusInsight(
          id: 'peak_focus_time',
          title: 'Peak Focus Time',
          valueFormatted: _formatHourWindow(peakStart),
          subtitle: 'Your most productive hours.',
          iconIdentifier: 'bolt',
          significanceScore: 100.0,
        ),
      );
    }

    // 5. Most Focused Day (visual reference match)
    if (bestDay != null && bestAvg > 0) {
      derived.add(
        DerivedFocusInsight(
          id: 'most_focused_day',
          title: 'Most Focused Day',
          valueFormatted: _weekdaysFull[bestDay],
          subtitle: '${_formatDurationHhMm(bestAvg)} average.',
          iconIdentifier: 'calendar',
          significanceScore: 95.0,
        ),
      );
    }

    // 6. Focus Trend (visual reference match)
    if (trend != null && prv.isNotEmpty && prevTotal > 0) {
      final isPos = trend >= 0;
      final arrow = isPos ? '↑' : '↓';
      derived.add(
        DerivedFocusInsight(
          id: 'focus_trend',
          title: 'Focus Trend',
          valueFormatted: '$arrow ${trend.abs().toStringAsFixed(0)}%',
          subtitle: range.period?.comparisonLabel ?? 'vs previous period',
          iconIdentifier: 'trending_up',
          significanceScore: 90.0,
        ),
      );
    }

    // 7. Session Continuity
    if (cur.length >= 3 && avg > 0) {
      derived.add(
        DerivedFocusInsight(
          id: 'session_continuity',
          title: 'Avg Session Length',
          valueFormatted: _formatDurationHhMm(avg),
          subtitle: 'Average duration across ${cur.length} focus sessions.',
          iconIdentifier: 'timer',
          significanceScore: 70.0,
        ),
      );
    }

    derived.sort((a, b) => b.significanceScore.compareTo(a.significanceScore));

    return FocusTimeSnapshot(
      range: range,
      totalMs: total,
      sessionCount: cur.length,
      averageMs: avg,
      longestMs: longest,
      previousTotalMs: prevTotal,
      previousSessionCount: prv.length,
      trendPercent: trend,
      daily: daily,
      hourly: hourly,
      weekdayTotals: weekdayTotals,
      weekdayDayCounts: weekdayCounts,
      weekdayHour: matrix,
      peakWindowStartHour: peakStart,
      mostFocusedWeekday: bestDay,
      mostFocusedWeekdayAvgMs: bestAvg,
      topActivities: top.take(5).toList(),
      derivedInsights: derived,
    );
  }

  static const List<String> _weekdaysShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _weekdaysFull = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static String _formatHourWindow(int startHour) {
    String formatSingle(int h) {
      final period = h >= 12 ? 'PM' : 'AM';
      var dH = h % 12;
      if (dH == 0) dH = 12;
      return '$dH:00 $period';
    }
    return '${formatSingle(startHour % 24)} – ${formatSingle((startHour + 2) % 24)}';
  }

  static String _formatDurationHhMm(int ms) {
    if (ms <= 0) return '0m';
    final totalMinutes = (ms / 60000).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  static int _key(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
}
