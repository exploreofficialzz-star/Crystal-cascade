import 'dart:async';
import 'package:flutter/foundation.dart';
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
  bool _isAvailable = false;
  bool _initialized = false;

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

  Future<void> _loadProducts() async {
    try {
      final response = await _iap.queryProductDetails(allProductIds);

      if (response.error != null) {
        debugPrint('[IAP] Query error: ${response.error?.message}');
      }
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('[IAP] Not found in store: ${response.notFoundIDs}');
        debugPrint('[IAP] → Create these in Play Console / App Store Connect');
      }

      for (final p in response.productDetails) {
        _products[p.id] = p;
        debugPrint('[IAP] Loaded: ${p.id} @ ${p.price}');
      }
    } catch (e) {
      debugPrint('[IAP] _loadProducts error: $e');
    }
  }

  // ─── Trigger a purchase ────────────────────────────────────────────────────
  Future<void> buyProduct(String productId) async {
    if (!_isAvailable) {
      _resultCtrl.add(IAPResult(
        success: false,
        productId: productId,
        error: 'Store not available on this device.',
      ));
      return;
    }

    final product = _products[productId];
    if (product == null) {
      // Products not loaded yet — try reloading
      await _loadProducts();
      final retried = _products[productId];
      if (retried == null) {
        _resultCtrl.add(IAPResult(
          success: false,
          productId: productId,
          error:
              'Product not found. Make sure it is published in the store and '
              'you have an internet connection.',
        ));
        return;
      }
    }

    try {
      final param = PurchaseParam(productDetails: _products[productId]!);
      // All products are consumable — can be rebought (e.g. extend remove-ads timer)
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

  // ─── Handle store callbacks ────────────────────────────────────────────────
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
  // For production add server-side receipt validation via Google Play / App Store API.
  // For indie games trusting the SDK is standard practice.
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
        coinPackStarterId  => '\$0.99',
        megaPackId         => '\$4.99',
        _                  => '',
      };

  void dispose() {
    _purchaseSub?.cancel();
    _resultCtrl.close();
  }
}
