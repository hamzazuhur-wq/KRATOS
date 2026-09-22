// Wave 6: Pure Dart progression calculator & compound gate evaluator.
// ADR-010: Compound level gate (XP threshold + mandatory objectives).
// ADR-011: Gentle exponential level curve + Duolingo tier ladder.

import 'dart:math' as math;
import '../../../domain/ids.dart';
import 'progression_models.dart';

class ProgressionCalculator {
  static final List<LevelCurveSnapshot> defaultCurves = _generateDefaultCurves();

  static final List<TierDefinitionSnapshot> defaultTiers = const [
    TierDefinitionSnapshot(
      name: 'Bronze',
      entryXp: 1000,
      ordinal: 1,
      icon: 'shield_bronze',
      color: '#CD7F32',
    ),
    TierDefinitionSnapshot(
      name: 'Silver',
      entryXp: 3000,
      ordinal: 2,
      icon: 'shield_silver',
      color: '#C0C0C0',
    ),
    TierDefinitionSnapshot(
      name: 'Gold',
      entryXp: 7000,
      ordinal: 3,
      icon: 'shield_gold',
      color: '#FFD700',
    ),
    TierDefinitionSnapshot(
      name: 'Crystal',
      entryXp: 15000,
      ordinal: 4,
      icon: 'gem_crystal',
      color: '#00FFFF',
    ),
    TierDefinitionSnapshot(
      name: 'Diamond',
      entryXp: 30000,
      ordinal: 5,
      icon: 'gem_diamond',
      color: '#B9F2FF',
    ),
    TierDefinitionSnapshot(
      name: 'Mythic',
      entryXp: 60000,
      ordinal: 6,
      icon: 'crown_mythic',
      color: '#C6F135',
    ),
  ];

  static List<LevelCurveSnapshot> _generateDefaultCurves() {
    final list = <LevelCurveSnapshot>[];
    var cumul = 0;

    list.add(const LevelCurveSnapshot(
      level: 1,
      deltaXp: 100,
      cumulativeXpRequired: 0,
    ));

    for (var lvl = 2; lvl <= 100; lvl++) {
      final delta = (100 * math.pow(1.085, lvl)).floor();
      cumul += delta;
      if (cumul > 14000000) cumul = 14000000;

      list.add(LevelCurveSnapshot(
        level: lvl,
        deltaXp: delta,
        cumulativeXpRequired: cumul,
      ));
    }
    return List.unmodifiable(list);
  }

  /// Calculates real-time progression from [totalXp].
  static ProgressionInfo calculate({
    required int totalXp,
    Id? lifeAreaId,
    List<LevelCurveSnapshot>? customCurves,
    List<TierDefinitionSnapshot>? customTiers,
    List<LevelObjectiveSnapshot> levelObjectives = const [],
    Set<Id> completedObjectiveIds = const {},
    bool testOutBypass = false,
  }) {
    final curves = customCurves ?? defaultCurves;
    final tiers = customTiers ?? defaultTiers;

    final safeXp = totalXp < 0 ? 0 : totalXp;

    // 1. Identify Level
    var currentLevelIdx = 0;
    for (var i = curves.length - 1; i >= 0; i--) {
      if (curves[i].cumulativeXpRequired <= safeXp) {
        currentLevelIdx = i;
        break;
      }
    }

    final currentCurve = curves[currentLevelIdx];
    final isMaxLevel = currentLevelIdx >= curves.length - 1;

    int xpInLevel;
    int xpToNext;
    double progressPct;

    if (isMaxLevel) {
      xpInLevel = 0;
      xpToNext = 0;
      progressPct = 100.0;
    } else {
      final nextCurve = curves[currentLevelIdx + 1];
      xpInLevel = safeXp - currentCurve.cumulativeXpRequired;
      xpToNext = nextCurve.cumulativeXpRequired - currentCurve.cumulativeXpRequired;
      if (xpToNext > 0) {
        progressPct = ((xpInLevel / xpToNext) * 100.0).clamp(0.0, 100.0);
      } else {
        progressPct = 100.0;
      }
    }

    // 2. Identify Tier
    var activeTier = tiers.first;
    for (final tier in tiers) {
      if (safeXp >= tier.entryXp) {
        activeTier = tier;
      }
    }

    // 3. Evaluate Compound Gate (ADR-010)
    final canPromote = _evaluatePromotionGate(
      objectives: levelObjectives,
      completedIds: completedObjectiveIds,
      testOutBypass: testOutBypass,
    );

    return ProgressionInfo(
      lifeAreaId: lifeAreaId,
      totalXp: safeXp,
      level: currentCurve.level,
      tier: activeTier.name,
      tierColor: activeTier.color,
      tierIcon: activeTier.icon,
      xpInLevel: xpInLevel,
      xpToNext: xpToNext,
      progressPct: double.parse(progressPct.toStringAsFixed(2)),
      canPromote: canPromote,
    );
  }

  /// Compound gate: advancement requires all mandatory objectives completed (ADR-010).
  static bool _evaluatePromotionGate({
    required List<LevelObjectiveSnapshot> objectives,
    required Set<Id> completedIds,
    required bool testOutBypass,
  }) {
    if (testOutBypass) return true;

    final mandatoryObjectives = objectives.where((o) => o.isMandatory);
    if (mandatoryObjectives.isEmpty) {
      return true;
    }

    return mandatoryObjectives.every((o) => completedIds.contains(o.id));
  }
}
