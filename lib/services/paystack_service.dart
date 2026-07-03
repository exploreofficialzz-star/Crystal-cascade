import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PaystackInitResult {
  final String authorizationUrl;
  final String reference;
  const PaystackInitResult({
    required this.authorizationUrl,
    required this.reference,
  });
}

/// Talks ONLY to our own backend (see /paystack-server at the project root)
/// — never to Paystack's API directly. Paystack's own docs are explicit
/// about why: calling their API from a mobile client means shipping the
/// secret key inside the APK, extractable by anyone with a decompiler. Our
/// backend holds that key instead; this service just relays to it.
///
/// The public key you provided (pk_live_...) isn't actually used in this
/// specific flow — the hosted-checkout-URL pattern authenticates entirely
/// through the backend's secret-key call to /transaction/initialize, so the
/// checkout page it returns is already fully authorized. It's kept here,
/// unused, in case you ever add Paystack Inline/Popup JS on a future web
/// build, where a public key genuinely is needed client-side.
class PaystackService {
  static final PaystackService _instance = PaystackService._internal();
  factory PaystackService() => _instance;
  PaystackService._internal();

  // Safe to keep client-side — this is the publishable key, not the secret.
  static const String publicKey =
      'pk_live_d145dd30b0e40a54e3d2533dfc544e41ea63fe94';

  /// ⚠️ REQUIRED BEFORE THIS PATH WORKS: set this to your deployed backend's
  /// base URL. See paystack-server/README.md for deployment steps (Firebase
  /// Cloud Functions or Render/Railway are both covered there).
  /// Left as an obvious placeholder on purpose — isConfigured below stays
  /// false until it's changed, so the Paystack path fails safely (no
  /// unpaid rewards) rather than silently pointing nowhere.
  static const String backendBaseUrl = 'https://YOUR-BACKEND-URL-HERE';

  /// The app has no accounts/login, so there's no real per-player email to
  /// send Paystack. A shared placeholder is fine — Paystack requires the
  /// field to exist, but nothing here depends on it being unique per player.
  static const String _placeholderEmail = 'player@chastechgroup.com';

  /// Where Paystack redirects after checkout. The WebView intercepts
  /// navigation to this URL before it ever really loads, so its content
  /// barely matters — but see paystack-server/callback-page/ for a small
  /// static "you can close this" page worth hosting there anyway, for the
  /// rare case a device's WebView renders a frame before interception fires.
  static const String callbackUrl =
      'https://exploreofficialzz-star.github.io/crystal-cascade-paystack/callback.html';

  bool get isConfigured => !backendBaseUrl.contains('YOUR-BACKEND-URL-HERE');

  /// Step 1 — ask our backend to open a Paystack transaction. The backend
  /// looks up the price for [productId] itself; nothing about price is ever
  /// sent from the client, so a modified app can't talk itself into a
  /// cheaper price.
  Future<PaystackInitResult?> initializeTransaction(String productId) async {
    if (!isConfigured) {
      debugPrint('[Paystack] backendBaseUrl is not configured yet.');
      return null;
    }
    try {
      final res = await http
          .post(
            Uri.parse('$backendBaseUrl/paystack/initialize'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'productId': productId,
              'email': _placeholderEmail,
              'callbackUrl': callbackUrl,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        debugPrint('[Paystack] initialize failed: ${res.statusCode} ${res.body}');
        return null;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final url = data['authorizationUrl'] as String?;
      final reference = data['reference'] as String?;
      if (url == null || reference == null) return null;

      return PaystackInitResult(authorizationUrl: url, reference: reference);
    } catch (e) {
      debugPrint('[Paystack] initialize error: $e');
      return null;
    }
  }

  /// Step 2 — after the checkout WebView closes, confirm with our backend
  /// (which confirms with Paystack directly, server-to-server) that the
  /// payment truly succeeded before the app grants anything.
  Future<bool> verifyTransaction({
    required String reference,
    required String productId,
  }) async {
    if (!isConfigured) return false;
    try {
      final res = await http
          .post(
            Uri.parse('$backendBaseUrl/paystack/verify'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'reference': reference, 'productId': productId}),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        debugPrint('[Paystack] verify failed: ${res.statusCode} ${res.body}');
        return false;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['verified'] == true;
    } catch (e) {
      debugPrint('[Paystack] verify error: $e');
      return false;
    }
  }
}
