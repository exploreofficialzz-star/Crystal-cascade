import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/gem.dart';
import '../providers/game_provider.dart';

/// Scene-level interaction director. It does not change puzzle state; it turns
/// a move into a single visual event with anticipation, travel, landing and
/// aftershock phases.
class InteractionDirector extends StatefulWidget {
  final GameReaction reaction;
  final int version;
  final int moveVersion;
  final GemColor? color;
  final bool hasFlight;
  final int combo;
  final Offset? flightStart;
  final Offset? flightEnd;

  const InteractionDirector({
    required this.reaction,
    required this.version,
    this.moveVersion = 0,
    required this.hasFlight,
    this.color,
    this.combo = 0,
    this.flightStart,
    this.flightEnd,
    super.key,
  });

  @override
  State<InteractionDirector> createState() => _InteractionDirectorState();
}

class _InteractionDirectorState extends State<InteractionDirector>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 980),
  );
  Offset? _eventStart;
  Offset? _eventEnd;
  int _eventMoveVersion = -1;

  @override
  void initState() {
    super.initState();
    _eventStart = widget.flightStart;
    _eventEnd = widget.flightEnd;
    _eventMoveVersion = widget.moveVersion;
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant InteractionDirector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A move is the atomic cinematic event. Reaction updates can happen several
    // times during one move (moved -> matched -> won), so they must not restart
    // the choreography and cut off the flight/landing phases.
    if (widget.moveVersion != oldWidget.moveVersion ||
        (widget.moveVersion == 0 && widget.version != oldWidget.version)) {
      _eventMoveVersion = widget.moveVersion;
      _eventStart = widget.flightStart ?? _eventStart;
      _eventEnd = widget.flightEnd ?? _eventEnd;
      _controller.forward(from: 0);
    } else {
      // Keep the endpoints after GemFlight removes itself. The landing and
      // aftershock must still resolve at the receiving tube, not at screen
      // center.
      _eventStart = widget.flightStart ?? _eventStart;
      _eventEnd = widget.flightEnd ?? _eventEnd;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _accent {
    switch (widget.color) {
      case GemColor.red: return Colors.redAccent;
      case GemColor.blue: return Colors.blueAccent;
      case GemColor.green: return Colors.greenAccent;
      case GemColor.yellow: return Colors.yellowAccent;
      case GemColor.purple: return Colors.purpleAccent;
      case GemColor.orange: return Colors.orangeAccent;
      case GemColor.white: return Colors.white;
      case null: return Colors.cyanAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final move = widget.reaction == GameReaction.moved;
    final important = move || widget.reaction == GameReaction.selected ||
        widget.reaction == GameReaction.deselected || widget.reaction == GameReaction.invalid ||
        widget.reaction == GameReaction.lowMoves || widget.reaction == GameReaction.lost ||
        widget.reaction == GameReaction.matched || widget.reaction == GameReaction.tubeCompleted ||
        widget.reaction == GameReaction.won;
    if (!important) return const SizedBox.shrink();

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          final anticipation = (1 - (_controller.value / .20)).clamp(0.0, 1.0);
          final landing = ((_controller.value - .55) / .22).clamp(0.0, 1.0);
          final aftershock = ((_controller.value - .72) / .28).clamp(0.0, 1.0);
          final strength = widget.reaction == GameReaction.won
              ? 1.45
              : 1 + math.min(widget.combo, 5) * .06;
          final eventStart = widget.flightStart ?? _eventStart;
          final eventEnd = widget.flightEnd ?? _eventEnd;
          final eventFlight = (widget.hasFlight || (eventStart != null && _controller.value < .98));

          return Stack(
            fit: StackFit.expand,
            children: [
              if (widget.reaction != GameReaction.moved)
                CustomPaint(painter: _StateFeedbackPainter(
                  progress: t,
                  reaction: widget.reaction,
                  accent: _accent,
                )),
              if (anticipation > 0 && (move || eventFlight))
                CustomPaint(painter: _AnticipationPainter(
                  progress: anticipation,
                  accent: _accent,
                  start: eventStart,
                  end: eventEnd,
                )),
              if (eventFlight && eventStart != null && eventEnd != null)
                CustomPaint(painter: _TrajectoryPainter(
                  progress: t,
                  accent: _accent,
                  start: eventStart!,
                  end: eventEnd!,
                )),
              if (landing > 0)
                CustomPaint(painter: _LandingPainter(
                  progress: landing,
                  accent: _accent,
                  strength: strength,
                  start: eventStart,
                  end: eventEnd,
                )),
              if (aftershock > 0 && (widget.reaction == GameReaction.matched || widget.reaction == GameReaction.tubeCompleted || widget.reaction == GameReaction.won))
                CustomPaint(painter: _AftershockPainter(
                  progress: aftershock,
                  accent: _accent,
                  strength: strength,
                  end: eventEnd,
                )),
            ],
          );
        },
      ),
    );
  }
}


