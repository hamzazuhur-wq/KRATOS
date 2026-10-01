import 'package:flutter_test/flutter_test.dart';
import 'package:kratos_app/features/progression/domain/global_progression.dart';

void main() {
  const cases = <(int, int, String)>[
    (0, 1, 'Bronze'),
    (1999, 1, 'Bronze'),
    (2000, 2, 'Silver'),
    (6999, 2, 'Silver'),
    (7000, 3, 'Gold'),
    (14999, 3, 'Gold'),
    (15000, 4, 'Crystal'),
    (29999, 4, 'Crystal'),
    (30000, 5, 'Diamond'),
    (59999, 5, 'Diamond'),
    (60000, 6, 'Obsidian'),
    (99999, 6, 'Obsidian'),
    (100000, 7, 'Mythic'),
    (174999, 7, 'Mythic'),
    (175000, 8, 'Ascendant'),
    (299999, 8, 'Ascendant'),
    (300000, 9, 'Transcendent'),
    (499999, 9, 'Transcendent'),
    (500000, 10, 'Eternal'),
    (900000, 10, 'Eternal'),
  ];

  for (final (xp, level, name) in cases) {
    test(
      '$xp XP resolves to $name ${GlobalProgressionDefinitions.levels[level - 1].romanNumeral}',
      () {
        final state = GlobalProgressionDefinitions.resolve(xp);
        expect(state.overallXp, xp);
        expect(state.currentLevel.levelNumber, level);
        expect(state.currentLevel.name, name);
        expect(
          state.currentLevel.romanNumeral,
          GlobalProgressionDefinitions.levels[level - 1].romanNumeral,
        );
      },
    );
  }

  test(
    'calculates progress and XP remaining without resetting accumulated XP',
    () {
      final state = GlobalProgressionDefinitions.resolve(5800);
      expect(state.currentLevel.name, 'Silver');
      expect(state.currentLevel.romanNumeral, 'II');
      expect(state.overallXp, 5800);
      expect(state.xpIntoLevel, 3800);
      expect(state.xpBetweenLevels, 5000);
      expect(state.xpToNextLevel, 1200);
      expect(state.progressPercent, 76);
    },
  );

  test('max level has no next level or fabricated progress target', () {
    final state = GlobalProgressionDefinitions.resolve(500000);
    expect(state.currentLevel.name, 'Eternal');
    expect(state.currentLevel.romanNumeral, 'X');
    expect(state.nextLevel, isNull);
    expect(state.xpToNextLevel, 0);
    expect(state.progressPercent, 100);
  });
}
