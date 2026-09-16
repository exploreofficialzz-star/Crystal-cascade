import 'dart:math';
import 'package:flutter/material.dart';
import '../models/gem.dart';
import 'gem_widget.dart';

/// 2.5D glass tube widget with landing bounce, selection lift, shimmer, and
/// state-driven visual feedback.
class TubeWidget extends StatefulWidget {
  final List<Gem> gems;
  final int       capacity;
  final bool      isSelected;
  final bool      isHintTarget;
  final VoidCallback onTap;
  final double    width;
  final double    gemSize;
  /// Increment this to trigger a landing impact animation.
  final int       landingTrigger;

  const TubeWidget({
    required this.gems,
    required this.capacity,
    required this.isSelected,
    required this.onTap,
    required this.width,
    required this.gemSize,
    this.isHintTarget    = false,
    this.landingTrigger  = 0,
    super.key,
  });

  @override
  State<TubeWidget> createState() => _TubeWidgetState();
}

class _TubeWidgetState extends State<TubeWidget>
    with TickerProviderStateMixin {
  late AnimationController _shimmerCtrl;
  late AnimationController _landingCtrl;
  late AnimationController _selectCtrl;

  late Animation<double> _shimmerAnim;
  late Animation<double> _landingAnim;
  late Animation<double> _selectAnim;

  int _prevGemCount     = 0;
  int _prevLandingTrig  = 0;

  @override
  void initState() {
    super.initState();
    _prevGemCount    = widget.gems.length;
    _prevLandingTrig = widget.landingTrigger;

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    _landingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _selectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    _shimmerAnim = CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut);

    // Bounce: rises to 1 quickly then settles back with natural overshoot.
    _landingAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 0.35),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 0.65),
    ]).animate(CurvedAnimation(parent: _landingCtrl, curve: Curves.easeOut));

    _selectAnim = CurvedAnimation(parent: _selectCtrl, curve: Curves.easeOutCubic);

    if (widget.isSelected) _selectCtrl.value = 1.0;
  }

  @override
  void didUpdateWidget(TubeWidget old) {
    super.didUpdateWidget(old);

    // Gem count increased → landing impact
    if (widget.gems.length > _prevGemCount ||
        widget.landingTrigger != _prevLandingTrig) {
      _landingCtrl.forward(from: 0.0);
      _prevLandingTrig = widget.landingTrigger;
    }
    _prevGemCount = widget.gems.length;

    // Selection toggled
    if (widget.isSelected && !old.isSelected) {
      _selectCtrl.forward(from: 0.0);
    } else if (!widget.isSelected && old.isSelected) {
      _selectCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _landingCtrl.dispose();
    _selectCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_shimmerCtrl, _landingCtrl, _selectCtrl]),
      builder: (context, _) {
        final shimmer    = _shimmerAnim.value;
        final landing    = _landingAnim.value;
        final selectVal  = _selectAnim.value;
        final isSelected = widget.isSelected;
        final isHint     = widget.isHintTarget;
        final tubeH      = widget.gemSize * widget.capacity + 20.0;

        // Lift the tube slightly when selected
        final liftY  = -selectVal * 7.0;
        // Subtle horizontal wobble on landing
        final shakeX = sin(landing * pi * 5) * landing * 3.5;

        return Transform.translate(
          offset: Offset(shakeX, liftY),
          child: GestureDetector(
            onTap: widget.onTap,
            child: SizedBox(
              width:  widget.width,
              height: tubeH,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  // ── Depth back-wall shadow ─────────────────────────────
                  Positioned(
                    left:   widget.width * 0.09,
                    right:  widget.width * 0.09,
                    top:    7,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.28),
                        borderRadius: const BorderRadius.only(
                          bottomLeft:  Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // ── Main glass body ────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end:   Alignment.bottomCenter,
                        colors: isHint
                            ? [
                                Colors.greenAccent.withOpacity(0.16 + shimmer * 0.06),
                                Colors.greenAccent.withOpacity(0.06),
                              ]
                            : isSelected
                                ? [
                                    Colors.white.withOpacity(0.24 + shimmer * 0.06),
                                    Colors.white.withOpacity(0.08),
                                  ]
                                : [
                                    Colors.white.withOpacity(0.14 + shimmer * 0.05),
                                    Colors.white.withOpacity(0.04),
                                  ],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft:     Radius.circular(20),
                        topRight:    Radius.circular(20),
                        bottomLeft:  Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      ),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white.withOpacity(0.78 + selectVal * 0.15)
                            : isHint
                                ? Colors.greenAccent.withOpacity(0.88)
                                : Colors.white.withOpacity(0.18 + shimmer * 0.08),
                        width: isSelected ? 2.2 : isHint ? 2.0 : 1.2,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color:       Colors.white.withOpacity(0.28),
                            blurRadius:  22,
                            spreadRadius: 2,
                          ),
                        if (isHint)
                          BoxShadow(
                            color:       Colors.greenAccent.withOpacity(0.45),
                            blurRadius:  20,
                            spreadRadius: 2,
                          ),
                        BoxShadow(
                          color:  Colors.black.withOpacity(0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      clipBehavior: Clip.none,
                      children: [
                        // ── Left-edge glass reflection ─────────────────
                        Positioned(
                          top:  10,
                          left: 7,
                          child: Container(
                            width:  widget.width * 0.13,
                            height: tubeH * 0.62,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end:   Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withOpacity(0.30 + shimmer * 0.10),
                                  Colors.white.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ── Top rim highlight ──────────────────────────
                        Positioned(
                          top:   0,
                          left:  0,
                          right: 0,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft:  Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.55 + shimmer * 0.15),
                                  Colors.white.withOpacity(0.08),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ── Hint arrow ─────────────────────────────────
                        if (isHint && widget.gems.length < widget.capacity)
                          Positioned(
                            top:  8,
                            child: Icon(
                              Icons.arrow_downward_rounded,
                              color: Colors.greenAccent.withOpacity(0.92),
                              size:  16,
                            ),
                          ),

                        // ── Ambient energy for empty tubes ─────────────
                        if (widget.gems.isEmpty)
                          Center(
                            child: Container(
                              width:  widget.width * 0.55,
                              height: widget.width * 0.55,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.05 + shimmer * 0.05),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // ── Gem stack ──────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6, left: 3, right: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: widget.gems.map((gem) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 1),
                                child: GemWidget(
                                  gem: gem.copyWith(
                                    isSelected: isSelected && gem == widget.gems.last,
                                  ),
                                  size:  widget.gemSize,
                                  isTop: gem == widget.gems.last,
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // ── Empty indicator ────────────────────────────
                        if (widget.gems.isEmpty)
                          Center(
                            child: Icon(
                              isHint ? Icons.add_circle : Icons.add_circle_outline,
                              color: isHint
                                  ? Colors.greenAccent.withOpacity(0.65)
                                  : Colors.white.withOpacity(0.18 + shimmer * 0.10),
                              size: widget.gemSize * 0.46,
                            ),
                          ),

                        // ── Landing impact flash ───────────────────────
                        if (landing > 0.01)
                          Positioned(
                            bottom: 0,
                            left:   0,
                            right:  0,
                            child: Container(
                              height: widget.gemSize * 0.6 * landing,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end:   Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withOpacity(0.30 * landing),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
