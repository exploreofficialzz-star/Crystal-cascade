import 'gem.dart';

class Level {
  final int id;
  final int tubesCount;
  final int tubeCapacity;
  final int maxMoves;
  final List<GemColor> availableColors;
  final int gemsPerColor;
  final int starThreshold1;
  final int starThreshold2;
  final int starThreshold3;
  final bool isUnlocked;
  final int? bestStars;
  final int? bestScore;

  Level({
    required this.id,
    required this.tubesCount,
    required this.tubeCapacity,
    required this.maxMoves,
    required this.availableColors,
    required this.gemsPerColor,
    this.starThreshold1 = 1,
    this.starThreshold2 = 2,
    this.starThreshold3 = 3,
    this.isUnlocked = false,
    this.bestStars,
    this.bestScore,
  });

  Level copyWith({
    int? id,
    int? tubesCount,
    int? tubeCapacity,
    int? maxMoves,
    List<GemColor>? availableColors,
    int? gemsPerColor,
    int? starThreshold1,
    int? starThreshold2,
    int? starThreshold3,
    bool? isUnlocked,
    int? bestStars,
    int? bestScore,
  }) {
    return Level(
      id: id ?? this.id,
      tubesCount: tubesCount ?? this.tubesCount,
      tubeCapacity: tubeCapacity ?? this.tubeCapacity,
      maxMoves: maxMoves ?? this.maxMoves,
      availableColors: availableColors ?? this.availableColors,
      gemsPerColor: gemsPerColor ?? this.gemsPerColor,
      starThreshold1: starThreshold1 ?? this.starThreshold1,
      starThreshold2: starThreshold2 ?? this.starThreshold2,
      starThreshold3: starThreshold3 ?? this.starThreshold3,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      bestStars: bestStars ?? this.bestStars,
      bestScore: bestScore ?? this.bestScore,
    );
  }

  int calculateStars(int movesRemaining) {
    if (movesRemaining >= starThreshold3) return 3;
    if (movesRemaining >= starThreshold2) return 2;
    if (movesRemaining >= starThreshold1) return 1;
    return 1;
  }
}
