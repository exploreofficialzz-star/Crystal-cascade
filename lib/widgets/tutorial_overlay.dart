import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../services/storage_service.dart';

// ─── Highlight target ─────────────────────────────────────────────────────────
enum _HL { none, gameArea, movesCounter, hintButton }

// ─── Step data ────────────────────────────────────────────────────────────────
class _Step {
  final String title;
  final String body;
  final IconData icon;
  final Color iconColor;
  final _HL highlight;
  final bool waitForAction;
  const _Step({
    required this.title,
    required this.body,
    required this.icon,
    this.iconColor = Colors.purpleAccent,
    this.highlight = _HL.none,
    this.waitForAction = false,
  });
}

const List<_Step> _steps = [
  _Step(
    title: 'Welcome to Crystal Cascade!',
    body: 'Sort glittering gems by color. Stack 3 or more matching gems at the top of any tube and they vanish — earning you coins!',
    icon: Icons.diamond,
    iconColor: Colors.cyanAccent,
  ),
  _Step(
    title: 'Your Crystal Tubes',
    body: 'Gems sit stacked in tubes. The top gem is always the one you can move. Your goal: empty every single tube.',
    icon: Icons.view_column,
    iconColor: Colors.purpleAccent,
    highlight: _HL.gameArea,
  ),
  _Step(
    title: 'Select a Tube',
    body: 'Tap any tube to pick up its top gem — it will glow white to show it is selected.',
    icon: Icons.touch_app,
    iconColor: Colors.amberAccent,
    highlight: _HL.gameArea,
    waitForAction: true,
  ),
  _Step(
    title: 'Move the Gem',
    body: 'Now tap a different tube to drop the gem there. Gems can only land on an empty tube OR a tube whose top gem is the same color.',
    icon: Icons.swap_horiz,
    iconColor: Colors.greenAccent,
    highlight: _HL.gameArea,
    waitForAction: true,
  ),
  _Step(
    title: 'Auto-Clear Combos!',
    body: 'When 3 or more identical gems stack at the top, they clear automatically. Chain clears for bonus coins and a higher score!',
    icon: Icons.auto_awesome,
    iconColor: Colors.orangeAccent,
  ),
  _Step(
    title: 'Mind Your Moves',
    body: 'Every move costs one from your budget shown at the top. Run out before clearing the board and you lose a life — plan ahead!',
    icon: Icons.timer_outlined,
    iconColor: Colors.redAccent,
    highlight: _HL.movesCounter,
  ),
  _Step(
    title: 'Hints Are Your Friend',
    body: 'Tap Hint to highlight your best next move in green. Hints cost coins — earn them free by watching short videos in the Shop.',
    icon: Icons.lightbulb_outline,
    iconColor: Colors.yellowAccent,
    highlight: _HL.hintButton,
  ),
  _Step(
    title: "You're Ready!",
    body: 'Clear every gem from every tube to win. The fewer moves you use, the more stars you earn. Good luck, Crystal Master!',
    icon: Icons.emoji_events,
    iconColor: Colors.amberAccent,
  ),
];

