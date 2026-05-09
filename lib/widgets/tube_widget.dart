import 'package:flutter/material.dart';
import '../models/gem.dart';
import 'gem_widget.dart';

class TubeWidget extends StatelessWidget {
  final List<Gem> gems;
  final int capacity;
  final bool isSelected;
  final bool isHintTarget;   // green glow = "move your gem HERE"
  final VoidCallback onTap;
  final double width;
  final double gemSize;

  const TubeWidget({
    required this.gems,
    required this.capacity,
    required this.isSelected,
    required this.onTap,
    required this.width,
    required this.gemSize,
    this.isHintTarget = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tubeHeight = gemSize * capacity + 20;

    Color borderColor;
    double borderWidth;
    List<BoxShadow> shadows;

    if (isSelected) {
      borderColor = Colors.white.withOpacity(0.8);
      borderWidth = 3;
      shadows = [
        BoxShadow(color: Colors.white.withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
      ];
    } else if (isHintTarget) {
      borderColor = Colors.greenAccent.withOpacity(0.9);
      borderWidth = 3;
      shadows = [
        BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 24, spreadRadius: 4),
        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
      ];
    } else {
      borderColor = Colors.white.withOpacity(0.2);
      borderWidth = 1.5;
      shadows = [
        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
      ];
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: tubeHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              isHintTarget
                  ? Colors.greenAccent.withOpacity(0.12)
                  : Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: shadows,
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Glass reflection
            Positioned(
              top: 10,
              left: 8,
              child: Container(
                width: width * 0.15,
                height: tubeHeight * 0.6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.0)],
                  ),
                ),
              ),
            ),
            // Hint target arrow indicator
            if (isHintTarget && gems.length < capacity)
              Positioned(
                top: 6,
                child: Column(
                  children: [
                    Icon(Icons.arrow_downward_rounded,
                        color: Colors.greenAccent.withOpacity(0.9), size: 16),
                  ],
                ),
              ),
            // Gems stack
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: gems.map((gem) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: GemWidget(
                      gem: gem.copyWith(isSelected: isSelected && gem == gems.last),
                      size: gemSize,
                    ),
                  );
                }).toList(),
              ),
            ),
            // Empty tube indicator
            if (gems.isEmpty)
              Center(
                child: Icon(
                  isHintTarget ? Icons.add_circle : Icons.add_circle_outline,
                  color: isHintTarget
                      ? Colors.greenAccent.withOpacity(0.6)
                      : Colors.white.withOpacity(0.3),
                  size: gemSize * 0.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
