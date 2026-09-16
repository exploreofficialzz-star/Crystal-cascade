import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/gem.dart';
import '../providers/game_provider.dart';

/// Coordinated scene-level feedback. This is deliberately presentation-only:
/// game rules remain inside GameProvider.
class ReactionChoreography extends StatefulWidget {
  final GameReaction reaction;
  final int version;
  final GemColor? color;
  final int combo;
  final bool celebrate;
  final Offset? start;
  final Offset? end;

  const ReactionChoreography({
    required this.reaction,
    required this.version,
    this.color,
    this.combo = 0,
    this.celebrate = false,
    this.start,
    this.end,
    super.key,
  });

  @override
  State<ReactionChoreography> createState() => _ReactionChoreographyState();
}

class _ReactionChoreographyState extends State<ReactionChoreography>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void didUpdateWidget(covariant ReactionChoreography oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.version != oldWidget.version) _controller.forward(from: 0);
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

  bool get _match => widget.reaction == GameReaction.matched ||
      widget.reaction == GameReaction.tubeCompleted;

  @override
  Widget build(BuildContext context) {
    final important = _match || widget.reaction == GameReaction.won || widget.celebrate;
    final statePulse = widget.reaction == GameReaction.invalid || widget.reaction == GameReaction.lowMoves || widget.reaction == GameReaction.lost || widget.reaction == GameReaction.selected;
    if (!important && !statePulse) return const SizedBox.shrink();

    final comboLevel = math.max(0, widget.combo - 1);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          final flash = Curves.easeOut.transform(math.min(1.0, _controller.value * 3.0));
          final fade = (1 - t).clamp(0.0, 1.0);
          final burstPower = widget.celebrate ? 1.35 : 0.8 + math.min(comboLevel, 5) * .08;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (flash < .55)
                Opacity(
                  opacity: (1 - flash / .55) * (widget.celebrate ? .10 : .045),
                  child: const ColoredBox(color: Colors.white),
                ),
              CustomPaint(
                painter: _ReactionPainter(
                  progress: t,
                  center: widget.end,
                  start: widget.start,
                  fade: fade,
                  accent: _accent,
                  burstPower: burstPower,
                  celebrate: widget.celebrate || widget.reaction == GameReaction.won,
                  stateReaction: widget.reaction,
                ),
              ),
              if (_match && comboLevel > 0 && t < .72)
                Align(
                  alignment: const Alignment(0, -.58),
                  child: Opacity(
                    opacity: ((1 - t) * 1.25).clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 1 + math.sin(t * math.pi) * .08,
                      child: Text(
                        widget.combo >= 3 ? 'CRYSTAL CASCADE  ×${widget.combo}' : 'COMBO  ×${widget.combo}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                          shadows: [Shadow(blurRadius: 14, color: Colors.black54)],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReactionPainter extends CustomPainter {
  final double progress;
  final double fade;
  final Offset? center;
  final Color accent;
  final double burstPower;
  final bool celebrate;
  final GameReaction stateReaction;
  final Offset? start;

  _ReactionPainter({
    required this.progress,
    this.center,
    this.start,
    required this.fade,
    required this.accent,
    required this.burstPower,
    required this.celebrate,
    required this.stateReaction,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final eventCenter = center ?? Offset(size.width * .5, size.height * .48);
    final minSide = math.min(size.width, size.height);
    final radius = minSide * .115 * (.15 + progress * 1.65) * burstPower;
    final anticipation = (1.0 - progress / .24).clamp(0.0, 1.0);
    if (start != null && anticipation > 0) {
      final p = start!;
      final ring = Paint()..style=PaintingStyle.stroke..strokeWidth=1.5..color=accent.withOpacity(.20*anticipation);
      canvas.drawCircle(p, minSide*(.035 + anticipation*.025), ring);
    }
    final impactPhase = ((progress - .30) / .22).clamp(0.0, 1.0);
    final completionPhase = ((progress - .52) / .48).clamp(0.0, 1.0);

    // A short-lived core flash makes the reaction read as an energy event
    // before the larger ring and shards travel outward.
    final coreFlash = math.max(0.0, 1.0 - progress * 4.2);
    if (coreFlash > 0) {
      final core = Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withOpacity(.30 * coreFlash),
          accent.withOpacity(.12 * coreFlash),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: eventCenter, radius: minSide * .16));
      canvas.drawCircle(eventCenter, minSide * .16, core);
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 + (1 - progress) * 2.5
      ..color = accent.withOpacity(.30 * fade);
    canvas.drawCircle(eventCenter, radius, ring);

    // Radiating energy spokes.
    final spokePaint = Paint()..strokeCap = StrokeCap.round;
    final spokes = celebrate ? 28 : 16;
    for (var i = 0; i < spokes; i++) {
      final a = math.pi * 2 * i / spokes + progress * .8;
      final inner = radius * (.72 + (i.isEven ? .08 : 0));
      final outer = radius * (1.15 + progress * (celebrate ? 1.45 : .85));
      spokePaint
        ..strokeWidth = (celebrate ? 2.2 : 1.35) * (1 - progress * .35)
        ..color = accent.withOpacity((celebrate ? .36 : .25) * fade * (i.isEven ? 1 : .55));
      canvas.drawLine(
        eventCenter + Offset(math.cos(a), math.sin(a)) * inner,
        eventCenter + Offset(math.cos(a), math.sin(a)) * outer,
        spokePaint,
      );
    }

    // Crystal shards travelling outward, giving matches a cascade feel.
    final shardPaint = Paint()..style = PaintingStyle.fill;
    final shardCount = celebrate ? 30 : 14;
    final shardFade = ((progress - .34) / .66).clamp(0.0, 1.0);
    for (var i = 0; i < shardCount; i++) {
      final seed = i * 17.31;
      final a = seed % (math.pi * 2) + progress * (i.isEven ? .9 : -.65);
      final distance = radius * (.55 + ((i * 37) % 100) / 100 * 1.45);
      final p = eventCenter + Offset(math.cos(a), math.sin(a)) * distance;
      final sizeFactor = 2.0 + ((i * 13) % 7);
      shardPaint.color = accent.withOpacity(.48 * fade * shardFade * (i.isEven ? 1 : .55));
      final path = Path()
        ..moveTo(p.dx, p.dy - sizeFactor * 1.7)
        ..lineTo(p.dx + sizeFactor, p.dy + sizeFactor)
        ..lineTo(p.dx - sizeFactor * .7, p.dy + sizeFactor * .65)
        ..close();
      canvas.drawPath(path, shardPaint);
    }

    // Secondary landing wave arrives later than the initial energy burst.
    if (impactPhase > 0) {
      final landingRadius = minSide * (.045 + impactPhase * .20) * burstPower;
      final landing = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1 - impactPhase)
        ..color = Colors.white.withOpacity(.24 * (1 - impactPhase));
      canvas.drawOval(
        Rect.fromCenter(center: Offset(eventCenter.dx, eventCenter.dy + minSide*.08), width: landingRadius*2.0, height: landingRadius*.58),
        landing,
      );
    }

    if (completionPhase > 0) {
      final inner = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withOpacity(.22 * (1 - completionPhase));
      canvas.drawCircle(eventCenter, minSide * (.10 + completionPhase*.18), inner);
    }

    if (stateReaction == GameReaction.invalid || stateReaction == GameReaction.lowMoves || stateReaction == GameReaction.lost || stateReaction == GameReaction.selected) {
      final stateColor = stateReaction == GameReaction.invalid ? Colors.deepOrangeAccent : stateReaction == GameReaction.lost ? Colors.blueAccent : stateReaction == GameReaction.lowMoves ? Colors.amberAccent : Colors.cyanAccent;
      final stateOpacity = (math.sin(progress * math.pi) * .16).clamp(0.0, .16);
      final statePaint = Paint()..style=PaintingStyle.stroke..strokeWidth=1.4..color=stateColor.withOpacity(stateOpacity);
      canvas.drawCircle(eventCenter, minSide*(.08 + progress*.10), statePaint);
    }

    final glowRadius = radius * (1.7 + math.sin(progress * math.pi) * .8);
    final glow = Paint()
      ..shader = RadialGradient(colors: [
        accent.withOpacity(.13 * fade),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: eventCenter, radius: glowRadius));
    canvas.drawCircle(eventCenter, glowRadius, glow);

    if (celebrate) {
      final halo = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withOpacity(.18 * fade);
      canvas.drawCircle(eventCenter, radius * .62, halo);
    }
  }

  @override
  bool shouldRepaint(covariant _ReactionPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.center != center || oldDelegate.start != start ||
      oldDelegate.fade != fade ||
      oldDelegate.accent != accent ||
      oldDelegate.burstPower != burstPower ||
      oldDelegate.celebrate != celebrate || oldDelegate.stateReaction != stateReaction;
}
