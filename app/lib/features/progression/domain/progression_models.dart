// Wave 6: Progression domain models.
// Pure Dart — represents curves, tiers, objectives, and computed progression state.

import '../../../domain/ids.dart';

/// Pre-computed level curve configuration.
class LevelCurveSnapshot {
  final int level;
  final int deltaXp;
  final int cumulativeXpRequired;

  const LevelCurveSnapshot({
    required this.level,
    required this.deltaXp,
    required this.cumulativeXpRequired,
  });
}

/// Tier definition configuration.
class TierDefinitionSnapshot {
  final String name;
  final int entryXp;
  final int ordinal;
  final String icon;
  final String color;

  const TierDefinitionSnapshot({
    required this.name,
    required this.entryXp,
    required this.ordinal,
    required this.icon,
    required this.color,
  });
}

/// Compound gate objective requirement for a level.
class LevelObjectiveSnapshot {
  final Id id;
  final int level;
  final String title;
  final String? description;
  final bool isMandatory;

  const LevelObjectiveSnapshot({
    required this.id,
    required this.level,
    required this.title,
    this.description,
    this.isMandatory = true,
  });
}

/// Real-time progression state for a LifeArea.
class ProgressionInfo {
  final Id? lifeAreaId;
  final int totalXp;
  final int level;
  final String tier;
  final String tierColor;
  final String tierIcon;
  final int xpInLevel;
  final int xpToNext;
  final double progressPct; // 0.0 to 100.0
  final bool canPromote;

  const ProgressionInfo({
    this.lifeAreaId,
    required this.totalXp,
    required this.level,
    required this.tier,
    required this.tierColor,
    required this.tierIcon,
    required this.xpInLevel,
    required this.xpToNext,
    required this.progressPct,
    required this.canPromote,
  });

  @override
  String toString() =>
      'ProgressionInfo(level: $level, tier: $tier, totalXp: $totalXp, inLevel: $xpInLevel/$xpToNext, pct: ${progressPct.toStringAsFixed(1)}%, canPromote: $canPromote)';
}
