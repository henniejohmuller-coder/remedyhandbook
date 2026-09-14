import 'dart:convert';
import 'package:crypto/crypto.dart';
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

  static const _merchantId  = '15410594';
  static const _merchantKey = '8dpf81oao9xdo';
  static const _passphrase  = 'PayfastHennie1';
  static const _sandbox     = false;

  static String get _pfUrl => _sandbox
      ? 'https://sandbox.payfast.co.za/eng/process'
      : 'https://payment.payfast.io/eng/process';

  static const _returnUrl = 'https://remedyhandbook.com/payment-success';
  static const _cancelUrl = 'https://remedyhandbook.com/payment-cancel';
  static const _notifyUrl = 'https://stawsdjfjzugeleldaxz.supabase.co/functions/v1/payfast-notify';

  // PHP-compatible urlencode
  String _phpEncode(String value) =>
      Uri.encodeComponent(value.trim()).replaceAll('%20', '+');

  // Generate MD5 signature
  String _generateSignature(Map<String, String> data) {
    final query = data.entries
        .map((e) => '${e.key}=${_phpEncode(e.value)}')
        .join('&');
    final withPp = '$query&passphrase=${_phpEncode(_passphrase)}';
    return md5.convert(utf8.encode(withPp)).toString();
  }

  // Build payment data
  Map<String, String> _buildData() {
    final user = SupabaseService.supabase.auth.currentUser;
    final email = user?.email ?? '';
    final firstName = email.isNotEmpty ? email.split('@').first : 'Customer';
    return {
      'merchant_id':       _merchantId,
      'merchant_key':      _merchantKey,
      'return_url':        _returnUrl,
      'cancel_url':        _cancelUrl,
      'notify_url':        _notifyUrl,
      'name_first':        firstName,
      'name_last':         '',
      'email_address':     email,
      'm_payment_id':      widget.orderId,
      'amount':            widget.amount.toStringAsFixed(2),
      'item_name':         widget.productName,
      'subscription_type': '2',
    };
  }

  String _buildPayFastHtml() {
    final data = _buildData();
    final sig = _generateSignature(data);
    final fields = data.entries
        .map((e) => '  <input type="hidden" name="${e.key}" value="${e.value}">')
        .join('\n');
    return '''<!DOCTYPE html>
<html>
<head><meta name="viewport" content="width=device-width, initial-scale=1">
<style>body{display:flex;justify-content:center;align-items:center;height:100vh;margin:0;background:#F5F0E8;font-family:sans-serif;}h2{color:#2C1A00;}</style>
</head>
<body>
<div style="text-align:center"><h2>Redirecting to PayFast...</h2><p>Please wait...</p></div>
<form id="pf" action="$_pfUrl" method="post">
$fields
  <input type="hidden" name="signature" value="$sig">
</form>
<script>document.getElementById('pf').submit();</script>
</body></html>''';
  }

  Future<void> _updateOrderStatus(String status) async {
    try {
      await SupabaseService.supabase
          .from('orders')
          .update({'status': status, 'payment_status': status})
          .eq('id', widget.orderId);
    } catch (e) {
      debugPrint('Error updating order status: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final data = _buildData();
        final sig = _generateSignature(data);
        final query = data.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&') + '&signature=$sig';
        final uri = Uri.parse('$_pfUrl?$query');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        if (mounted) Navigator.pop(context);
      });
      return;
    }

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          if (url.startsWith(_returnUrl)) {
            _updateOrderStatus('paid');
            _onPaymentSuccess();
          } else if (url.startsWith(_cancelUrl)) {
            _updateOrderStatus('cancelled');
            _onPaymentCancelled();
          } else {
            setState(() => _loading = true);
          }
        },
        onPageFinished: (url) => setState(() => _loading = false),
      ))
      ..loadHtmlString(_buildPayFastHtml());
  }

  Future<void> _enableOneClick() async {
    try {
      final userId = SupabaseService.supabase.auth.currentUser?.id;
      if (userId == null) return;
      await SupabaseService.supabase.from('profiles')
          .update({'payfast_oneclick_enabled': true})
          .eq('id', userId);
    } catch (e) {
      debugPrint('Error enabling one-click: ' + e.toString());
    }
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
        content: Text('Thank you!' + '\n' + widget.productName,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Ask about one-click payment
              if (mounted) {
                final enable = await showDialog<bool>(
                  context: context,
                  builder: (ctx2) => AlertDialog(
                    backgroundColor: AppColors.dark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('One-click payments?',
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    content: const Text('Enable one-click payments for future orders? Your card will be charged automatically.',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx2, false),
                        child: const Text('No thanks', style: TextStyle(color: Colors.white54))),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx2, true),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary, foregroundColor: AppColors.dark),
                        child: const Text('Yes, enable')),
                    ],
                  ),
                );
                if (enable == true) await _enableOneClick();
              }
              if (mounted) Navigator.pop(context);
            },
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
              content: const Text('Are you sure?'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Continue')),
                ElevatedButton(
                  onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red, foregroundColor: Colors.white),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: Stack(children: [
          WebViewWidget(controller: _controller!),
          if (_loading) const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        ])),
      ])),
    );
  }
}


