import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'analytics_models.dart';

/// Supported types of positive trends in KRATOS Analytics.
/// Strictly limited to metrics with unambiguous improvement semantics (Higher = Better).
enum PositiveTrendMetric {
  focusTime,
  totalXp,
  xpVelocity,
  completionRate,
  consistency,
  sessionsCount,
  activeDays,
  lifeAreaXp,
  currentStreak,
}

/// A single, fully substantiated Positive Trend insight derived strictly from
/// real KRATOS analytics data.
///
/// Contains NO arbitrary advice, NO AI hallucinations, and NO motivational fluff.
@immutable
class PositiveTrendInsight {
  final PositiveTrendMetric metric;
  final String title;
  final String currentValueFormatted;
  final String previousValueFormatted;
  final String deltaFormatted;
  final double deltaValue;
  final double percentageChange;
  final String comparisonPeriodLabel;
  final String factualDescription;
  final String iconIdentifier;
  final String? relatedLifeAreaId;
  final String? relatedLifeAreaName;
  final double significanceScore;

  const PositiveTrendInsight({
    required this.metric,
    required this.title,
    required this.currentValueFormatted,
    required this.previousValueFormatted,
    required this.deltaFormatted,
    required this.deltaValue,
    required this.percentageChange,
    required this.comparisonPeriodLabel,
    required this.factualDescription,
    required this.iconIdentifier,
    this.relatedLifeAreaId,
    this.relatedLifeAreaName,
    required this.significanceScore,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PositiveTrendInsight &&
          runtimeType == other.runtimeType &&
          metric == other.metric &&
          title == other.title &&
          currentValueFormatted == other.currentValueFormatted &&
          deltaFormatted == other.deltaFormatted &&
          relatedLifeAreaId == other.relatedLifeAreaId;

  @override
  int get hashCode => Object.hash(
        metric,
        title,
        currentValueFormatted,
        deltaFormatted,
        relatedLifeAreaId,
      );
}

/// Deterministic Positive Trend Detection Engine.
///
/// Evaluates an [AnalyticsSnapshot] against strict data sufficiency rules and
/// significance thresholds. Rejects noise, spurious small-sample jumps, and zero baselines.
class PositiveTrendDetector {
  const PositiveTrendDetector._();

  static List<PositiveTrendInsight> detect(
    AnalyticsSnapshot snapshot, {
    int? maxResults,
  }) {
    final candidates = <PositiveTrendInsight>[];
    final comparisonLabel = snapshot.range.period?.comparisonLabel ?? 'vs previous period';

    // ─────────────────────────────────────────────────────────────────────────
    // 1. Focus Time Trend
    // ─────────────────────────────────────────────────────────────────────────
    final focus = snapshot.focusTime;
    if (focus != null && focus.hasPreviousData && focus.previousTotalMs > 0) {
      final currentMs = focus.totalMs;
      final prevMs = focus.previousTotalMs;
      final diffMs = currentMs - prevMs;
      final pct = focus.trendPercent ?? (((diffMs) / prevMs) * 100.0);

      // Sufficiency: at least 15 min increase AND at least 5% improvement
      if (diffMs >= 15 * 60 * 1000 && pct >= 5.0) {
        final currentHhMm = _formatDurationHhMm(currentMs);
        final prevHhMm = _formatDurationHhMm(prevMs);
        final diffHhMm = _formatDurationHhMm(diffMs);
        final pctStr = '+${pct.toStringAsFixed(0)}%';

        candidates.add(
          PositiveTrendInsight(
            metric: PositiveTrendMetric.focusTime,
            title: 'Focus time increased',
            currentValueFormatted: currentHhMm,
            previousValueFormatted: prevHhMm,
            deltaFormatted: pctStr,
            deltaValue: diffMs.toDouble(),
            percentageChange: pct,
            comparisonPeriodLabel: comparisonLabel,
            factualDescription: '+$diffHhMm compared with the previous period.',
            iconIdentifier: 'timer',
            significanceScore: math.min(100.0, pct) + (diffMs / 3600000.0) * 12.0,
          ),
        );
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 2. Total XP Trend
    // ─────────────────────────────────────────────────────────────────────────
    final currentXp = snapshot.totalXp;
    final prevXp = snapshot.previousTotalXp > 0
        ? snapshot.previousTotalXp
        : snapshot.xpDelta.previous.toInt();

    if (prevXp > 0 && currentXp > prevXp) {
      final diffXp = currentXp - prevXp;
      final pct = snapshot.xpDelta.changePct > 0
          ? snapshot.xpDelta.changePct
          : ((diffXp / prevXp) * 100.0);

      // Sufficiency: at least 50 XP increase AND at least 5% improvement
      if (diffXp >= 50 && pct >= 5.0) {
        final pctStr = '+${pct.toStringAsFixed(0)}%';
        candidates.add(
          PositiveTrendInsight(
            metric: PositiveTrendMetric.totalXp,
            title: 'Total XP increased',
            currentValueFormatted: _formatNumber(currentXp),
            previousValueFormatted: _formatNumber(prevXp),
            deltaFormatted: pctStr,
            deltaValue: diffXp.toDouble(),
            percentageChange: pct,
            comparisonPeriodLabel: comparisonLabel,
            factualDescription: '+${_formatNumber(diffXp)} XP compared with the previous period.',
            iconIdentifier: 'bolt',
            significanceScore: math.min(100.0, pct) + (diffXp / 100.0) * 5.0,
          ),
        );
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 3. XP Velocity (XP / Day)
    // ─────────────────────────────────────────────────────────────────────────
    final currVel = snapshot.xpVelocityDelta.current;
    final prevVel = snapshot.xpVelocityDelta.previous;
    if (prevVel > 0 && currVel > prevVel) {
      final diffVel = currVel - prevVel;
      final pct = snapshot.xpVelocityDelta.changePct;

      // Sufficiency: at least 5 XP/day increase AND at least 5% improvement
      if (diffVel >= 5.0 && pct >= 5.0) {
        final pctStr = '+${pct.toStringAsFixed(0)}%';
        candidates.add(
          PositiveTrendInsight(
            metric: PositiveTrendMetric.xpVelocity,
            title: 'XP velocity improved',
            currentValueFormatted: '${currVel.toStringAsFixed(1)} XP/d',
            previousValueFormatted: '${prevVel.toStringAsFixed(1)} XP/d',
            deltaFormatted: pctStr,
            deltaValue: diffVel,
            percentageChange: pct,
            comparisonPeriodLabel: comparisonLabel,
            factualDescription: '+${diffVel.toStringAsFixed(1)} XP/day compared with the previous period.',
            iconIdentifier: 'speed',
            significanceScore: math.min(100.0, pct) + diffVel * 4.0,
          ),
        );
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 4. Completion Rate Trend (Percentage Points)
    // ─────────────────────────────────────────────────────────────────────────
    final currCompletion = snapshot.completionRateDelta.current;
    final prevCompletion = snapshot.completionRateDelta.previous;
    if (prevCompletion > 0 && currCompletion > prevCompletion) {
      final diffPoints = currCompletion - prevCompletion;

      // Sufficiency: at least 3 percentage points improvement
      if (diffPoints >= 3.0) {
        final ptsStr = '+${diffPoints.toStringAsFixed(0)}% pts';
        candidates.add(
          PositiveTrendInsight(
            metric: PositiveTrendMetric.completionRate,
            title: 'Completion rate improved',
            currentValueFormatted: '${currCompletion.toStringAsFixed(0)}%',
            previousValueFormatted: '${prevCompletion.toStringAsFixed(0)}%',
            deltaFormatted: ptsStr,
            deltaValue: diffPoints,
            percentageChange: diffPoints,
            comparisonPeriodLabel: comparisonLabel,
            factualDescription: '+${diffPoints.toStringAsFixed(0)} percentage points compared with the previous period.',
            iconIdentifier: 'check_circle',
            significanceScore: diffPoints * 4.0,
          ),
        );
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 5. Consistency Trend (Active Days Rate)
    // ─────────────────────────────────────────────────────────────────────────
    final currConsistency = snapshot.consistencyDelta.current;
    final prevConsistency = snapshot.consistencyDelta.previous;
    if (prevConsistency > 0 && currConsistency > prevConsistency) {
      final diffPoints = currConsistency - prevConsistency;

      // Sufficiency: at least 4 percentage points improvement
      if (diffPoints >= 4.0) {
        final ptsStr = '+${diffPoints.toStringAsFixed(0)}% pts';
        candidates.add(
          PositiveTrendInsight(
            metric: PositiveTrendMetric.consistency,
            title: 'Consistency improved',
            currentValueFormatted: '${currConsistency.toStringAsFixed(0)}%',
            previousValueFormatted: '${prevConsistency.toStringAsFixed(0)}%',
            deltaFormatted: ptsStr,
            deltaValue: diffPoints,
            percentageChange: diffPoints,
            comparisonPeriodLabel: comparisonLabel,
            factualDescription: '+${diffPoints.toStringAsFixed(0)} percentage points compared with the previous period.',
            iconIdentifier: 'calendar',
            significanceScore: diffPoints * 3.5,
          ),
        );
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 6. Focus Sessions Count Trend
    // ─────────────────────────────────────────────────────────────────────────
    if (focus != null && focus.previousSessionCount > 0 && focus.sessionCount > focus.previousSessionCount) {
      final diffSessions = focus.sessionCount - focus.previousSessionCount;
      final pct = ((diffSessions / focus.previousSessionCount) * 100.0);

      // Sufficiency: at least 2 sessions increase
      if (diffSessions >= 2) {
        candidates.add(
          PositiveTrendInsight(
            metric: PositiveTrendMetric.sessionsCount,
            title: 'Focus sessions increased',
            currentValueFormatted: '${focus.sessionCount}',
            previousValueFormatted: '${focus.previousSessionCount}',
            deltaFormatted: '+$diffSessions',
            deltaValue: diffSessions.toDouble(),
            percentageChange: pct,
            comparisonPeriodLabel: comparisonLabel,
            factualDescription: '+$diffSessions sessions compared with the previous period.',
            iconIdentifier: 'repeat',
            significanceScore: diffSessions * 14.0,
          ),
        );
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // 7. Life Area XP Trends (Respects Life Area Filter)
    // ─────────────────────────────────────────────────────────────────────────
    for (final area in snapshot.lifeAreas) {
      if (snapshot.lifeAreaId != null && area.id != snapshot.lifeAreaId) {
        continue;
      }
      if (area.previousXp > 0 && area.xp > area.previousXp) {
        final diffXp = area.xp - area.previousXp;
        final pct = ((diffXp / area.previousXp) * 100.0);

        // Sufficiency: at least 50 XP increase AND at least 5% growth
        if (diffXp >= 50 && pct >= 5.0) {
          final pctStr = '+${pct.toStringAsFixed(0)}%';
          candidates.add(
            PositiveTrendInsight(
              metric: PositiveTrendMetric.lifeAreaXp,
              title: '${area.name} XP increased',
              currentValueFormatted: _formatNumber(area.xp),
              previousValueFormatted: _formatNumber(area.previousXp),
              deltaFormatted: pctStr,
              deltaValue: diffXp.toDouble(),
              percentageChange: pct,
              comparisonPeriodLabel: comparisonLabel,
              factualDescription: '+${_formatNumber(diffXp)} XP compared with the previous period.',
              iconIdentifier: 'category',
              relatedLifeAreaId: area.id,
              relatedLifeAreaName: area.name,
              significanceScore: math.min(100.0, pct) + (diffXp / 100.0) * 4.0,
            ),
          );
        }
      }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Sort deterministically by significance score descending
    // ─────────────────────────────────────────────────────────────────────────
    candidates.sort((a, b) => b.significanceScore.compareTo(a.significanceScore));

    if (maxResults != null) {
      return candidates.take(maxResults).toList();
    }
    return candidates;
  }

  static String _formatDurationHhMm(int ms) {
    if (ms <= 0) return '0m';
    final totalSec = ms ~/ 1000;
    final hours = totalSec ~/ 3600;
    final mins = (totalSec % 3600) ~/ 60;
    if (hours == 0) return '${mins}m';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  static String _formatNumber(int value) {
    if (value >= 1000000) {
      final v = value / 1000000.0;
      return '${v.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
    }
    if (value >= 1000) {
      final v = value / 1000.0;
      return '${v.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}k';
    }
    return '$value';
  }
}
