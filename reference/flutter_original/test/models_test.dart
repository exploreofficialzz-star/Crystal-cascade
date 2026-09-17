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
    test('First level is unlocked by default', () {
      final level = GameConstants.generateLevel(1);
      expect(level.isUnlocked, true);
    });

    test('Level 1 has correct configuration', () {
      final level1 = GameConstants.generateLevel(1);
      expect(level1.id, 1);
      expect(level1.tubesCount, 3);
      expect(level1.tubeCapacity, 6);
      expect(level1.availableColors.length, 2);
    });

    test('Level generation continues indefinitely past the old 100-level cap', () {
      final level150 = GameConstants.generateLevel(150);
      expect(level150.id, 150);
      expect(level150.tubesCount, greaterThan(0));
      expect(level150.availableColors, isNotEmpty);
      expect(level150.maxMoves, greaterThan(0));
    });

    test('Color count never exceeds available gem assets', () {
      final farLevel = GameConstants.generateLevel(5000);
      expect(farLevel.availableColors.length,
          lessThanOrEqualTo(GameConstants.maxColors));
    });

    test('Tube count never exceeds the 10-tube screen cap', () {
      final farLevel = GameConstants.generateLevel(5000);
      expect(farLevel.tubesCount, lessThanOrEqualTo(10));
    });

    test('Move budget stays positive at extreme level numbers', () {
      final extremeLevel = GameConstants.generateLevel(100000);
      expect(extremeLevel.maxMoves, greaterThan(0));
    });
  });
}
