import '../models/gem.dart';
import '../models/level.dart';

class GameConstants {
  static const String appName = 'Crystal Cascade';
  static const String appVersion = '1.0.0';
  static const String developerTag = 'by chAs';
  static const String packageName = 'com.chastechgroup.crystalcascade';

  // AdMob Test IDs - Replace with production IDs before release
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  static const String rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  // Gameplay Constants
  static const int maxLives = 5;
  static const int lifeRegenMinutes = 30;
  static const int coinsPerStar = 10;
  static const int coinsPerLevelComplete = 20;
  static const int hintCost = 50;
  static const int extraMovesCost = 30;
  static const int extraTubeCost = 100;

  // Animation Durations
  static const Duration gemMoveDuration = Duration(milliseconds: 300);
  static const Duration matchFlashDuration = Duration(milliseconds: 200);
  static const Duration particleDuration = Duration(milliseconds: 800);

  // Level Generation
  static List<Level> generateLevels() {
    final List<Level> levels = [];

    for (int i = 1; i <= 100; i++) {
      int tubesCount;
      int tubeCapacity;
      int maxMoves;
      int colorsCount;
      int gemsPerColor;

      if (i <= 5) {
        tubesCount = 3;
        tubeCapacity = 4;
        colorsCount = 2;
        gemsPerColor = 4;
        maxMoves = 12;
      } else if (i <= 15) {
        tubesCount = 4;
        tubeCapacity = 4;
        colorsCount = 3;
        gemsPerColor = 4;
        maxMoves = 20;
      } else if (i <= 30) {
        tubesCount = 5;
        tubeCapacity = 4;
        colorsCount = 4;
        gemsPerColor = 4;
        maxMoves = 28;
      } else if (i <= 50) {
        tubesCount = 6;
        tubeCapacity = 5;
        colorsCount = 4;
        gemsPerColor = 5;
        maxMoves = 40;
      } else if (i <= 75) {
        tubesCount = 7;
        tubeCapacity = 5;
        colorsCount = 5;
        gemsPerColor = 5;
        maxMoves = 55;
      } else {
        tubesCount = 8;
        tubeCapacity = 6;
        colorsCount = 6;
        gemsPerColor = 6;
        maxMoves = 75;
      }

      final allColors = [
        GemColor.red,
        GemColor.blue,
        GemColor.green,
        GemColor.yellow,
        GemColor.purple,
        GemColor.orange,
        GemColor.white,
      ];

      final availableColors = <GemColor>[];
      for (int c = 0; c < colorsCount && c < allColors.length; c++) {
        availableColors.add(allColors[c]);
      }

      levels.add(Level(
        id: i,
        tubesCount: tubesCount,
        tubeCapacity: tubeCapacity,
        maxMoves: maxMoves,
        availableColors: availableColors,
        gemsPerColor: gemsPerColor,
        starThreshold1: (maxMoves * 0.2).ceil(),
        starThreshold2: (maxMoves * 0.4).ceil(),
        starThreshold3: (maxMoves * 0.6).ceil(),
        isUnlocked: i == 1,
      ));
    }

    return levels;
  }
}
