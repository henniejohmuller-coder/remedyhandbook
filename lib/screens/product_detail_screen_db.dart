import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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
  bool _isSaved = false;
  bool _savingToggle = false;

  @override
  void initState() {
    super.initState();
    _checkSaved();
  }

  static List<String> _extractUrls(String text) {
    final urlRegex = RegExp(r'https?://[^\s\])"]+', caseSensitive: false);
    return urlRegex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  Future<void> _checkSaved() async {
    final id = widget.product['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final saved = await SupabaseService.isProductSaved(id);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _toggleSaved() async {
    if (_savingToggle) return;
    setState(() => _savingToggle = true);
    final id = widget.product['id']?.toString() ?? '';
    if (_isSaved) {
      await SupabaseService.unsaveProduct(id);
    } else {
      await SupabaseService.saveProduct(id);
    }
    if (mounted) setState(() { _isSaved = !_isSaved; _savingToggle = false; });
  }

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
            YellowAppBar(
              title: name,
              subtitle: type,
              showBack: true,
              actions: [
                _savingToggle
                    ? const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark)))
                    : IconButton(
                        icon: Icon(
                          _isSaved ? Icons.favorite : Icons.favorite_border,
                          color: _isSaved ? Colors.red : AppColors.dark,
                        ),
                        onPressed: _toggleSaved,
                        tooltip: _isSaved ? 'Remove from favourites' : 'Save to favourites',
                      ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    p['image_url'] != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(12),
                            child: Image.network(p['image_url'], height: 280, width: double.infinity, fit: BoxFit.cover))
                        : HerbIconPlaceholder(size: 280, icon: type == 'Component' ? Icons.eco : Icons.science),
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
                        if (_extractUrls(description).isNotEmpty)
                          _ClinicalReferencesRow(urls: _extractUrls(description)),
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

class _ClinicalReferencesRow extends StatelessWidget {
  final List<String> urls;
  const _ClinicalReferencesRow({required this.urls});

  String _labelFor(String url) {
    if (url.contains('pubmed.ncbi.nlm.nih.gov')) {
      final match = RegExp(r'/(\d+)/?$').firstMatch(url);
      return match != null ? 'PubMed PMID ${match.group(1)}' : 'PubMed Study';
    }
    if (url.contains('mdpi.com') || url.contains('doi.org')) {
      return 'Full Article (MDPI)';
    }
    return 'Clinical Reference';
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('Clinical Studies',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          ...urls.map((url) => InkWell(
            onTap: () => _open(url),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.open_in_new, size: 14, color: Colors.blue),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _labelFor(url),
                      style: const TextStyle(fontSize: 13, color: Colors.blue,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          )),
        ],
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
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10), color: Colors.white),
        child: Icon(icon, size: 16, color: AppColors.dark),
      ),
    );
  }
}

