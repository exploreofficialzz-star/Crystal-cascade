import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/gem.dart';

/// Premium physical-feeling crystal transfer. The puzzle state changes in the
/// provider immediately; this layer choreographs the visual journey over it.
class GemFlight extends StatefulWidget {
  final GemColor color;
  final Offset start;
  final Offset end;
  final VoidCallback onComplete;

  const GemFlight({
    required this.color,
    required this.start,
    required this.end,
    required this.onComplete,
    super.key,
  });

  @override
  State<GemFlight> createState() => _GemFlightState();
}

class _GemFlightState extends State<GemFlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  )..forward();

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _glow {
    switch (widget.color) {
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final raw = Curves.easeInOutCubic.transform(_controller.value);
        final start = widget.start;
        final end = widget.end;
        final distance = (end - start).distance;
        final lift = math.min(96.0, 46 + distance * .18);
        final mid = Offset((start.dx + end.dx) / 2, math.min(start.dy, end.dy) - lift);
        final one = 1 - raw;
        final pos = Offset(
          one * one * start.dx + 2 * one * raw * mid.dx + raw * raw * end.dx,
          one * one * start.dy + 2 * one * raw * mid.dy + raw * raw * end.dy,
        );
        final tangent = Offset(
          2 * one * (mid.dx - start.dx) + 2 * raw * (end.dx - mid.dx),
          2 * one * (mid.dy - start.dy) + 2 * raw * (end.dy - mid.dy),
        );
        final angle = math.atan2(tangent.dy, tangent.dx) + math.sin(raw * math.pi * 3) * .12;
        final launch = Curves.easeOut.transform(math.min(1, raw * 4));
        final settle = raw > .82 ? (raw - .82) / .18 : 0.0;
        final scale = .86 + math.sin(raw * math.pi) * .25 - settle * .12 + math.sin(settle * math.pi) * .06;
        final opacity = raw > .94 ? (1 - raw) / .06 : 1.0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Motion trail: inexpensive circles instead of a large particle system.
            for (var i = 1; i <= 6; i++)
              Positioned(
                left: pos.dx - 18 - tangent.dx * i * .012,
                top: pos.dy - 18 - tangent.dy * i * .012,
                child: Opacity(
                  opacity: ((1 - i / 8) * .18 * launch).clamp(0.0, 1.0),
                  child: Container(
                    width: 36 - i * 3.5,
                    height: 36 - i * 3.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _glow.withOpacity(.32),
                      boxShadow: [BoxShadow(color: _glow.withOpacity(.28), blurRadius: 12)],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: pos.dx - 22,
              top: pos.dy + 22,
              child: Opacity(
                opacity: (.08 + launch * .16) * (1 - settle * .5),
                child: Container(
                  width: 44,
                  height: 9,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: Colors.black.withOpacity(.32),
                    boxShadow: [BoxShadow(color: _glow.withOpacity(.18), blurRadius: 10)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: pos.dx - 29,
              top: pos.dy - 29,
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: angle,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: _glow.withOpacity(.88), blurRadius: 26, spreadRadius: 4),
                          BoxShadow(color: Colors.black.withOpacity(.32), blurRadius: 8, offset: const Offset(2, 5)),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(widget.color.assetPath, width: 52, height: 52),
                          Container(
                            width: 31,
                            height: 31,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [Colors.white54, Colors.transparent]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (settle > 0)
              Positioned(
                left: end.dx - 24,
                top: end.dy - 24,
                child: Opacity(
                  opacity: (settle * (1 - settle)).clamp(0.0, 1.0) * 4,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _glow.withOpacity(.65), width: 2),
                      boxShadow: [BoxShadow(color: _glow.withOpacity(.35), blurRadius: 18)],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
