import 'package:flutter/material.dart';

import '../domain/analytics_models.dart';

/// One progression milestone node along the level ladder track.
class XpProgressMilestone {
  final int ordinal;
  final String roman;
  final String tierName;
  final int entryXp;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLocked;

  const XpProgressMilestone({
    required this.ordinal,
    required this.roman,
    required this.tierName,
    required this.entryXp,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLocked,
  });
}

/// Breakdown of XP earned by a single source category in the active period.
class XpSourceMetric {
  final String name;
  final IconData icon;
  final int xp;
  final double percent; // 0.0 to 100.0

  const XpSourceMetric({
    required this.name,
    required this.icon,
    required this.xp,
    required this.percent,
  });
}

/// Comprehensive, verified snapshot for the Wave 06 XP Progress component.
class XpProgressData {
  final String? lifeAreaId;
  final String lifeAreaName;
  final AnalyticsPeriod period;
  final bool isAllLifeAreas;

  // Gauge metrics
  final int currentXp; // In-level XP for specific area, or period XP for All
  final int targetXp; // Level threshold XP for specific area, or period goal
  final double progressPercent; // 0.0 to 100.0
  final int remainingXp; // XP required to reach next level
  final int totalHistoricalXp; // Lifetime XP in this domain (or all domains)

  // Period performance
  final int periodXp;
  final MetricDelta periodDelta;

  // Level & Tier information
  final int levelNumber;
  final String levelRoman;
  final String tierName;
  final String tierDescription;
  final bool canPromote;

  // Milestone ladder & source breakdown
  final List<XpProgressMilestone> milestones;
  final List<XpSourceMetric> sources;

  // Aggregate metadata (when isAllLifeAreas is true)
  final int activeLifeAreasCount;
  final String? topLifeAreaName;

  const XpProgressData({
    required this.lifeAreaId,
    required this.lifeAreaName,
    required this.period,
    required this.isAllLifeAreas,
    required this.currentXp,
    required this.targetXp,
    required this.progressPercent,
    required this.remainingXp,
    required this.totalHistoricalXp,
    required this.periodXp,
    required this.periodDelta,
    required this.levelNumber,
    required this.levelRoman,
    required this.tierName,
    required this.tierDescription,
    required this.canPromote,
    required this.milestones,
    required this.sources,
    this.activeLifeAreasCount = 0,
    this.topLifeAreaName,
  });

  /// Factory for an empty/zero progression state.
  factory XpProgressData.empty({
    String? lifeAreaId,
    String lifeAreaName = 'All Life Areas',
    AnalyticsPeriod period = AnalyticsPeriod.month,
  }) {
    return XpProgressData(
      lifeAreaId: lifeAreaId,
      lifeAreaName: lifeAreaName,
      period: period,
      isAllLifeAreas: lifeAreaId == null,
      currentXp: 0,
      targetXp: 1000,
      progressPercent: 0.0,
      remainingXp: 1000,
      totalHistoricalXp: 0,
      periodXp: 0,
      periodDelta: const MetricDelta(
        current: 0,
        previous: 0,
        changePct: 0,
        isPositive: true,
        isNeutral: true,
      ),
      levelNumber: 1,
      levelRoman: 'I',
      tierName: 'Wood',
      tierDescription: 'Foundation phase: establish consistent daily habits.',
      canPromote: false,
      milestones: const [],
      sources: const [],
      activeLifeAreasCount: 0,
      topLifeAreaName: null,
    );
  }
}
