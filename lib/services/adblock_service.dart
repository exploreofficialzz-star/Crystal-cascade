import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'network_service.dart';
import 'storage_service.dart';

enum AdBlockStatus {
  unknown,     // not checked yet
  clear,       // ads reachable — no blocker
  blocked,     // ad domains unreachable while internet is working
}

class AdBlockService {
  static final AdBlockService _instance = AdBlockService._internal();
  factory AdBlockService() => _instance;
  AdBlockService._internal();

  final NetworkService _network = NetworkService();
  final StorageService _storage = StorageService();

  AdBlockStatus _status = AdBlockStatus.unknown;
  final StreamController<AdBlockStatus> _ctrl =
      StreamController<AdBlockStatus>.broadcast();

  AdBlockStatus get status => _status;
  Stream<AdBlockStatus> get statusStream => _ctrl.stream;

  /// True when blocker is active AND user has NOT paid to remove ads.
  bool get shouldShowAdBlockWall =>
      _status == AdBlockStatus.blocked && !_storage.isAdsRemoved();

  // ─── Init ─────────────────────────────────────────────────────────────────
  Future<void> init() async {
    // Only check when internet is confirmed — avoids false positives on no-internet
    if (_network.isOnline) await _check();

    // Re-check whenever connectivity changes
    _network.statusStream.listen((netStatus) async {
      if (netStatus == NetworkStatus.connected) await _check();
    });
  }

  // ─── Manual re-check (called by "I've disabled it" button) ────────────────
  Future<void> recheck() async => await _check();

  // ─── Core detection ───────────────────────────────────────────────────────
  //
  //  Strategy: try to resolve TWO known Google ad-serving domains.
  //  If BOTH fail while the network is confirmed working → ad blocker active.
  //  Requiring both to fail avoids false positives from temporary DNS hiccups.
  Future<void> _check() async {
    if (!_network.isOnline) return; // don't accuse when there's no internet

    final reachable = await _canReachAdDomains();
    final newStatus =
        reachable ? AdBlockStatus.clear : AdBlockStatus.blocked;

    if (newStatus != _status) {
      _status = newStatus;
      _ctrl.add(_status);
      debugPrint('[AdBlock] Status → $_status');
    }
  }

  Future<bool> _canReachAdDomains() async {
    // First domain — primary Google Ad Services endpoint used by AdMob
    final first = await _lookup('googleads.g.doubleclick.net');
    if (first) return true; // not blocked

    // Both must fail to confirm blocking (reduces false positives)
    final second = await _lookup('pagead2.googlesyndication.com');
    return second; // false = both failed = blocked
  }

  Future<bool> _lookup(String host) async {
    try {
      final result = await InternetAddress.lookup(host)
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (_) {
      return false;
    }
  }

  void dispose() => _ctrl.close();
}
