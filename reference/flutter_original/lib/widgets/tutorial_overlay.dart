import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../services/storage_service.dart';

// ─── Step data ────────────────────────────────────────────────────────────────
enum _HL { none, movesCounter, hintButton }

class _Step {
  final String title;
  final String body;
  final String shortBody; // one-liner used by the compact guide banner
  final IconData icon;
  final Color iconColor;
  final _HL highlight;
  final bool waitForAction;
  const _Step({
    required this.title,
    required this.body,
    required this.shortBody,
    required this.icon,
    this.iconColor = Colors.purpleAccent,
    this.highlight = _HL.none,
    this.waitForAction = false,
  });
}

const List<_Step> _steps = [
  _Step(
    title: 'Welcome to Crystal Cascade!',
    body: 'Sort glittering gems by color. Stack 3 or more matching gems at the top of a tube and they vanish — earning you coins!',
    shortBody: 'Stack gems to clear tubes and earn coins.',
    icon: Icons.diamond,
    iconColor: Colors.cyanAccent,
  ),
  _Step(
    title: 'Your Crystal Tubes',
    body: 'Gems sit stacked inside tubes. Only the top gem moves. Your goal: empty every single tube.',
    shortBody: 'Only the top gem in each tube can move.',
    icon: Icons.view_column,
    iconColor: Colors.purpleAccent,
  ),
  _Step(
    title: 'Select a Tube',
    body: 'Tap any tube to pick up its top gem.',
    shortBody: 'Tap any tube below to pick up its top gem.',
    icon: Icons.touch_app,
    iconColor: Colors.amberAccent,
    waitForAction: true,
  ),
  _Step(
    title: 'Move the Gem',
    body: 'Now tap a different tube to drop the gem there.',
    shortBody: 'Tap another tube to drop the gem there.',
    icon: Icons.swap_horiz,
    iconColor: Colors.greenAccent,
    waitForAction: true,
  ),
  _Step(
    title: 'Auto-Clear Combos!',
    body: 'When 3 or more identical gems stack at the top, they vanish automatically. Chain clears for bonus coins!',
    shortBody: '3+ matching gems at the top clear automatically.',
    icon: Icons.auto_awesome,
    iconColor: Colors.orangeAccent,
  ),
  _Step(
    title: 'Watch Your Moves',
    body: 'Every move uses one from your budget shown here. Run out before clearing the board and you lose a life.',
    shortBody: 'Every move costs one from your budget.',
    icon: Icons.timer_outlined,
    iconColor: Colors.redAccent,
    highlight: _HL.movesCounter,
  ),
  _Step(
    title: 'Use Hints Wisely',
    body: 'Tap Hint to highlight your best next move. Hints cost coins — earn them free by watching videos in the Shop.',
    shortBody: 'Tap Hint to reveal your best next move.',
    icon: Icons.lightbulb_outline,
    iconColor: Colors.yellowAccent,
    highlight: _HL.hintButton,
  ),
  _Step(
    title: "You're Ready!",
    body: 'Clear every tube to win stars. The fewer moves you use, the better your score. Good luck, Crystal Master!',
    shortBody: 'Clear every tube to win. Good luck!',
    icon: Icons.emoji_events,
    iconColor: Colors.amberAccent,
  ),
];

