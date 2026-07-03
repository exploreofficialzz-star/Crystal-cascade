import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../providers/game_provider.dart';
import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import 'game_screen.dart';
import 'home_screen.dart';
import 'level_select_screen.dart';
import 'shop_screen.dart';

class GameOverScreen extends StatefulWidget {
  const GameOverScreen({super.key});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confetti;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  bool _confettiPlayed = false;
  final StorageService _storage = StorageService();

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _confetti.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _triggerConfetti(bool isWin) {
    if (isWin && !_confettiPlayed) {
      _confettiPlayed = true;
      _confetti.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, game, _) {
        final isWin = game.status == GameStatus.won;
        _triggerConfetti(isWin);

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  isWin
                      ? 'assets/images/bg_victory.jpg'
                      : 'assets/images/bg_menu.jpg',
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
              child: SafeArea(
                child: Stack(
                  children: [
                    // Confetti — win only
                    if (isWin)
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConfettiWidget(
                          confettiController: _confetti,
                          blastDirectionality: BlastDirectionality.explosive,
                          numberOfParticles: 30,
                          colors: const [
                            Colors.amber,
                            Colors.purpleAccent,
                            Colors.blueAccent,
                            Colors.greenAccent,
                            Colors.redAccent,
                          ],
                        ),
                      ),

                    Column(
                      children: [
                        Expanded(
                          child: SlideTransition(
                            position: _slideAnim,
                            child: isWin
                                ? _WinContent(game: game)
                                : _LoseContent(game: game, storage: _storage),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── WIN SCREEN ───────────────────────────────────────────────────────────────

class _WinContent extends StatelessWidget {
  final GameProvider game;
  const _WinContent({required this.game});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // Trophy
            const Icon(Icons.emoji_events, color: Colors.amber, size: 90),
            const SizedBox(height: 12),

            const Text(
              'LEVEL COMPLETE!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 24),

            // Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                final lit = i < game.stars;
                return AnimatedContainer(
                  duration: Duration(milliseconds: 300 + i * 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    lit ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: lit ? Colors.amber : Colors.white24,
                    size: 56,
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Score + coins earned
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: Colors.white.withOpacity(0.15), width: 1),
              ),
              child: Column(children: [
                Text(
                  'Score: ${game.score}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.monetization_on,
                      color: Colors.amber, size: 18),
                  const SizedBox(width: 4),
                  Text(
                    '+${GameConstants.coinsPerLevelComplete} coins earned',
                    style: TextStyle(
                        color: Colors.amber.withOpacity(0.9), fontSize: 14),
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 36),

            // Next Level
            _Btn(
              label: 'Next Level',
              icon: Icons.arrow_forward_rounded,
              color: Colors.greenAccent,
              onTap: () {
                final nextId = (game.currentLevel?.id ?? 0) + 1;
                game.startLevel(game.levelAt(nextId));
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const GameScreen()),
                );
              },
            ),
            const SizedBox(height: 14),

            // Level Select
            _Btn(
              label: 'Level Select',
              icon: Icons.grid_view_rounded,
              color: Colors.blueAccent,
              onTap: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
                (r) => false,
              ),
            ),
            const SizedBox(height: 14),

            // Menu
            _Btn(
              label: 'Main Menu',
              icon: Icons.home_rounded,
              color: Colors.white60,
              onTap: () {
                AudioService().playBGM();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (r) => false,
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─── LOSE SCREEN ──────────────────────────────────────────────────────────────

class _LoseContent extends StatelessWidget {
  final GameProvider game;
  final StorageService storage;
  const _LoseContent({required this.game, required this.storage});

  @override
  Widget build(BuildContext context) {
    final coins = game.totalCoins;
    final canAffordMoves = coins >= GameConstants.extraMovesCost;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),

            // Sad icon
            const Icon(Icons.sentiment_dissatisfied_rounded,
                color: Colors.redAccent, size: 90),
            const SizedBox(height: 12),

            const Text(
              'OUT OF MOVES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'So close! Try again or grab more moves.',
              style:
                  TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Score + coin balance
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: Colors.white.withOpacity(0.15), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(children: [
                    const Text('Score',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text('${game.score}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ]),
                  Container(width: 1, height: 36, color: Colors.white12),
                  Column(children: [
                    const Text('Coins',
                        style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Row(children: [
                      const Icon(Icons.monetization_on,
                          color: Colors.amber, size: 16),
                      const SizedBox(width: 3),
                      Text('$coins',
                          style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Option 1: Watch Ad — always free ──────────────────────────────
            _Btn(
              label: 'Watch Ad for +5 Moves',
              icon: Icons.play_circle_outline_rounded,
              color: Colors.amberAccent,
              onTap: () {
                AdMobService().showRewardedAd(type: 'extra_moves');
                game.claimRewardMoves(5);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),

            // ── Option 2: Use coins ────────────────────────────────────────────
            _Btn(
              label: canAffordMoves
                  ? 'Use ${GameConstants.extraMovesCost} Coins for +5 Moves'
                  : 'Not enough coins (need ${GameConstants.extraMovesCost})',
              icon: Icons.monetization_on_rounded,
              color: canAffordMoves ? Colors.purpleAccent : Colors.white24,
              onTap: canAffordMoves
                  ? () {
                      game.buyExtraMoves();
                      Navigator.pop(context);
                    }
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ShopScreen()),
                      ),
            ),
            const SizedBox(height: 24),

            const _Divider(),
            const SizedBox(height: 20),

            // ── Retry (costs a life) ───────────────────────────────────────────
            _Btn(
              label: 'Retry  (${game.lives} lives left)',
              icon: Icons.refresh_rounded,
              color: Colors.orangeAccent,
              onTap: () {
                if (game.lives > 0) {
                  game.useLifeAndRestart();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const GameScreen()),
                  );
                } else {
                  _showNoLivesDialog(context, game);
                }
              },
            ),
            const SizedBox(height: 12),

            // ── Shop shortcut ──────────────────────────────────────────────────
            _Btn(
              label: 'Visit Shop',
              icon: Icons.storefront_rounded,
              color: Colors.blueAccent,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopScreen()),
              ),
            ),
            const SizedBox(height: 12),

            // ── Menu ───────────────────────────────────────────────────────────
            _Btn(
              label: 'Main Menu',
              icon: Icons.home_rounded,
              color: Colors.white60,
              onTap: () {
                AudioService().playBGM();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (r) => false,
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showNoLivesDialog(BuildContext context, GameProvider game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.redAccent.withOpacity(0.5), width: 1),
        ),
        title: const Text('No Lives Left!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.favorite_border, color: Colors.redAccent, size: 56),
          const SizedBox(height: 16),
          const Text(
            'All lives are used up.\nWatch a video to get one free life!',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              AdMobService().showRewardedAd(type: 'life');
              game.claimRewardLife();
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: const Text('Watch Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _Btn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 12),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ]),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Container(height: 1, color: Colors.white12)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('OR',
            style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 12,
                fontWeight: FontWeight.bold)),
      ),
      Expanded(child: Container(height: 1, color: Colors.white12)),
    ]);
  }
}
