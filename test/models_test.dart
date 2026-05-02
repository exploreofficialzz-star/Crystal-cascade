import 'package:flutter_test/flutter_test.dart';
import 'package:crystal_cascade/models/gem.dart';
import 'package:crystal_cascade/models/level.dart';
import 'package:crystal_cascade/utils/constants.dart';

void main() {
  group('Gem Model Tests', () {
    test('GemColorExtension returns correct asset paths', () {
      expect(GemColor.red.assetPath, 'assets/images/gem_red.png');
      expect(GemColor.blue.assetPath, 'assets/images/gem_blue.png');
      expect(GemColor.green.assetPath, 'assets/images/gem_green.png');
    });

    test('GemColorExtension returns correct names', () {
      expect(GemColor.red.name, 'Ruby');
      expect(GemColor.purple.name, 'Amethyst');
      expect(GemColor.white.name, 'Diamond');
    });

    test('Gem copyWith works correctly', () {
      final gem = Gem(id: 'test', color: GemColor.red);
      final copied = gem.copyWith(isSelected: true);

      expect(copied.id, gem.id);
      expect(copied.color, gem.color);
      expect(copied.isSelected, true);
      expect(gem.isSelected, false);
    });
  });

  group('Level Model Tests', () {
    test('Level calculates stars correctly', () {
      final level = Level(
        id: 1,
        tubesCount: 3,
        tubeCapacity: 4,
        maxMoves: 20,
        availableColors: [GemColor.red, GemColor.blue],
        gemsPerColor: 4,
        starThreshold1: 4,
        starThreshold2: 8,
        starThreshold3: 12,
      );

      expect(level.calculateStars(15), 3);
      expect(level.calculateStars(10), 2);
      expect(level.calculateStars(5), 1);
      expect(level.calculateStars(2), 1);
    });

    test('Level copyWith preserves unchanged values', () {
      final level = Level(
        id: 1,
        tubesCount: 3,
        tubeCapacity: 4,
        maxMoves: 20,
        availableColors: [GemColor.red],
        gemsPerColor: 4,
      );

      final copied = level.copyWith(bestStars: 3);
      expect(copied.id, 1);
      expect(copied.tubesCount, 3);
      expect(copied.bestStars, 3);
    });
  });

  group('GameConstants Tests', () {
    test('Generates 100 levels', () {
      final levels = GameConstants.generateLevels();
      expect(levels.length, 100);
    });

    test('First level is unlocked by default', () {
      final levels = GameConstants.generateLevels();
      expect(levels[0].isUnlocked, true);
    });

    test('Level 1 has correct configuration', () {
      final levels = GameConstants.generateLevels();
      final level1 = levels[0];
      expect(level1.id, 1);
      expect(level1.tubesCount, 3);
      expect(level1.tubeCapacity, 6);
      expect(level1.availableColors.length, 2);
    });
  });
}
