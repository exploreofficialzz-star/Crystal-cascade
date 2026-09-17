enum GemColor {
  red,
  blue,
  green,
  yellow,
  purple,
  orange,
  white,
}

extension GemColorExtension on GemColor {
  String get assetPath {
    switch (this) {
      case GemColor.red:
        return 'assets/images/gem_red.png';
      case GemColor.blue:
        return 'assets/images/gem_blue.png';
      case GemColor.green:
        return 'assets/images/gem_green.png';
      case GemColor.yellow:
        return 'assets/images/gem_yellow.png';
      case GemColor.purple:
        return 'assets/images/gem_purple.png';
      case GemColor.orange:
        return 'assets/images/gem_orange.png';
      case GemColor.white:
        return 'assets/images/gem_white.png';
    }
  }

  String get name {
    switch (this) {
      case GemColor.red:
        return 'Ruby';
      case GemColor.blue:
        return 'Sapphire';
      case GemColor.green:
        return 'Emerald';
      case GemColor.yellow:
        return 'Citrine';
      case GemColor.purple:
        return 'Amethyst';
      case GemColor.orange:
        return 'Topaz';
      case GemColor.white:
        return 'Diamond';
    }
  }
}

class Gem {
  final String id;
  final GemColor color;
  bool isMatched;
  bool isSelected;
  double opacity;

  Gem({
    required this.id,
    required this.color,
    this.isMatched = false,
    this.isSelected = false,
    this.opacity = 1.0,
  });

  Gem copyWith({
    String? id,
    GemColor? color,
    bool? isMatched,
    bool? isSelected,
    double? opacity,
  }) {
    return Gem(
      id: id ?? this.id,
      color: color ?? this.color,
      isMatched: isMatched ?? this.isMatched,
      isSelected: isSelected ?? this.isSelected,
      opacity: opacity ?? this.opacity,
    );
  }
}
