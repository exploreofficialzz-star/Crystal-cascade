import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/game_provider.dart';
import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../utils/constants.dart';
import '../widgets/ad_banner_widget.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
              _buildAppBar(context),
              const AdBannerWidget(),
              Expanded(
                child: Consumer<GameProvider>(
                  builder: (context, game, child) {
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Current Balance
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.amber.withOpacity(0.2),
                                Colors.orange.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.account_balance_wallet,
                                color: Colors.amber,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '${game.totalCoins}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Free Coins Section
                        _buildSectionTitle('Free Coins'),
                        _buildFreeCoinCard(
                          'Watch Video',
                          'Get 20 coins free',
                          Icons.play_circle_fill,
                          Colors.purpleAccent,
                          () {
                            AdMobService().showRewardedAd(type: 'coins');
                            game.claimRewardCoins(20);
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildFreeCoinCard(
                          'Daily Bonus',
                          'Claim your daily reward',
                          Icons.card_giftcard,
                          Colors.greenAccent,
                          () {
                            AudioService().playCoin();
                            game.claimRewardCoins(50);
                            _showClaimedDialog(context, 50);
                          },
                        ),
                        const SizedBox(height: 24),
                        // Remove Ads
                        _buildSectionTitle('Premium'),
                        _buildPremiumCard(
                          'Remove Ads',
                          'Enjoy ad-free gameplay forever',
                          Icons.block,
                          Colors.redAccent,
                          '\$2.99',
                          () => _showPurchaseDialog(context, 'Remove Ads', '\$2.99'),
                        ),
                        const SizedBox(height: 8),
                        _buildPremiumCard(
                          'Coin Pack',
                          '500 coins + 5 hints',
                          Icons.stars,
                          Colors.amber,
                          '\$0.99',
                          () => _showPurchaseDialog(context, 'Coin Pack', '\$0.99'),
                        ),
                        const SizedBox(height: 8),
                        _buildPremiumCard(
                          'Mega Pack',
                          '2000 coins + 20 hints + No Ads',
                          Icons.diamond,
                          Colors.blueAccent,
                          '\$4.99',
                          () => _showPurchaseDialog(context, 'Mega Pack', '\$4.99'),
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
              'Shop',
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.purpleAccent.withOpacity(0.8),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildFreeCoinCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    String price,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                price,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showClaimedDialog(BuildContext context, int amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Colors.amber.withOpacity(0.5),
            width: 1,
          ),
        ),
        title: const Text(
          'Reward Claimed!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.greenAccent,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              'You received $amount coins!',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context, String item, String price) {
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
        title: Text(
          'Buy $item?',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Purchase for $price?\n\nThis is a demo. In production, integrate with in_app_purchase package.',
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
              Navigator.pop(context);
              _showPurchaseSuccess(context, item);
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

  void _showPurchaseSuccess(BuildContext context, String item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.greenAccent, width: 1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.greenAccent,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              '$item purchased!',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
