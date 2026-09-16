import 'package:flutter/material.dart';
import '../models/gem.dart';

/// 2.5D animated gem widget. Supports idle shimmer, selection lift, and glow.
class GemWidget extends StatefulWidget {
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
  State<GemWidget> createState() => _GemWidgetState();
}

class _GemWidgetState extends State<GemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  late Animation<double>   _shimmerAnim;

  @override
  void initState() {
    super.initState();
    // Stagger shimmer period slightly per gem color so they don't all pulse together.
    final ms = 1800 + widget.gem.color.index * 250;
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    )..repeat(reverse: true);
    _shimmerAnim = CurvedAnimation(
      parent: _shimmerCtrl,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glow       = _glowColor;
    final isSelected = widget.gem.isSelected;
    final s          = widget.size;

    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, child) {
        final shimmer = _shimmerAnim.value;
        return GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            width:  s,
            height: s,
            transform: isSelected
                ? (Matrix4.identity()
                  ..translate(0.0, -7.0, 0.0)
                  ..scale(1.10))
                : Matrix4.identity(),
            transformAlignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                // Coloured glow
                BoxShadow(
                  color: glow.withOpacity(
                    isSelected ? 0.85 : 0.30 + shimmer * 0.18,
                  ),
                  blurRadius:   isSelected ? 24 : 12 + shimmer * 5,
                  spreadRadius: isSelected ? 5  : 1  + shimmer,
                ),
                // Drop shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Gem image
                Image.asset(
                  widget.gem.color.assetPath,
                  width:  s * 0.90,
                  height: s * 0.90,
                  fit: BoxFit.contain,
                ),
                // Inner shimmer highlight
                Container(
                  width:  s * 0.50,
                  height: s * 0.50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withOpacity(0.20 + shimmer * 0.28),
                        Colors.white.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
                // Selection ring
                if (isSelected)
                  Container(
                    width:  s * 1.18,
                    height: s * 1.18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.92),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: glow.withOpacity(0.70),
                          blurRadius:   14,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color get _glowColor {
    switch (widget.gem.color) {
      case GemColor.red:    return Colors.redAccent;
      case GemColor.blue:   return Colors.blueAccent;
      case GemColor.green:  return Colors.greenAccent;
      case GemColor.yellow: return Colors.yellowAccent;
      case GemColor.purple: return Colors.purpleAccent;
      case GemColor.orange: return Colors.orangeAccent;
      case GemColor.white:  return Colors.white;
    }
  }
}
