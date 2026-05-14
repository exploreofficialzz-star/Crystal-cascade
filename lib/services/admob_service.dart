import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/constants.dart';
import 'adblock_service.dart';
import 'storage_service.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  final StorageService _storage = StorageService();

  // ── Loaded ad objects ─────────────────────────────────────────────────────
  BannerAd?              _bannerAd;
  InterstitialAd?        _interstitialAd;
  RewardedAd?            _rewardedAd;
  RewardedInterstitialAd? _rewardedInterstitialAd;
  NativeAd?              _nativeAd;

  // ── Retry counters ────────────────────────────────────────────────────────
  int _interstitialRetries        = 0;
  int _rewardedRetries            = 0;
  int _rewardedInterstitialRetries = 0;
  static const int _maxRetries    = 3;

  // ── Interstitial cooldown (policy: min 30 s between fullscreen ads) ───────
  DateTime? _lastInterstitialShown;

  // ── Reward stream ─────────────────────────────────────────────────────────
  final StreamController<String> _rewardCtrl =
      StreamController<String>.broadcast();

  /// type strings: 'coins' | 'extra_moves' | 'hint' | 'life' | 'bonus'
  Stream<String> get onRewardEarned => _rewardCtrl.stream;

  bool get adsRemoved => _storage.isAdsRemoved();

  // ─── Init ─────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await MobileAds.instance.initialize();
  }

  /// Call from HomeScreen initState — preloads every ad type simultaneously.
  void preloadAds() {
    if (adsRemoved) {
      // Still preload rewarded — user can always watch for bonuses
      _loadRewardedAd();
      return;
    }
    _loadInterstitialAd();
    _loadRewardedAd();
    _loadRewardedInterstitialAd();
    // Native ad preloaded on demand (per screen)
  }

  // ─── BANNER ───────────────────────────────────────────────────────────────
  /// Returns a loaded BannerAd or null if ads removed.
  BannerAd? createBannerAd() {
    if (adsRemoved) return null;
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: GameConstants.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => debugPrint('[Ad] Banner loaded'),
        onAdFailedToLoad: (ad, error) {
          debugPrint('[Ad] Banner failed: ${error.message} (code ${error.code})');
          ad.dispose();
          // Error code 2 = network error — likely ad blocker
          if (error.code == 2) AdBlockService().recheck();
        },
      ),
    );
    _bannerAd!.load();
    return _bannerAd;
  }

  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  // ─── INTERSTITIAL ─────────────────────────────────────────────────────────
  void _loadInterstitialAd() {
    if (adsRemoved) return;
    InterstitialAd.load(
      adUnitId: GameConstants.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialRetries = 0;
          debugPrint('[Ad] Interstitial loaded');
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd(); // preload next immediately
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('[Ad] Interstitial load failed: ${error.message} (code ${error.code})');
          if (error.code == 2) AdBlockService().recheck();
          if (_interstitialRetries < _maxRetries) {
            _interstitialRetries++;
            Future.delayed(Duration(seconds: _interstitialRetries * 2),
                _loadInterstitialAd);
          }
        },
      ),
    );
  }

  /// Shows interstitial respecting the 30-second policy cooldown.
  void showInterstitialAd() {
    if (adsRemoved) return;

    final now = DateTime.now();
    if (_lastInterstitialShown != null) {
      final elapsed = now.difference(_lastInterstitialShown!).inSeconds;
      if (elapsed < GameConstants.interstitialCooldownSecs) {
        debugPrint('[Ad] Interstitial skipped — cooldown ($elapsed s)');
        _loadInterstitialAd();
        return;
      }
    }

    if (_interstitialAd != null) {
      _lastInterstitialShown = now;
      _interstitialAd!.show();
    } else {
      debugPrint('[Ad] Interstitial not ready — loading');
      _loadInterstitialAd();
    }
  }

  // ─── REWARDED ─────────────────────────────────────────────────────────────
  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: GameConstants.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedRetries = 0;
          debugPrint('[Ad] Rewarded loaded');
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('[Ad] Rewarded load failed: ${error.message} (code ${error.code})');
          if (error.code == 2) AdBlockService().recheck();
          if (_rewardedRetries < _maxRetries) {
            _rewardedRetries++;
            Future.delayed(Duration(seconds: _rewardedRetries * 2),
                _loadRewardedAd);
          }
        },
      ),
    );
  }

  /// [type] — what reward to grant: 'coins' | 'extra_moves' | 'hint' | 'life'
  void showRewardedAd({required String type}) {
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (_, reward) {
          debugPrint('[Ad] Reward earned: $type');
          _rewardCtrl.add(type);
        },
      );
    } else {
      debugPrint('[Ad] Rewarded not ready — loading');
      _loadRewardedAd();
    }
  }

  bool get isRewardedReady => _rewardedAd != null;

  // ─── REWARDED INTERSTITIAL ────────────────────────────────────────────────
  // Best for: daily bonus popup, bonus moves between levels, app-open reward.
  void _loadRewardedInterstitialAd() {
    RewardedInterstitialAd.load(
      adUnitId: GameConstants.rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd = ad;
          _rewardedInterstitialRetries = 0;
          debugPrint('[Ad] Rewarded interstitial loaded');
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedInterstitialAd = null;
              _loadRewardedInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, _) {
              ad.dispose();
              _rewardedInterstitialAd = null;
              _loadRewardedInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('[Ad] Rewarded interstitial load failed: ${error.message}');
          if (_rewardedInterstitialRetries < _maxRetries) {
            _rewardedInterstitialRetries++;
            Future.delayed(
              Duration(seconds: _rewardedInterstitialRetries * 2),
              _loadRewardedInterstitialAd,
            );
          }
        },
      ),
    );
  }

  /// Show rewarded interstitial — e.g. daily login bonus, between-level bonus.
  void showRewardedInterstitialAd({String type = 'bonus'}) {
    if (_rewardedInterstitialAd != null) {
      _rewardedInterstitialAd!.show(
        onUserEarnedReward: (_, reward) {
          debugPrint('[Ad] Rewarded interstitial reward: $type');
          _rewardCtrl.add(type);
        },
      );
    } else {
      debugPrint('[Ad] Rewarded interstitial not ready — loading');
      _loadRewardedInterstitialAd();
    }
  }

  bool get isRewardedInterstitialReady => _rewardedInterstitialAd != null;

  // ─── NATIVE ADVANCED ──────────────────────────────────────────────────────
  // Used in Shop, Level Select, and Game Over screens for in-content ads.
  NativeAd? loadNativeAd({required NativeAdListener listener}) {
    if (adsRemoved) return null;
    _nativeAd?.dispose();
    _nativeAd = NativeAd(
      adUnitId: GameConstants.nativeAdUnitId,
      listener: listener,
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: const Color(0xFF1a1a2e),
        cornerRadius: 12,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFFFFFFFF),
          backgroundColor: const Color(0xFF533483),
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFFFFFFFF),
          style: NativeTemplateFontStyle.bold,
          size: 16,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFFCCCCCC),
          style: NativeTemplateFontStyle.normal,
          size: 14,
        ),
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0xFFAAAAAA),
          style: NativeTemplateFontStyle.normal,
          size: 12,
        ),
      ),
    );
    _nativeAd!.load();
    return _nativeAd;
  }

  void disposeNativeAd() {
    _nativeAd?.dispose();
    _nativeAd = null;
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────
  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _rewardedInterstitialAd?.dispose();
    _nativeAd?.dispose();
    _rewardCtrl.close();
  }
}
