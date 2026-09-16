import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../providers/game_provider.dart';

enum GuardianMood { idle, happy, excited, confused, angry, worried, sad }

class CrystalGuardian extends StatefulWidget {
  final GuardianMood mood;
  final GameReaction reaction;
  final double size;
  final int reactionVersion;
  /// -1..1: where the Guardian should look relative to the board.
  final double lookX;
  const CrystalGuardian({required this.mood, this.reaction = GameReaction.none, this.size = 110, this.reactionVersion = 0, this.lookX = 0, super.key});

  @override
  State<CrystalGuardian> createState() => _CrystalGuardianState();
}

class _CrystalGuardianState extends State<CrystalGuardian>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 1800),
  )..repeat();
  late final AnimationController _reaction = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 620),
  );
  late final AnimationController _gaze = AnimationController(
    vsync: this, duration: const Duration(milliseconds: 260),
  );
  double _fromLookX = 0;
  double _toLookX = 0;

  @override
  void initState() {
    super.initState();
    _fromLookX = widget.lookX;
    _toLookX = widget.lookX;
  }

  @override
  void didUpdateWidget(covariant CrystalGuardian oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reactionVersion != oldWidget.reactionVersion) _reaction.forward(from: 0);
    if (widget.lookX != oldWidget.lookX) {
      _fromLookX = oldWidget.lookX;
      _toLookX = widget.lookX;
      _gaze.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _reaction.dispose();
    _gaze.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _reaction]),
      builder: (context, child) {
        final wave = math.sin(_controller.value * math.pi * 2);
        final reaction = Curves.easeOut.transform(_reaction.value);
        final gazeT = Curves.easeOutCubic.transform(_gaze.value);
        final animatedLookX = _fromLookX + (_toLookX - _fromLookX) * gazeT;
        final excited = widget.mood == GuardianMood.excited || widget.mood == GuardianMood.happy;
        final reactionBounce = math.sin(reaction * math.pi);
        final blinkWave = math.sin((_controller.value * math.pi * 2) * 1.5 - .8);
        final blink = math.max(0.0, blinkWave);
        final gesture = math.sin(reaction * math.pi);
        final gestureOut = gesture * widget.size * .055;
        final gestureUp = gesture * widget.size * .07;
        final eyeEnergy = .5 + .5 * math.sin(_controller.value * math.pi * 4);
        final expressionPulse = widget.mood == GuardianMood.excited ? gesture : 0.0;
        final bob = (excited ? wave * 5 : wave * 2) - reactionBounce * 7;
        final moodTilt = widget.mood == GuardianMood.angry ? .035 : widget.mood == GuardianMood.confused ? .045 : .012;
        final gestureTilt = widget.mood == GuardianMood.happy || widget.mood == GuardianMood.excited ? math.sin(reaction * math.pi) * .035 : 0;
        final reactionTilt = widget.reaction == GameReaction.invalid ? math.sin(reaction * math.pi * 2) * .055 : widget.reaction == GameReaction.lost ? .025 : widget.reaction == GameReaction.won ? -math.sin(reaction * math.pi) * .035 : 0.0;
        final tilt = wave * moodTilt + gestureTilt + reactionTilt;
        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(
            angle: tilt,
            child: CustomPaint(
              size: Size(widget.size, widget.size * 1.2),
              painter: _GuardianPainter(widget.mood, widget.reaction, _controller.value, _reaction.value, animatedLookX, blink, eyeEnergy, expressionPulse, gestureOut, gestureUp),
            ),
          ),
        );
      },
    );
  }
}

class _GuardianPainter extends CustomPainter {
  final GuardianMood mood;
  final GameReaction reaction;
  final double t;
  final double reactionProgress;
  final double lookX;
  final double blink;
  final double eyeEnergy;
  final double expressionPulse;
  final double gestureOut;
  final double gestureUp;
  _GuardianPainter(this.mood, this.reaction, this.t, this.reactionProgress, this.lookX, this.blink, this.eyeEnergy, this.expressionPulse, this.gestureOut, this.gestureUp);

