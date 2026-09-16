import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/environment_reaction_manager.dart';

/// 7-layer parallax living background.
/// Layers: base gradient → far crystals → light rays → ambient particles →
///         foreground mist → bloom overlay.
class LivingBackgroundWidget extends StatefulWidget {
  const LivingBackgroundWidget({super.key});

  @override
  State<LivingBackgroundWidget> createState() => _LivingBackgroundWidgetState();
}

class _LivingBackgroundWidgetState extends State<LivingBackgroundWidget>
    with TickerProviderStateMixin {
  late AnimationController _crystalCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _rayCtrl;
  late AnimationController _fogCtrl;

  @override
  void initState() {
    super.initState();
    _crystalCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat(reverse: true);
    _particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();
    _rayCtrl      = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat(reverse: true);
    _fogCtrl      = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _crystalCtrl.dispose();
    _particleCtrl.dispose();
    _rayCtrl.dispose();
    _fogCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final env = context.watch<EnvironmentReactionManager>();

    return AnimatedBuilder(
      animation: Listenable.merge([_crystalCtrl, _particleCtrl, _rayCtrl, _fogCtrl]),
      builder: (context, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            // Layer 0 – Base gradient (reacts to light intensity)
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end:   Alignment.bottomRight,
                  colors: [
                    const Color(0xFF0C0C28),
                    Color.lerp(const Color(0xFF12112E), const Color(0xFF22115A), env.lightIntensity * 0.55)!,
                    Color.lerp(const Color(0xFF1A0A3A), const Color(0xFF3E1870), env.lightIntensity * 0.45)!,
                  ],
                ),
              ),
            ),

            // Layer 1 – Far background crystals
            RepaintBoundary(
              child: CustomPaint(
                painter: _BackgroundCrystalsPainter(
                  t:         _crystalCtrl.value,
                  intensity: env.lightIntensity,
                ),
              ),
            ),

            // Layer 2 – Diagonal light rays
            Opacity(
              opacity: (0.03 + _rayCtrl.value * 0.07) * env.lightIntensity.clamp(0.0, 1.0),
              child: CustomPaint(
                painter: _LightRaysPainter(t: _rayCtrl.value),
              ),
            ),

            // Layer 3 – Ambient floating particles
            RepaintBoundary(
              child: CustomPaint(
                painter: _AmbientParticlesPainter(
                  t:         _particleCtrl.value,
                  intensity: env.particleIntensity,
                ),
              ),
            ),

            // Layer 4 – Soft fog / mist
            Opacity(
              opacity: (0.025 + _fogCtrl.value * 0.035).clamp(0.0, 1.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, 0.25),
                    radius: 0.85,
                    colors: [Color(0x28AAAAFF), Colors.transparent],
                  ),
                ),
              ),
            ),

            // Layer 5 – Bloom flash (tube/level completion)
            if (env.bloomActive)
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: env.bloomActive ? 0.14 : 0.0,
                  duration: const Duration(milliseconds: 350),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.0,
                        colors: [
                          Colors.white.withOpacity(0.30),
                          Colors.purple.withOpacity(0.08),
                          Colors.transparent,
                        ],
                      ),
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

// ─────────────────────────────────────────────────────────────────────────────
// Sub-painters
// ─────────────────────────────────────────────────────────────────────────────

class _BackgroundCrystalsPainter extends CustomPainter {
  final double t;
  final double intensity;

  const _BackgroundCrystalsPainter({required this.t, required this.intensity});

  // Hardcoded crystal data: [xFrac, yFrac, sizeFrac, baseAngle, colorIndex]
  static const _crystals = [
    [0.10, 0.12, 0.17, 0.28],
    [0.84, 0.07, 0.14, -0.38],
    [0.04, 0.60, 0.12, 0.55],
    [0.88, 0.52, 0.19, -0.22],
    [0.50, 0.03, 0.10, 0.11],
    [0.25, 0.80, 0.13, 0.45],
    [0.72, 0.75, 0.11, -0.35],
  ];

