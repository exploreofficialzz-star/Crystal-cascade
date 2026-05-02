import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart';
import '../providers/game_provider.dart';
import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../widgets/ad_banner_widget.dart';
import 'game_screen.dart';
import 'home_screen.dart';
import 'level_select_screen.dart';

class GameOverScreen extends StatefulWidget {
  const GameOverScreen({super.key});

  @override
  State<GameOverScreen> createState() => _GameOverScreenState();
}

class _GameOverScreenState extends State<GameOverScreen> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, game, child) {
        final isWin = game.status == GameStatus.won;

        if (isWin && _confettiController.state != ConfettiControllerState.playing) {
          _confettiController.play();
        }

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
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              child: SafeArea(
                child: Stack(
                  children: [
                    // Confetti for win
                    if (isWin)
                      Align(
                        alignment: Alignment.topCenter,
                        child: ConfettiWidget(
                          confettiController: _confettiController,
                          blastDirectionality: BlastDirectionality.explosive,
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
                        const AdBannerWidget(),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Result Icon
                              Icon(
                                isWin ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                                color: isWin ? Colors.amber : Colors.redAccent,
                                size: 80,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                isWin ? 'LEVEL COMPLETE!' : 'OUT OF MOVES',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 30),
                              // Stars
                              if (isWin)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(3, (index) {
                                    return AnimatedContainer(
                                      duration: Duration(
                                        milliseconds: 300 + (index * 200),
                                      ),
                                      margin: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Icon(
                                        Icons.star,
                                        color: index < game.stars
                                            ? Colors.amber
                                            : Colors.white.withOpacity(0.2),
                                        size: 50,
                                      ),
                                    );
                                  }),
                                ),
                              const SizedBox(height: 30),
                              // Score
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Score: ${game.score}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (isWin)
                                      Text(
                                        '+${GameConstants.coinsPerLevelComplete} Coins',
                                        style: TextStyle(
                                          color: Colors.amber.withOpacity(0.8),
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 40),
                              // Buttons
                              if (isWin)
                                _buildActionButton(
                                  'Next Level',
                                  Icons.arrow_forward,
                                  Colors.greenAccent,
                                  () => _nextLevel(context, game),
                                )
                              else
                                _buildActionButton(
                                  'Watch Ad for +5 Moves',
                                  Icons.play_circle_outline,
                                  Colors.amberAccent,
                                  () {
                                    AdMobService().showRewardedAd(type: 'extra_moves');
                                    game.claimRewardMoves(5);
                                    Navigator.pop(context);
                                  },
                                ),
                              const SizedBox(height: 16),
                              _buildActionButton(
                                'Retry',
                                Icons.refresh,
                                Colors.orangeAccent,
                                () {
                                  if (game.lives > 0) {
                                    game.useLifeAndRestart();
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => const GameScreen(),
                                      ),
                                    );
                                  } else {
                                    _showNoLivesDialog(context);
                                  }
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildActionButton(
                                'Menu',
                                Icons.home,
                                Colors.white70,
                                () {
                                  AudioService().playBGM();
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const HomeScreen(),
                                    ),
                                    (route) => false,
                                  );
                                },
                              ),
                            ],
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

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 260,
        height: 55,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextLevel(BuildContext context, GameProvider game) {
    final currentId = game.currentLevel?.id ?? 1;
    if (currentId < game.levels.length) {
      final nextLevel = game.levels[currentId];
      game.startLevel(nextLevel);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const GameScreen()),
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
        (route) => false,
      );
    }
  }

  void _showNoLivesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.redAccent.withOpacity(0.5),
            width: 1,
          ),
        ),
        title: const Text(
          'No Lives Left',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.favorite_border,
              color: Colors.redAccent,
              size: 50,
            ),
            const SizedBox(height: 16),
            Text(
              'Watch a video to get a free life!',
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              AdMobService().showRewardedAd(type: 'life');
              context.read<GameProvider>().claimRewardLife();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Watch Video'),
          ),
        ],
      ),
    );
  }
}
