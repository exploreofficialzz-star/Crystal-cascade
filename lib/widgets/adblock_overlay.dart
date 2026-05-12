import 'dart:async';
import 'package:flutter/material.dart';
import '../services/adblock_service.dart';
import '../services/storage_service.dart';
import '../screens/shop_screen.dart';

/// Placed in MaterialApp's builder alongside NetworkOverlay.
/// Blocks the app with a branded wall when an ad blocker is detected
/// and the user has not purchased an ad-free pass.
class AdBlockOverlay extends StatefulWidget {
  final Widget child;
  const AdBlockOverlay({required this.child, super.key});

  @override
  State<AdBlockOverlay> createState() => _AdBlockOverlayState();
}

class _AdBlockOverlayState extends State<AdBlockOverlay>
    with SingleTickerProviderStateMixin {
  late StreamSubscription<AdBlockStatus> _sub;
  bool _show = false;
  bool _isChecking = false;

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void initState() {
    super.initState();

    // Reflect current status immediately
    _updateShow(AdBlockService().shouldShowAdBlockWall);

    _sub = AdBlockService().statusStream.listen((status) {
      _updateShow(AdBlockService().shouldShowAdBlockWall);
    });
  }

  void _updateShow(bool show) {
    if (!mounted) return;
    setState(() => _show = show);
    show ? _anim.forward() : _anim.reverse();
  }

  @override
  void dispose() {
    _sub.cancel();
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _anim,
          builder: (context, child) => Opacity(
            opacity: _anim.value,
            child: IgnorePointer(ignoring: !_show, child: child),
          ),
          child: _AdBlockScreen(
            isChecking: _isChecking,
            onRecheck: () async {
              setState(() => _isChecking = true);
              await AdBlockService().recheck();
              if (mounted) setState(() => _isChecking = false);
            },
            onGoAdFree: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ShopScreen(scrollToRemoveAds: true),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── The wall UI ──────────────────────────────────────────────────────────────

class _AdBlockScreen extends StatelessWidget {
  final bool isChecking;
  final VoidCallback onRecheck;
  final VoidCallback onGoAdFree;

  const _AdBlockScreen({
    required this.isChecking,
    required this.onRecheck,
    required this.onGoAdFree,
  });

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
                // ── Icon ───────────────────────────────────────────────────
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withOpacity(0.12),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.block,
                    color: Colors.redAccent,
                    size: 52,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Title ─────────────────────────────────────────────────
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

                // ── Body ──────────────────────────────────────────────────
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
                  child: Column(
                    children: [
                      Text(
                        'Crystal Cascade is free to play because of ads. '
                        'Your ad blocker is preventing ads from loading.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 14,
                          height: 1.5,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Please choose one of the options below to continue:',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 13,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Option 1: Disable ad blocker ──────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isChecking ? null : onRecheck,
                    icon: isChecking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.refresh_rounded,
                            color: Colors.black),
                    label: Text(
                      isChecking
                          ? 'Checking…'
                          : 'I\'ve Disabled My Ad Blocker',
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

                // ── Option 2: Go Ad-Free ───────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onGoAdFree,
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

                // ── How to disable tip ────────────────────────────────────
                Text(
                  'Tip: Open your VPN or ad-blocker app,\n'
                  'disable it for Crystal Cascade, then tap\n'
                  '"I\'ve Disabled My Ad Blocker" above.',
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
