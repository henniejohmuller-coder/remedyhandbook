import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';

class PayFastScreen extends StatefulWidget {
  final String productName;
  final double amount;
  final String orderId;

  const PayFastScreen({
    super.key,
    required this.productName,
    required this.amount,
    required this.orderId,
  });

  @override
  State<PayFastScreen> createState() => _PayFastScreenState();
}

class _PayFastScreenState extends State<PayFastScreen> {
  WebViewController? _controller;
  bool _loading = true;

  // ── PayFast Credentials ───────────────────────────────────────────────────
  static const _receiver    = '15410594'; // Your Merchant ID
  static const _sandbox     = false;

  static String get _pfUrl => _sandbox
      ? 'https://sandbox.payfast.co.za/eng/process'
      : 'https://payment.payfast.io/eng/process';

  static const _returnUrl = 'https://remedyhandbook.com/';
  static const _cancelUrl = 'https://remedyhandbook.com/';
  static const _notifyUrl = 'https://remedyhandbook.com/';

  // ── Build HTML form for POST submission ───────────────────────────────────
  String _buildPayFastHtml() {
    final amount = widget.amount.toStringAsFixed(2);
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body { display: flex; justify-content: center; align-items: center; 
           height: 100vh; margin: 0; background: #F5F0E8; font-family: sans-serif; }
    .loading { text-align: center; color: #2C1A00; }
    h2 { color: #2C1A00; }
  </style>
</head>
<body>
  <div class="loading">
    <h2>Redirecting to PayFast...</h2>
    <p>Please wait while we redirect you to secure payment.</p>
  </div>
  <form id="pf" name="PayFastPayNowForm" action="$_pfUrl" method="post">
    <input type="hidden" name="cmd" value="_paynow">
    <input type="hidden" name="receiver" value="$_receiver">
    <input type="hidden" name="return_url" value="$_returnUrl">
    <input type="hidden" name="cancel_url" value="$_cancelUrl">
    <input type="hidden" name="notify_url" value="$_notifyUrl">
    <input type="hidden" name="amount" value="$amount">
    <input type="hidden" name="item_name" value="${widget.productName}">
    <input type="hidden" name="m_payment_id" value="${widget.orderId}">
  </form>
  <script>document.getElementById('pf').submit();</script>
</body>
</html>
''';
  }

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      // On web: build PayFast URL and open in new tab
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final amount = widget.amount.toStringAsFixed(2);
        // Use GET parameters for web (simpler than POST form)
        final params = {
          'cmd': '_paynow',
          'receiver': _receiver,
          'return_url': _returnUrl,
          'cancel_url': _cancelUrl,
          'notify_url': _notifyUrl,
          'amount': amount,
          'item_name': widget.productName,
          'm_payment_id': widget.orderId,
        };
        final query = params.entries.map((e) => e.key + '=' + Uri.encodeComponent(e.value)).join('&');
        final pfUrl = _pfUrl + '?' + query;
        final uri = Uri.parse(pfUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (mounted) Navigator.pop(context);
      });
      return;
    }

    // On mobile: load HTML in WebView which auto-submits form to PayFast
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (url) {
          setState(() => _loading = false);
          if (url.contains('payment-success') || url.startsWith(_returnUrl)) {
            _onPaymentSuccess();
          } else if (url.contains('payment-cancel') || url.startsWith(_cancelUrl)) {
            _onPaymentCancelled();
          }
        },
      ))
      ..loadHtmlString(_buildPayFastHtml());
  }

  void _onPaymentSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.dark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Payment Successful!',
            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
        content: Text('Thank you for your order!\n${widget.productName}',
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: AppColors.dark),
            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _onPaymentCancelled() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment cancelled'), backgroundColor: Colors.orange));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || _controller == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: Column(children: [
          YellowAppBar(title: 'Redirecting to PayFast',
              subtitle: 'R${widget.amount.toStringAsFixed(2)}', showBack: true),
          const Expanded(child: Center(
              child: CircularProgressIndicator(color: AppColors.primary))),
        ])),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        YellowAppBar(
          title: 'Secure Payment',
          subtitle: 'R${widget.amount.toStringAsFixed(2)} — ${widget.productName}',
          showBack: true,
          onBack: () => showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Cancel Payment?'),
              content: const Text('Are you sure you want to cancel?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Continue')),
                ElevatedButton(
                  onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: Stack(children: [
          WebViewWidget(controller: _controller!),
          if (_loading) const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ])),
      ])),
    );
  }
}