class _StateFeedbackPainter extends CustomPainter {
  final double progress;
  final GameReaction reaction;
  final Color accent;
  _StateFeedbackPainter({required this.progress, required this.reaction, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .5, size.height * .48);
    final p = math.sin(progress * math.pi);
    if (reaction == GameReaction.selected || reaction == GameReaction.deselected) {
      final r = size.shortestSide * (.035 + p * .055);
      canvas.drawCircle(center, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = accent.withOpacity(.28 * (1-progress)));
      return;
    }
    if (reaction == GameReaction.invalid) {
      final red = Colors.redAccent.withOpacity(.38 * (1-progress));
      final paint = Paint()..color = red..strokeWidth = 3.2..strokeCap = StrokeCap.round;
      final r = size.shortestSide * (.035 + p * .045);
      canvas.drawLine(center + Offset(-r, -r), center + Offset(r, r), paint);
      canvas.drawLine(center + Offset(r, -r), center + Offset(-r, r), paint);
    } else if (reaction == GameReaction.lowMoves) {
      final edge = Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.amberAccent.withOpacity(.22 * (1-progress));
      canvas.drawCircle(center, size.shortestSide * (.22 + p * .16), edge);
    } else if (reaction == GameReaction.lost) {
      final veil = Paint()..color = Colors.blueGrey.withOpacity(.06 * (1-progress));
      canvas.drawRect(Offset.zero & size, veil);
    }
  }

  @override
  bool shouldRepaint(covariant _StateFeedbackPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.reaction != reaction || oldDelegate.accent != accent;
}

class _AnticipationPainter extends CustomPainter {
  final double progress; final Color accent; final Offset? start; final Offset? end;
  _AnticipationPainter({required this.progress, required this.accent, this.start, this.end});
  @override
  void paint(Canvas canvas, Size size) {
    final center = start ?? Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * (.035 + progress * .045);
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2 * progress..color = accent.withOpacity(.30 * progress);
    canvas.drawCircle(center, r, p);
    final rays = Paint()..strokeCap = StrokeCap.round..strokeWidth = 1.4;
    if (end != null) {
      final line = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.1..color = accent.withOpacity(.12 * progress);
      canvas.drawLine(center, end!, line);
    }
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi * 2 / 10;
      final inner = r * .55;
      final outer = r * (1.6 + progress * .8);
      rays.color = Colors.white.withOpacity(.22 * progress);
      canvas.drawLine(center + Offset(math.cos(a), math.sin(a)) * inner, center + Offset(math.cos(a), math.sin(a)) * outer, rays);
    }
  }
  @override bool shouldRepaint(covariant _AnticipationPainter old) => old.progress != progress || old.accent != accent || old.start != start || old.end != end;
}

class _TrajectoryPainter extends CustomPainter {
  final double progress;
  final Color accent;
  final Offset start;
  final Offset end;
  _TrajectoryPainter({required this.progress, required this.accent, required this.start, required this.end});

  @override
  void paint(Canvas canvas, Size size) {
    final distance = (end - start).distance;
    final lift = math.min(96.0, 46 + distance * .18);
    final mid = Offset((start.dx + end.dx) / 2, math.min(start.dy, end.dy) - lift);
    final path = Path()..moveTo(start.dx, start.dy);
    path.quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = accent.withOpacity(.10 * (1 - progress));
    canvas.drawPath(path, glow);

    final one = 1 - progress;
    final pos = Offset(
      one * one * start.dx + 2 * one * progress * mid.dx + progress * progress * end.dx,
      one * one * start.dy + 2 * one * progress * mid.dy + progress * progress * end.dy,
    );
    final dot = Paint()..color = Colors.white.withOpacity(.26 * (1 - progress));
    canvas.drawCircle(pos, 2.1, dot);
  }

  @override
  bool shouldRepaint(covariant _TrajectoryPainter old) =>
      old.progress != progress || old.start != start || old.end != end || old.accent != accent;
}

class _LandingPainter extends CustomPainter {
  final double progress; final Color accent; final double strength; final Offset? start; final Offset? end;
  _LandingPainter({required this.progress, required this.accent, required this.strength, this.start, this.end});
  @override
  void paint(Canvas canvas, Size size) {
    final center = end ?? Offset(size.width / 2, size.height * .55);
    final maxR = math.min(size.width, size.height) * .23 * strength;
    final rx = maxR * progress;
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = (3.2 * (1-progress)).clamp(0.7, 3.2)..color = accent.withOpacity(.36 * (1-progress));
    canvas.drawOval(Rect.fromCenter(center: center, width: rx * 2, height: rx * .56), p);
    final glow = Paint()
      ..shader = RadialGradient(colors: [Colors.white.withOpacity(.20 * (1-progress)), accent.withOpacity(.10 * (1-progress)), Colors.transparent]).createShader(Rect.fromCircle(center: center, radius: maxR));
    canvas.drawCircle(center, maxR * .55, glow);
  }
  @override bool shouldRepaint(covariant _LandingPainter old) => old.progress != progress || old.accent != accent || old.strength != strength || old.end != end;
}

class _AftershockPainter extends CustomPainter {
  final double progress; final Color accent; final double strength; final Offset? end;
  _AftershockPainter({required this.progress, required this.accent, required this.strength, this.end});
  @override
  void paint(Canvas canvas, Size size) {
    final center = end ?? Offset(size.width / 2, size.height * .48);
    final r = math.min(size.width, size.height) * (.12 + progress * .30) * strength;
    final p = Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = accent.withOpacity(.20 * (1-progress));
    canvas.drawCircle(center, r, p);
    final dots = 12;
    final dot = Paint()..color = accent.withOpacity(.28 * (1-progress));
    for (var i = 0; i < dots; i++) {
      final a = i * math.pi * 2 / dots + progress * .8;
      final d = r * (1.05 + .18 * math.sin(i));
      canvas.drawCircle(center + Offset(math.cos(a), math.sin(a)) * d, 1.7, dot);
    }
  }
  @override bool shouldRepaint(covariant _AftershockPainter old) => old.progress != progress || old.accent != accent || old.strength != strength || old.end != end;
}