  Color get _accent {
    switch (mood) {
      case GuardianMood.happy:
      case GuardianMood.excited:
        return Colors.cyanAccent;
      case GuardianMood.angry:
        return Colors.deepOrangeAccent;
      case GuardianMood.worried:
        return Colors.amberAccent;
      case GuardianMood.sad:
        return Colors.blueAccent;
      case GuardianMood.confused:
        return Colors.purpleAccent;
      case GuardianMood.idle:
        return Colors.lightBlueAccent;
    }
  }

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height * .48);
    final glow = Paint()
      ..color = _accent.withOpacity(.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(c, s.width * .38, glow);

    // Legs.
    final body = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withOpacity(.75), _accent.withOpacity(.48), Colors.white.withOpacity(.14)],
      ).createShader(Rect.fromCircle(center: c, radius: s.width * .33));
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Colors.white.withOpacity(.48);

    final leftLeg = RRect.fromRectAndRadius(
      Rect.fromLTWH(s.width * .29, s.height * .77, s.width * .13, s.height * .22),
      const Radius.circular(8),
    );
    final rightLeg = RRect.fromRectAndRadius(
      Rect.fromLTWH(s.width * .58, s.height * .77, s.width * .13, s.height * .22),
      const Radius.circular(8),
    );
    canvas.drawRRect(leftLeg, body); canvas.drawRRect(rightLeg, body);
    final gesture = math.sin(reactionProgress * math.pi);
    if (gesture > 0 && (mood == GuardianMood.happy || mood == GuardianMood.excited)) {
      canvas.drawCircle(Offset(s.width*.355, s.height*.98 - gestureUp*.35), s.width*.055, Paint()..color = _accent.withOpacity(.32));
      canvas.drawCircle(Offset(s.width*.645, s.height*.98 - gestureUp*.35), s.width*.055, Paint()..color = _accent.withOpacity(.32));
    }

    // Reaction-specific whole-body choreography: anticipation, recoil, inspection and celebration.
    final rp = reactionProgress;
    final hit = math.sin(rp * math.pi);
    final recoil = math.sin((rp * math.pi).clamp(0.0, math.pi));
    final inspecting = reaction == GameReaction.selected || reaction == GameReaction.moved;
    final invalid = reaction == GameReaction.invalid;
    final low = reaction == GameReaction.lowMoves;
    final lost = reaction == GameReaction.lost;
    final won = reaction == GameReaction.won;
    if (inspecting) {
      canvas.drawLine(Offset(s.width*.30, s.height*.58), Offset(s.width*(.16 + lookX*.035), s.height*(.50 + hit*.04)), armGesturePaint(s));
      canvas.drawLine(Offset(s.width*.70, s.height*.58), Offset(s.width*.84, s.height*(.62 - hit*.03)), armGesturePaint(s));
    }
    if (invalid) {
      canvas.drawCircle(Offset(c.dx, s.height*.62), s.width*(.18 + hit*.08), Paint()..style=PaintingStyle.stroke..strokeWidth=1.2..color=_accent.withOpacity(.20*hit));
    }
    if (low || lost) {
      canvas.drawLine(Offset(s.width*.32, s.height*.59), Offset(s.width*.16, s.height*(.76 + hit*.04)), armGesturePaint(s));
      canvas.drawLine(Offset(s.width*.68, s.height*.59), Offset(s.width*.84, s.height*(.76 + hit*.04)), armGesturePaint(s));
    }
    if (won) {
      final lift = hit * s.height*.06;
      canvas.drawCircle(Offset(s.width*.12, s.height*.30-lift), s.width*.035, Paint()..color=_accent.withOpacity(.7));
      canvas.drawCircle(Offset(s.width*.88, s.height*.30-lift), s.width*.035, Paint()..color=_accent.withOpacity(.7));
    }

    // Arms with mood-dependent pose.
    final arm = Paint()..color = Colors.white.withOpacity(.62)..strokeWidth = s.width * .075..strokeCap = StrokeCap.round;
    final armWave = math.sin(t * math.pi * 2) * s.width * .025;
    if (mood == GuardianMood.excited || mood == GuardianMood.happy) {
      final leftHand = Offset(s.width*.08 - gestureOut, s.height*.34 - gestureUp + armWave);
      final rightHand = Offset(s.width*.92 + gestureOut, s.height*.34 - gestureUp - armWave);
      canvas.drawLine(Offset(s.width*.30, s.height*.58), leftHand, arm);
      canvas.drawLine(Offset(s.width*.70, s.height*.58), rightHand, arm);
      canvas.drawCircle(leftHand, s.width*.035, Paint()..color = _accent.withOpacity(.50 + gesture*.25));
      canvas.drawCircle(rightHand, s.width*.035, Paint()..color = _accent.withOpacity(.50 + gesture*.25));
    } else if (mood == GuardianMood.angry) {
      canvas.drawLine(Offset(s.width*.30, s.height*.58), Offset(s.width*.10, s.height*.70), arm);
      canvas.drawLine(Offset(s.width*.70, s.height*.58), Offset(s.width*.90, s.height*.70), arm);
    } else {
      canvas.drawLine(Offset(s.width*.29, s.height*.58), Offset(s.width*.08, s.height*.67), arm);
      canvas.drawLine(Offset(s.width*.71, s.height*.58), Offset(s.width*.92, s.height*.67), arm);
    }

    // Crystal body.
    final path = Path()
      ..moveTo(c.dx, s.height*.20)
      ..lineTo(s.width*.76, s.height*.42)
      ..lineTo(s.width*.67, s.height*.78)
      ..lineTo(s.width*.33, s.height*.78)
      ..lineTo(s.width*.24, s.height*.42)
      ..close();
    canvas.drawPath(path, body); canvas.drawPath(path, outline);

    // Head / face.
    final head = Path()
      ..moveTo(c.dx, s.height*.04)
      ..lineTo(s.width*.78, s.height*.24)
      ..lineTo(s.width*.69, s.height*.52)
      ..lineTo(s.width*.31, s.height*.52)
      ..lineTo(s.width*.22, s.height*.24)
      ..close();
    canvas.drawPath(head, body); canvas.drawPath(head, outline);

    // Chest core.
    final corePulse = .75 + math.sin(t * math.pi * 2) * .15;
    canvas.drawCircle(Offset(c.dx, s.height*.63), s.width*.075,
      Paint()..color = _accent.withOpacity(corePulse)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    canvas.drawCircle(Offset(c.dx, s.height*.63), s.width*.045, Paint()..color = Colors.white.withOpacity(.8));

    _drawFace(canvas, s);
  }

  Paint armGesturePaint(Size s) => Paint()
    ..color = Colors.white.withOpacity(.72)
    ..strokeWidth = s.width*.065
    ..strokeCap = StrokeCap.round;

  void _drawFace(Canvas canvas, Size s) {
    final eyePaint = Paint()..color = Colors.white.withOpacity(.92 + eyeEnergy * .06);
    final pupil = Paint()..color = const Color(0xFF10152F);
    final left = Offset(s.width*.40, s.height*.31);
    final right = Offset(s.width*.60, s.height*.31);
    final eyeR = s.width*.055;
    final blinkScale = 1.0 - Curves.easeInOut.transform(blink) * .92;
    final eyeRy = eyeR * blinkScale;
    canvas.drawOval(Rect.fromCenter(center: left, width: eyeR*2, height: math.max(1.5, eyeRy*2)), eyePaint);
    canvas.drawOval(Rect.fromCenter(center: right, width: eyeR*2, height: math.max(1.5, eyeRy*2)), eyePaint);

    double pupilY = 0;
    if (mood == GuardianMood.worried) pupilY = s.height*.008;
    if (mood == GuardianMood.sad) pupilY = s.height*.012;
    final gaze = lookX.clamp(-1.0, 1.0) * s.width * .035;
    final pupilScale = mood == GuardianMood.excited ? 1.0 : .88;
    if (blinkScale > .12) {
      canvas.drawCircle(left + Offset(gaze, pupilY), eyeR*.55*pupilScale, pupil);
      canvas.drawCircle(right + Offset(gaze, pupilY), eyeR*.55*pupilScale, pupil);
    }

    final brow = Paint()..color = const Color(0xFF17203B)..strokeWidth = s.width*.035..strokeCap = StrokeCap.round;
    if (mood == GuardianMood.angry) {
      canvas.drawLine(Offset(s.width*.34,s.height*.25), Offset(s.width*.45,s.height*.27), brow);
      canvas.drawLine(Offset(s.width*.55,s.height*.27), Offset(s.width*.66,s.height*.25), brow);
    } else if (mood == GuardianMood.worried || mood == GuardianMood.sad) {
      canvas.drawLine(Offset(s.width*.34,s.height*.27), Offset(s.width*.45,s.height*.25), brow);
      canvas.drawLine(Offset(s.width*.55,s.height*.25), Offset(s.width*.66,s.height*.27), brow);
    } else if (mood == GuardianMood.confused) {
      canvas.drawLine(Offset(s.width*.34,s.height*.265), Offset(s.width*.45,s.height*.25), brow);
      canvas.drawLine(Offset(s.width*.55,s.height*.25), Offset(s.width*.66,s.height*.275), brow);
    }

    if (mood == GuardianMood.happy || mood == GuardianMood.excited) {
      final cheek = Paint()..color = Colors.pinkAccent.withOpacity(.10 + expressionPulse * .10);
      canvas.drawCircle(Offset(s.width*.34, s.height*.40), s.width*.035, cheek);
      canvas.drawCircle(Offset(s.width*.66, s.height*.40), s.width*.035, cheek);
    }

    final mouth = Paint()..color = const Color(0xFF1A2342)..style = PaintingStyle.stroke..strokeWidth = s.width*.035..strokeCap = StrokeCap.round;
    final path = Path();
    if (mood == GuardianMood.happy || mood == GuardianMood.excited) {
      path.moveTo(s.width*.39,s.height*.39); path.quadraticBezierTo(s.width*.50,s.height*(mood == GuardianMood.excited ? .50 : .47),s.width*.61,s.height*.39);
      if (mood == GuardianMood.excited) {
        canvas.drawOval(Rect.fromCenter(center: Offset(s.width*.50,s.height*.415), width: s.width*.13, height: s.height*.08), Paint()..color = const Color(0xFF11182F));
      }
    } else if (mood == GuardianMood.sad || mood == GuardianMood.worried) {
      path.moveTo(s.width*.40,s.height*.45); path.quadraticBezierTo(s.width*.50,s.height*.38,s.width*.60,s.height*.45);
    } else if (mood == GuardianMood.angry) {
      path.moveTo(s.width*.41,s.height*.43); path.lineTo(s.width*.59,s.height*.43);
    } else if (mood == GuardianMood.confused) {
      path.moveTo(s.width*.43,s.height*.42); path.quadraticBezierTo(s.width*.50,s.height*.46,s.width*.57,s.height*.41);
    } else {
      path.moveTo(s.width*.43,s.height*.41); path.quadraticBezierTo(s.width*.50,s.height*.44,s.width*.57,s.height*.41);
    }
    canvas.drawPath(path, mouth);
  }

  @override
  bool shouldRepaint(covariant _GuardianPainter oldDelegate) => oldDelegate.t != t || oldDelegate.mood != mood || oldDelegate.reaction != reaction || oldDelegate.lookX != lookX || oldDelegate.blink != blink || oldDelegate.eyeEnergy != eyeEnergy || oldDelegate.expressionPulse != expressionPulse || oldDelegate.gestureOut != gestureOut || oldDelegate.gestureUp != gestureUp || oldDelegate.reactionProgress != reactionProgress;
}
