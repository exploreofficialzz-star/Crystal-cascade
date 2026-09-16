import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/gem.dart';
import '../providers/game_provider.dart';
import 'gem_widget.dart';

class TubeWidget extends StatefulWidget {
  final List<Gem> gems;
  final int capacity;
  final bool isSelected;
  final bool isHintTarget;
  final bool isReceiving;
  final int reactionVersion;
  final GameReaction reaction;
  final VoidCallback onTap;
  final double width;
  final double gemSize;

  const TubeWidget({
    required this.gems,
    required this.capacity,
    required this.isSelected,
    required this.onTap,
    required this.width,
    required this.gemSize,
    this.isHintTarget = false,
    this.isReceiving = false,
    this.reactionVersion = 0,
    this.reaction = GameReaction.none,
    super.key,
  });

  @override
  State<TubeWidget> createState() => _TubeWidgetState();
}

class _TubeWidgetState extends State<TubeWidget>
    with TickerProviderStateMixin {
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();
  late final AnimationController _impact = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  int _previousLength = 0;
  int _lastReactionVersion = 0;

  @override
  void initState() {
    super.initState();
    _previousLength = widget.gems.length;
    _lastReactionVersion = widget.reactionVersion;
  }

  @override
  void didUpdateWidget(covariant TubeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final lengthChanged = widget.gems.length != _previousLength;
    final reactionChanged = widget.reactionVersion != _lastReactionVersion;
    if (lengthChanged || reactionChanged) {
      _impact.forward(from: 0);
    }
    _previousLength = widget.gems.length;
    _lastReactionVersion = widget.reactionVersion;
  }

  @override
  void dispose() {
    _ambient.dispose();
    _impact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tubeHeight = widget.gemSize * widget.capacity + 42;
    final active = widget.isSelected || widget.isHintTarget || widget.isReceiving;
    final filled = widget.gems.length / widget.capacity;
    final complete = widget.gems.isNotEmpty && widget.gems.length >= widget.capacity;
    final reactionAccent = widget.reaction == GameReaction.matched || widget.reaction == GameReaction.tubeCompleted
        ? Colors.cyanAccent
        : widget.reaction == GameReaction.won
            ? Colors.amberAccent
            : widget.reaction == GameReaction.lost
                ? Colors.blueAccent
                : null;
    final accent = reactionAccent ?? (complete ? Colors.amberAccent : (widget.isHintTarget ? Colors.greenAccent : (widget.isReceiving ? Colors.white : Colors.cyanAccent)));

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_ambient, _impact]),
        builder: (context, child) {
          final shimmer = (math.sin(_ambient.value * math.pi * 2) + 1) / 2;
          final impact = Curves.easeOutBack.transform(_impact.value);
          final impactScale = 1 + math.sin(impact * math.pi) * .018;
          final impactY = math.sin(impact * math.pi) * 3;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutBack,
            transformAlignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .0022)
              ..translate(0.0, (widget.isSelected ? -6.0 : 0.0) - impactY, 0.0)
              ..scale(impactScale, 1.0, 1.0)
              ..rotateX(widget.isSelected ? -.055 : 0.0)
              ..rotateY(widget.isReceiving ? math.sin(_impact.value * math.pi) * .028 : 0.0),
            width: widget.width,
            height: tubeHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.width * .24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(.23 + shimmer * .035),
                  Colors.white.withOpacity(.065),
                  Colors.black.withOpacity(.13),
                ],
              ),
              border: Border.all(
                color: widget.isHintTarget
                    ? Colors.greenAccent.withOpacity(.95)
                    : active
                        ? Colors.white.withOpacity(.9)
                        : Colors.white.withOpacity(.25),
                width: active ? 2.4 : 1.25,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(active ? .28 + shimmer * .10 : .08),
                  blurRadius: active ? 22 : 13,
                  spreadRadius: active ? 2 : 0,
                  offset: const Offset(0, 9),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(.34),
                  blurRadius: 12,
                  offset: const Offset(5, 9),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.width * .22),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  // Magical energy at the bottom of the glass.
                  Positioned(
                    left: 5,
                    right: 5,
                    bottom: 5,
                    height: math.max(12, (tubeHeight - 12) * filled * .16),
                    child: Opacity(
                      opacity: .18 + shimmer * .06,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          gradient: const LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.cyanAccent, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (reactionAccent != null)
                    Positioned(
                      left: 5, right: 5,
                      bottom: 10 + (tubeHeight - 30) * filled,
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _impact,
                          builder: (context, _) {
                            final wave = Curves.easeOut.transform(_impact.value);
                            return Opacity(
                              opacity: (math.sin(wave * math.pi) * .55).clamp(0.0, .55),
                              child: Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(99),
                                  gradient: LinearGradient(colors: [
                                    Colors.transparent,
                                    reactionAccent.withOpacity(.85),
                                    Colors.transparent,
                                  ]),
                                  boxShadow: [BoxShadow(color: reactionAccent.withOpacity(.28), blurRadius: 9)],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  if (reactionAccent != null)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _impact,
                          builder: (context, _) => Opacity(
                            opacity: (math.sin(_impact.value * math.pi) * .30).clamp(0.0, .30),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(widget.width * .22),
                                border: Border.all(color: reactionAccent.withOpacity(.9), width: 2),
                                boxShadow: [BoxShadow(color: reactionAccent.withOpacity(.28), blurRadius: 18, spreadRadius: 1)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Receiving energy sloshes at the current fill level, then settles.
                  if (widget.isReceiving || _impact.value > .02)
                    Positioned(
                      left: widget.width * .13,
                      right: widget.width * .13,
                      bottom: 18 + math.max(0.0, filled - .02) * (tubeHeight - 44),
                      child: Transform.scale(
                        scaleX: 1 + math.sin(_impact.value * math.pi) * .16,
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            gradient: LinearGradient(colors: [Colors.transparent, accent.withOpacity(.34), Colors.transparent]),
                            boxShadow: [BoxShadow(color: accent.withOpacity(.18), blurRadius: 7)],
                          ),
                        ),
                      ),
                    ),

                  // A thin energy surface wave rises and falls with the impact.
                  // It gives the tube contents a liquid/magical response without
                  // simulating a full fluid system.
                  if (filled > 0)
                    Positioned(
                      left: 7,
                      right: 7,
                      bottom: 13 + (tubeHeight - 34) * filled,
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _impact,
                          builder: (context, _) {
                            final wave = math.sin(_impact.value * math.pi);
                            return Transform.scale(
                              scaleX: 1 + wave * .12,
                              child: Container(
                                height: 3.5,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(99),
                                  gradient: LinearGradient(colors: [
                                    Colors.transparent,
                                    accent.withOpacity(.18 + wave * .35),
                                    Colors.transparent,
                                  ]),
                                  boxShadow: [BoxShadow(color: accent.withOpacity(.12 + wave * .18), blurRadius: 8)],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  // Glass rim: layered elliptical highlight makes the tube read as a
                  // real container from the elevated camera angle.
                  Positioned(
                    top: 1,
                    left: 3,
                    right: 3,
                    child: Container(
                      height: 13,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(.42),
                            Colors.white.withOpacity(.08),
                          ],
                        ),
                        border: Border.all(color: Colors.white.withOpacity(.28)),
                        boxShadow: [
                          BoxShadow(color: Colors.white.withOpacity(.08), blurRadius: 5),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            color: Colors.white.withOpacity(.24),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Inner rim shadow gives the glass an opening/depth cue.
                  Positioned(
                    top: 7,
                    left: 8,
                    right: 8,
                    child: IgnorePointer(
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: Colors.black.withOpacity(.10),
                        ),
                      ),
                    ),
                  ),
                  // Glass rim highlight.
                  Positioned(
                    top: 3,
                    left: 3,
                    right: 3,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: LinearGradient(colors: [
                          Colors.white.withOpacity(.58),
                          Colors.white.withOpacity(.06),
                        ]),
                        border: Border.all(color: Colors.white.withOpacity(.12)),
                      ),
                    ),
                  ),
                  // Long glass reflection.
                  Positioned(
                    left: widget.width * .12,
                    top: 12,
                    bottom: 14,
                    child: Container(
                      width: widget.width * .085,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: LinearGradient(colors: [
                          Colors.white.withOpacity(.38),
                          Colors.white.withOpacity(.0),
                        ]),
                      ),
                    ),
                  ),
                  // Moving highlight gives the glass a premium animated read.
                  Positioned(
                    left: widget.width * (.20 + shimmer * .48),
                    top: 14,
                    bottom: 12,
                    child: IgnorePointer(
                      child: Container(
                        width: 2.2,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(99),
                          color: Colors.white.withOpacity(.10 + shimmer * .10),
                        ),
                      ),
                    ),
                  ),
                  if (widget.isReceiving)
                    Positioned(
                      left: 8,
                      right: 8,
                      top: 18,
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _impact,
                          builder: (context, _) {
                            final p = Curves.easeInOut.transform(_impact.value);
                            return Opacity(
                              opacity: .12 + math.sin(p * math.pi) * .28,
                              child: Container(
                                height: 2.5,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(99),
                                  gradient: LinearGradient(colors: [
                                    Colors.transparent,
                                    Colors.white.withOpacity(.8),
                                    Colors.cyanAccent.withOpacity(.45),
                                    Colors.transparent,
                                  ]),
                                  boxShadow: [BoxShadow(color: Colors.cyanAccent.withOpacity(.25), blurRadius: 10)],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  if (complete)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(widget.width * .22),
                            border: Border.all(color: Colors.amberAccent.withOpacity(.55 + shimmer * .18), width: 1.4),
                            boxShadow: [BoxShadow(color: Colors.amberAccent.withOpacity(.16 + shimmer * .08), blurRadius: 16)],
                          ),
                        ),
                      ),
                    ),
                  if (widget.isReceiving)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(widget.width * .22),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.white.withOpacity(.22 + shimmer * .10), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (active)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.white.withOpacity(.10), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Curved side refraction bands. These stay faint so the gems remain the hero.
                  Positioned(
                    left: 1, top: 16, bottom: 13, width: 4,
                    child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: LinearGradient(colors: [Colors.white.withOpacity(.16), Colors.transparent]),
                    ))),
                  ),
                  Positioned(
                    right: 1, top: 17, bottom: 13, width: 3,
                    child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: LinearGradient(colors: [Colors.transparent, Colors.cyanAccent.withOpacity(.08 + shimmer * .05)]),
                    ))),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4, top: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: widget.gems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final gem = entry.value;
                        final isTop = widget.gems.isNotEmpty && identical(gem, widget.gems.last);
                        // Lower crystals settle first; the top crystal carries the
                        // strongest visible aftershock, selling a stacked physical load.
                        final stackWeight = widget.gems.length <= 1
                            ? 1.0
                            : (index + 1) / widget.gems.length;
                        // Impacts travel upward through the stack: lower gems
                        // settle first, then the load above them responds a few
                        // frames later. This is intentionally lightweight but
                        // makes the pile read as several physical crystals.
                        final delay = index * .045;
                        final localImpact = ((_impact.value - delay) / (1 - delay)).clamp(0.0, 1.0);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 1.5),
                          child: GemWidget(
                            key: ValueKey(gem.id),
                            gem: gem.copyWith(isSelected: widget.isSelected && isTop),
                            size: widget.gemSize,
                            isTop: isTop,
                            impactPulse: (localImpact * (0.45 + stackWeight * .55)).clamp(0.0, 1.0),
                            stackIndex: index,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  if (widget.gems.isEmpty)
                    Center(
                      child: Icon(
                        widget.isHintTarget ? Icons.add_circle : Icons.add_circle_outline,
                        color: widget.isHintTarget
                            ? Colors.greenAccent.withOpacity(.65)
                            : Colors.white.withOpacity(.22),
                        size: widget.gemSize * .48,
                      ),
                    ),
                  if (widget.isHintTarget && widget.gems.length < widget.capacity)
                    Positioned(
                      top: 9,
                      child: Icon(
                        Icons.arrow_downward_rounded,
                        color: Colors.greenAccent.withOpacity(.92),
                        size: 16,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
