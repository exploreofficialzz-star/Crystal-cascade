import 'package:flutter/material.dart';
import '../services/adblock_service.dart';
import '../screens/shop_screen.dart';

/// Uses ValueListenableBuilder — reads ValueNotifier directly.
/// Can NEVER miss a status update, no stream subscriptions needed.
class AdBlockOverlay extends StatelessWidget {
  final Widget child;
  const AdBlockOverlay({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdBlockStatus>(
      valueListenable: AdBlockService().statusNotifier,
      builder: (context, status, _) {
        final show = AdBlockService().shouldShowAdBlockWall;

        return Stack(
          children: [
            child,
            if (show)
              _AdBlockWall(
                onRecheck: () => AdBlockService().recheck(),
                onGoAdFree: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ShopScreen(scrollToRemoveAds: true),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdBlockWall extends StatefulWidget {
  final Future<void> Function() onRecheck;
  final VoidCallback onGoAdFree;

  const _AdBlockWall({required this.onRecheck, required this.onGoAdFree});

  @override
  State<_AdBlockWall> createState() => _AdBlockWallState();
}

class _AdBlockWallState extends State<_AdBlockWall> {
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
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
                // Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withOpacity(0.12),
                    border: Border.all(
                        color: Colors.redAccent.withOpacity(0.4), width: 1.5),
                  ),
                  child: const Icon(Icons.block,
                      color: Colors.redAccent, size: 52),
                ),
                const SizedBox(height: 28),

                // Title
                const Text(
                  'Ad Blocker Detected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),

                // Body
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12), width: 1),
                  ),
                  child: Column(children: [
                    Text(
                      'Crystal Cascade is free because of ads. '
                      'Your ad blocker is preventing ads from loading.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 14,
                        height: 1.5,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Please disable your ad blocker or go ad-free below.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 13,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ]),
                ),
                const SizedBox(height: 28),

                // Button 1: Disable blocker
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _checking
                        ? null
                        : () async {
                            setState(() => _checking = true);
                            await widget.onRecheck();
                            if (mounted) setState(() => _checking = false);
                          },
                    icon: _checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.refresh_rounded,
                            color: Colors.black),
                    label: Text(
                      _checking ? 'Checking…' : "I've Disabled My Ad Blocker",
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      disabledBackgroundColor: Colors.white24,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Button 2: Go ad-free
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.onGoAdFree,
                    icon: const Icon(Icons.star, color: Colors.white),
                    label: const Text(
                      'Go Ad-Free  —  from \$0.99',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Tip
                Text(
                  'Tip: Disable your ad-blocker app or browser extension,\n'
                  'then tap "I\'ve Disabled My Ad Blocker".',
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
}
