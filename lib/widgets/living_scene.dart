import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../providers/game_provider.dart';
import 'living_background.dart';

/// Presentation stage shared by the board, Guardian and environmental effects.
/// It adds a restrained camera impulse to important gameplay events.
class LivingScene extends StatefulWidget {
  final Widget child;
  final double intensity;
  final int reactionVersion;
  final GameReaction reaction;
  final bool celebrate;
  final Offset? focusStart;
  final Offset? focusEnd;

  const LivingScene({
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
  State<LivingScene> createState() => _LivingSceneState();
}

class _LivingSceneState extends State<LivingScene>
    with TickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);
  late final AnimationController _reaction = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  );

  @override
  void didUpdateWidget(covariant LivingScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reactionVersion != oldWidget.reactionVersion) {
      _reaction.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    _reaction.dispose();
    super.dispose();
  }

  double get _kickStrength {
    switch (widget.reaction) {
      case GameReaction.matched:
      case GameReaction.tubeCompleted:
        return 1.0;
      case GameReaction.won:
        return 1.35;
      case GameReaction.invalid:
        return .55;
      case GameReaction.lowMoves:
      case GameReaction.lost:
        return .7;
      default:
        return .35;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LivingBackground(
      intensity: widget.intensity,
      reactionVersion: widget.reactionVersion,
      reaction: widget.reaction,
      celebrate: widget.celebrate,
      focusStart: widget.focusStart,
      focusEnd: widget.focusEnd,
      child: AnimatedBuilder(
        animation: Listenable.merge([_ambient, _reaction]),
        builder: (context, child) {
          final ambient = (_ambient.value - .5) * 2;
          final r = Curves.easeOutCubic.transform(_reaction.value);
          final decay = 1 - r;
          final strength = widget.intensity * _kickStrength;
          final focus = widget.focusEnd ?? widget.focusStart;
          final fx = focus == null ? 0.0 : ((focus.dx / 360.0) - .5).clamp(-.5, .5);
          final fy = focus == null ? 0.0 : ((focus.dy / 520.0) - .5).clamp(-.5, .5);
          final impulse = math.sin(r * math.pi) * strength;
          final lateral = math.sin(r * math.pi * 1.7) * 3.2 * strength;
          final scale = 1.0 + impulse * .006;
          final rotateX = -.014 * ambient * widget.intensity + impulse * .010;
          final rotateY = .010 * ambient * widget.intensity + lateral * .0008;
          final rotateZ = math.sin(r * math.pi * 2.0) * .004 * strength;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0018)
              ..translate(lateral * decay - fx * impulse * 7.0, -ambient * 1.4 - impulse * 2.8 - fy * impulse * 4.0, 0.0)
              ..scale(scale, scale, 1.0)
              ..rotateX(rotateX)
              ..rotateY(rotateY)
              ..rotateZ(rotateZ),
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
