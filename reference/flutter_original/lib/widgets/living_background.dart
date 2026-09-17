import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../providers/game_provider.dart';

/// A lightweight animated crystal environment. The painter deliberately uses
/// Flutter primitives so the scene can feel deep and alive on mobile without
/// requiring a full real-time 3D engine.
class LivingBackground extends StatefulWidget {
  final Widget child;
  final double intensity;
  final int reactionVersion;
  final GameReaction reaction;
  final bool celebrate;
  final Offset? focusStart;
  final Offset? focusEnd;

  const LivingBackground({
    required this.child,
    this.intensity = .35,
    this.reactionVersion = 0,
    this.reaction = GameReaction.none,
    this.celebrate = false,
    this.focusStart,
    this.focusEnd,
    super.key,
  });

  @override
  State<LivingBackground> createState() => _LivingBackgroundState();
}

class _LivingBackgroundState extends State<LivingBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  )..repeat();
  late final AnimationController _reactionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void didUpdateWidget(covariant LivingBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reactionVersion != oldWidget.reactionVersion) {
      _reactionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _reactionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _reactionController]),
      builder: (context, child) => CustomPaint(
        painter: _CrystalWorldPainter(
          _controller.value,
          widget.intensity,
          _reactionController.value,
          widget.reaction,
          widget.celebrate,
          widget.focusStart,
          widget.focusEnd,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _CrystalWorldPainter extends CustomPainter {
  final double t;
  final double intensity;
  final double reaction;
  final GameReaction gameReaction;
  final bool celebrate;
  final Offset? focusStart;
  final Offset? focusEnd;

  _CrystalWorldPainter(this.t, this.intensity, this.reaction, this.gameReaction, this.celebrate, this.focusStart, this.focusEnd);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF060816), Color(0xFF0D1735), Color(0xFF102A4D), Color(0xFF351A55)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final pulse = math.sin(reaction * math.pi) * intensity;
    final reactionColor = gameReaction == GameReaction.won || gameReaction == GameReaction.tubeCompleted
        ? Colors.amberAccent
        : gameReaction == GameReaction.matched
            ? Colors.cyanAccent
            : gameReaction == GameReaction.lost
                ? Colors.blueAccent
                : Colors.white;
    final ambient = .06 + pulse * .08 + (celebrate ? .06 : 0);

    // Three depth planes: distant silhouettes, mid-world shards, and a soft
    // foreground veil. Their different drift speeds sell the elevated camera
    // without adding a 3D engine.
    _drawDepthCrystals(canvas, size, t, intensity, 0.35, .07, 9);
    _drawDepthCrystals(canvas, size, t, intensity, 0.85, .10, 6);

    // Atmospheric orbs.
    for (var i = 0; i < 6; i++) {
      final x = size.width * (0.08 + i * 0.18) +
          math.sin(t * math.pi * 2 + i) * (18 + intensity * 12);
      final y = size.height * (0.16 + (i % 4) * 0.23) +
          math.cos(t * math.pi * 2 + i) * 14;
      final r = size.width * (0.10 + (i % 2) * 0.035);
      final p = Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withOpacity(ambient),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: Offset(x, y), radius: r));
      canvas.drawCircle(Offset(x, y), r, p);
    }

    // Distant monoliths create the first depth layer.
    final crystals = <Offset>[
      Offset(size.width * .08, size.height * .24),
      Offset(size.width * .91, size.height * .20),
      Offset(size.width * .16, size.height * .78),
      Offset(size.width * .84, size.height * .76),
    ];
    for (var i = 0; i < crystals.length; i++) {
      final drift = math.sin(t * math.pi * 2 + i * 1.8) * (6 + intensity * 5);
      final scale = i < 2 ? .19 : .15;
      _drawCrystal(canvas, crystals[i] + Offset(drift, 0), size.width * scale, i, pulse);
    }

    // Floating motes.
    final motePaint = Paint();
    for (var i = 0; i < 42; i++) {
      final x = ((i * 73.0) % size.width + t * (10 + i % 6) * 5) % size.width;
      final y = ((i * 41.0) % size.height + math.sin(t * math.pi * 2 + i) * 12) % size.height;
      final radius = .7 + (i % 3) * .55 + pulse.abs() * .7;
      motePaint.color = Colors.white.withOpacity(.10 + (i % 4) * .022 + pulse.abs() * .08);
      canvas.drawCircle(Offset(x, y), radius, motePaint);
    }

    // Slow diagonal energy beam.
    final beam = Paint()
      ..shader = LinearGradient(colors: [
        Colors.transparent,
        reactionColor.withOpacity(.025 + pulse.abs() * .07),
        Colors.transparent,
      ]).createShader(Rect.fromLTWH(-size.width, 0, size.width * 3, size.height));
    final dx = (t * size.width * 1.5) - size.width;
    canvas.save();
    canvas.translate(dx, 0);
    canvas.rotate(-0.18);
    canvas.drawRect(Rect.fromLTWH(0, size.height * .08, size.width * .8, size.height * .9), beam);
    canvas.restore();

    // Foreground glints pass slowly across the scene, like dust catching
    // crystal light. Keep these sparse so the puzzle remains readable.
    for (var i = 0; i < 10; i++) {
      final x = ((i * 117.0 + t * size.width * (0.18 + i * .012)) % (size.width + 40)) - 20;
      final y = size.height * (.10 + (i * .083) % .78) + math.sin(t * math.pi * 2 + i) * 9;
      final r = 1.0 + (i % 2) * .7;
      final p = Paint()..color = Colors.white.withOpacity(.08 + ambient * .35);
      canvas.drawCircle(Offset(x, y), r, p);
    }

    // Localized crystal light follows the active move instead of always
    // flashing at screen center. This makes the board feel spatial.
    final focus = focusEnd ?? focusStart;
    if (focus != null && reaction > 0 && reaction < 1) {
      final local = Curves.easeOut.transform(math.sin(reaction * math.pi));
      final localRadius = size.width * (.10 + local * .34);
      final localGlow = Paint()
        ..shader = RadialGradient(colors: [
          reactionColor.withOpacity(.18 * local),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: focus, radius: localRadius));
      canvas.drawCircle(focus, localRadius, localGlow);
      for (var i = 0; i < 5; i++) {
        final a = t * math.pi * 2 + i * 1.25;
        final p = focus + Offset(math.cos(a), math.sin(a)) * (12 + local * 28);
        canvas.drawCircle(p, 1.1 + local * 1.5, Paint()..color = reactionColor.withOpacity(.20 * local));
      }
    }

    // Soft mist bands provide atmospheric depth without a heavy blur layer.
    final mist = Paint()..color = Colors.white.withOpacity(.018 + intensity * .012);
    for (var i = 0; i < 3; i++) {
      final y = size.height * (.20 + i * .29) + math.sin(t * math.pi * 2 + i) * 10;
      canvas.drawOval(Rect.fromCenter(center: Offset(size.width*.5, y), width: size.width*(.72 + i*.08), height: size.height*.075), mist);
    }

    // Short-lived world pulse during a reaction.
    if (reaction > 0 && reaction < 1) {
      final wave = Curves.easeOut.transform(reaction);
      final ringPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = reactionColor.withOpacity((1 - wave) * .15 * intensity);
      canvas.drawCircle(Offset(size.width * .5, size.height * .52), size.width * (.15 + wave * .7), ringPaint);
    }
  }

  void _drawDepthCrystals(Canvas canvas, Size size, double time, double intensity, double speed, double opacity, int count) {
    for (var i = 0; i < count; i++) {
      final x = size.width * ((i + 1) / (count + 1)) + math.sin(time * math.pi * 2 * speed + i) * (8 + intensity * 12);
      final y = size.height * (.18 + (i % 5) * .16) + math.cos(time * math.pi * 2 * speed + i) * 10;
      final h = size.height * (.11 + (i % 3) * .025);
      final w = h * (.28 + (i % 2) * .08);
      final path = Path()
        ..moveTo(x, y - h)
        ..lineTo(x + w, y - h * .18)
        ..lineTo(x + w * .62, y + h)
        ..lineTo(x - w * .62, y + h)
        ..lineTo(x - w, y - h * .18)
        ..close();
      final p = Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.white.withOpacity(opacity), const Color(0xFF8A74FF).withOpacity(opacity * .8), Colors.cyanAccent.withOpacity(opacity * .28)],
      ).createShader(Rect.fromLTWH(x-w, y-h, w*2, h*2));
      canvas.drawPath(path, p);
      canvas.drawPath(path, Paint()..style=PaintingStyle.stroke..strokeWidth=1..color=Colors.white.withOpacity(opacity*.75));
    }
  }

  void _drawCrystal(Canvas canvas, Offset center, double h, int seed, double pulse) {
    final w = h * .42;
    final path = Path()
      ..moveTo(center.dx, center.dy - h / 2)
      ..lineTo(center.dx + w / 2, center.dy - h * .18)
      ..lineTo(center.dx + w * .32, center.dy + h / 2)
      ..lineTo(center.dx - w * .32, center.dy + h / 2)
      ..lineTo(center.dx - w / 2, center.dy - h * .18)
      ..close();
    final p = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(.055 + pulse.abs() * .06),
          const Color(0xFF9B7CFF).withOpacity(.07 + seed * .009),
          Colors.cyanAccent.withOpacity(.025 + pulse.abs() * .03),
        ],
      ).createShader(Rect.fromCenter(center: center, width: w, height: h));
    canvas.drawPath(path, p);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(.075 + pulse.abs() * .05);
    canvas.drawPath(path, edge);
  }

  @override
  bool shouldRepaint(covariant _CrystalWorldPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.intensity != intensity ||
      oldDelegate.reaction != reaction ||
      oldDelegate.gameReaction != gameReaction ||
      oldDelegate.celebrate != celebrate || oldDelegate.focusStart != focusStart || oldDelegate.focusEnd != focusEnd;
}
