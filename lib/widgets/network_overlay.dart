import 'dart:async';
import 'package:flutter/material.dart';
import '../services/network_service.dart';

/// Wraps any screen and slides a branded offline overlay over it
/// the moment connectivity is lost. Two distinct messages:
///
///   disconnected     → "No internet connection. Enable Wi-Fi or mobile data."
///   connectedNoData  → "Connected but no internet. Check your plan or Wi-Fi."
class NetworkOverlay extends StatefulWidget {
  final Widget child;

  const NetworkOverlay({required this.child, super.key});

  @override
  State<NetworkOverlay> createState() => _NetworkOverlayState();
}

class _NetworkOverlayState extends State<NetworkOverlay>
    with SingleTickerProviderStateMixin {
  late StreamSubscription<NetworkStatus> _sub;
  NetworkStatus _status = NetworkService().status;
  bool _isChecking = false;

  late final AnimationController _animCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);

  @override
  void initState() {
    super.initState();
    _sub = NetworkService().statusStream.listen((status) {
      setState(() => _status = status);
      if (!_isOnline(status)) {
        _animCtrl.forward();
      } else {
        _animCtrl.reverse();
      }
    });

    // Show overlay immediately if already offline when screen opens
    if (!_isOnline(_status)) _animCtrl.value = 1.0;
  }

  @override
  void dispose() {
    _sub.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  bool _isOnline(NetworkStatus s) =>
      s == NetworkStatus.connected || s == NetworkStatus.checking;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Actual app content ──────────────────────────────────────────────
        widget.child,

        // ── Offline overlay (fades in/out) ──────────────────────────────────
        FadeTransition(
          opacity: _fadeAnim,
          child: IgnorePointer(
            ignoring: _isOnline(_status),
            child: _OfflineScreen(
              status: _status,
              isChecking: _isChecking,
              onRetry: () async {
                setState(() => _isChecking = true);
                await NetworkService().recheck();
                if (mounted) setState(() => _isChecking = false);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineScreen extends StatelessWidget {
  final NetworkStatus status;
  final bool isChecking;
  final VoidCallback onRetry;

  const _OfflineScreen({
    required this.status,
    required this.isChecking,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isNoData = status == NetworkStatus.connectedNoData;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1a1a2e),
            Color(0xFF16213e),
            Color(0xFF0f3460),
            Color(0xFF533483),
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Icon ───────────────────────────────────────────────────
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    isNoData ? Icons.signal_wifi_bad : Icons.wifi_off_rounded,
                    color: isNoData
                        ? Colors.orangeAccent
                        : Colors.redAccent,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Title ──────────────────────────────────────────────────
                Text(
                  isNoData
                      ? 'Connected But No Internet'
                      : 'No Internet Connection',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // ── Body message ───────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12), width: 1),
                  ),
                  child: Text(
                    isNoData
                        ? 'Your device is connected to a network, but we can\'t '
                            'reach the internet.\n\n'
                            '• Check your mobile data plan\n'
                            '• Try a different Wi-Fi network\n'
                            '• Disable and re-enable mobile data'
                        : 'Crystal Cascade needs an internet connection to load '
                            'ads and sync your progress.\n\n'
                            '• Turn on Wi-Fi or mobile data\n'
                            '• Disable airplane mode\n'
                            '• Check your SIM card is active',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 14,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.left,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Retry button ───────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isChecking ? null : onRetry,
                    icon: isChecking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded,
                            color: Colors.black),
                    label: Text(
                      isChecking ? 'Checking…' : 'Try Again',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isNoData
                          ? Colors.orangeAccent
                          : Colors.purpleAccent,
                      disabledBackgroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Small footer note ──────────────────────────────────────
                Text(
                  'Your progress is saved locally.\nReconnect to continue playing.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
