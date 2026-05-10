import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Three distinct network states the app cares about.
enum NetworkStatus {
  /// Actively checking — shown briefly on startup.
  checking,

  /// Device has a connection AND real internet packets get through.
  connected,

  /// Device shows Wi-Fi or mobile signal but DNS / ping fails.
  /// Cause: no data plan, captive portal, WiFi with no internet.
  connectedNoData,

  /// No network interface at all (airplane mode, no SIM, no WiFi).
  disconnected,
}

class NetworkService {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<NetworkStatus> _controller =
      StreamController<NetworkStatus>.broadcast();

  NetworkStatus _status = NetworkStatus.checking;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  // Public API
  NetworkStatus get status => _status;
  Stream<NetworkStatus> get statusStream => _controller.stream;
  bool get isOnline => _status == NetworkStatus.connected;

  // ─── Init ─────────────────────────────────────────────────────────────────
  Future<void> init() async {
    // First check
    await _update();

    // Subscribe to OS-level connectivity changes
    _sub = _connectivity.onConnectivityChanged.listen((results) async {
      // Debounce: wait 800ms for the network stack to settle before pinging
      await Future.delayed(const Duration(milliseconds: 800));
      await _update();
    });
  }

  // ─── Core check ───────────────────────────────────────────────────────────
  Future<void> _update() async {
    final results = await _connectivity.checkConnectivity();

    // No interface at all
    if (results.contains(ConnectivityResult.none) || results.isEmpty) {
      _emit(NetworkStatus.disconnected);
      return;
    }

    // Device reports a connection — confirm real internet via DNS lookup
    final hasInternet = await _pingInternet();
    _emit(hasInternet ? NetworkStatus.connected : NetworkStatus.connectedNoData);
  }

  /// Returns true only when we can actually resolve a hostname.
  /// Uses dart:io — no extra package, no HTTP overhead.
  Future<bool> _pingInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    } on TimeoutException {
      return false;
    } catch (e) {
      debugPrint('Network ping error: $e');
      return false;
    }
  }

  void _emit(NetworkStatus newStatus) {
    if (_status == newStatus) return; // no-op if unchanged
    _status = newStatus;
    _controller.add(newStatus);
    debugPrint('[NetworkService] → $newStatus');
  }

  /// Manually re-check (called by the "Try Again" button).
  Future<void> recheck() async => await _update();

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
