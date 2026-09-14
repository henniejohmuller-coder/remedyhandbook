import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import 'cart_screen.dart';

class ProductDetailScreenDB extends StatefulWidget {
  final Map<String, dynamic> product;
  final String? linkedRemedyId;
  const ProductDetailScreenDB({super.key, required this.product, this.linkedRemedyId});

  @override
  State<ProductDetailScreenDB> createState() => _ProductDetailScreenDBState();
}

class _ProductDetailScreenDBState extends State<ProductDetailScreenDB> {
  int _quantity = 1;
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final p             = widget.product;
    final name          = p['name'] ?? '';
    final type          = p['type'] ?? '';
    final price         = (p['price'] as num).toDouble();
    final originalPrice = p['original_price'] != null ? (p['original_price'] as num).toDouble() : null;
    final inStock       = p['in_stock'] ?? true;
    final deliveryDays  = p['delivery_days'] ?? '2-3';
    final prepGuide     = p['prep_guide_included'] ?? true;
    final description   = p['description'] ?? '';
    final category      = p['category'] ?? '';
    final brand           = p['brand'] ?? '';
    final primaryHerb     = p['primary_herb'] ?? '';
    final mainConstituent = p['main_constituent'] ?? '';

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
                    p['image_url'] != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(12),
                            child: Image.network(p['image_url'], height: 140, width: double.infinity, fit: BoxFit.cover))
                        : HerbIconPlaceholder(size: 140, icon: type == 'Component' ? Icons.eco : Icons.science),
                    const SizedBox(height: 16),
                    Row(children: [
                      Text('R${price.toInt()}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.dark)),
                      if (originalPrice != null) ...[
                        const SizedBox(width: 8),
                        Text('R${originalPrice.toInt()}', style: const TextStyle(fontSize: 16, color: AppColors.textSecondary, decoration: TextDecoration.lineThrough)),
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
                        if (description.isNotEmpty) InfoRow(label: 'Description', value: description),
                        InfoRow(label: 'Category', value: category),
                        InfoRow(label: 'Brand', value: brand),
                        if (primaryHerb.isNotEmpty) InfoRow(label: 'Primary Herb', value: primaryHerb),
                        if (mainConstituent.isNotEmpty) InfoRow(label: 'Main Constituent', value: mainConstituent),
                        if (prepGuide) InfoRow(label: 'Prep guide',
                            valueWidget: const Text('Included', style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.w500))),
                      ]),
                    ),
                    const SectionLabel('QUANTITY'),
                    Row(children: [
                      _QtyBtn(icon: Icons.remove, onTap: () { if (_quantity > 1) setState(() => _quantity--); }),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text('$_quantity', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      _QtyBtn(icon: Icons.add, onTap: () => setState(() => _quantity++)),
                      const SizedBox(width: 8),
                      const Text('unit', style: AppTextStyles.caption),
                    ]),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _adding || !inStock ? null : () async {
                          setState(() => _adding = true);
                          await SupabaseService.addToCart(p['id'], quantity: _quantity);
                          setState(() => _adding = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ Added to cart!'), backgroundColor: Colors.green));
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
                          disabledBackgroundColor: Colors.grey.shade200,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0),
                        child: _adding
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                            : Text('Add to cart · R${(price * _quantity).toInt()}',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
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

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), color: Colors.white),
        child: Icon(icon, size: 16, color: AppColors.dark),
      ),
    );
  }
}

