import 'dart:async';
import 'package:flutter/material.dart';
import '../services/network_service.dart';

/// Placed in MaterialApp's builder — covers EVERY screen and route.
///
///   disconnected     → "No internet connection."
///   connectedNoData  → "Connected but no internet. Check your plan or Wi-Fi."
///
/// The overlay stays permanently until NetworkStatus.connected is confirmed.
/// It does NOT hide during the 'checking' state to prevent flickering.
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
    duration: const Duration(milliseconds: 350),
  );

  @override
  void initState() {
    super.initState();

    _sub = NetworkService().statusStream.listen((status) {
      setState(() => _status = status);

      // Only hide when CONFIRMED connected — checking counts as offline
      if (_isOffline(status)) {
        _animCtrl.forward();
      } else if (status == NetworkStatus.connected) {
        _animCtrl.reverse();
      }
      // 'checking' → do nothing, keep overlay visible
    });

    // Show overlay immediately if already offline on first render
    if (_isOffline(_status)) _animCtrl.value = 1.0;
  }

  @override
  void dispose() {
    _sub.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  /// Overlay is shown for disconnected AND connectedNoData AND checking.
  /// Only CONFIRMED connected hides it.
  bool _isOffline(NetworkStatus s) => s != NetworkStatus.connected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── App content (always present underneath) ─────────────────────────
        widget.child,

        // ── Full-screen offline overlay ──────────────────────────────────────
        AnimatedBuilder(
          animation: _animCtrl,
          builder: (context, child) {
            return Opacity(
              opacity: _animCtrl.value,
              child: IgnorePointer(
                // Block all interaction when visible
                ignoring: _animCtrl.value == 0,
                child: child,
              ),
            );
          },
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
      ],
    );
  }
}

// ─── Offline Screen ────────────────────────────────────────────────────────────

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
      width: double.infinity,
      height: double.infinity,
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
                // ── Icon ─────────────────────────────────────────────────────
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
                    isNoData
                        ? Icons.signal_wifi_bad
                        : Icons.wifi_off_rounded,
                    color: isNoData
                        ? Colors.orangeAccent
                        : Colors.redAccent,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Title ─────────────────────────────────────────────────────
                Text(
                  isNoData
                      ? 'Connected But No Internet'
                      : 'No Internet Connection',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none, // no underline
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // ── Message box ───────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isNoData
                            ? 'Your device is connected but we can\'t reach the internet.'
                            : 'Crystal Cascade needs internet to load ads and sync progress.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          height: 1.5,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._buildBullets(
                        isNoData
                            ? [
                                'Check your mobile data plan',
                                'Try a different Wi-Fi network',
                                'Disable and re-enable mobile data',
                              ]
                            : [
                                'Turn on Wi-Fi or mobile data',
                                'Disable airplane mode',
                                'Check your SIM card is active',
                              ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Retry button ──────────────────────────────────────────────
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
                        decoration: TextDecoration.none,
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

                // ── Footer ────────────────────────────────────────────────────
                Text(
                  'Your progress is saved locally.\nReconnect to continue playing.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 12,
                    decoration: TextDecoration.none,
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

  /// Bullet points as separate Text widgets — no underlines possible.
  List<Widget> _buildBullets(List<String> points) {
    return points.map((point) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '• ',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
                decoration: TextDecoration.none,
              ),
            ),
            Expanded(
              child: Text(
                point,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                  height: 1.4,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
