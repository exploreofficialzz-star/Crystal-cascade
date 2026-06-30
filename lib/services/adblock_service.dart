import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'network_service.dart';
import 'storage_service.dart';

enum AdBlockStatus { unknown, clear, blocked }

/// Standard ad-block detector. Uses ValueNotifier so the overlay
/// never misses a status change.
///
///  Detection — DNS resolution of known ad-serving domains
///              (3 domains in parallel). If a majority fail to resolve,
///              the device is treated as having an ad blocker enabled
///              (Pi-hole, AdGuard DNS, hosts-file blocker, etc).
///
///  Periodic re-check every 60 s + manual recheck() trigger
///  (e.g. called from AdMob callbacks or the overlay's retry button).
class AdBlockService {
  static final AdBlockService _instance = AdBlockService._internal();
  factory AdBlockService() => _instance;
  AdBlockService._internal();

  final NetworkService _network = NetworkService();
  final StorageService _storage = StorageService();

  AdBlockStatus _status = AdBlockStatus.unknown;

  /// ValueNotifier — overlay reads this directly, never misses an update.
  final ValueNotifier<AdBlockStatus> statusNotifier =
      ValueNotifier<AdBlockStatus>(AdBlockStatus.unknown);

  Timer? _periodicTimer;
  bool _checking = false;

  AdBlockStatus get status => _status;

  /// True when blocker active AND user has not paid to remove ads.
  bool get shouldShowAdBlockWall =>
      _status == AdBlockStatus.blocked && !_storage.isAdsRemoved();

  // ─── Ad domains ───────────────────────────────────────────────────────────
  static const List<String> _dnsDomains = [
    'googleads.g.doubleclick.net',
    'pagead2.googlesyndication.com',
    'www.googleadservices.com',
  ];

  // ─── Init ─────────────────────────────────────────────────────────────────
  Future<void> init() async {
    // Small delay so the app fully renders before blocking the screen
    await Future.delayed(const Duration(seconds: 2));

    if (_network.isOnline) await _runFullCheck();

    // Re-check on every confirmed reconnect
    _network.statusStream.listen((s) async {
      if (s == NetworkStatus.connected) await _runFullCheck();
    });

    // Periodic — catches a blocker enabled mid-session
    _periodicTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) async {
        if (_network.isOnline) await _runFullCheck();
      },
    );
  }

  /// Called by AdMob callbacks and the overlay's "I've disabled" button.
  Future<void> recheck() async {
    if (_network.isOnline) await _runFullCheck();
  }

  // ─── Main detection ───────────────────────────────────────────────────────
  Future<void> _runFullCheck() async {
    if (_checking) return; // prevent overlapping checks
    if (!_network.isOnline) return;
    _checking = true;

    try {
      // DNS resolution of ad-serving domains, run in parallel
      final dnsResults = await Future.wait(
        _dnsDomains.map(_dnsLookup),
      );
      final dnsFailures = dnsResults.where((ok) => !ok).length;

      debugPrint(
          '[AdBlock] DNS failures: $dnsFailures/${_dnsDomains.length}');

      // Blocked if a majority of ad-domain lookups fail to resolve.
      final blocked = dnsFailures >= 2;

      _emit(blocked ? AdBlockStatus.blocked : AdBlockStatus.clear);
    } finally {
      _checking = false;
    }
  }

  // ─── DNS lookup ───────────────────────────────────────────────────────────
  Future<bool> _dnsLookup(String host) async {
    try {
      final r = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 5));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ─── Emit ─────────────────────────────────────────────────────────────────
  void _emit(AdBlockStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    statusNotifier.value = newStatus; // overlay picks this up instantly
    debugPrint('[AdBlock] → $newStatus');
  }

  void dispose() {
    _periodicTimer?.cancel();
    statusNotifier.dispose();
  }
}
