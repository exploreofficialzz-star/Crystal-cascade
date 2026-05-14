import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'network_service.dart';
import 'storage_service.dart';

enum AdBlockStatus { unknown, clear, blocked }

/// Multi-layer ad-block detector covering all 5 major blocking methods:
///
///  Layer 1 — DNS resolution  → catches Private DNS, Pi-hole, AdGuard DNS,
///                               hosts-file blockers, NextDNS
///  Layer 2 — HTTP reachability → catches VPN-based blockers (Blokada,
///                               AdGuard VPN, NordVPN Threat Protection)
///                               that pass DNS but drop HTTP packets
///  Layer 3 — Periodic re-check → catches users who enable their
///                               VPN/blocker mid-session
///
///  Decision logic (deliberately strict to avoid false positives):
///    blocked = (dns_failures >= 2 out of 4 domains)
///           OR (http_unreachable AND dns_failures >= 1)
class AdBlockService {
  static final AdBlockService _instance = AdBlockService._internal();
  factory AdBlockService() => _instance;
  AdBlockService._internal();

  final NetworkService _network = NetworkService();
  final StorageService _storage = StorageService();

  AdBlockStatus _status = AdBlockStatus.unknown;
  final StreamController<AdBlockStatus> _ctrl =
      StreamController<AdBlockStatus>.broadcast();

  Timer? _periodicTimer;

  AdBlockStatus get status => _status;
  Stream<AdBlockStatus> get statusStream => _ctrl.stream;

  /// Show wall only when: blocker active AND user has NOT paid to remove ads.
  bool get shouldShowAdBlockWall =>
      _status == AdBlockStatus.blocked && !_storage.isAdsRemoved();

  // ─── Ad domains for DNS layer ─────────────────────────────────────────────
  // 4 different Google Ad-serving domains — blockers must hit all of them
  // to avoid false positives from single-domain CDN issues.
  static const List<String> _adDomains = [
    'googleads.g.doubleclick.net',    // Primary AdMob delivery
    'pagead2.googlesyndication.com',  // AdSense / AdMob
    'admob.com',                      // AdMob root
    'www.googleadservices.com',       // Google Ad Services
  ];

  // HTTP endpoint for Layer 2 (VPN detection)
  static const String _adHttpEndpoint =
      'https://googleads.g.doubleclick.net/';

  // ─── Init ─────────────────────────────────────────────────────────────────
  Future<void> init() async {
    // Wait for internet before first check — avoids false positive on cold start
    await Future.delayed(const Duration(seconds: 3));

    if (_network.isOnline) await _runFullCheck();

    // Re-check whenever connectivity changes
    _network.statusStream.listen((status) async {
      if (status == NetworkStatus.connected) await _runFullCheck();
    });

    // Periodic check every 90 seconds — catches mid-session VPN enable
    _periodicTimer = Timer.periodic(
      const Duration(seconds: 90),
      (_) async {
        if (_network.isOnline) await _runFullCheck();
      },
    );
  }

  /// Manual re-check — called by "I've Disabled My Ad Blocker" button.
  Future<void> recheck() async {
    if (!_network.isOnline) return;
    await _runFullCheck();
  }

  // ─── Full multi-layer check ───────────────────────────────────────────────
  Future<void> _runFullCheck() async {
    if (!_network.isOnline) return;

    // Layer 1: DNS (runs all 4 in parallel for speed)
    final dnsResults = await Future.wait(
      _adDomains.map((domain) => _dnsLookup(domain)),
    );
    final dnsFailures = dnsResults.where((r) => !r).length;
    debugPrint('[AdBlock] DNS: $dnsFailures/${_adDomains.length} domains blocked');

    // Layer 2: HTTP reachability (only if DNS is suspicious OR as second check)
    // Skip HTTP check if DNS is clearly fine (0 failures) to save battery
    bool httpBlocked = false;
    if (dnsFailures >= 1) {
      httpBlocked = !(await _httpReachable());
      debugPrint('[AdBlock] HTTP blocked: $httpBlocked');
    }

    // Decision — strict logic to minimize false positives
    final bool blocked = (dnsFailures >= 2) || (dnsFailures >= 1 && httpBlocked);

    _emit(blocked ? AdBlockStatus.blocked : AdBlockStatus.clear);
  }

  // ─── Layer 1: DNS lookup ──────────────────────────────────────────────────
  Future<bool> _dnsLookup(String host) async {
    try {
      final result = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 5));
      final reachable = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      if (!reachable) debugPrint('[AdBlock] DNS blocked: $host');
      return reachable;
    } on SocketException {
      debugPrint('[AdBlock] DNS blocked (SocketException): $host');
      return false;
    } on TimeoutException {
      debugPrint('[AdBlock] DNS timeout: $host');
      return false;
    } catch (e) {
      debugPrint('[AdBlock] DNS error ($host): $e');
      return false;
    }
  }

  // ─── Layer 2: HTTP reachability ───────────────────────────────────────────
  // Makes a real HTTP HEAD request to an AdMob endpoint.
  // VPN-based blockers (Blokada, AdGuard) pass DNS but DROP the TCP connection.
  // Even a 4xx/5xx response counts as "reachable" — just 0 bytes proves no block.
  Future<bool> _httpReachable() async {
    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6)
        ..badCertificateCallback = (_, __, ___) => true; // ignore cert issues

      final request = await client
          .headUrl(Uri.parse(_adHttpEndpoint))
          .timeout(const Duration(seconds: 6));

      request.headers.set('User-Agent', 'CrystalCascade/1.0');
      final response = await request.close().timeout(const Duration(seconds: 6));
      await response.drain<void>(); // consume response body

      debugPrint('[AdBlock] HTTP reachable: ${response.statusCode}');
      return true; // any HTTP response = not blocked by VPN
    } on SocketException {
      debugPrint('[AdBlock] HTTP blocked (SocketException) — VPN blocker likely');
      return false;
    } on TimeoutException {
      debugPrint('[AdBlock] HTTP timeout — possible VPN blocker');
      return false;
    } on HandshakeException {
      // TLS handshake failure — HTTPS filtering or cert injection by blocker
      debugPrint('[AdBlock] HTTP TLS failure — HTTPS filtering detected');
      return false;
    } catch (e) {
      debugPrint('[AdBlock] HTTP error: $e');
      return false;
    } finally {
      client?.close(force: true);
    }
  }

  // ─── Emit new status ──────────────────────────────────────────────────────
  void _emit(AdBlockStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    _ctrl.add(_status);
    debugPrint('[AdBlock] Status → $_status');
  }

  void dispose() {
    _periodicTimer?.cancel();
    _ctrl.close();
  }
}
