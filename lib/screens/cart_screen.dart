import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import 'delivery_screen.dart';
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  // Static reload callback
  static VoidCallback? _reloadCallback;
  static void reload() => _reloadCallback?.call();

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  double _discountPct = 0;
  int?   _enrollmentId;

  @override
  void initState() {
    super.initState();
    CartScreen._reloadCallback = _loadCart;
    _loadCart();
    _loadDiscount();
  }

  Future<void> _loadDiscount() async {
    final userId = SupabaseService.supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await SupabaseService.supabase
          .from('profiles')
          .select('enrollment_id, discount_pct')
          .eq('id', userId)
          .single();
      if (mounted) {
        setState(() {
          _enrollmentId = data['enrollment_id'] as int?;
          _discountPct  = ((data['discount_pct'] ?? 0) as num).toDouble();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    CartScreen._reloadCallback = null;
    super.dispose();
  }

  Future<void> _loadCart() async {
    setState(() => _loading = true);
    try {
      final items = await SupabaseService.getCart();
      print('Cart raw: $items');
      // Filter out items where product was deleted
      // Keep ALL items — show error state for those with missing product
      // rather than silently dropping them
      final totalQty = items.fold<int>(0, (sum, i) => sum + ((i['quantity'] ?? 1) as int));
      CartBadge.update(totalQty);
      setState(() { _items = items; _loading = false; });
    } catch (e) {
      print('Cart error: $e');
      setState(() => _loading = false);
    }
  }

  double get subtotal => _items.fold(0, (s, i) {
    final product = i['products'];
    if (product == null) return s;
    final price = ((product['price'] ?? 0) as num).toDouble();
    final qty   = (i['quantity'] ?? 1) as int;
    return s + price * qty;
  });

  double get discountAmount     => _discountPct > 0 ? subtotal * _discountPct / 100 : 0;
  double get discountedSubtotal => subtotal - discountAmount;

  Future<void> _updateQty(String productId, int qty) async {
    await SupabaseService.updateCartQuantity(productId, qty);
    _loadCart();
  }

  Future<void> _remove(String productId) async {
    // Update badge immediately
    CartBadge.update((CartBadge.notifier.value - 1).clamp(0, 999));
    await SupabaseService.removeFromCart(productId);
    _loadCart();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Builder(builder: (_) {
              final totalQty = _items.fold<int>(0,
                  (s, i) => s + ((i['quantity'] ?? 1) as int));
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  YellowAppBar(
                    title: 'My cart',
                    subtitle: '$totalQty item${totalQty == 1 ? '' : 's'}',
                    showBack: true,
                  ),
                  if (_discountPct > 0)
                    Positioned.fill(
                      child: Align(
                        alignment: const Alignment(0.3, 0.0),
                        child: Transform.rotate(
                          angle: -0.52,
                          child: _DiscountStamp(pct: _discountPct),
                        ),
                      ),
                    ),
                ],
              );
            }),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _items.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.shopping_cart_outlined, size: 56, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          const Text('Your cart is empty', style: AppTextStyles.heading3),
                          const SizedBox(height: 4),
                          const Text('Add items from the Recipes page', style: AppTextStyles.caption),
                        ]))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final item      = _items[i];
                            final product   = (item['products'] as Map?)?.cast<String, dynamic>();
                            // Skip items with no matching product (deleted/broken reference)
                            if (product == null) return const SizedBox.shrink();
                            final name      = (product['name'] ?? '').toString();
                            final type      = (product['type'] ?? '').toString();
                            final price     = ((product['price'] ?? 0) as num).toDouble();
                            final imageUrl  = (product['image_url'] ?? '').toString();
                            final qty       = (item['quantity'] ?? 1) as int;
                            final productId = (item['product_id'] ?? '').toString();
                            if (productId.isEmpty) return const SizedBox.shrink();

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white, borderRadius: BorderRadius.circular(10),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                              ),
                              child: Row(children: [
                                // Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const HerbIconPlaceholder(size: 60))
                                      : const HerbIconPlaceholder(size: 60),
                                ),
                                const SizedBox(width: 12),
                                // Info
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(name, style: AppTextStyles.heading3, overflow: TextOverflow.ellipsis),
                                  Text(type, style: AppTextStyles.caption),
                                  const SizedBox(height: 4),
                                  Text('R${price.toInt()}', style: AppTextStyles.heading3),
                                ])),
                                // Qty controls
                                Column(children: [
                                  Row(children: [
                                    _QtyBtn(icon: Icons.remove, onTap: () => _updateQty(productId, qty - 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text('$qty', style: AppTextStyles.heading3),
                                    ),
                                    _QtyBtn(icon: Icons.add, onTap: () => _updateQty(productId, qty + 1)),
                                  ]),
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: () => _remove(productId),
                                    child: const Text('Remove', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500)),
                                  ),
                                ]),
                              ]),
                            );
                          },
                        ),
            ),
            // Summary
            if (!_loading && _items.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))],
                ),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Subtotal', style: AppTextStyles.body),
                    Text('R${subtotal.toInt()}', style: AppTextStyles.body),
                  ]),
                  if (_discountPct > 0) ...[
                    const SizedBox(height: 4),
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(
                        'Discount (${_discountPct % 1 == 0 ? _discountPct.toInt() : _discountPct}%'
                        '${_enrollmentId != null ? ' · #$_enrollmentId' : ''})',
                        style: const TextStyle(fontSize: 13, color: Colors.green),
                      ),
                      Text('- R${discountAmount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w600)),
                    ]),
                  ],
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Delivery', style: AppTextStyles.caption),
                    const Text('Pending', style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                  ]),
                  const Divider(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Products total', style: AppTextStyles.heading3),
                    Text('R${discountedSubtotal.toInt()}', style: AppTextStyles.heading2),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const DeliveryScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
                        minimumSize: const Size(double.infinity, 44),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Choose Delivery & Checkout',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: AppColors.background, borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(icon, size: 16, color: AppColors.dark),
      ),
    );
  }
}

class _DiscountStamp extends StatelessWidget {
  final double pct;
  const _DiscountStamp({required this.pct});
  @override
  Widget build(BuildContext context) {
    final label = pct % 1 == 0 ? '${pct.toInt()}%' : '$pct%';
    return Opacity(
      opacity: 0.88,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFB71C1C), width: 2),
          borderRadius: BorderRadius.circular(3),
          color: Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('EARLY SUPPORTER', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w900, color: Color(0xFFB71C1C), letterSpacing: 1.0, height: 1.2)),
            Text('$label DISCOUNT', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFFB71C1C), letterSpacing: 0.8, height: 1.2)),
          ],
        ),
      ),
    );
  }
}
