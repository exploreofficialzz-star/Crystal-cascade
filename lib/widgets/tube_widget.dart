import 'package:flutter/material.dart';
import '../models/gem.dart';
import 'gem_widget.dart';

class TubeWidget extends StatelessWidget {
  final List<Gem> gems;
  final int capacity;
  final bool isSelected;
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
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tubeHeight = gemSize * capacity + 20;

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
              Colors.white.withOpacity(0.15),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.8)
                : Colors.white.withOpacity(0.2),
            width: isSelected ? 3 : 1.5,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.white.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Glass reflection effect
            Positioned(
              top: 10,
              left: 8,
              child: Container(
                width: width * 0.15,
                height: tubeHeight * 0.6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.3),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
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
                  Icons.add_circle_outline,
                  color: Colors.white.withOpacity(0.3),
                  size: gemSize * 0.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
