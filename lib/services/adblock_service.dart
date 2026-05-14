import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'network_service.dart';
import 'storage_service.dart';

enum AdBlockStatus { unknown, clear, blocked }

/// Three-layer ad-block detector. Uses ValueNotifier so the overlay
/// NEVER misses a status change — no broadcast stream race conditions.
///
///  Layer 1 — DNS resolution  (4 domains in parallel)
///            Catches: Private DNS, Pi-hole, AdGuard DNS, hosts file
///
///  Layer 2 — TCP socket connect (ALWAYS runs, not gated on DNS)
///            Catches: VPN-based blockers (Blokada, AdGuard VPN,
///            NordVPN Threat Protection) that pass DNS but block TCP
///
///  Layer 3 — Periodic re-check every 60 s + AdMob callback trigger
///            Catches: blocker enabled mid-session
///
///  Decision (avoids false positives):
///    blocked = (dns_failures >= 2)
///           OR (dns_failures >= 1 AND tcp_failures >= 1)
///           OR (tcp_failures >= 2)   ← VPN with clean DNS
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
    'admob.com',
    'www.googleadservices.com',
  ];

  // TCP targets — port 443. VPN blockers drop the SYN packet here.
  static const List<String> _tcpHosts = [
    'googleads.g.doubleclick.net',
    'pagead2.googlesyndication.com',
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

    // Periodic — catches VPN enabled mid-session
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
      // Layer 1: DNS (all 4 in parallel)
      final dnsResults = await Future.wait(
        _dnsDomains.map(_dnsLookup),
      );
      final dnsFailures = dnsResults.where((ok) => !ok).length;

      // Layer 2: TCP socket (ALWAYS runs — catches VPN blockers with clean DNS)
      final tcpResults = await Future.wait(
        _tcpHosts.map((h) => _tcpConnect(h, 443)),
      );
      final tcpFailures = tcpResults.where((ok) => !ok).length;

      debugPrint(
          '[AdBlock] DNS failures: $dnsFailures/${_dnsDomains.length}  '
          'TCP failures: $tcpFailures/${_tcpHosts.length}');

      final blocked = (dnsFailures >= 2) ||
          (dnsFailures >= 1 && tcpFailures >= 1) ||
          (tcpFailures >= 2);

      _emit(blocked ? AdBlockStatus.blocked : AdBlockStatus.clear);
    } finally {
      _checking = false;
    }
  }

  // ─── Layer 1: DNS ─────────────────────────────────────────────────────────
  Future<bool> _dnsLookup(String host) async {
    try {
      final r = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 5));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ─── Layer 2: TCP socket ──────────────────────────────────────────────────
  /// Tries to open a TCP connection. VPN/DNS-over-HTTPS blockers drop this.
  /// Any successful TCP handshake (even if TLS fails after) = not blocked.
  Future<bool> _tcpConnect(String host, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      return true;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
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
