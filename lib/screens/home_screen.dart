import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../widgets/ad_banner_widget.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    AudioService().playBGM();
    AdMobService().preloadAds();
    context.read<SettingsProvider>().loadSettings();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/bg_menu.jpg'),
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
                Colors.black.withOpacity(0.6),
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const AdBannerWidget(),
                Expanded(
                  child: Consumer<GameProvider>(
                    builder: (context, game, child) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Top Bar - Coins & Lives
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildResourceChip(
                                  Icons.monetization_on,
                                  '${game.totalCoins}',
                                  Colors.amber,
                                  () => _showShop(context),
                                ),
                                _buildResourceChip(
                                  Icons.favorite,
                                  '${game.lives}/5',
                                  Colors.redAccent,
                                  null,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Logo with shimmer
                          Shimmer.fromColors(
                            baseColor: Colors.white,
                            highlightColor: Colors.purpleAccent,
                            period: const Duration(seconds: 2),
                            child: Image.asset(
                              'assets/images/game_logo.png',
                              width: 320,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            GameConstants.developerTag,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 50),
                          // Play Button
                          _buildMainButton(
                            'PLAY',
                            Icons.play_arrow_rounded,
                            Colors.purpleAccent,
                            () => _startGame(context),
                          ),
                          const SizedBox(height: 16),
                          // Level Select Button
                          _buildMainButton(
                            'LEVELS',
                            Icons.grid_view_rounded,
                            Colors.blueAccent,
                            () => _showLevels(context),
                          ),
                          const SizedBox(height: 16),
                          // Shop Button
                          _buildMainButton(
                            'SHOP',
                            Icons.shopping_bag_rounded,
                            Colors.amberAccent,
                            () => _showShop(context),
                          ),
                          const Spacer(),
                          // Bottom Row - Settings & Stars
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildIconButton(
                                  Icons.settings,
                                  () => _showSettings(context),
                                ),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${game.totalStars}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                _buildIconButton(
                                  Icons.share,
                                  () {},
                                ),
                              ],
                            ),
                          ),
                        ],
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

  Widget _buildResourceChip(
    IconData icon,
    String value,
    Color color,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 240,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.8),
                  color.withOpacity(0.6),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3 + _controller.value * 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  void _startGame(BuildContext context) {
    final game = context.read<GameProvider>();
    final nextLevel = game.levels.firstWhere(
      (l) => l.isUnlocked && l.bestStars == null,
      orElse: () => game.levels.firstWhere((l) => l.isUnlocked),
    );
    game.startLevel(nextLevel);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const GameScreen()),
    );
  }

  void _showLevels(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LevelSelectScreen()),
    );
  }

  void _showShop(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShopScreen()),
    );
  }

  void _showSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}
