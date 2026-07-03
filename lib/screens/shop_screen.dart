import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../services/admob_service.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';
import '../widgets/native_ad_widget.dart';

class ShopScreen extends StatefulWidget {
  /// When true, page opens scrolled to the Remove Ads section.
  /// Used by the ad-block wall "Go Ad-Free" button.
  final bool scrollToRemoveAds;

  const ShopScreen({super.key, this.scrollToRemoveAds = false});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final StorageService _storage = StorageService();
  final ScrollController _scrollCtrl = ScrollController();

  StreamSubscription<IAPResult>? _iapSub;
  String? _purchasingId; // product currently being purchased

  // Key used to scroll to Remove Ads section
  final GlobalKey _removeAdsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _listenToIAP();

    // Scroll to Remove Ads after first frame if requested
    if (widget.scrollToRemoveAds) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToRemoveAds());
    }
  }

  void _listenToIAP() {
    _iapSub = IAPService().purchaseResultStream.listen((result) {
      if (!mounted) return;
      setState(() => _purchasingId = null);

      if (result.error == 'canceled') return; // user dismissed → silent

      if (result.success) {
        setState(() {}); // refresh coins, hints, remove-ads badge
        _snack('✅ Purchase successful!', Colors.greenAccent);
      } else if (result.error != null) {
        _snack('❌ ${result.error}', Colors.redAccent);
      }
    });
  }

  void _scrollToRemoveAds() {
    final ctx = _removeAdsKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      duration: const Duration(seconds: 3),
    ));
  }

  /// Triggers a real store purchase. Shows loading on the tapped card.
  void _buy(String productId) async {
    if (_purchasingId != null) return; // block double-tap
    setState(() => _purchasingId = productId);
    await IAPService().buyProduct(context, productId);
    // Result handled by stream listener above
  }

  @override
  void dispose() {
    _iapSub?.cancel();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {}); // refresh remove-ads badge when returning to screen
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
              Expanded(
                child: Consumer<GameProvider>(
                  builder: (context, game, _) => ListView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildBalanceCard(game),
                      const SizedBox(height: 24),

                      // ── Free Coins ─────────────────────────────────────
                      _sectionTitle('Free Coins'),
                      _freeCard(
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
                      _freeCard(
                        'Daily Bonus',
                        'Claim your 50-coin daily reward',
                        Icons.card_giftcard,
                        Colors.greenAccent,
                        () {
                          AudioService().playCoin();
                          game.claimRewardCoins(50);
                          _snack('🎁 50 coins claimed!', Colors.amber);
                        },
                      ),
                      const SizedBox(height: 24),

                      // ── Native ad — blends into the list, not a wall ────
                      const NativeAdWidget(),
                      const SizedBox(height: 24),

                      // ── Hints ──────────────────────────────────────────
                      _sectionTitle('Hints  (you have ${game.hints})'),
                      _hintAdCard(game),
                      const SizedBox(height: 8),
                      _premiumCard(
                        productId: IAPService.hintPackSmallId,
                        title: 'Hint Pack — Small',
                        subtitle:
                            '${GameConstants.hintPackSmallCount} hints, ready when you need them',
                        icon: Icons.lightbulb,
                        color: Colors.yellowAccent,
                      ),
                      const SizedBox(height: 8),
                      _premiumCard(
                        productId: IAPService.hintPackLargeId,
                        title: 'Hint Pack — Large',
                        subtitle:
                            '${GameConstants.hintPackLargeCount} hints  ·  best value',
                        icon: Icons.lightbulb_circle,
                        color: Colors.amber,
                        badge: 'BEST VALUE',
                      ),
                      const SizedBox(height: 24),

                      // ── Remove Ads ─────────────────────────────────────
                      _sectionTitle('Remove Ads', key: _removeAdsKey),
                      _removeAdsBanner(),
                      const SizedBox(height: 12),
                      _removeAdsTierCard(
                        productId: IAPService.removeAdsDayId,
                        label: '☀️  Day Pass',
                        description: 'Ad-free for 24 hours',
                        tier: 'day',
                        color: Colors.orangeAccent,
                        durationMs: GameConstants.removeAdsDayMs,
                      ),
                      const SizedBox(height: 8),
                      _removeAdsTierCard(
                        productId: IAPService.removeAdsWeekendId,
                        label: '📅  Weekend Pass',
                        description: 'Ad-free for 48 hours — great for binge sessions',
                        tier: 'weekend',
                        color: Colors.blueAccent,
                        durationMs: GameConstants.removeAdsWeekendMs,
                      ),
                      const SizedBox(height: 8),
                      _removeAdsTierCard(
                        productId: IAPService.removeAdsMonthId,
                        label: '🌙  Monthly Pass',
                        description: 'Ad-free for 30 days — best deal',
                        tier: 'month',
                        color: Colors.purpleAccent,
                        durationMs: GameConstants.removeAdsMonthMs,
                        badge: 'BEST DEAL',
                      ),
                      const SizedBox(height: 24),

                      // ── Coin Packs ─────────────────────────────────────
                      _sectionTitle('Coin Packs'),
                      _premiumCard(
                        productId: IAPService.coinPackStarterId,
                        title: 'Coin Pack',
                        subtitle: '500 coins + 5 hints',
                        icon: Icons.stars,
                        color: Colors.amber,
                      ),
                      const SizedBox(height: 8),
                      _premiumCard(
                        productId: IAPService.megaPackId,
                        title: 'Mega Pack',
                        subtitle: '2 000 coins + 20 hints + 48 h No Ads',
                        icon: Icons.diamond,
                        color: Colors.blueAccent,
                        badge: 'POPULAR',
                      ),
                      const SizedBox(height: 24),

                      // ── Restore Purchases ──────────────────────────────
                      _restoreButton(),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Balance card ─────────────────────────────────────────────────────────
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
          _statBadge(Icons.account_balance_wallet, '${game.totalCoins}',
              'Coins', Colors.amber),
          Container(width: 1, height: 40, color: Colors.white12),
          _statBadge(
              Icons.lightbulb, '${game.hints}', 'Hints', Colors.yellowAccent),
          Container(width: 1, height: 40, color: Colors.white12),
          _statBadge(
              Icons.favorite, '${game.lives}', 'Lives', Colors.redAccent),
        ],
      ),
    );
  }

  Widget _statBadge(IconData icon, String value, String label, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
              color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label,
          style:
              TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
    ]);
  }

  // ─── Hint watch-ad card ───────────────────────────────────────────────────
  Widget _hintAdCard(GameProvider game) {
    return GestureDetector(
      onTap: () {
        AdMobService().onRewardEarned.first.then((_) {
          game.addHints(1);
          _snack('💡 You got 1 hint!', Colors.amber);
        });
        AdMobService().showRewardedAd(type: 'hint');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.yellowAccent.withOpacity(0.3), width: 1),
        ),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                color: Colors.yellowAccent.withOpacity(0.2),
                shape: BoxShape.circle),
            child: const Icon(Icons.play_circle_fill,
                color: Colors.yellowAccent, size: 24),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Watch Video',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              Text('Get 1 free hint',
                  style: TextStyle(color: Colors.white60, fontSize: 13)),
            ]),
          ),
          const Icon(Icons.arrow_forward_ios,
              color: Colors.yellowAccent, size: 16),
        ]),
      ),
    );
  }

  // ─── Remove Ads active banner ─────────────────────────────────────────────
  Widget _removeAdsBanner() {
    if (!_storage.isAdsRemoved()) return const SizedBox.shrink();
    final expiry =
        DateTime.fromMillisecondsSinceEpoch(_storage.getRemoveAdsExpiry());
    final rem = expiry.difference(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 1),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Ads removed! Expires in ${rem.inHours}h ${rem.inMinutes % 60}m',
            style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  // ─── Remove Ads tier card ─────────────────────────────────────────────────
  Widget _removeAdsTierCard({
    required String productId,
    required String label,
    required String description,
    required String tier,
    required Color color,
    required int durationMs,
    String? badge,
  }) {
    final isActive = _storage.getRemoveAdsTier() == tier && _storage.isAdsRemoved();
    final isLoading = _purchasingId == productId;
    final price = IAPService().priceFor(productId);

    return GestureDetector(
      onTap: isActive || isLoading ? null : () => _buy(productId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            isActive
                ? Colors.greenAccent.withOpacity(0.15)
                : color.withOpacity(0.12),
            color.withOpacity(0.04),
          ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? Colors.greenAccent.withOpacity(0.6)
                : color.withOpacity(0.45),
            width: isActive ? 2 : 1.5,
          ),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 12)],
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  _badge(badge, color),
                ],
                if (isActive) ...[
                  const SizedBox(width: 8),
                  _badge('ACTIVE', Colors.greenAccent),
                ],
              ]),
              const SizedBox(height: 4),
              Text(description,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.55), fontSize: 12)),
            ]),
          ),
          const SizedBox(width: 12),
          _priceChip(
            isActive ? '✓' : price,
            isActive ? Colors.greenAccent : color,
            isLoading: isLoading,
          ),
        ]),
      ),
    );
  }

  // ─── Generic premium card ─────────────────────────────────────────────────
  Widget _premiumCard({
    required String productId,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? badge,
  }) {
    final isLoading = _purchasingId == productId;
    final price = IAPService().priceFor(productId);

    return GestureDetector(
      onTap: isLoading ? null : () => _buy(productId),
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
        child: Row(children: [
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
                  Row(children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold)),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      _badge(badge, color),
                    ],
                  ]),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 12)),
                ]),
          ),
          _priceChip(price, color, isLoading: isLoading),
        ]),
      ),
    );
  }

  // ─── Shared helpers ───────────────────────────────────────────────────────
  Widget _priceChip(String label, Color color, {bool isLoading = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
      ),
      child: isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: color),
            )
          : Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }

  Widget _freeCard(String title, String subtitle, IconData icon, Color color,
      VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(children: [
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
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 13)),
                ]),
          ),
          Icon(Icons.arrow_forward_ios, color: color.withOpacity(0.5), size: 16),
        ]),
      ),
    );
  }

  Widget _sectionTitle(String title, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: TextStyle(
              color: Colors.purpleAccent.withOpacity(0.8),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8)),
    );
  }

  Widget _restoreButton() {
    return Center(
      child: TextButton.icon(
        onPressed: () async {
          await IAPService().restorePurchases();
          _snack('Restoring purchases…', Colors.blueAccent);
        },
        icon: const Icon(Icons.restore, color: Colors.white38, size: 18),
        label: const Text('Restore Purchases',
            style: TextStyle(color: Colors.white38, fontSize: 13)),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Text('Shop',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
