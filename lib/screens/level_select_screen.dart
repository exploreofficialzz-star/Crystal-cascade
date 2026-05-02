import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/game_provider.dart';
import '../models/level.dart';
import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../widgets/ad_banner_widget.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  @override
  void initState() {
    super.initState();
    AdMobService().preloadAds();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg_levelselect.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.4),
                Colors.black.withOpacity(0.7),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(context),
                const AdBannerWidget(),
                Expanded(
                  child: Consumer<GameProvider>(
                    builder: (context, game, child) {
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: game.levels.length,
                        itemBuilder: (context, index) {
                          final level = game.levels[index];
                          return _buildLevelCard(context, level, game);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Select Level',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelCard(BuildContext context, Level level, GameProvider game) {
    final bool isLocked = !level.isUnlocked;
    final bool isCompleted = level.bestStars != null;

    return GestureDetector(
      onTap: isLocked
          ? null
          : () {
              AudioService().playTap();
              game.startLevel(level);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GameScreen()),
              );
            },
      child: Container(
        decoration: BoxDecoration(
          gradient: isLocked
              ? null
              : LinearGradient(
                  colors: [
                    Colors.purpleAccent.withOpacity(0.3),
                    Colors.blueAccent.withOpacity(0.3),
                  ],
                ),
          color: isLocked ? Colors.black.withOpacity(0.4) : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked
                ? Colors.white.withOpacity(0.1)
                : Colors.white.withOpacity(0.3),
            width: isLocked ? 1 : 2,
          ),
          boxShadow: isLocked
              ? null
              : [
                  BoxShadow(
                    color: Colors.purpleAccent.withOpacity(0.2),
                    blurRadius: 10,
                  ),
                ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLocked)
              Icon(
                Icons.lock,
                color: Colors.white.withOpacity(0.3),
                size: 28,
              )
            else if (isCompleted)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  return Icon(
                    Icons.star,
                    color: i < (level.bestStars ?? 0)
                        ? Colors.amber
                        : Colors.white.withOpacity(0.2),
                    size: 16,
                  );
                }),
              )
            else
              Shimmer.fromColors(
                baseColor: Colors.white.withOpacity(0.5),
                highlightColor: Colors.purpleAccent,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              '${level.id}',
              style: TextStyle(
                color: isLocked
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
