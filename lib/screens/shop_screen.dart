import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/ad_banner_widget.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final StorageService _storage = StorageService();

  // Rebuild whenever we return to this page so the active-tier badge refreshes
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {});
  }

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
                        // ── Balance ──────────────────────────────────────────
                        _buildBalanceCard(game),
                        const SizedBox(height: 24),

                        // ── Free Coins ───────────────────────────────────────
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
                          'Claim your 50-coin daily reward',
                          Icons.card_giftcard,
                          Colors.greenAccent,
                          () {
                            AudioService().playCoin();
                            game.claimRewardCoins(50);
                            _showClaimedDialog(context, 50);
                          },
                        ),
                        const SizedBox(height: 24),

                        // ── Hints ────────────────────────────────────────────
                        _buildSectionTitle('Hints  (you have ${game.hints})'),
                        _buildHintAdCard(game),
                        const SizedBox(height: 8),
                        _buildPremiumCard(
                          title: 'Hint Pack — Small',
                          subtitle: '${GameConstants.hintPackSmallCount} hints, ready when you need them',
                          icon: Icons.lightbulb,
                          color: Colors.yellowAccent,
                          price: GameConstants.hintPackSmallPrice,
                          badge: null,
                          onTap: () => _showPurchaseDialog(
                            context,
                            'Hint Pack (${GameConstants.hintPackSmallCount} hints)',
                            GameConstants.hintPackSmallPrice,
                            onConfirm: () => game.addHints(GameConstants.hintPackSmallCount),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPremiumCard(
                          title: 'Hint Pack — Large',
                          subtitle: '${GameConstants.hintPackLargeCount} hints  ·  best value',
                          icon: Icons.lightbulb_circle,
                          color: Colors.amber,
                          price: GameConstants.hintPackLargePrice,
                          badge: 'BEST VALUE',
                          onTap: () => _showPurchaseDialog(
                            context,
                            'Hint Pack (${GameConstants.hintPackLargeCount} hints)',
                            GameConstants.hintPackLargePrice,
                            onConfirm: () => game.addHints(GameConstants.hintPackLargeCount),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Remove Ads — Tiered ───────────────────────────────
                        _buildSectionTitle('Remove Ads'),
                        _buildRemoveAdsBanner(),
                        const SizedBox(height: 12),
                        _buildRemoveAdsTierCard(
                          label: '☀️  Day Pass',
                          description: 'Ad-free for 24 hours',
                          price: GameConstants.removeAdsDayPrice,
                          tier: 'day',
                          color: Colors.orangeAccent,
                          durationMs: GameConstants.removeAdsDayMs,
                        ),
                        const SizedBox(height: 8),
                        _buildRemoveAdsTierCard(
                          label: '📅  Weekend Pass',
                          description: 'Ad-free for 48 hours — great for binge sessions',
                          price: GameConstants.removeAdsWeekendPrice,
                          tier: 'weekend',
                          color: Colors.blueAccent,
                          durationMs: GameConstants.removeAdsWeekendMs,
                        ),
                        const SizedBox(height: 8),
                        _buildRemoveAdsTierCard(
                          label: '🌙  Monthly Pass',
                          description: 'Ad-free for 30 days — best deal',
                          price: GameConstants.removeAdsMonthPrice,
                          tier: 'month',
                          color: Colors.purpleAccent,
                          durationMs: GameConstants.removeAdsMonthMs,
                          badge: 'BEST DEAL',
                        ),
                        const SizedBox(height: 24),

                        // ── Coin Packs ────────────────────────────────────────
                        _buildSectionTitle('Coin Packs'),
                        _buildPremiumCard(
                          title: 'Coin Pack',
                          subtitle: '500 coins + 5 hints',
                          icon: Icons.stars,
                          color: Colors.amber,
                          price: '\$0.99',
                          badge: null,
                          onTap: () => _showPurchaseDialog(
                            context, 'Coin Pack', '\$0.99',
                            onConfirm: () {
                              game.claimRewardCoins(500);
                              game.addHints(5);
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPremiumCard(
                          title: 'Mega Pack',
                          subtitle: '2 000 coins + 20 hints + 48 h No Ads',
                          icon: Icons.diamond,
                          color: Colors.blueAccent,
                          price: '\$4.99',
                          badge: 'POPULAR',
                          onTap: () => _showPurchaseDialog(
                            context, 'Mega Pack', '\$4.99',
                            onConfirm: () async {
                              game.claimRewardCoins(2000);
                              game.addHints(20);
                              await _storage.setRemoveAdsTier(
                                  'weekend', GameConstants.removeAdsWeekendMs);
                              setState(() {});
                            },
                          ),
                        ),
                        const SizedBox(height: 30),
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

  // ─── Balance Card ─────────────────────────────────────────────────────────
  Widget _buildBalanceCard(GameProvider game) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Colors.amber.withOpacity(0.2),
          Colors.orange.withOpacity(0.1),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatBadge(Icons.account_balance_wallet, '${game.totalCoins}', 'Coins', Colors.amber),
          Container(width: 1, height: 40, color: Colors.white12),
          _buildStatBadge(Icons.lightbulb, '${game.hints}', 'Hints', Colors.yellowAccent),
          Container(width: 1, height: 40, color: Colors.white12),
          _buildStatBadge(Icons.favorite, '${game.lives}', 'Lives', Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
      ],
    );
  }

  // ─── Hint watch-ad card ───────────────────────────────────────────────────
  Widget _buildHintAdCard(GameProvider game) {
    return GestureDetector(
      onTap: () {
        AdMobService().onRewardEarned.first.then((_) {
          game.addHints(1);
          _showClaimedDialog(context, 0, isHint: true);
        });
        AdMobService().showRewardedAd(type: 'hint');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.yellowAccent.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.yellowAccent.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_circle_fill, color: Colors.yellowAccent, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Watch Video', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text('Get 1 free hint', style: TextStyle(color: Colors.white60, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.yellowAccent, size: 16),
          ],
        ),
      ),
    );
  }

  // ─── Remove Ads active banner ─────────────────────────────────────────────
  Widget _buildRemoveAdsBanner() {
    final isActive = _storage.isAdsRemoved();
    if (!isActive) return const SizedBox.shrink();

    final expiry = DateTime.fromMillisecondsSinceEpoch(_storage.getRemoveAdsExpiry());
    final remaining = expiry.difference(DateTime.now());
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ads removed! Expires in ${h}h ${m}m',
              style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Remove Ads tier card ─────────────────────────────────────────────────
  Widget _buildRemoveAdsTierCard({
    required String label,
    required String description,
    required String price,
    required String tier,
    required Color color,
    required int durationMs,
    String? badge,
  }) {
    final currentTier = _storage.getRemoveAdsTier();
    final isCurrentTier = currentTier == tier && _storage.isAdsRemoved();

    return GestureDetector(
      onTap: isCurrentTier
          ? null
          : () => _showRemoveAdsPurchaseDialog(
                context, label, price, tier, durationMs, color),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            isCurrentTier
                ? Colors.greenAccent.withOpacity(0.15)
                : color.withOpacity(0.12),
            color.withOpacity(0.04),
          ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrentTier
                ? Colors.greenAccent.withOpacity(0.6)
                : color.withOpacity(0.45),
            width: isCurrentTier ? 2 : 1.5,
          ),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 12)],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(badge,
                              style: TextStyle(
                                  color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                      if (isCurrentTier) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('ACTIVE',
                              style: TextStyle(
                                  color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(description,
                      style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrentTier
                    ? Colors.greenAccent.withOpacity(0.2)
                    : color.withOpacity(0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isCurrentTier ? '✓' : price,
                style: TextStyle(
                    color: isCurrentTier ? Colors.greenAccent : color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Generic premium card ─────────────────────────────────────────────────
  Widget _buildPremiumCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String price,
    required String? badge,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(badge,
                              style: TextStyle(
                                  color: color, fontSize: 8, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text(subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(price,
                  style: TextStyle(
                      color: color, fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Free coin card ───────────────────────────────────────────────────────
  Widget _buildFreeCoinCard(
      String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration:
                  BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 16),
          ],
        ),
      ),
    );
  }

  // ─── Section title ────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: TextStyle(
              color: Colors.purpleAccent.withOpacity(0.8),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8)),
    );
  }

  // ─── App bar ──────────────────────────────────────────────────────────────
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
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text('Shop',
                style: TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────
  void _showRemoveAdsPurchaseDialog(BuildContext context, String label, String price,
      String tier, int durationMs, Color color) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: color.withOpacity(0.5), width: 1),
        ),
        title: Text('Remove Ads — $label?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block, color: color, size: 52),
            const SizedBox(height: 12),
            Text(
              'Purchase $label for $price?\n\n'
              'Ads will be hidden for the full duration. '
              'Timer starts immediately after purchase.',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text('(Demo mode — wire in_app_purchase in production)',
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _storage.setRemoveAdsTier(tier, durationMs);
              if (!mounted) return;
              Navigator.pop(ctx);
              setState(() {});
              _showPurchaseSuccess(context, label);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Buy $price',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPurchaseDialog(BuildContext context, String item, String price,
      {required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5), width: 1),
        ),
        title: Text('Buy $item?',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: Text(
          'Purchase for $price?\n\n'
          'Demo mode — wire in_app_purchase in production.',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
              _showPurchaseSuccess(context, item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Buy'),
          ),
        ],
      ),
    );
  }

  void _showClaimedDialog(BuildContext context, int amount, {bool isHint = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.amber.withOpacity(0.5), width: 1),
        ),
        title: const Text('Reward Claimed!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isHint ? Icons.lightbulb : Icons.check_circle,
                color: isHint ? Colors.yellowAccent : Colors.greenAccent, size: 60),
            const SizedBox(height: 16),
            Text(
              isHint ? 'You received 1 hint!' : 'You received $amount coins!',
              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purpleAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  void _showPurchaseSuccess(BuildContext context, String item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colors.greenAccent, width: 1),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent, size: 60),
            const SizedBox(height: 16),
            Text('$item purchased!',
                style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('OK', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
