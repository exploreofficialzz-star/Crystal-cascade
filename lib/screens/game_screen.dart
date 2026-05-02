import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/tube_widget.dart';
import 'game_over_screen.dart';
import 'home_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final game = context.read<GameProvider>();
        if (game.status == GameStatus.playing) {
          game.pauseGame();
          _showPauseMenu(context);
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: Consumer<GameProvider>(
          builder: (context, game, child) {
            if (game.status == GameStatus.won || game.status == GameStatus.lost) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  AdMobService().showInterstitialAd();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const GameOverScreen()),
                  );
                }
              });
            }

            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1a1a2e),
                    Color(0xFF16213e),
                    Color(0xFF0f3460),
                    Color(0xFF533483),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Top HUD
                    _buildTopHUD(game),
                    const SizedBox(height: 8),
                    const AdBannerWidget(),
                    const SizedBox(height: 8),
                    // Game Area
                    Expanded(
                      child: _buildGameArea(game),
                    ),
                    // Bottom Controls
                    _buildBottomControls(game),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopHUD(GameProvider game) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          _buildHUDButton(
            Icons.arrow_back_ios,
            () => _onBackPressed(context),
          ),
          // Level & Moves
          Expanded(
            child: Column(
              children: [
                Text(
                  'Level ${game.currentLevel?.id ?? 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: game.movesRemaining <= 3
                            ? Colors.red.withOpacity(0.3 + _pulseController.value * 0.3)
                            : Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: game.movesRemaining <= 3
                              ? Colors.redAccent.withOpacity(0.8)
                              : Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Moves: ${game.movesRemaining}',
                        style: TextStyle(
                          color: game.movesRemaining <= 3
                              ? Colors.redAccent
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // Pause button
          _buildHUDButton(
            Icons.pause,
            () {
              game.pauseGame();
              _showPauseMenu(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHUDButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildGameArea(GameProvider game) {
    final tubeCount = game.tubes.length;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    if (isPortrait) {
      // Portrait: wrap tubes in rows
      return Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 16,
          children: List.generate(tubeCount, (index) {
            return TubeWidget(
              gems: game.tubes[index],
              capacity: game.currentLevel?.tubeCapacity ?? 4,
              isSelected: game.selectedTubeIndex == index,
              onTap: () => game.onTubeTap(index),
              width: 65,
              gemSize: 48,
            );
          }),
        ),
      );
    } else {
      // Landscape: horizontal scroll
      return Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(tubeCount, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TubeWidget(
                  gems: game.tubes[index],
                  capacity: game.currentLevel?.tubeCapacity ?? 4,
                  isSelected: game.selectedTubeIndex == index,
                  onTap: () => game.onTubeTap(index),
                  width: 70,
                  gemSize: 52,
                ),
              );
            }),
          ),
        ),
      );
    }
  }

  Widget _buildBottomControls(GameProvider game) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            Icons.lightbulb_outline,
            'Hint',
            Colors.yellowAccent,
            () => game.useHint(),
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
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
            ),
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PauseDialog(),
    );
  }

  void _showExtraMovesDialog(BuildContext context) {
    final game = context.read<GameProvider>();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.purpleAccent.withOpacity(0.5),
            width: 1,
          ),
        ),
        title: const Text(
          'Extra Moves',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add_circle,
              color: Colors.greenAccent,
              size: 50,
            ),
            const SizedBox(height: 16),
            Text(
              'Get +5 moves for ${GameConstants.extraMovesCost} coins?',
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Or watch a video for free!',
              style: TextStyle(
                color: Colors.amberAccent.withOpacity(0.8),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              AdMobService().showRewardedAd(type: 'extra_moves');
              Navigator.pop(context);
            },
            child: const Text(
              'Watch Video',
              style: TextStyle(color: Colors.amberAccent),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              game.buyExtraMoves();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Buy'),
          ),
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
          side: BorderSide(
            color: Colors.orangeAccent.withOpacity(0.5),
            width: 1,
          ),
        ),
        title: const Text(
          'Restart Level?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Your current progress will be lost.',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
          textAlign: TextAlign.center,
        ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }
}

class _PauseDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.read<GameProvider>();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1a1a2e).withOpacity(0.95),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.purpleAccent.withOpacity(0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.purpleAccent.withOpacity(0.2),
              blurRadius: 30,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'PAUSED',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 30),
            _buildPauseButton(
              'Resume',
              Icons.play_arrow,
              Colors.greenAccent,
              () {
                game.resumeGame();
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _buildPauseButton(
              'Restart',
              Icons.refresh,
              Colors.orangeAccent,
              () {
                game.restartLevel();
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _buildPauseButton(
              'Settings',
              Icons.settings,
              Colors.blueAccent,
              () {
                // Navigate to settings
              },
            ),
            const SizedBox(height: 12),
            _buildPauseButton(
              'Quit',
              Icons.exit_to_app,
              Colors.redAccent,
              () {
                AudioService().playBGM();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPauseButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        height: 50,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
