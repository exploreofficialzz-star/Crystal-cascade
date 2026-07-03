import 'package:flutter/material.dart';
import '../services/adblock_service.dart';
import '../screens/shop_screen.dart';

/// Non-blocking nudge, NOT a functionality gate.
///
/// Google Play policy prohibits withholding core app functionality to
/// coerce a purchase or behavior change. DNS-based ad-block detection is
/// also unreliable as a hard gate — it can't distinguish "ad blocker" from
/// "user has Pi-hole/NextDNS/Quad9 private DNS for unrelated reasons," so a
/// full-screen lock would incorrectly shut real players out of a game
/// they're otherwise entitled to play. This shows a small, dismissible
/// banner instead: the game underneath stays fully playable at all times.
class AdBlockOverlay extends StatefulWidget {
  final Widget child;
  const AdBlockOverlay({required this.child, super.key});

  @override
  State<AdBlockOverlay> createState() => _AdBlockOverlayState();
}

class _AdBlockOverlayState extends State<AdBlockOverlay> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdBlockStatus>(
      valueListenable: AdBlockService().statusNotifier,
      builder: (context, status, _) {
        final show = AdBlockService().shouldShowAdBlockWall && !_dismissed;

        return Stack(
          children: [
            widget.child,
            if (show)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: _AdBlockBanner(
                    onDismiss: () => setState(() => _dismissed = true),
                    onGoAdFree: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const ShopScreen(scrollToRemoveAds: true),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdBlockBanner extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback onGoAdFree;

  const _AdBlockBanner({required this.onDismiss, required this.onGoAdFree});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF16213e),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.amberAccent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ads help keep Crystal Cascade free.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
            TextButton(
              onPressed: onGoAdFree,
              child: const Text('Go ad-free',
                  style: TextStyle(
                      color: Colors.amberAccent,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none)),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.white.withOpacity(0.6), size: 18),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 16,
            ),
          ],
        ),
      ),
    );
  }
}
