import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/character_reaction_manager.dart';
import '../managers/environment_reaction_manager.dart';
import '../providers/game_provider.dart';
import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/crystal_guardian_widget.dart';
import '../widgets/living_background_widget.dart';
import '../widgets/tube_widget.dart';
import '../widgets/tutorial_overlay.dart';
import 'game_over_screen.dart';
import 'home_screen.dart';
import 'shop_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController        _pulseController;
  StreamSubscription<String>?     _rewardSubscription;
  late CharacterReactionManager   _charManager;
  late EnvironmentReactionManager _envManager;
  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _showTutorial = !StorageService().hasTutorialCompleted();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Reaction managers – created here so they live as long as the screen.
    _charManager = CharacterReactionManager();
    _envManager  = EnvironmentReactionManager();

    // Subscribe managers to the game event stream after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final game = context.read<GameProvider>();
      _charManager.subscribe(game.eventStream);
      _envManager.subscribe(game.eventStream);
    });

    _rewardSubscription = AdMobService().onRewardEarned.listen((type) {
      if (!mounted || type != 'extra_moves') return;
      context.read<GameProvider>().claimRewardMoves(5);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 +5 moves added!'),
          backgroundColor: Colors.greenAccent,
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _rewardSubscription?.cancel();
    _charManager.dispose();
    _envManager.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      AudioService().pauseBGM();
    } else if (state == AppLifecycleState.resumed) {
      final game = context.read<GameProvider>();
      if (game.status == GameStatus.playing) AudioService().resumeBGM();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<CharacterReactionManager>.value(value: _charManager),
        ChangeNotifierProvider<EnvironmentReactionManager>.value(value: _envManager),
      ],
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          final game = context.read<GameProvider>();
          if (game.status == GameStatus.playing) {
            game.pauseGame();
            _showPauseMenu(context);
          } else {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          body: Consumer<GameProvider>(
            builder: (context, game, child) {
              if (game.status == GameStatus.won || game.status == GameStatus.lost) {
                if (_showTutorial) {
                  StorageService().markTutorialCompleted();
                  _showTutorial = false;
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    AdMobService().showInterstitialAd();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const GameOverScreen()),
                    );
                  }
                });
              }

              final isLevelOne = (game.currentLevel?.id ?? 0) == 1;

              return Stack(
                fit: StackFit.expand,
                children: [
                  // ── Layer 0: Living parallax background ─────────────
                  const LivingBackgroundWidget(),

                  // ── Layer 1: Game UI ────────────────────────────────
                  SafeArea(
                    child: Column(
                      children: [
                        _buildTopHUD(game),
                        const SizedBox(height: 6),
                        const AdBannerWidget(),
                        const SizedBox(height: 6),
                        // ── Game area + Guardian ─────────────────────
                        Expanded(
                          child: Stack(
                            children: [
                              // Tube board with subtle 2.5D perspective
                              Positioned.fill(
                                child: _buildGameArea(game),
                              ),
                              // Crystal Guardian – secondary, bottom-right
                              Positioned(
                                right:  6,
                                bottom: 8,
                                width:  82,
                                height: 170,
                                child: const CrystalGuardianWidget(),
                              ),
                            ],
                          ),
                        ),
                        _buildBottomControls(game),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),

                  // ── Layer 2: Tutorial overlay ────────────────────────
                  if (_showTutorial && isLevelOne)
                    TutorialOverlay(
                      onComplete: () {
                        if (mounted) setState(() => _showTutorial = false);
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── HUD ────────────────────────────────────────────────────────────────────
  Widget _buildTopHUD(GameProvider game) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildHUDButton(Icons.arrow_back_ios, () => _onBackPressed(context)),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Level ${game.currentLevel?.id ?? 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final isLow = game.movesRemaining <= 3;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isLow
                            ? Colors.red.withOpacity(0.30 + _pulseController.value * 0.30)
                            : Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isLow
                              ? Colors.redAccent.withOpacity(0.80)
                              : Colors.white.withOpacity(0.22),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Moves: ${game.movesRemaining}',
                        style: TextStyle(
                          color:      isLow ? Colors.redAccent : Colors.white,
                          fontSize:   14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          _buildHUDButton(Icons.pause, () {
            game.pauseGame();
            _showPauseMenu(context);
          }),
        ],
      ),
    );
  }

  Widget _buildHUDButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  44,
        height: 44,
        decoration: BoxDecoration(
          color:  Colors.black.withOpacity(0.35),
          shape:  BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6)],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ── Game area ──────────────────────────────────────────────────────────────
  Widget _buildGameArea(GameProvider game) {
    final tubeCount = game.tubes.length;
    // 2.5D perspective transform – subtle tilt gives depth without hurting readability.
    return Center(
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.00055)    // perspective depth
          ..rotateX(-0.055),           // slight elevation angle
        alignment: Alignment.center,
        child: Wrap(
          alignment:  WrapAlignment.center,
          spacing:    10,
          runSpacing: 14,
          children: List.generate(tubeCount, (index) {
            return TubeWidget(
              gems:           game.tubes[index],
              capacity:       game.currentLevel?.tubeCapacity ?? 4,
              isSelected:     game.selectedTubeIndex  == index,
              isHintTarget:   game.hintDestinationIndex == index,
              onTap:          () => game.onTubeTap(index),
              width:          64,
              gemSize:        46,
            );
          }),
        ),
      ),
    );
  }

  // ── Bottom controls ────────────────────────────────────────────────────────
  Widget _buildBottomControls(GameProvider game) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.20),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            Icons.lightbulb_outline,
            game.hints > 0 ? 'Hint (${game.hints})' : 'Hint',
            game.hints > 0 ? Colors.yellowAccent : Colors.white38,
            () => _onHintTap(context),
          ),
          _buildControlButton(
            Icons.add_circle_outline,
            '+5 Moves',
            Colors.greenAccent,
            () => _showExtraMovesDialog(context),
          ),
          _buildControlButton(
            Icons.refresh,
            'Restart',
            Colors.orangeAccent,
            () => _showRestartDialog(context),
          ),
          _buildControlButton(
            Icons.view_column,
            '+1 Tube',
            Colors.cyanAccent,
            () => _showExtraTubeDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width:  50,
            height: 50,
            decoration: BoxDecoration(
              color:  Colors.black.withOpacity(0.32),
              shape:  BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.50), width: 1.5),
              boxShadow: [BoxShadow(color: color.withOpacity(0.22), blurRadius: 10)],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 11)),
        ],
      ),
    );
  }

  // ── Hint handler ───────────────────────────────────────────────────────────
  void _onHintTap(BuildContext context) async {
    final game   = context.read<GameProvider>();
    final result = await game.useHint();
    if (!mounted) return;
    switch (result) {
      case HintResult.used:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('💡 Hint used! ${game.hints} remaining.'),
          backgroundColor: Colors.amber.withOpacity(0.9),
          duration: const Duration(seconds: 2),
        ));
        break;
      case HintResult.usedCoins:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '💡 Hint used! (${GameConstants.hintCost} coins spent) — ${game.totalCoins} left.'),
          backgroundColor: Colors.amber.withOpacity(0.9),
          duration: const Duration(seconds: 2),
        ));
        break;
      case HintResult.noCoins:
      case HintResult.noHints:
        _showHintMonetizationDialog(context, game);
    }
  }

  void _showHintMonetizationDialog(BuildContext context, GameProvider game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.yellowAccent.withOpacity(0.4), width: 1.5),
        ),
        title: const Text('Out of Hints!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lightbulb, color: Colors.yellowAccent, size: 52),
            const SizedBox(height: 12),
            const Text('Get a hint to reveal the best move.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  AdMobService().onRewardEarned.first.then((_) {
                    if (!mounted) return;
                    game.addHints(1);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('💡 You got 1 hint!'),
                          backgroundColor: Colors.amber,
                          duration: Duration(seconds: 2)),
                    );
                  });
                  AdMobService().showRewardedAd(type: 'hint');
                },
                icon: const Icon(Icons.play_circle_fill, color: Colors.black),
                label: const Text('Watch Ad — Free Hint',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: game.totalCoins >= GameConstants.hintCost
                    ? () async {
                        final bought = await game.buyHintWithCoins();
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        if (bought) {
                          await game.useHint();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                '💡 Hint applied! ${GameConstants.hintCost} coins spent.'),
                            backgroundColor: Colors.amber.withOpacity(0.9),
                            duration: const Duration(seconds: 2),
                          ));
                        }
                      }
                    : null,
                icon: const Icon(Icons.monetization_on, color: Colors.white),
                label: Text('Use ${GameConstants.hintCost} Coins  (have ${game.totalCoins})',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  disabledBackgroundColor: Colors.purple.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const ShopScreen()));
                },
                icon: const Icon(Icons.storefront, color: Colors.purpleAccent),
                label: const Text('Buy Hint Pack in Shop',
                    style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now', style: TextStyle(color: Colors.white38)),
          ),
        ],
      ),
    );
  }

  void _onBackPressed(BuildContext context) {
    final game = context.read<GameProvider>();
    if (game.status == GameStatus.playing) {
      game.pauseGame();
      _showPauseMenu(context);
    }
  }

  void _showPauseMenu(BuildContext context) {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const _PauseDialog());
  }

  void _showExtraMovesDialog(BuildContext context) {
    final game = context.read<GameProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5), width: 1),
        ),
        title: const Text('Extra Moves',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_circle, color: Colors.greenAccent, size: 56),
            const SizedBox(height: 16),
            const Text('+5 Moves',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text('Watch a short video for free:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  AdMobService().showRewardedAd(type: 'extra_moves');
                },
                icon: const Icon(Icons.play_circle_outline, color: Colors.black),
                label: const Text('Watch Video',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(children: [
              Expanded(child: Divider(color: Colors.white24)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('OR', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
              Expanded(child: Divider(color: Colors.white24)),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final hasCoins = game.totalCoins >= GameConstants.extraMovesCost;
                  Navigator.pop(ctx);
                  if (hasCoins) {
                    game.buyExtraMoves();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Not enough coins! Watch a video instead.'),
                        backgroundColor: Colors.redAccent,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.monetization_on, color: Colors.white),
                label: Text('Use ${GameConstants.extraMovesCost} Coins',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('You have ${game.totalCoins} coins',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }

  void _showExtraTubeDialog(BuildContext context) {
    final game = context.read<GameProvider>();
    if (!game.canAddExtraTube) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Max extra tubes reached for this level.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.cyanAccent.withOpacity(0.5), width: 1),
        ),
        title: const Text('Extra Tube',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.view_column, color: Colors.cyanAccent, size: 56),
            const SizedBox(height: 16),
            const Text('+1 Tube',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text(
              'Stuck? An extra tube gives you room to work with.\nWatch a short video for free:',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  AdMobService().onRewardEarned.first.then((_) {
                    if (!mounted) return;
                    game.addFreeExtraTube();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🧪 +1 tube added!'),
                          backgroundColor: Colors.cyanAccent,
                          duration: Duration(seconds: 2)),
                    );
                  });
                  AdMobService().showRewardedAd(type: 'extra_tube');
                },
                icon: const Icon(Icons.play_circle_outline, color: Colors.black),
                label: const Text('Watch Video',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amberAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(children: [
              Expanded(child: Divider(color: Colors.white24)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('OR', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ),
              Expanded(child: Divider(color: Colors.white24)),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final hasCoins = game.totalCoins >= GameConstants.extraTubeCost;
                  Navigator.pop(ctx);
                  if (hasCoins) {
                    game.buyExtraTube();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Not enough coins! Watch a video instead.'),
                          backgroundColor: Colors.redAccent,
                          duration: Duration(seconds: 2)),
                    );
                  }
                },
                icon: const Icon(Icons.monetization_on, color: Colors.white),
                label: Text('Use ${GameConstants.extraTubeCost} Coins',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('You have ${game.totalCoins} coins',
                style: const TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }

  void _showRestartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.orangeAccent.withOpacity(0.5), width: 1),
        ),
        title: const Text('Restart Level?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: Text('Your current progress will be lost.',
            style: TextStyle(color: Colors.white.withOpacity(0.70)),
            textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<GameProvider>().restartLevel();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Restart', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}

// ── Pause dialog ─────────────────────────────────────────────────────────────

class _PauseDialog extends StatelessWidget {
  const _PauseDialog();
  @override
  Widget build(BuildContext context) {
    final game = context.read<GameProvider>();
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e).withOpacity(0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.purpleAccent.withOpacity(0.50), width: 2),
          boxShadow: [BoxShadow(color: Colors.purpleAccent.withOpacity(0.20), blurRadius: 30)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('PAUSED',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4)),
            const SizedBox(height: 30),
            _pauseBtn('Resume',  Icons.play_arrow,  Colors.greenAccent,  () {
              game.resumeGame();
              AudioService().resumeBGM();
              Navigator.pop(context);
            }),
            const SizedBox(height: 12),
            _pauseBtn('Restart', Icons.refresh,     Colors.orangeAccent, () {
              game.restartLevel();
              Navigator.pop(context);
            }),
            const SizedBox(height: 12),
            _pauseBtn('Quit',    Icons.exit_to_app, Colors.redAccent,    () {
              AudioService().playBGM();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (r) => false,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _pauseBtn(String text, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  200,
        height: 50,
        decoration: BoxDecoration(
          color:  color.withOpacity(0.18),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: color.withOpacity(0.50), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Text(text,
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
