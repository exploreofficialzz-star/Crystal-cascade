import 'package:flutter/material.dart';
import '../models/gem.dart';

class GemWidget extends StatelessWidget {
  final Gem gem;
  final double size;
  final bool isTop;
  final VoidCallback? onTap;

  const GemWidget({
    required this.gem,
    required this.size,
    this.isTop = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _getGlowColor().withOpacity(gem.isSelected ? 0.8 : 0.4),
              blurRadius: gem.isSelected ? 20 : 12,
              spreadRadius: gem.isSelected ? 4 : 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Gem image
            Image.asset(
              gem.color.assetPath,
              width: size * 0.9,
              height: size * 0.9,
              fit: BoxFit.contain,
            ),
            // Shine effect overlay
            Container(
              width: size * 0.6,
              height: size * 0.6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.4),
                    Colors.white.withOpacity(0.0),
                  ],
                ),
              ),
            ),
            // Selection ring
            if (gem.isSelected)
              Container(
                width: size * 1.1,
                height: size * 1.1,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getGlowColor().withOpacity(0.8),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getGlowColor() {
    switch (gem.color) {
      case GemColor.red:
        return Colors.redAccent;
      case GemColor.blue:
        return Colors.blueAccent;
      case GemColor.green:
        return Colors.greenAccent;
      case GemColor.yellow:
        return Colors.yellowAccent;
      case GemColor.purple:
        return Colors.purpleAccent;
      case GemColor.orange:
        return Colors.orangeAccent;
      case GemColor.white:
        return Colors.white;
    }
  }
}
