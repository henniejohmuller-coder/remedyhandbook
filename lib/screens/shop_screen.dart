import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import 'product_detail_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  static VoidCallback? _reloadCallback;
  static void reload() => _reloadCallback?.call();

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String _filter = 'All';
  String _search = '';
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ShopScreen._reloadCallback = _loadProducts;
    _loadProducts();
  }

  @override
  void dispose() {
    ShopScreen._reloadCallback = null;
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getProducts();
      if (!mounted) return;
      setState(() { _products = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _products.where((p) {
      final type    = (p['type'] ?? '').toString();
      final name    = (p['name'] ?? '').toString().toLowerCase();
      final desc    = (p['description'] ?? '').toString().toLowerCase();
      final matchFilter = _filter == 'All'
          || (_filter == 'Components' && type == 'Component')
          || (_filter == 'Remedies'   && type == 'Remedy');
      final matchSearch = _search.isEmpty
          || name.contains(_search.toLowerCase())
          || desc.contains(_search.toLowerCase());
      return matchFilter && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const YellowAppBar(title: 'Shop', subtitle: 'Free delivery over R500'),
            const SizedBox(height: 12),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: AppTextStyles.caption,
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                    suffixIcon: _search.isNotEmpty
                        ? GestureDetector(
                            onTap: () { _searchController.clear(); setState(() => _search = ''); },
                            child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary))
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Filter tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: ['All', 'Components', 'Remedies'].map((tab) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = tab),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _filter == tab ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _filter == tab ? AppColors.primary : Colors.grey.shade200),
                      ),
                      child: Text(tab, style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: _filter == tab ? AppColors.dark : AppColors.textSecondary)),
                    ),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Grid
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filtered.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.storefront_outlined, size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 8),
                          const Text('No products yet', style: AppTextStyles.heading3),
                          const SizedBox(height: 4),
                          const Text('Products added via Admin Review will appear here', style: AppTextStyles.caption, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          TextButton.icon(onPressed: _loadProducts,
                              icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
                        ]))
                      : RefreshIndicator(
                          onRefresh: _loadProducts,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final p = _filtered[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _ProductCard(
                                  product: p,
                                  onTap: () => Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => ProductDetailScreenDB(product: p))),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Product Card ──────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name     = product['name'] ?? '';
    final desc     = product['description'] ?? '';
    final type     = product['type'] ?? '';
    final price    = ((product['price'] ?? 0) as num).toDouble();
    final imageUrl = product['image_url'] ?? '';
    final isComp   = type == 'Component';
    final stock    = product['stock'] as int?;
    final inStock  = stock == null || stock > 0;

    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Image — fixed 80x80 square, same size for all products
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              child: Container(
                width: 80, height: 80,
                color: Colors.grey.shade50,
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl,
                        width: 80, height: 80,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _placeholder(isComp))
                    : _placeholder(isComp),
              ),
            ),
            // Details — expands to fill remaining width
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name, style: AppTextStyles.heading3, softWrap: true),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(desc, style: AppTextStyles.caption,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isComp ? AppColors.lightGreen : AppColors.lightYellow,
                          borderRadius: BorderRadius.circular(4)),
                        child: Text(type,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 8),
                      Text('R${price.toInt()}',
                          style: const TextStyle(fontWeight: FontWeight.bold,
                              fontSize: 14, color: AppColors.dark)),
                    ]),
                  ],
                ),
              ),
            ),
            // Add button — right side, vertically centred
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: ElevatedButton(
                  onPressed: inStock ? onTap : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: inStock ? AppColors.primary : Colors.grey.shade200,
                    foregroundColor: inStock ? AppColors.dark : Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0, minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(inStock ? '+ Add' : 'N/A',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ]),
        ),
      ),
    ),
    );
  }

  Widget _placeholder(bool isComp) {
    return Container(
      width: double.infinity,
      color: isComp ? AppColors.lightGreen : AppColors.lightYellow,
      child: Icon(isComp ? Icons.eco : Icons.science, size: 36, color: isComp ? AppColors.herbGreen : AppColors.primary),
    );
  }
}
