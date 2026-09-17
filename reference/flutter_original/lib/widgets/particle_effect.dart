import 'package:flutter/material.dart';
import 'dart:math';

class ParticleEffect extends StatefulWidget {
  final Color color;
  final int particleCount;
  final double size;

  const ParticleEffect({
    this.color = Colors.white,
    this.particleCount = 20,
    this.size = 100,
    super.key,
  });

  @override
  State<ParticleEffect> createState() => _ParticleEffectState();
}

class _ParticleEffectState extends State<ParticleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _particles = List.generate(
      widget.particleCount,
      (index) => Particle(
        angle: (index / widget.particleCount) * 2 * pi,
        speed: Random().nextDouble() * 100 + 50,
        size: Random().nextDouble() * 8 + 4,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: _particles.map((particle) {
              final progress = _controller.value;
              final x = cos(particle.angle) * particle.speed * progress;
              final y = sin(particle.angle) * particle.speed * progress;
              final opacity = 1.0 - progress;

              return Positioned(
                left: widget.size / 2 + x - particle.size / 2,
                top: widget.size / 2 + y - particle.size / 2,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: particle.size,
                    height: particle.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withOpacity(0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class Particle {
  final double angle;
  final double speed;
  final double size;

  Particle({
    required this.angle,
    required this.speed,
    required this.size,
  });
}