// ─── Public widget ────────────────────────────────────────────────────────────
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
  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeIn);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, -0.06), end: Offset.zero)
            .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  void _advance() {
    if (_stepIdx >= _steps.length - 1) {
      StorageService().markTutorialCompleted();
      widget.onComplete();
      return;
    }
    setState(() => _stepIdx++);
    _entryCtrl..reset()..forward();
  }

  void _checkGameState(GameProvider game) {
    final step = _steps[_stepIdx];
    if (!step.waitForAction) {
      _prevMovesRemaining = game.movesRemaining;
      _prevSelectedTubeIndex = game.selectedTubeIndex;
      return;
    }
    // Step 2: advance when player taps a tube
    if (_stepIdx == 2 &&
        _prevSelectedTubeIndex != game.selectedTubeIndex &&
        game.selectedTubeIndex != -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _advance();
      });
    }
    // Step 3: advance when a move completes
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

    // Interactive steps get the compact guide banner — nothing blocks the game.
    // All other steps get the modal card with a full scrim.
    if (step.waitForAction) {
      return _buildGuideBanner(step, size, viewPad);
    }
    return _buildModal(step, size, viewPad);
  }

  // ── Guide banner (interactive steps 2 & 3) ──────────────────────────────────
  // Only a subtle top-fade covers the HUD/ad area.
  // The game area and all bottom controls are completely unobstructed.
  Widget _buildGuideBanner(_Step step, Size size, EdgeInsets viewPad) {
    // Subtle gradient scrim fading from the top — only dims the HUD/ad strip.
    final topFadeHeight = viewPad.top + 140.0;

    // Banner floats just below the HUD + ad banner, above the first tube row.
    final bannerTop = viewPad.top + 132.0;

    return Stack(
      children: [
        // Top-only fade — does NOT block touches anywhere
        IgnorePointer(
          child: Container(
            height: topFadeHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.45),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Compact guide banner — also does NOT block the game below it
        Positioned(
          top: bannerTop,
          left: 12,
          right: 12,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: _GuideBanner(
                step: step,
                stepIndex: _stepIdx,
                totalSteps: _steps.length,
                pulseCtrl: _pulseCtrl,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Modal (non-interactive steps) ────────────────────────────────────────────
  Widget _buildModal(_Step step, Size size, EdgeInsets viewPad) {
    final hl = _highlightRect(step.highlight, size, viewPad);
    final hasSpotlight = step.highlight != _HL.none;

    // Card positioning: keep away from the spotlight
    final AlignmentGeometry cardAlignment;
    switch (step.highlight) {
      case _HL.movesCounter:
        // Spotlight at top → card in lower-center
        cardAlignment = const Alignment(0, 0.5);
      case _HL.hintButton:
        // Spotlight at bottom-left → card in upper-center
        cardAlignment = const Alignment(0, -0.3);
      case _HL.none:
        cardAlignment = Alignment.center;
    }

    return Stack(
      children: [
        // Full scrim with optional spotlight hole
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => CustomPaint(
              painter: _ScrimPainter(
                spotlightRect: hl,
                pulse: _pulseCtrl.value,
                hasSpotlight: hasSpotlight,
              ),
              size: size,
            ),
          ),
        ),

        // Tap anywhere to advance
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _advance,
          child: const SizedBox.expand(),
        ),

        // Compact modal card, centered / offset away from spotlight
        Align(
          alignment: cardAlignment,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _ModalCard(
                  step: step,
                  stepIndex: _stepIdx,
                  totalSteps: _steps.length,
                  onNext: _advance,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Rect _highlightRect(_HL hl, Size size, EdgeInsets viewPad) {
    final hudBottom = viewPad.top + 70.0;
    switch (hl) {
      case _HL.movesCounter:
        return Rect.fromLTRB(
          size.width * 0.20, hudBottom - 28, size.width * 0.80, hudBottom + 16);
      case _HL.hintButton:
        return Rect.fromLTRB(
          0, size.height - 122, size.width * 0.40, size.height - 2);
      case _HL.none:
        return Rect.zero;
    }
  }
}

// ─── Guide banner widget (compact — used only for interactive steps) ──────────
class _GuideBanner extends StatelessWidget {
  final _Step step;
  final int stepIndex;
  final int totalSteps;
  final AnimationController pulseCtrl;
  const _GuideBanner({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1e1245).withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purpleAccent.withOpacity(0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon pill
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: step.iconColor.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: step.iconColor.withOpacity(0.5)),
            ),
            child: Icon(step.icon, color: step.iconColor, size: 20),
          ),
          const SizedBox(width: 12),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.shortBody,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Step counter + spinner
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${stepIndex + 1}/$totalSteps',
                style: TextStyle(
                  color: Colors.purpleAccent.withOpacity(0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedBuilder(
                animation: pulseCtrl,
                builder: (_, __) => SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color:
                        Colors.purpleAccent.withOpacity(0.4 + pulseCtrl.value * 0.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Modal card widget (used for non-interactive steps) ───────────────────────
class _ModalCard extends StatelessWidget {
  final _Step step;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;
  const _ModalCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = stepIndex == totalSteps - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2d1b69), Color(0xFF1a1a2e)],
        ),
        borderRadius: BorderRadius.circular(22),
        border:
            Border.all(color: Colors.purpleAccent.withOpacity(0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.purpleAccent.withOpacity(0.20),
            blurRadius: 24,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(totalSteps, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: i == stepIndex ? 18 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: i == stepIndex
                      ? Colors.purpleAccent
                      : Colors.white.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: step.iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: step.iconColor.withOpacity(0.5)),
            ),
            child: Icon(step.icon, color: step.iconColor, size: 24),
          ),
          const SizedBox(height: 10),

          // Title
          Text(
            step.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // Body
          Text(
            step.body,
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 12.5,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Next / Start button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purpleAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                isLast ? '\u2728  Start Playing!' : 'Next  \u2192',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Scrim / spotlight painter ────────────────────────────────────────────────
class _ScrimPainter extends CustomPainter {
  final Rect spotlightRect;
  final double pulse;
  final bool hasSpotlight;
  const _ScrimPainter(
      {required this.spotlightRect,
      required this.pulse,
      required this.hasSpotlight});

  @override
  void paint(Canvas canvas, Size size) {
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final scrim = Paint()..color = Colors.black.withOpacity(0.76);
    if (!hasSpotlight || spotlightRect == Rect.zero) {
      canvas.drawRect(full, scrim);
      return;
    }
    final rrect = RRect.fromRectAndRadius(
        spotlightRect.inflate(3 + pulse * 4), const Radius.circular(14));
    canvas.drawPath(
      Path.combine(
          PathOperation.difference, Path()..addRect(full), Path()..addRRect(rrect)),
      scrim,
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.purpleAccent.withOpacity(0.3 + pulse * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) =>
      old.spotlightRect != spotlightRect ||
      old.pulse != pulse ||
      old.hasSpotlight != hasSpotlight;
}
