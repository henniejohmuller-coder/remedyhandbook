import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import 'checkout_screen.dart';
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

  @override
  void initState() {
    super.initState();
    CartScreen._reloadCallback = _loadCart;
    _loadCart();
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

  double get shipping {
    if (subtotal >= 500) return 0;
    // Use highest delivery_cost among items, fallback to R85
    double maxDelivery = 0;
    for (final i in _items) {
      final dc = ((i['products']?['delivery_cost'] ?? 0) as num).toDouble();
      if (dc > maxDelivery) maxDelivery = dc;
    }
    return maxDelivery > 0 ? maxDelivery : 85;
  }
  double get total    => subtotal + shipping;

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
              return YellowAppBar(
                title: 'My cart',
                subtitle: '$totalQty item${totalQty == 1 ? '' : 's'}',
                showBack: true,
              );
            }),
            // Free delivery bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  const Icon(Icons.local_shipping_outlined, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    total >= 500
                        ? '🎉 Free delivery unlocked!'
                        : 'Add R${(500 - subtotal).toInt()} more for free delivery!',
                    style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500),
                  ),
                ]),
              ),
            ),
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
                                color: Colors.white, borderRadius: BorderRadius.circular(12),
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
                                  Text('R${price.toInt()}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.dark)),
                                ])),
                                // Qty controls
                                Column(children: [
                                  Row(children: [
                                    _QtyBtn(icon: Icons.remove, onTap: () => _updateQty(productId, qty - 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Delivery', style: AppTextStyles.caption),
                    Text(shipping == 0 ? 'FREE' : 'R${shipping.toInt()}',
                        style: TextStyle(fontSize: 13, color: shipping == 0 ? Colors.green : AppColors.textSecondary)),
                  ]),
                  const Divider(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dark)),
                    Text('R${total.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.dark)),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const CheckoutScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: Text('Checkout · R${total.toInt()}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