// ─── Overlay widget ───────────────────────────────────────────────────────────
class TutorialOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  const TutorialOverlay({super.key, required this.onComplete});

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {
  int _stepIdx = 0;
  int _prevMovesRemaining = -1;
  int _prevSelectedTubeIndex = -2;

  late final AnimationController _pulseCtrl;
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _advance() {
    if (_stepIdx >= _steps.length - 1) {
      StorageService().markTutorialCompleted();
      widget.onComplete();
      return;
    }
    setState(() => _stepIdx++);
    _slideCtrl..reset()..forward();
  }

  void _checkGameState(GameProvider game) {
    final step = _steps[_stepIdx];
    if (!step.waitForAction) {
      _prevMovesRemaining = game.movesRemaining;
      _prevSelectedTubeIndex = game.selectedTubeIndex;
      return;
    }
    if (_stepIdx == 2 &&
        _prevSelectedTubeIndex != game.selectedTubeIndex &&
        game.selectedTubeIndex != -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _advance();
      });
    }
    if (_stepIdx == 3 &&
        _prevMovesRemaining != -1 &&
        game.movesRemaining < _prevMovesRemaining) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _advance();
      });
    }
    _prevMovesRemaining = game.movesRemaining;
    _prevSelectedTubeIndex = game.selectedTubeIndex;
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameProvider>();
    _checkGameState(game);

    final step = _steps[_stepIdx];
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final viewPad = mq.viewPadding;
    final hl = _highlightRect(step.highlight, size, viewPad);
    final hasHole = step.highlight != _HL.none;
    final cardBottom =
        viewPad.bottom + (step.highlight == _HL.hintButton ? 145.0 : 20.0);

    return Stack(
      children: [
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => CustomPaint(
              painter: _SpotlightPainter(
                rect: hl,
                pulse: _pulseCtrl.value,
                hasHole: hasHole,
              ),
              size: size,
            ),
          ),
        ),
        if (!step.waitForAction)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _advance,
            child: const SizedBox.expand(),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: cardBottom,
          child: SlideTransition(
            position: _slideAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: _StepCard(
                step: step,
                stepIndex: _stepIdx,
                totalSteps: _steps.length,
                onNext: step.waitForAction ? null : _advance,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Rect _highlightRect(_HL hl, Size size, EdgeInsets viewPad) {
    final hudBottom = viewPad.top + 70.0;
    final gameTop = hudBottom + 60.0;
    switch (hl) {
      case _HL.gameArea:
        return Rect.fromLTRB(8, gameTop, size.width - 8, size.height - 115.0);
      case _HL.movesCounter:
        return Rect.fromLTRB(
            size.width * 0.22, hudBottom - 26, size.width * 0.78, hudBottom + 14);
      case _HL.hintButton:
        return Rect.fromLTRB(
            0, size.height - 120, size.width * 0.38, size.height - 2);
      case _HL.none:
        return Rect.zero;
    }
  }
}

// ─── Spotlight painter ────────────────────────────────────────────────────────
class _SpotlightPainter extends CustomPainter {
  final Rect rect;
  final double pulse;
  final bool hasHole;
  const _SpotlightPainter(
      {required this.rect, required this.pulse, required this.hasHole});

  @override
  void paint(Canvas canvas, Size size) {
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final scrim = Paint()..color = Colors.black.withOpacity(0.74);
    if (!hasHole || rect == Rect.zero) {
      canvas.drawRect(full, scrim);
      return;
    }
    final rrect = RRect.fromRectAndRadius(
        rect.inflate(3 + pulse * 5), const Radius.circular(16));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(full),
        Path()..addRRect(rrect),
      ),
      scrim,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.purpleAccent.withOpacity(0.35 + pulse * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.rect != rect || old.pulse != pulse || old.hasHole != hasHole;
}

// ─── Step card ────────────────────────────────────────────────────────────────
class _StepCard extends StatelessWidget {
  final _Step step;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback? onNext;
  const _StepCard(
      {required this.step,
      required this.stepIndex,
      required this.totalSteps,
      this.onNext});

  @override
  Widget build(BuildContext context) {
    final isLast = stepIndex == totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2d1b69), Color(0xFF1a1a2e)],
        ),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.purpleAccent.withOpacity(0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(0.22),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalSteps, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == stepIndex ? 22 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == stepIndex
                      ? Colors.purpleAccent
                      : Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: step.iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: step.iconColor.withOpacity(0.5)),
            ),
            child: Icon(step.icon, color: step.iconColor, size: 28),
          ),
          const SizedBox(height: 12),
          Text(step.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(step.body,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.80),
                  fontSize: 13.5,
                  height: 1.45),
              textAlign: TextAlign.center),
          const SizedBox(height: 18),
          if (onNext == null)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      color: Colors.white.withOpacity(0.45)),
                ),
                const SizedBox(width: 10),
                Text('Waiting for your move\u2026',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.45), fontSize: 12)),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  isLast ? '\u2728  Start Playing!' : 'Next  \u2192',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
