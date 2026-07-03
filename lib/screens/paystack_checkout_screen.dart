import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/paystack_service.dart';

/// Loads Paystack's hosted checkout page (the authorization_url our backend
/// returned) and watches navigation for the redirect back to
/// [PaystackService.callbackUrl], which means the payment flow is over —
/// success, failure, or the user closing it themselves all land here the
/// same way, since Paystack always redirects eventually.
///
/// Pops with the transaction [reference] once the callback fires (the
/// caller still verifies that reference against our backend afterwards —
/// this screen never claims to know whether the payment succeeded, only
/// that the flow finished), or pops with null if the user backs out early.
class PaystackCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;
  final String reference;

  const PaystackCheckoutScreen({
    super.key,
    required this.checkoutUrl,
    required this.reference,
  });

  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _finished = false; // guards against popping twice

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            if (request.url.startsWith(PaystackService.callbackUrl)) {
              _finish(widget.reference);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _finish(String? reference) {
    if (_finished) return;
    _finished = true;
    Navigator.of(context).pop(reference);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _finish(null);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1a1a2e),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1a1a2e),
          elevation: 0,
          title: const Text(
            'Secure Checkout',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => _finish(null),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: Container(
              height: 2,
              color: Colors.greenAccent.withOpacity(0.6),
            ),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(color: Colors.purpleAccent),
              ),
          ],
        ),
      ),
    );
  }
}
