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

  // ─── Coin Economy (tightened to drive ad views & purchases) ───────────────
  static const int coinsPerStar = 2;           // was 10 — per 3-gem match
  static const int coinsPerLevelComplete = 5;  // was 20 — flat level reward
  static const int hintCost = 40;              // coins to buy 1 hint
  static const int extraMovesCost = 30;        // coins for +5 moves
  static const int startingCoins = 25;         // was 100
  static const int startingHints = 1;          // was 3

  // ─── Gameplay Constants ────────────────────────────────────────────────────
  static const int maxLives = 5;
  static const int lifeRegenMinutes = 30;
  static const int extraTubeCost = 100;

  // ─── Remove Ads — Tiered Pricing ──────────────────────────────────────────
  static const String removeAdsDayPrice     = '\$0.99';
  static const String removeAdsWeekendPrice = '\$2.99';
  static const String removeAdsMonthPrice   = '\$8.99';

  static const int removeAdsDayMs     = 24 * 60 * 60 * 1000;
  static const int removeAdsWeekendMs = 48 * 60 * 60 * 1000;
  static const int removeAdsMonthMs   = 30 * 24 * 60 * 60 * 1000;

  // ─── Hint Packs ───────────────────────────────────────────────────────────
  static const String hintPackSmallPrice = '\$0.99';
  static const String hintPackLargePrice = '\$1.99';
  static const int hintPackSmallCount = 5;
  static const int hintPackLargeCount = 15;

  // ─── Animation Durations ──────────────────────────────────────────────────
  static const Duration gemMoveDuration    = Duration(milliseconds: 300);
  static const Duration matchFlashDuration = Duration(milliseconds: 200);
  static const Duration particleDuration   = Duration(milliseconds: 800);
  static const Duration hintGlowDuration   = Duration(seconds: 2);

  static List<Level> generateLevels() {
    final List<Level> levels = [];
    for (int i = 1; i <= 100; i++) {
      int tubesCount, tubeCapacity, maxMoves, colorsCount, gemsPerColor;
      if (i <= 5) {
        tubesCount = 3; tubeCapacity = 6; colorsCount = 2; gemsPerColor = 6; maxMoves = 12;
      } else if (i <= 15) {
        tubesCount = 4; tubeCapacity = 6; colorsCount = 3; gemsPerColor = 6; maxMoves = 20;
      } else if (i <= 30) {
        tubesCount = 5; tubeCapacity = 6; colorsCount = 4; gemsPerColor = 6; maxMoves = 28;
      } else if (i <= 50) {
        tubesCount = 6; tubeCapacity = 6; colorsCount = 4; gemsPerColor = 6; maxMoves = 40;
      } else if (i <= 75) {
        tubesCount = 7; tubeCapacity = 6; colorsCount = 5; gemsPerColor = 6; maxMoves = 55;
      } else {
        tubesCount = 8; tubeCapacity = 6; colorsCount = 6; gemsPerColor = 6; maxMoves = 75;
      }
      final allColors = [
        GemColor.red, GemColor.blue, GemColor.green, GemColor.yellow,
        GemColor.purple, GemColor.orange, GemColor.white,
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
