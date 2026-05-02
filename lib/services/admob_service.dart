import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../utils/constants.dart';
import 'storage_service.dart';

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();
  factory AdMobService() => _instance;
  AdMobService._internal();

  final StorageService _storage = StorageService();

  BannerAd? _bannerAd;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  int _interstitialLoadAttempts = 0;
  int _rewardedLoadAttempts = 0;
  static const int maxFailedLoadAttempts = 3;

  final StreamController<bool> _rewardStreamController = StreamController<bool>.broadcast();
  Stream<bool> get onRewardEarned => _rewardStreamController.stream;

  bool get adsRemoved => _storage.getRemoveAdsPurchased();

  Future<void> init() async {
    await MobileAds.instance.initialize();
  }

  // Banner Ad
  BannerAd? createBannerAd() {
    if (adsRemoved) return null;
    _bannerAd?.dispose();
    _bannerAd = BannerAd(
      adUnitId: GameConstants.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => debugPrint('Banner ad loaded'),
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner ad failed: ${error.message}');
          ad.dispose();
        },
      ),
    );
    _bannerAd?.load();
    return _bannerAd;
  }

  void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  // Interstitial Ad
  void loadInterstitialAd() {
    if (adsRemoved) return;
    InterstitialAd.load(
      adUnitId: GameConstants.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _interstitialLoadAttempts = 0;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Interstitial failed to show: ${error.message}');
              ad.dispose();
              loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed to load: ${error.message}');
          _interstitialLoadAttempts++;
          if (_interstitialLoadAttempts < maxFailedLoadAttempts) {
            loadInterstitialAd();
          }
        },
      ),
    );
  }

  void showInterstitialAd() {
    if (adsRemoved) return;
    if (_interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      loadInterstitialAd();
    }
  }

  // Rewarded Ad
  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: GameConstants.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedLoadAttempts = 0;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('Rewarded failed to show: ${error.message}');
              ad.dispose();
              loadRewardedAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('Rewarded failed to load: ${error.message}');
          _rewardedLoadAttempts++;
          if (_rewardedLoadAttempts < maxFailedLoadAttempts) {
            loadRewardedAd();
          }
        },
      ),
    );
  }

  void showRewardedAd({required String type}) {
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('Reward earned: ${reward.amount} ${reward.type}');
          _rewardStreamController.add(true);
        },
      );
    } else {
      loadRewardedAd();
    }
  }

  void preloadAds() {
    if (adsRemoved) return;
    loadInterstitialAd();
    loadRewardedAd();
  }

  void dispose() {
    _bannerAd?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _rewardStreamController.close();
  }
}
