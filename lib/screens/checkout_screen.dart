import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import 'order_confirmation_screen.dart';
import 'payfast_screen.dart';
import 'cart_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _paying  = false;
  String? _savedToken;

  final _nameController    = TextEditingController();
  final _emailController   = TextEditingController();
  final _phoneController   = TextEditingController();
  final _addressController  = TextEditingController();
  final _cityController     = TextEditingController();
  final _postalController   = TextEditingController();
  final _provinceController = TextEditingController();
  final _specialController  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCart();
    _loadSavedToken();
    _prefillProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalController.dispose();
    _provinceController.dispose();
    _specialController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedToken() async {
    try {
      final userId = SupabaseService.supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await SupabaseService.supabase
          .from('profiles').select('payfast_token,payfast_token_status')
          .eq('id', userId).single();
      if (data['payfast_token'] != null && data['payfast_token_status'] == 'active') {
        setState(() => _savedToken = data['payfast_token']);
      }
    } catch (_) {}
  }

  Future<void> _loadCart() async {
    final items = await SupabaseService.getCart();
    setState(() { _items = items; _loading = false; });
  }

  Future<void> _prefillProfile() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;
      final profile = await SupabaseService.getProfile(userId);
      // Try shipping_address first, fallback to flat profile fields
      final addr = profile?['shipping_address'] as Map? ?? {};
      setState(() {
        _nameController.text     = addr['full_name']   ?? profile?['full_name'] ?? '';
        _emailController.text    = SupabaseService.currentUser?.email ?? '';
        _phoneController.text    = addr['phone']       ?? profile?['phone'] ?? '';
        _addressController.text  = addr['address1']            ?? profile?['address'] ?? '';
        _cityController.text     = addr['city']                 ?? profile?['city'] ?? '';
        _postalController.text   = addr['postal_code']          ?? '';
        _provinceController.text = addr['province']             ?? '';
        _specialController.text  = addr['special_instructions'] ?? '';
      });
    } catch (_) {}
  }

  double get subtotal => _items.fold(0, (s, i) {
    final product = i['products'];
    if (product == null) return s;
    final price = ((product['price'] ?? 0) as num).toDouble();
    final qty   = (i['quantity'] ?? 1) as int;
    return s + price * qty;
  });
  double get shipping => subtotal >= 500 ? 0 : 85;
  double get total    => subtotal + shipping;

  Future<void> _payWithToken() async {
    if (_nameController.text.isEmpty || _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _paying = true);
    try {
      final orderResult = await SupabaseService.placeOrder(
        deliveryDetails: {
          'full_name':   _nameController.text.trim(),
          'email':       _emailController.text.trim(),
          'phone':       _phoneController.text.trim(),
          'address':     _addressController.text.trim(),
          'city':        _cityController.text.trim(),
          'postal_code': _postalController.text.trim(),
          'country':     'South Africa',
        },
        cartItems: _items, subtotal: subtotal, shipping: shipping, total: total,
      );
      final orderId = orderResult['id']?.toString() ?? '';
      await SupabaseService.supabase.rpc('process_token_payment', params: {
        'p_token': _savedToken,
        'p_amount': (total * 100).round(),
        'p_item_name': 'Remedy Handbook Order',
        'p_order_id': orderId,
      });
      CartBadge.update(0);
      CartScreen.reload();
      setState(() => _paying = false);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderConfirmationScreen()));
      }
    } catch (e) {
      setState(() => _paying = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ' + e.toString()), backgroundColor: Colors.red));
    }
  }

  Future<void> _pay() async {
    if (_nameController.text.isEmpty || _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _paying = true);
    try {
      final orderResult = await SupabaseService.placeOrder(
        deliveryDetails: {
          'full_name':   _nameController.text.trim(),
          'email':       _emailController.text.trim(),
          'phone':       _phoneController.text.trim(),
          'address':     _addressController.text.trim(),
          'city':        _cityController.text.trim(),
          'postal_code': _postalController.text.trim(),
          'country':     'South Africa',
        },
        cartItems: _items,
        subtotal: subtotal,
        shipping: shipping,
        total: total,
      );
      setState(() => _paying = false);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => PayFastScreen(
          productName: 'Remedy Handbook Order',
          amount: total,
          orderId: orderResult['id']?.toString() ?? '',
        ),
      ));
      if (mounted) {
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Complete payment in browser. Return here after payment.'),
              backgroundColor: Colors.blue, duration: Duration(seconds: 8)));
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderConfirmationScreen()));
        }
      }
    } catch (e) {
      setState(() => _paying = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order failed: ' + e.toString()), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const YellowAppBar(title: 'Checkout', subtitle: 'Almost there!', showBack: true),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                        // Delivery details
                        const SectionLabel('DELIVERY DETAILS'),
                        _inputField('Full name *', _nameController, 'e.g. Maria Smit'),
                        const SizedBox(height: 10),
                        _inputField('Email *', _emailController, 'e.g. maria@email.com'),
                        const SizedBox(height: 10),
                        _inputField('Phone *', _phoneController, 'e.g. +27 82 123 4567'),
                        const SizedBox(height: 10),
                        _inputField('Address *', _addressController, 'e.g. 12 Rose Street'),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _inputField('City', _cityController, 'Cape Town')),
                          const SizedBox(width: 10),
                          Expanded(child: _inputField('Province', _provinceController, 'Western Cape')),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _inputField('Postal code', _postalController, '8001')),
                          const SizedBox(width: 10),
                          Expanded(child: _inputField('Country', TextEditingController(text: 'South Africa'), 'South Africa')),
                        ]),
                        const SizedBox(height: 10),
                        _inputField('Special instructions', _specialController, 'e.g. Leave at gate', maxLines: 2),
                        const SizedBox(height: 16),

                        // Cart items
                        const SectionLabel('ORDER ITEMS'),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                          child: Column(children: [
                            ..._items.map((item) {
                              final product = (item['products'] as Map?)?.cast<String, dynamic>() ?? {};
                              final name    = (product['name'] ?? '').toString();
                              final price   = ((product['price'] ?? 0) as num).toDouble();
                              final qty     = (item['quantity'] ?? 1) as int;
                              if (name.isEmpty) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Expanded(child: Text('$name x$qty', style: AppTextStyles.body, overflow: TextOverflow.ellipsis)),
                                  Text('R${(price * qty).toInt()}', style: AppTextStyles.body),
                                ]),
                              );
                            }),
                          ]),
                        ),
                        const SizedBox(height: 12),

                        // Totals
                        const SectionLabel('ORDER SUMMARY'),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                          child: Column(children: [
                            InfoRow(label: 'Subtotal', value: 'R${subtotal.toInt()}'),
                            InfoRow(
                              label: 'Delivery',
                              value: shipping == 0 ? 'FREE' : 'R${shipping.toInt()}',
                            ),
                            const Divider(height: 16),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text('R${total.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.dark)),
                            ]),
                          ]),
                        ),
                        const SizedBox(height: 20),

                        // Pay button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _paying ? null : (_savedToken != null ? _payWithToken : _pay),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.dark, foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            child: _paying
                                ? const SizedBox(width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Text(_savedToken != null ? 'One-click Pay R\  ' : 'Pay R\ securely  ',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(4)),
                                      child: const Text('PayFast', style: TextStyle(color: AppColors.dark, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ]),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Redirected to PayFast to complete payment\nsecurely.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.caption,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField(String label, TextEditingController controller, String hint, {int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTextStyles.label),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    ]);
  }
}





