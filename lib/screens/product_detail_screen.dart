import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            YellowAppBar(
              title: widget.product.name,
              subtitle: widget.product.type,
              showBack: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product image
                    const HerbIconPlaceholder(size: 140, icon: Icons.science),
                    const SizedBox(height: 16),
                    // Price
                    Row(
                      children: [
                        Text('R${widget.product.price.toInt()}',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.dark)),
                        if (widget.product.originalPrice != null) ...[
                          const SizedBox(width: 8),
                          Text('R${widget.product.originalPrice!.toInt()}',
                            style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, decoration: TextDecoration.lineThrough)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.check_circle, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text('In stock · Ships in ${widget.product.deliveryDays} days',
                        style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500)),
                    ]),
                    const SectionLabel("WHAT'S INCLUDED"),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                      child: Column(
                        children: [
                          InfoRow(label: 'Name', value: widget.product.name),
                          InfoRow(label: 'Type', value: widget.product.type),
                          if (widget.product.description.isNotEmpty) InfoRow(label: 'Description', value: widget.product.description),
                          InfoRow(label: 'Category', value: widget.product.category),
                          InfoRow(label: 'Brand', value: widget.product.brand),
                          InfoRow(label: 'Linked recipe', value: widget.product.linkedRemedy),
                          InfoRow(
                            label: 'Prep guide',
                            valueWidget: const Text('Included', style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),
                    ),
                    const SectionLabel('QUANTITY'),
                    Row(
                      children: [
                        _QtyButton(icon: Icons.remove, onTap: () { if (_quantity > 1) setState(() => _quantity--); }),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        _QtyButton(icon: Icons.add, onTap: () => setState(() => _quantity++)),
                        const SizedBox(width: 8),
                        const Text('unit', style: AppTextStyles.caption),
                      ],
                    ),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Add to cart · R${(widget.product.price * _quantity).toInt()}',
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text('View recipe', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Icon(icon, size: 16, color: AppColors.dark),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DB VERSION — uses Map<String, dynamic> from Supabase
// ═══════════════════════════════════════════════════════════════════════════

class ProductDetailScreenDB extends StatefulWidget {
  final Map<String, dynamic> product;
  final String? linkedRemedyId;  // pass to load all sibling products
  const ProductDetailScreenDB({super.key, required this.product, this.linkedRemedyId});

  @override
  State<ProductDetailScreenDB> createState() => _ProductDetailScreenDBState();
}

class _ProductDetailScreenDBState extends State<ProductDetailScreenDB> {
  int _quantity = 1;
  Map<String, dynamic> _product = {};
  bool _loading = true;
  List<Map<String, dynamic>> _siblingProducts = [];

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    _loadFresh();
    _loadSiblings();
  }

  Future<void> _loadSiblings() async {
    // Use passed linkedRemedyId OR fall back to the product's own field
    final remedyId = widget.linkedRemedyId
        ?? widget.product['linked_remedy_id']?.toString();
    if (remedyId == null || remedyId.isEmpty) return;
    try {
      final data = await SupabaseService.supabase
          .from('products')
          .select()
          .eq('linked_remedy_id', remedyId)
          .order('type')
          .order('name');
      if (mounted) {
        setState(() {
          // All products linked to this remedy, excluding this one
          _siblingProducts = (data as List)
              .cast<Map<String, dynamic>>()
              .where((p) => p['id']?.toString() != _product['id']?.toString())
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadFresh() async {
    try {
      final id = widget.product['id'];
      if (id == null) { setState(() => _loading = false); return; }
      final result = await SupabaseService.supabase
          .from('products').select().eq('id', id).single();
      setState(() { _product = result; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String get name         => _product['name'] ?? '';
  String get type         => _product['type'] ?? '';
  double get price        => ((_product['price'] ?? 0) as num).toDouble();
  double? get origPrice   => _product['original_price'] != null
      ? ((_product['original_price']) as num).toDouble() : null;
  bool   get inStock      => _product['in_stock'] == true;
  String get deliveryDays => _product['delivery_days'] ?? '2-3';
  String get imageUrl     => _product['image_url'] ?? '';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            YellowAppBar(title: name, subtitle: type, showBack: true),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    imageUrl.isNotEmpty
                        ? ClipRRect(borderRadius: BorderRadius.circular(12),
                            child: Container(
                              height: 140,
                              color: Colors.grey.shade50,
                              child: Transform.scale(
                                scale: 0.50,
                                child: Image.network(
                                  '$imageUrl?${DateTime.now().millisecondsSinceEpoch}',
                                  width: double.infinity, fit: BoxFit.contain,
                                  headers: const {'Cache-Control': 'no-cache'},
                                  errorBuilder: (_, __, ___) => const HerbIconPlaceholder(size: 120),
                                ),
                              ),
                            ))
                        : const HerbIconPlaceholder(size: 120, icon: Icons.science),
                    const SizedBox(height: 16),
                    Row(children: [
                      Text('R${price.toInt()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.dark)),
                      if (origPrice != null) ...[
                        const SizedBox(width: 8),
                        Text('R${origPrice!.toInt()}', style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, decoration: TextDecoration.lineThrough)),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(inStock ? Icons.check_circle : Icons.cancel, size: 14, color: inStock ? Colors.green : Colors.red),
                      const SizedBox(width: 4),
                      Text(inStock ? 'In stock · Ships in $deliveryDays days' : 'Out of stock',
                          style: TextStyle(fontSize: 12, color: inStock ? Colors.green : Colors.red, fontWeight: FontWeight.w500)),
                    ]),
                    const SectionLabel("WHAT'S INCLUDED"),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                      child: Column(children: [
                        InfoRow(label: 'Name', value: name),
                        InfoRow(label: 'Type', value: type),
                        if (_product['description'] != null &&
                            _product['description'].toString().isNotEmpty)
                          InfoRow(label: 'Description',
                              value: _product['description'].toString()),
                        if (_product['prep_guide_included'] == true)
                          const InfoRow(label: 'Prep guide',
                              valueWidget: Text('Included', style: TextStyle(
                                  fontSize: 13, color: Colors.green,
                                  fontWeight: FontWeight.w500))),
                      ]),
                    ),
                    const SectionLabel('QUANTITY'),
                    Row(children: [
                      _QtyButton(icon: Icons.remove, onTap: () { if (_quantity > 1) setState(() => _quantity--); }),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      _QtyButton(icon: Icons.add, onTap: () => setState(() => _quantity++)),
                      const SizedBox(width: 8),
                      const Text('unit', style: AppTextStyles.caption),
                    ]),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (!SupabaseService.isLoggedIn) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please sign in to add to cart'), backgroundColor: Colors.red));
                            return;
                          }
                          // Update badge immediately
                          CartBadge.update(CartBadge.notifier.value + _quantity);
                          // Save to Supabase
                          await SupabaseService.addToCart(_product['id'], quantity: _quantity);
                          // Reload cart screen and sync badge with real count
                          CartScreen.reload();
                          SupabaseService.getCart().then((cart) {
                            CartBadge.update(cart.fold<int>(0, (s, i) => s + ((i['quantity'] ?? 1) as int)));
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('✅ ${_quantity}x $name added to cart!'),
                              backgroundColor: Colors.green,
                              duration: const Duration(seconds: 2),
                            ));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Text('Add to cart · R${(price * _quantity).toInt()}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                    // ── Other items linked to this remedy ──────────────
                    if (_siblingProducts.isNotEmpty) ...[
                      const SectionLabel('ALSO IN THIS COLLECTION'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _siblingProducts.map((p) {
                          final pName  = p['name']?.toString() ?? '';
                          final pPrice = ((p['price'] ?? 0) as num).toInt();
                          final pImg   = p['image_url']?.toString() ?? '';
                          final pType  = p['type']?.toString() ?? '';
                          return GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreenDB(
                                  product: p,
                                  linkedRemedyId: widget.linkedRemedyId
                                      ?? widget.product['linked_remedy_id']?.toString(),
                                ),
                              ),
                            ),
                            child: Container(
                              width: (MediaQuery.of(context).size.width - 56) / 3,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: pType == 'Component'
                                      ? AppColors.dark : AppColors.primary,
                                  width: 1.2,
                                ),
                              ),
                              child: Column(children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    height: 90,
                                    width: double.infinity,
                                    color: Colors.grey.shade50,
                                    child: pImg.isNotEmpty
                                        ? Image.network(pImg,
                                            height: 90, width: double.infinity,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) =>
                                                const HerbIconPlaceholder(size: 90))
                                        : const HerbIconPlaceholder(size: 90),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(pName,
                                    style: const TextStyle(
                                        fontSize: 10, fontWeight: FontWeight.w700),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center),
                                Text('R$pPrice', style: AppTextStyles.caption),
                                const SizedBox(height: 4),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: pType == 'Component'
                                        ? AppColors.dark : AppColors.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    pType == 'Component'
                                        ? 'Component' : 'Remedy',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color: pType == 'Component'
                                          ? AppColors.primary : AppColors.dark,
                                    ),
                                  ),
                                ),
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

