import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/storage_service.dart';
import '../utils/constants.dart';

/// Emitted on purchaseResultStream after every transaction.
class IAPResult {
  final bool success;
  final String productId;
  final String? error; // 'canceled' means user dismissed — handle silently

  const IAPResult({
    required this.success,
    required this.productId,
    this.error,
  });
}

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  final StorageService _storage = StorageService();

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  final StreamController<IAPResult> _resultCtrl =
      StreamController<IAPResult>.broadcast();

  final Map<String, ProductDetails> _products = {};

  // Products reported as missing by the store on last query.
  // Non-empty means they haven't been published in Play Console yet.
  final Set<String> _notFoundIds = {};

  bool _isAvailable = false;
  bool _initialized = false;
  bool _loadingProducts = false; // prevents concurrent load calls

  // ─── Product IDs ───────────────────────────────────────────────────────────
  // These MUST match exactly what you create in:
  //   Google Play Console → Monetize → Products → In-app products
  //   App Store Connect   → Features → In-App Purchases
  static const String removeAdsDayId     = 'remove_ads_day';
  static const String removeAdsWeekendId = 'remove_ads_weekend';
  static const String removeAdsMonthId   = 'remove_ads_month';
  static const String hintPackSmallId    = 'hint_pack_small';
  static const String hintPackLargeId    = 'hint_pack_large';
  static const String coinPackStarterId  = 'coin_pack_starter';
  static const String megaPackId         = 'mega_pack';

  static const Set<String> allProductIds = {
    removeAdsDayId,
    removeAdsWeekendId,
    removeAdsMonthId,
    hintPackSmallId,
    hintPackLargeId,
    coinPackStarterId,
    megaPackId,
  };

  // ─── Public API ────────────────────────────────────────────────────────────
  bool get isAvailable => _isAvailable;
  Stream<IAPResult> get purchaseResultStream => _resultCtrl.stream;

  /// True when at least one product successfully loaded from the store.
  bool get areProductsLoaded => _products.isNotEmpty;

  /// True when this specific product was returned by the store.
  bool isProductAvailable(String productId) => _products.containsKey(productId);

  /// Real store price for a product. Falls back to our constant if not loaded.
  String priceFor(String productId) =>
      _products[productId]?.price ?? _fallbackPrice(productId);

  // ─── Init ─────────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _isAvailable = await _iap.isAvailable();
    if (!_isAvailable) {
      debugPrint('[IAP] Store not available on this device');
      return;
    }

    // Listen BEFORE querying — avoids missing purchases that complete during query
    _purchaseSub = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onError: (e) => debugPrint('[IAP] Stream error: $e'),
    );

    await _loadProducts();

    // Recover any interrupted purchases (important for Android & iOS)
    await _iap.restorePurchases();
  }

  Future<void> _loadProducts({int attempt = 1}) async {
    if (_loadingProducts) return;
    _loadingProducts = true;

    try {
      final response = await _iap
          .queryProductDetails(allProductIds)
          .timeout(const Duration(seconds: 15));

      if (response.error != null) {
        debugPrint('[IAP] Query error: ${response.error?.message}');
      }

      if (response.notFoundIDs.isNotEmpty) {
        _notFoundIds
          ..clear()
          ..addAll(response.notFoundIDs);
        debugPrint(
          '[IAP] ⚠️  Products NOT found in store (${response.notFoundIDs.length}): '
          '${response.notFoundIDs.join(', ')}\n'
          '[IAP] → Create & publish these in Play Console / App Store Connect.',
        );
      } else {
        _notFoundIds.clear();
      }

      for (final p in response.productDetails) {
        _products[p.id] = p;
        debugPrint('[IAP] ✅ Loaded: ${p.id} @ ${p.price}');
      }
    } on TimeoutException {
      debugPrint('[IAP] _loadProducts timed out (attempt $attempt)');
      // Retry once after a short delay, then give up
      if (attempt < 2) {
        await Future.delayed(const Duration(seconds: 4));
        _loadingProducts = false;
        await _loadProducts(attempt: attempt + 1);
        return;
      }
    } catch (e) {
      debugPrint('[IAP] _loadProducts error: $e');
    } finally {
      _loadingProducts = false;
    }
  }

  // ─── Trigger a purchase ────────────────────────────────────────────────────
  Future<void> buyProduct(BuildContext context, String productId) async {
    if (!_isAvailable) {
      _resultCtrl.add(IAPResult(
        success: false,
        productId: productId,
        error: 'Store not available on this device.',
      ));
      return;
    }

    // Try to load products if none are in cache yet
    if (!areProductsLoaded) {
      await _loadProducts();
    }

    final product = _products[productId];
    if (product == null) {
      final isNotFound = _notFoundIds.contains(productId);
      _resultCtrl.add(IAPResult(
        success: false,
        productId: productId,
        error: isNotFound
            ? 'This product has not been published in the store yet. '
              'Please try again after an app update.'
            : 'Product unavailable. Check your internet connection and try again.',
      ));
      return;
    }

    try {
      final param = PurchaseParam(productDetails: product);
      // All products are consumable — can be rebought (e.g. to extend the
      // remove-ads timer or top-up hint/coin packs multiple times).
      await _iap.buyConsumable(purchaseParam: param);
    } catch (e) {
      debugPrint('[IAP] buyProduct error: $e');
      _resultCtrl.add(IAPResult(
        success: false,
        productId: productId,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onPurchaseUpdates(
      List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchase in purchaseDetailsList) {
      debugPrint('[IAP] ${purchase.productID} → ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (await _verifyPurchase(purchase)) {
            await _deliverProduct(purchase.productID);
            _resultCtrl.add(
                IAPResult(success: true, productId: purchase.productID));
          } else {
            _resultCtrl.add(IAPResult(
              success: false,
              productId: purchase.productID,
              error: 'Purchase verification failed. Contact support.',
            ));
          }

        case PurchaseStatus.pending:
          debugPrint('[IAP] Pending: ${purchase.productID}');

        case PurchaseStatus.canceled:
          _resultCtrl.add(IAPResult(
            success: false,
            productId: purchase.productID,
            error: 'canceled', // handled silently in UI
          ));

        case PurchaseStatus.error:
          final msg = purchase.error?.message ?? 'Unknown store error';
          debugPrint('[IAP] Error: $msg');
          _resultCtrl.add(IAPResult(
            success: false,
            productId: purchase.productID,
            error: msg,
          ));
      }

      // Must always call completePurchase or the transaction stays pending
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  // ─── Grant rewards ─────────────────────────────────────────────────────────
  Future<void> _deliverProduct(String productId) async {
    switch (productId) {
      case removeAdsDayId:
        await _storage.setRemoveAdsTier('day', GameConstants.removeAdsDayMs);

      case removeAdsWeekendId:
        await _storage.setRemoveAdsTier(
            'weekend', GameConstants.removeAdsWeekendMs);

      case removeAdsMonthId:
        await _storage.setRemoveAdsTier(
            'month', GameConstants.removeAdsMonthMs);

      case hintPackSmallId:
        await _storage.addHints(GameConstants.hintPackSmallCount);

      case hintPackLargeId:
        await _storage.addHints(GameConstants.hintPackLargeCount);

      case coinPackStarterId:
        await _storage.addCoins(500);
        await _storage.addHints(5);

      case megaPackId:
        await _storage.addCoins(2000);
        await _storage.addHints(20);
        await _storage.setRemoveAdsTier(
            'weekend', GameConstants.removeAdsWeekendMs);

      default:
        debugPrint('[IAP] Unknown product: $productId — nothing delivered');
    }
    debugPrint('[IAP] Delivered: $productId');
  }

  // ─── Verification ─────────────────────────────────────────────────────────
  // For production: add server-side receipt validation via Google Play /
  // App Store API. For indie games trusting the SDK is standard practice.
  Future<bool> _verifyPurchase(PurchaseDetails purchase) async => true;

  // ─── Restore (called from shop UI) ────────────────────────────────────────
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;
    await _iap.restorePurchases();
  }

  // ─── Fallback prices (shown before store responds) ─────────────────────────
  String _fallbackPrice(String id) => switch (id) {
        removeAdsDayId     => GameConstants.removeAdsDayPrice,
        removeAdsWeekendId => GameConstants.removeAdsWeekendPrice,
        removeAdsMonthId   => GameConstants.removeAdsMonthPrice,
        hintPackSmallId    => GameConstants.hintPackSmallPrice,
        hintPackLargeId    => GameConstants.hintPackLargePrice,
        coinPackStarterId  => r'$0.99',
        megaPackId         => r'$4.99',
        _                  => '',
      };

  void dispose() {
    _purchaseSub?.cancel();
    _resultCtrl.close();
  }
}
