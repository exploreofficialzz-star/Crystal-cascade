import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/admob_service.dart';

/// In-content native ad, styled to sit naturally inside a vertical list
/// (Shop screen). Renders nothing while loading or if ads are removed.
class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({super.key});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final ad = AdMobService().loadNativeAd(
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _failed = true);
        },
      ),
    );
    _nativeAd = ad;
    if (ad == null) _failed = true; // ads removed — nothing to load
  }

  @override
  void dispose() {
    // Service owns a single shared instance — only dispose if we're the
    // last screen holding it (AdMobService.disposeNativeAd handles reload
    // safety for the next screen that requests one).
    AdMobService().disposeNativeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || !_isLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: AdWidget(ad: _nativeAd!),
    );
  }
}
