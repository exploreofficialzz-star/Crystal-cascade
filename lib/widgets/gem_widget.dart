import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/gem.dart';

class GemWidget extends StatefulWidget {
  final Gem gem;
  final double size;
  final bool isTop;
  final VoidCallback? onTap;
  final double impactPulse;
  final int stackIndex;

  const GemWidget({
    required this.gem,
    required this.size,
    this.isTop = false,
    this.onTap,
    this.impactPulse = 0.0,
    this.stackIndex = 0,
    super.key,
  });

  @override
  State<GemWidget> createState() => _GemWidgetState();
}

class _GemWidgetState extends State<GemWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getGlowColor() {
    switch (widget.gem.color) {
      case GemColor.red: return Colors.redAccent;
      case GemColor.blue: return Colors.blueAccent;
      case GemColor.green: return Colors.greenAccent;
      case GemColor.yellow: return Colors.yellowAccent;
      case GemColor.purple: return Colors.purpleAccent;
      case GemColor.orange: return Colors.orangeAccent;
      case GemColor.white: return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final wave = math.sin(_controller.value * math.pi * 2);
          final selected = widget.gem.isSelected;
          final impact = math.sin(widget.impactPulse * math.pi).clamp(0.0, 1.0);
          final phase = widget.stackIndex * .42;
          final settle = widget.isTop ? math.max(0.0, math.sin(_controller.value * math.pi * 2 + .7 + phase)) * .8 : 0.0;
          final contact = math.max(0.0, math.sin(widget.impactPulse * math.pi - widget.stackIndex * .11));
          final lift = selected ? 4.0 : (widget.isTop ? wave * .8 : 0.0) + contact * (2.0 + widget.stackIndex * .45);
          final rotation = selected ? wave * .035 : (widget.isTop ? wave * .012 : 0.0) + contact * (widget.stackIndex.isEven ? .018 : -.018);
          final settleScale = widget.isTop ? 1.0 + settle * .012 : 1.0;
          final scale = selected ? 1.09 + wave * .012 : 1.0 + impact * (widget.isTop ? .075 : .025) + contact * .025;

          return Transform.translate(
            offset: Offset(0, -lift - impact * (widget.isTop ? 3.0 : 1.0)),
            child: Transform.rotate(
              angle: rotation,
              child: Transform.scale(
                scale: scale * settleScale,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getGlowColor().withOpacity(selected ? .9 : (.46 + impact * .32)),
                        blurRadius: selected ? 23 : 13 + impact * 8,
                        spreadRadius: selected ? 5 : 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(.34),
                        blurRadius: 8,
                        offset: const Offset(2, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        widget.gem.color.assetPath,
                        width: widget.size * .91,
                        height: widget.size * .91,
                        fit: BoxFit.contain,
                      ),
                      Container(
                        width: widget.size * .58,
                        height: widget.size * .58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            Colors.white.withOpacity(.48),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                      Positioned(
                        left: widget.size * .20,
                        top: widget.size * .17,
                        child: Container(
                          width: widget.size * .14,
                          height: widget.size * .25,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            color: Colors.white.withOpacity(.22 + wave.abs() * .10),
                          ),
                        ),
                      ),
                      if (impact > .05)
                        Container(
                          width: widget.size * (1.02 + impact * .16),
                          height: widget.size * (1.02 + impact * .16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(.22 * impact),
                              width: 1.5,
                            ),
                          ),
                        ),
                      if (selected)
                        Container(
                          width: widget.size * 1.1,
                          height: widget.size * 1.1,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(.9),
                              width: 2.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