  static const _colors = [
    Color(0xFF4444FF),
    Color(0xFF7A4AFF),
    Color(0xFF4A9EFF),
    Color(0xFF6A44FF),
    Color(0xFF44AAFF),
    Color(0xFF9044FF),
    Color(0xFF44CCFF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < _crystals.length; i++) {
      final d      = _crystals[i];
      final x      = (d[0] as double) * size.width;
      final y      = (d[1] as double) * size.height;
      final s      = (d[2] as double) * size.width;
      final angle  = (d[3] as double) + (t - 0.5) * 0.18;
      final color  = _colors[i % _colors.length];
      final alpha  = (0.045 + intensity * 0.045).clamp(0.0, 0.15);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      _drawCrystal(canvas, s, color.withOpacity(alpha));
      canvas.restore();
    }
  }

  void _drawCrystal(Canvas canvas, double s, Color color) {
    final path = Path()
      ..moveTo(0, -s)
      ..lineTo(s * 0.48, -s * 0.18)
      ..lineTo(s * 0.38, s * 0.80)
      ..lineTo(0, s)
      ..lineTo(-s * 0.38, s * 0.80)
      ..lineTo(-s * 0.48, -s * 0.18)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(color.opacity * 1.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_BackgroundCrystalsPainter o) =>
      o.t != t || o.intensity != intensity;
}

// ─────────────────────────────────────────────────────────────────────────────

class _LightRaysPainter extends CustomPainter {
  final double t;
  const _LightRaysPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    const angles = [0.30, 0.52, 0.75, 1.02, 1.30];
    final cx     = size.width  * 0.28;
    final len    = size.height * 1.6;

    for (final a in angles) {
      final dx = cos(a) * len;
      final dy = sin(a) * len;
      final path = Path()
        ..moveTo(cx, 0)
        ..lineTo(cx + dx - 18, dy)
        ..lineTo(cx + dx + 18, dy)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
  }

  @override
  bool shouldRepaint(_LightRaysPainter o) => o.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────

class _AmbientParticlesPainter extends CustomPainter {
  final double t;
  final double intensity;

  const _AmbientParticlesPainter({required this.t, required this.intensity});

  // Pre-seeded random-looking particle data to avoid calling Random() in paint.
  static const _seeds = [
    [0.08, 0.85, 0.35, 1.5, 0.12],
    [0.21, 0.40, 0.58, 2.5, 0.73],
    [0.34, 0.65, 0.22, 1.0, 0.44],
    [0.45, 0.20, 0.68, 3.0, 0.88],
    [0.57, 0.92, 0.45, 2.0, 0.25],
    [0.63, 0.55, 0.30, 1.5, 0.60],
    [0.71, 0.30, 0.72, 2.5, 0.35],
    [0.80, 0.78, 0.52, 1.8, 0.90],
    [0.14, 0.50, 0.42, 2.2, 0.55],
    [0.90, 0.15, 0.65, 3.0, 0.18],
    [0.28, 0.10, 0.28, 1.2, 0.80],
    [0.52, 0.70, 0.55, 2.0, 0.42],
    [0.76, 0.45, 0.38, 1.6, 0.68],
    [0.40, 0.95, 0.48, 2.4, 0.05],
    [0.95, 0.60, 0.25, 1.0, 0.95],
    [0.05, 0.25, 0.60, 2.8, 0.30],
    [0.68, 0.88, 0.35, 1.4, 0.72],
    [0.35, 0.35, 0.70, 3.0, 0.50],
    [0.50, 0.50, 0.20, 1.0, 0.20],
    [0.85, 0.92, 0.45, 2.0, 0.65],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final count = (intensity * _seeds.length).toInt().clamp(4, _seeds.length);

    for (int i = 0; i < count; i++) {
      final d      = _seeds[i];
      final baseX  = (d[0] as double) * size.width;
      final baseY  = (d[1] as double) * size.height;
      final speed  = (d[2] as double);
      final ps     = (d[3] as double);
      final phase  = (d[4] as double);

      final tt  = (t * speed + phase) % 1.0;
      final x   = baseX + sin(tt * 2 * pi) * 14.0;
      final y   = baseY - tt * size.height * 0.28;
      final opa = (1.0 - tt).clamp(0.0, 1.0) * 0.38 * intensity;

      if (opa < 0.01) continue;

      canvas.drawCircle(
        Offset(x, y),
        ps,
        Paint()
          ..color = (i % 3 == 0 ? const Color(0xFFBBBBFF) : Colors.white).withOpacity(opa)
          ..maskFilter = ps > 2.2 ? const MaskFilter.blur(BlurStyle.normal, 2) : null,
      );
    }
  }

  @override
  bool shouldRepaint(_AmbientParticlesPainter o) =>
      o.t != t || o.intensity != intensity;
}
