import '../../../domain/ids.dart';
import 'progression_models.dart';

/// Canonical definitions for the account-wide progression ladder.
/// Life Area progression intentionally continues to use [ProgressionCalculator].
class GlobalLevelDefinition {
  final int levelNumber;
  final String romanNumeral;
  final String name;
  final int xpThreshold;
  final String colorHex;
  final String icon;

  const GlobalLevelDefinition({
    required this.levelNumber,
    required this.romanNumeral,
    required this.name,
    required this.xpThreshold,
    required this.colorHex,
    required this.icon,
  });
}

class GlobalProgressionState {
  final int overallXp;
  final GlobalLevelDefinition currentLevel;
  final GlobalLevelDefinition? nextLevel;
  final int xpIntoLevel;
  final int xpBetweenLevels;
  final int xpToNextLevel;
  final double progressPercent;

  const GlobalProgressionState({
    required this.overallXp,
    required this.currentLevel,
    required this.nextLevel,
    required this.xpIntoLevel,
    required this.xpBetweenLevels,
    required this.xpToNextLevel,
    required this.progressPercent,
  });

  ProgressionInfo toProgressionInfo() => ProgressionInfo(
    lifeAreaId: const Id('overall'),
    totalXp: overallXp,
    level: currentLevel.levelNumber,
    tier: currentLevel.name,
    tierColor: currentLevel.colorHex,
    tierIcon: currentLevel.icon,
    xpInLevel: xpIntoLevel,
    xpToNext: xpBetweenLevels,
    progressPct: progressPercent,
    canPromote: true,
  );
}

class GlobalProgressionDefinitions {
  static const levels = <GlobalLevelDefinition>[
    GlobalLevelDefinition(
      levelNumber: 1,
      romanNumeral: 'I',
      name: 'Bronze',
      xpThreshold: 0,
      colorHex: '#CD7F32',
      icon: 'shield_bronze',
    ),
    GlobalLevelDefinition(
      levelNumber: 2,
      romanNumeral: 'II',
      name: 'Silver',
      xpThreshold: 2000,
      colorHex: '#C0C0C0',
      icon: 'shield_silver',
    ),
    GlobalLevelDefinition(
      levelNumber: 3,
      romanNumeral: 'III',
      name: 'Gold',
      xpThreshold: 7000,
      colorHex: '#FFD700',
      icon: 'shield_gold',
    ),
    GlobalLevelDefinition(
      levelNumber: 4,
      romanNumeral: 'IV',
      name: 'Crystal',
      xpThreshold: 15000,
      colorHex: '#8FE8FF',
      icon: 'gem_crystal',
    ),
    GlobalLevelDefinition(
      levelNumber: 5,
      romanNumeral: 'V',
      name: 'Diamond',
      xpThreshold: 30000,
      colorHex: '#B9F2FF',
      icon: 'gem_diamond',
    ),
    GlobalLevelDefinition(
      levelNumber: 6,
      romanNumeral: 'VI',
      name: 'Obsidian',
      xpThreshold: 60000,
      colorHex: '#6F7785',
      icon: 'shield_obsidian',
    ),
    GlobalLevelDefinition(
      levelNumber: 7,
      romanNumeral: 'VII',
      name: 'Mythic',
      xpThreshold: 100000,
      colorHex: '#A970FF',
      icon: 'crown_mythic',
    ),
    GlobalLevelDefinition(
      levelNumber: 8,
      romanNumeral: 'VIII',
      name: 'Ascendant',
      xpThreshold: 175000,
      colorHex: '#FF6BD6',
      icon: 'star_ascendant',
    ),
    GlobalLevelDefinition(
      levelNumber: 9,
      romanNumeral: 'IX',
      name: 'Transcendent',
      xpThreshold: 300000,
      colorHex: '#FF9F43',
      icon: 'flare_transcendent',
    ),
    GlobalLevelDefinition(
      levelNumber: 10,
      romanNumeral: 'X',
      name: 'Eternal',
      xpThreshold: 500000,
      colorHex: '#EEFF08',
      icon: 'crown_eternal',
    ),
  ];

  static GlobalProgressionState resolve(int overallXp) {
    final safeXp = overallXp < 0 ? 0 : overallXp;
    var index = 0;
    for (var i = 1; i < levels.length; i++) {
      if (safeXp < levels[i].xpThreshold) break;
      index = i;
    }

    final current = levels[index];
    final next = index + 1 < levels.length ? levels[index + 1] : null;
    final levelSpan = next == null ? 0 : next.xpThreshold - current.xpThreshold;
    final intoLevel = safeXp - current.xpThreshold;
    final remaining = next == null ? 0 : next.xpThreshold - safeXp;
    final percent = next == null
        ? 100.0
        : ((intoLevel / levelSpan) * 100).clamp(0.0, 100.0);

    return GlobalProgressionState(
      overallXp: safeXp,
      currentLevel: current,
      nextLevel: next,
      xpIntoLevel: intoLevel,
      xpBetweenLevels: levelSpan,
      xpToNextLevel: remaining,
      progressPercent: double.parse(percent.toStringAsFixed(2)),
    );
  }
}
