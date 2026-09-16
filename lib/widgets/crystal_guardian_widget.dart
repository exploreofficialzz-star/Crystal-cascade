import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/character_reaction_manager.dart';

/// Crystal Guardian — the expressive 2.5D character companion.
/// Drawn entirely with [CustomPainter]; no external assets required.
class CrystalGuardianWidget extends StatefulWidget {
  const CrystalGuardianWidget({super.key});

  @override
  State<CrystalGuardianWidget> createState() => _CrystalGuardianWidgetState();
}

class _CrystalGuardianWidgetState extends State<CrystalGuardianWidget>
    with TickerProviderStateMixin {
  late AnimationController _bobCtrl;
  late AnimationController _blinkCtrl;
  late AnimationController _reactionCtrl;
  late AnimationController _celebrateCtrl;

  GuardianMood _prevMood        = GuardianMood.neutral;
  bool         _prevBlinkTrigger = false;

  @override
  void initState() {
    super.initState();

    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );

    _reactionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _celebrateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _bobCtrl.dispose();
    _blinkCtrl.dispose();
    _reactionCtrl.dispose();
    _celebrateCtrl.dispose();
    super.dispose();
  }

  void _onMoodChanged(GuardianMood mood) {
    if (mood == GuardianMood.celebrating) {
      _celebrateCtrl.repeat(reverse: true);
    } else {
      _celebrateCtrl.stop();
      _celebrateCtrl.reset();
    }
    _reactionCtrl.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<CharacterReactionManager>();

    // Trigger animations on changes (post-frame to avoid build-phase mutation).
    if (manager.mood != _prevMood) {
      _prevMood = manager.mood;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onMoodChanged(manager.mood);
      });
    }
    if (manager.blinkTrigger != _prevBlinkTrigger) {
      _prevBlinkTrigger = manager.blinkTrigger;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _blinkCtrl.forward(from: 0.0);
      });
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        _bobCtrl,
        _blinkCtrl,
        _reactionCtrl,
        _celebrateCtrl,
      ]),
      builder: (context, _) {
        return CustomPaint(
          painter: _GuardianPainter(
            bobValue:      CurvedAnimation(parent: _bobCtrl,      curve: Curves.easeInOut).value,
            blinkValue:    TweenSequence<double>([
                             TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 1),
                             TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 1),
                           ]).evaluate(CurvedAnimation(parent: _blinkCtrl, curve: Curves.easeInOut)),
            reactionValue: _reactionCtrl.value,
            celebValue:    _celebrateCtrl.value,
            mood:          manager.mood,
            excitement:    manager.excitement,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painter
// ─────────────────────────────────────────────────────────────────────────────

class _GuardianPainter extends CustomPainter {
  final double       bobValue;
  final double       blinkValue;
  final double       reactionValue;
  final double       celebValue;
  final GuardianMood mood;
  final double       excitement;

  const _GuardianPainter({
    required this.bobValue,
    required this.blinkValue,
    required this.reactionValue,
    required this.celebValue,
    required this.mood,
    required this.excitement,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w  = size.width;
    final h  = size.height;
    final cx = w / 2;

    final bobY   = (bobValue - 0.5) * 10.0;
    double shakeX = 0.0;
    if (mood == GuardianMood.frustrated) {
      shakeX = sin(reactionValue * pi * 7) * reactionValue * 5.5;
    }
    final scaleBonus = mood == GuardianMood.celebrating ? 1.0 + celebValue * 0.07 : 1.0;

    canvas.save();
    canvas.translate(cx + shakeX, 0);
    canvas.scale(scaleBonus, scaleBonus);
    canvas.translate(-cx, 0);
    canvas.translate(0, bobY);

    _drawCrown(canvas, cx, h * 0.09, w, h);
    _drawHead(canvas, cx, h * 0.28, w, h);
    _drawEyes(canvas, cx, h * 0.265, w, h);
    _drawMouth(canvas, cx, h * 0.345, w);
    _drawBody(canvas, cx, h * 0.585, w, h);
    _drawChestCrystal(canvas, cx, h * 0.555, w * 0.115);
    _drawArms(canvas, cx, h * 0.53, w, h);
    _drawLegs(canvas, cx, h * 0.78, w, h);
    if (mood == GuardianMood.celebrating && celebValue > 0.05) {
      _drawSparkles(canvas, size, celebValue);
    }

    canvas.restore();
  }

  // ── Crown ──────────────────────────────────────────────────────────────
  void _drawCrown(Canvas canvas, double cx, double baseY, double w, double h) {
    const colors = [Color(0xFFE040FB), Color(0xFF40C4FF), Color(0xFF69F0AE)];
    final xs     = [cx - w * 0.155, cx, cx + w * 0.155];
    final heights = [h * 0.095, h * 0.125, h * 0.095];

    for (int i = 0; i < 3; i++) {
      final x  = xs[i];
      final ch = heights[i];
      final path = Path()
        ..moveTo(x, baseY - ch)
        ..lineTo(x - w * 0.055, baseY)
        ..lineTo(x + w * 0.055, baseY)
        ..close();

      final r = Rect.fromLTWH(x - w * 0.055, baseY - ch, w * 0.11, ch + 2);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors[i].withOpacity(0.95), colors[i].withOpacity(0.35)],
          ).createShader(r),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withOpacity(0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9,
      );
    }
  }

  // ── Head ───────────────────────────────────────────────────────────────
  void _drawHead(Canvas canvas, double cx, double cy, double w, double h) {
    final hw = w * 0.295;
    final hh = h * 0.155;
    final r  = Rect.fromCenter(center: Offset(cx, cy), width: hw * 2, height: hh * 2);

    final path = Path()
      ..moveTo(cx, cy - hh)
      ..lineTo(cx + hw - hw * 0.14, cy - hh + hh * 0.18)
      ..lineTo(cx + hw, cy)
      ..lineTo(cx + hw - hw * 0.10, cy + hh)
      ..lineTo(cx - hw + hw * 0.10, cy + hh)
      ..lineTo(cx - hw, cy)
      ..lineTo(cx - hw + hw * 0.14, cy - hh + hh * 0.18)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [const Color(0xFF8CBCE8), const Color(0xFF4A7EC0)],
        ).createShader(r),
    );
    // Glass highlight strip
    canvas.drawPath(
      Path()
        ..moveTo(cx - hw + hw * 0.15, cy - hh + hh * 0.12)
        ..lineTo(cx - hw + hw * 0.30, cy - hh + hh * 0.12)
        ..lineTo(cx - hw + hw * 0.24, cy + hh * 0.05)
        ..lineTo(cx - hw + hw * 0.11, cy - hh * 0.05)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withOpacity(0.33), Colors.white.withOpacity(0.0)],
        ).createShader(r),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
  }

  // ── Eyes ───────────────────────────────────────────────────────────────
  void _drawEyes(Canvas canvas, double cx, double ey, double w, double h) {
    final er  = w * 0.10;
    final lx  = cx - w * 0.135;
    final rx  = cx + w * 0.135;

    // Blink by vertically squishing
    canvas.save();
    if (blinkValue < 1.0) {
      canvas.translate(0, ey);
      canvas.scale(1.0, blinkValue < 0 ? 0 : blinkValue);
      canvas.translate(0, -ey);
    }

    // Whites
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(lx, ey), er, whitePaint);
    canvas.drawCircle(Offset(rx, ey), er, whitePaint);

    // Pupils – shift slightly toward board when watching
    final px = mood == GuardianMood.watching ? w * 0.03 : 0.0;
    final pr = er * 0.55;
    final pupilPaint = Paint()..color = const Color(0xFF1565C0);
    canvas.drawCircle(Offset(lx + px, ey + 1), pr, pupilPaint);
    canvas.drawCircle(Offset(rx + px, ey + 1), pr, pupilPaint);

    // Specular dot
    final specPaint = Paint()..color = Colors.white.withOpacity(0.9);
    canvas.drawCircle(Offset(lx + px - pr * 0.32, ey - pr * 0.32 + 1), er * 0.22, specPaint);
    canvas.drawCircle(Offset(rx + px - pr * 0.32, ey - pr * 0.32 + 1), er * 0.22, specPaint);

    // Excited glow ring
    if (mood == GuardianMood.excited || mood == GuardianMood.celebrating) {
      final glowP = Paint()
        ..color = Colors.cyanAccent.withOpacity(0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;
      canvas.drawCircle(Offset(lx, ey), er + 2.5, glowP);
      canvas.drawCircle(Offset(rx, ey), er + 2.5, glowP);
    }

    // Frustrated brows
    if (mood == GuardianMood.frustrated) {
      final browP = Paint()
        ..color = const Color(0xFF1A1A2E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(lx - er, ey - er - 1.5),
        Offset(lx + er * 0.5, ey - er * 0.45 - 3.5),
        browP,
      );
      canvas.drawLine(
        Offset(rx - er * 0.5, ey - er * 0.45 - 3.5),
        Offset(rx + er, ey - er - 1.5),
        browP,
      );
    }

    canvas.restore();
  }

  // ── Mouth ──────────────────────────────────────────────────────────────
  void _drawMouth(Canvas canvas, double cx, double my, double w) {
    final mw = w * 0.155;
    final p  = Paint()
      ..color = const Color(0xFF1A1A2E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    switch (mood) {
      case GuardianMood.happy:
        path
          ..moveTo(cx - mw, my)
          ..quadraticBezierTo(cx, my + mw * 0.65, cx + mw, my);
        break;
      case GuardianMood.excited:
      case GuardianMood.celebrating:
        path
          ..moveTo(cx - mw * 1.1, my)
          ..quadraticBezierTo(cx, my + mw * 0.9, cx + mw * 1.1, my);
        break;
      case GuardianMood.sad:
        path
          ..moveTo(cx - mw * 0.85, my + mw * 0.35)
          ..quadraticBezierTo(cx, my - mw * 0.25, cx + mw * 0.85, my + mw * 0.35);
        break;
      case GuardianMood.frustrated:
        path
          ..moveTo(cx - mw * 0.75, my + mw * 0.30)
          ..quadraticBezierTo(cx, my - mw * 0.25, cx + mw * 0.75, my + mw * 0.30);
        break;
      case GuardianMood.nervous:
        path
          ..moveTo(cx - mw, my)
          ..cubicTo(cx - mw * 0.5, my + mw * 0.45, cx + mw * 0.5, my - mw * 0.12, cx + mw, my + mw * 0.22);
        break;
      default:
        path
          ..moveTo(cx - mw * 0.8, my)
          ..quadraticBezierTo(cx, my + mw * 0.22, cx + mw * 0.8, my);
    }
    canvas.drawPath(path, p);
  }

  // ── Body ───────────────────────────────────────────────────────────────
  void _drawBody(Canvas canvas, double cx, double cy, double w, double h) {
    final bw = w * 0.32;
    final bh = h * 0.195;
    final r  = Rect.fromCenter(center: Offset(cx, cy), width: bw * 2, height: bh * 2);

    final path = Path()
      ..moveTo(cx, cy - bh)
      ..lineTo(cx + bw - bw * 0.10, cy - bh + bh * 0.18)
      ..lineTo(cx + bw, cy + bh * 0.65)
      ..lineTo(cx + bw - bw * 0.16, cy + bh)
      ..lineTo(cx - bw + bw * 0.16, cy + bh)
      ..lineTo(cx - bw, cy + bh * 0.65)
      ..lineTo(cx - bw + bw * 0.10, cy - bh + bh * 0.18)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [const Color(0xFF5B7FC1), const Color(0xFF2C4A8A)],
        ).createShader(r),
    );
    // Glass shine
    canvas.drawPath(
      Path()
        ..moveTo(cx - bw + bw * 0.13, cy - bh + bh * 0.13)
        ..lineTo(cx - bw + bw * 0.29, cy - bh + bh * 0.13)
        ..lineTo(cx - bw + bw * 0.23, cy + bh * 0.50)
        ..lineTo(cx - bw + bw * 0.09, cy + bh * 0.40)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withOpacity(0.30), Colors.white.withOpacity(0.0)],
        ).createShader(r),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  // ── Chest Crystal ──────────────────────────────────────────────────────
  void _drawChestCrystal(Canvas canvas, double cx, double cy, double s) {
    final glowR = s * (1.9 + excitement * 1.3);
    canvas.drawCircle(
      Offset(cx, cy),
      glowR,
      Paint()
        ..color = Color.lerp(
          const Color(0xFFFFE082).withOpacity(0.18),
          Colors.white.withOpacity(0.38),
          excitement,
        )!
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    final dPath = Path()
      ..moveTo(cx, cy - s)
      ..lineTo(cx + s * 0.72, cy)
      ..lineTo(cx, cy + s)
      ..lineTo(cx - s * 0.72, cy)
      ..close();
    canvas.drawPath(
      dPath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(const Color(0xFFFFE082), Colors.white, excitement)!,
            const Color(0xFFFF9800).withOpacity(0.55),
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: s)),
    );
    // Facet line
    canvas.drawPath(
      Path()
        ..moveTo(cx - s * 0.72, cy)
        ..lineTo(cx, cy - s * 0.22)
        ..lineTo(cx + s * 0.72, cy),
      Paint()
        ..color = Colors.white.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.85,
    );
  }

  // ── Arms ───────────────────────────────────────────────────────────────
  void _drawArms(Canvas canvas, double cx, double ay, double w, double h) {
    final armW = w * 0.13;
    final armH = h * 0.16;
    final lift  = mood == GuardianMood.celebrating ? reactionValue * h * 0.09 : 0.0;

    for (final side in [-1, 1]) {
      final ax       = cx + side * (w * 0.32 + armW * 0.5);
      final rotation = side * (0.28 - lift / (h * 0.09 + 0.001) * 0.65);

      canvas.save();
      canvas.translate(ax, ay - lift);
      canvas.rotate(rotation);
      canvas.translate(-ax, -(ay - lift));

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(ax, ay - lift), width: armW, height: armH),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
            colors: [const Color(0xFF7090C8), const Color(0xFF3A5A96)],
          ).createShader(rect.outerRect),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..color = Colors.white.withOpacity(0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      canvas.restore();
    }
  }

  // ── Legs ───────────────────────────────────────────────────────────────
  void _drawLegs(Canvas canvas, double cx, double ly, double w, double h) {
    for (final side in [-1, 1]) {
      final lx   = cx + side * w * 0.12;
      final lw2  = w * 0.07;
      final lh2  = h * 0.11;
      final path = Path()
        ..moveTo(lx - lw2, ly)
        ..lineTo(lx + lw2, ly)
        ..lineTo(lx + lw2 * 0.75, ly + lh2)
        ..lineTo(lx - lw2 * 0.75, ly + lh2)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFF3A5A96));
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withOpacity(0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
  }

  // ── Celebration sparkles ───────────────────────────────────────────────
  void _drawSparkles(Canvas canvas, Size size, double t) {
    final rng     = Random(42);
    const count   = 8;
    final cx      = size.width  / 2;
    final cy      = size.height * 0.40;

    for (int i = 0; i < count; i++) {
      final angle  = (i / count) * 2 * pi + t * pi;
      final dist   = 28 + rng.nextDouble() * 22;
      final sx     = cx + cos(angle) * dist;
      final sy     = cy + sin(angle) * dist * 0.65;
      final fade   = (sin(t * pi)).clamp(0.0, 1.0);
      final sz     = fade * 4.0;
      if (sz < 0.3) continue;

      final starPath = Path();
      for (int j = 0; j < 4; j++) {
        final a = j * pi / 2 + t * pi * 0.5;
        final r = j % 2 == 0 ? sz : sz * 0.28;
        if (j == 0) {
          starPath.moveTo(sx + cos(a) * r, sy + sin(a) * r);
        } else {
          starPath.lineTo(sx + cos(a) * r, sy + sin(a) * r);
        }
      }
      starPath.close();

      canvas.drawPath(
        starPath,
        Paint()..color = Colors.white.withOpacity(0.85 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_GuardianPainter old) =>
      old.bobValue      != bobValue      ||
      old.blinkValue    != blinkValue    ||
      old.reactionValue != reactionValue ||
      old.celebValue    != celebValue    ||
      old.mood          != mood          ||
      old.excitement    != excitement;
}
