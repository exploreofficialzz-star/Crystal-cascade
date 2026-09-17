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
  StreamSubscription<String>? _rewardSub;

  String? _purchasingId; // product currently being purchased
  bool _claimingDaily = false; // guards a fast double-tap during the async claim write
  bool _watchingAdForCoins = false; // prevents double-tap on Watch Video → Coins
  bool _watchingAdForHint = false;  // prevents double-tap on Watch Video → Hint

  // Key used to scroll to Remove Ads section
  final GlobalKey _removeAdsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _listenToIAP();
    _listenToAdRewards();

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

  // Subscribe to ad rewards with type filtering — avoids the dangerous .first
  // pattern which could fire for the wrong reward type or hang indefinitely.
  void _listenToAdRewards() {
    _rewardSub = AdMobService().onRewardEarned.listen((type) {
      if (!mounted) return;

      switch (type) {
        case 'coins':
          if (_watchingAdForCoins) {
            _watchingAdForCoins = false;
            context.read<GameProvider>().claimRewardCoins(20);
            _snack('🪙 +20 coins!', Colors.amber);
          }

        case 'hint':
          if (_watchingAdForHint) {
            _watchingAdForHint = false;
            context.read<GameProvider>().addHints(1);
            _snack('💡 You got 1 hint!', Colors.amber);
          }
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
    if (!IAPService().isProductAvailable(productId)) {
      _snack('⚠️ This product is not available yet. Try again later.', Colors.orangeAccent);
      return;
    }
    setState(() => _purchasingId = productId);
    await IAPService().buyProduct(context, productId);
    // Result handled by stream listener above
  }

  @override
  void dispose() {
    _iapSub?.cancel();
    _rewardSub?.cancel();
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
                  builder: (context, game, _) {
                    final canClaimDaily = StorageService().canClaimDailyBonus();
                    final dailyRemaining = StorageService().getDailyBonusTimeRemaining();
                    return ListView(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildBalanceCard(game),
                      const SizedBox(height: 24),

                      // ── Store availability notice ───────────────────────
                      if (!IAPService().isAvailable)
                        _storeUnavailableNotice(),

                      // ── Free Coins ─────────────────────────────────────
                      _sectionTitle('Free Coins'),
                      _freeCard(
                        'Watch Video',
                        'Get 20 coins free',
                        Icons.play_circle_fill,
                        Colors.purpleAccent,
                        _watchingAdForCoins
                            ? null // already watching
                            : () {
                                setState(() => _watchingAdForCoins = true);
                                AdMobService().showRewardedAd(type: 'coins');
                                // Coins are granted by _listenToAdRewards when
                                // the reward fires — NOT here.
                              },
                      ),
                      const SizedBox(height: 8),
                      _freeCard(
                        'Daily Bonus',
                        canClaimDaily
                            ? 'Claim your ${GameConstants.dailyBonusCoins}-coin daily reward'
                            : 'Come back in ${_formatDuration(dailyRemaining)}',
                        canClaimDaily ? Icons.card_giftcard : Icons.timer,
                        canClaimDaily ? Colors.greenAccent : Colors.grey,
                        canClaimDaily
                            ? () async {
                                if (_claimingDaily) return;
                                setState(() => _claimingDaily = true);
                                await StorageService().claimDailyBonus();
                                AudioService().playCoin();
                                game.claimRewardCoins(GameConstants.dailyBonusCoins);
                                _snack('🎁 ${GameConstants.dailyBonusCoins} coins claimed!',
                                    Colors.amber);
                                if (mounted) setState(() => _claimingDaily = false);
                              }
                            : () => _snack(
                                'Come back in ${_formatDuration(dailyRemaining)}!',
                                Colors.orangeAccent),
                      ),
                      const SizedBox(height: 24),

                      // ── Native ad — blends into the list, not a wall ────
                      const NativeAdWidget(),
                      const SizedBox(height: 24),

                      // ── Hints ──────────────────────────────────────────
                      _sectionTitle('Hints  (you have ${game.hints})'),
                      _hintAdCard(),
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

  // ─── Store unavailable notice ─────────────────────────────────────────────
  Widget _storeUnavailableNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.5), width: 1),
      ),
      child: const Row(children: [
        Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Store is unavailable. Purchases are disabled until connectivity is restored.',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
          ),
        ),
      ]),
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
  Widget _hintAdCard() {
    return GestureDetector(
      onTap: _watchingAdForHint
          ? null
          : () {
              setState(() => _watchingAdForHint = true);
              AdMobService().showRewardedAd(type: 'hint');
              // Hint is granted by _listenToAdRewards when the reward fires.
            },
      child: AnimatedOpacity(
        opacity: _watchingAdForHint ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
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
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _watchingAdForHint ? 'Ad loading…' : 'Watch Video',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
                const Text('Get 1 free hint',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios,
                color: Colors.yellowAccent, size: 16),
          ]),
        ),
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
    final isAvailable = IAPService().isProductAvailable(productId);
    final price = IAPService().priceFor(productId);

    return GestureDetector(
      onTap: isActive || isLoading || !isAvailable ? null : () => _buy(productId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            isActive
                ? Colors.greenAccent.withOpacity(0.15)
                : color.withOpacity(isAvailable ? 0.12 : 0.05),
            color.withOpacity(0.04),
          ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? Colors.greenAccent.withOpacity(0.6)
                : color.withOpacity(isAvailable ? 0.45 : 0.2),
            width: isActive ? 2 : 1.5,
          ),
          boxShadow: [BoxShadow(color: color.withOpacity(isAvailable ? 0.1 : 0.03), blurRadius: 12)],
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(label,
                    style: TextStyle(
                        color: isAvailable ? Colors.white : Colors.white38,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
                if (badge != null) ...[ const SizedBox(width: 8), _badge(badge, color) ],
                if (isActive) ...[ const SizedBox(width: 8), _badge('ACTIVE', Colors.greenAccent) ],
              ]),
              const SizedBox(height: 4),
              Text(description,
                  style: TextStyle(
                      color: Colors.white.withOpacity(isAvailable ? 0.55 : 0.3),
                      fontSize: 12)),
              if (!isAvailable && IAPService().isAvailable)
                const Text('Coming soon',
                    style: TextStyle(color: Colors.white38, fontSize: 10)),
            ]),
          ),
          const SizedBox(width: 12),
          _priceChip(
            isActive ? '✓' : (isAvailable ? price : '—'),
            isActive ? Colors.greenAccent : (isAvailable ? color : Colors.white24),
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
    final isAvailable = IAPService().isProductAvailable(productId);
    final price = IAPService().priceFor(productId);

    return GestureDetector(
      onTap: isLoading || !isAvailable ? null : () => _buy(productId),
      child: AnimatedOpacity(
        opacity: isAvailable ? 1.0 : 0.5,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              color.withOpacity(isAvailable ? 0.15 : 0.06),
              color.withOpacity(0.05),
            ]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(isAvailable ? 0.4 : 0.15), width: 1.5),
            boxShadow: [BoxShadow(color: color.withOpacity(isAvailable ? 0.1 : 0.03), blurRadius: 10)],
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
                          style: TextStyle(
                              color: isAvailable ? Colors.white : Colors.white38,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                      if (badge != null) ...[ const SizedBox(width: 6), _badge(badge, color) ],
                    ]),
                    Text(subtitle,
                        style: TextStyle(
                            color: Colors.white.withOpacity(isAvailable ? 0.6 : 0.3),
                            fontSize: 12)),
                    if (!isAvailable && IAPService().isAvailable)
                      const Text('Coming soon',
                          style: TextStyle(color: Colors.white38, fontSize: 10)),
                  ]),
            ),
            _priceChip(
              isAvailable ? price : '—',
              isAvailable ? color : Colors.white24,
              isLoading: isLoading,
            ),
          ]),
        ),
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

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return 'a moment';
  }

  Widget _freeCard(String title, String subtitle, IconData icon, Color color,
      VoidCallback? onTap) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: isDisabled ? 0.55 : 1.0,
        duration: const Duration(milliseconds: 200),
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
