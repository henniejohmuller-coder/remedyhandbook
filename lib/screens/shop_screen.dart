import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import 'product_detail_screen.dart';

class ShopScreen extends StatefulWidget {
  final String? initialSearch;
  final String? initialType;
  // SKU-based filter from Find screen (Shop Products mode via filter_matrix)
  final Set<String>? initialTaxonomySkus;

  const ShopScreen({
    super.key,
    this.initialSearch,
    this.initialType,
    this.initialTaxonomySkus,
  });

  static VoidCallback? _reloadCallback;
  static void reload() => _reloadCallback?.call();

  // Persisted filter state — survives tab switches
  static String _savedFilter      = 'All';
  static String _savedSearch      = '';
  static String _savedCatFilter   = 'All';
  static String _savedBrandFilter = 'All';

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String _filter      = ShopScreen._savedFilter;
  String _search      = ShopScreen._savedSearch;
  String _catFilter   = ShopScreen._savedCatFilter;
  String _brandFilter = ShopScreen._savedBrandFilter;
  // SKU filter from Find → Shop Products (via filter_matrix)
  Set<String>? _taxSkus;
  List<Map<String, dynamic>> _products = [];
  List<String> _catOptions   = ['All'];
  List<String> _brandOptions = ['All'];
  bool _loading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ShopScreen._reloadCallback = _loadProducts;
    // Restore search controller text from saved state
    _searchController.text = _search;
    // If navigated from Find → Shop Products, receive matching SKUs
    if (widget.initialTaxonomySkus != null && widget.initialTaxonomySkus!.isNotEmpty) {
      _taxSkus = widget.initialTaxonomySkus;
    }
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      _search = widget.initialSearch!;
      _searchController.text = widget.initialSearch!;
    }
    if (widget.initialType == 'Component')        _filter = 'Components';
    if (widget.initialType == 'Remedy')           _filter = 'Herbal Remedies';
    if (widget.initialType == 'Exercise Support') _filter = 'Exercise Support';
    _loadProducts();
  }

  void _setFilter(String v)      => setState(() { _filter      = ShopScreen._savedFilter      = v; });
  void _setSearch(String v)      => setState(() { _search      = ShopScreen._savedSearch      = v; });
  void _setCatFilter(String v)   => setState(() { _catFilter   = ShopScreen._savedCatFilter   = v; });
  void _setBrandFilter(String v) => setState(() { _brandFilter = ShopScreen._savedBrandFilter = v; });

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
      final _catList = data.map((p) => (p['product_type'] ?? '').toString().trim()).where((c) => c.isNotEmpty).toSet().toList()..sort();
      final cats = ['All', ..._catList];
      final _brandList = data.map((p) => (p['brand'] ?? '').toString().trim()).where((b) => b.isNotEmpty).toSet().toList()..sort();
      final brands = ['All', ..._brandList];
      setState(() {
        _products     = data;
        _catOptions   = cats;
        _brandOptions = brands;
        _loading      = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Split search input by comma or semicolon into individual terms.
  List<String> get _searchTerms => _search
      .split(RegExp(r'[,;]'))
      .map((t) => t.trim().toLowerCase())
      .where((t) => t.isNotEmpty)
      .toList();

  List<Map<String, dynamic>> get _filtered {
    final terms = _searchTerms;
    return _products.where((p) {
      final type = (p['type'] ?? '').toString();

      // Tab filter
      final matchFilter = _filter == 'All'
          || (_filter == 'Components'       && type == 'Component')
          || (_filter == 'Herbal Remedies'  && type == 'Remedy')
          || (_filter == 'Exercise Support' && type == 'Exercise Support');

      // Search name only — description matches cause false positives
      final bool matchSearch;
      if (terms.isEmpty) {
        matchSearch = true;
      } else {
        final name = (p['name'] ?? '').toString().toLowerCase();
        matchSearch = terms.any((term) => name.contains(term));
      }

      // Type dropdown filter
      final matchCat = _catFilter == 'All'
          || (p['product_type'] ?? '').toString().trim().toLowerCase()
              == _catFilter.toLowerCase();

      // Brand dropdown filter
      final matchBrand = _brandFilter == 'All'
          || (p['brand'] ?? '').toString().trim().toLowerCase()
              == _brandFilter.toLowerCase();

      // SKU filter from Find → Shop Products (via filter_matrix)
      final matchTaxSku = _taxSkus == null || _taxSkus!.contains((p['sku'] ?? '').toString());

      return matchFilter && matchSearch && matchCat && matchBrand && matchTaxSku;
    }).toList();
  }

  void _showSearchDropdown(BuildContext context, String label, List<String> options,
      String current, ValueChanged<String> onChanged) {
    final searchCtrl = TextEditingController();
    List<String> filtered = List.from(options);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          title: Text('Select $label',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: double.maxFinite, height: 400,
            child: Column(children: [
              TextField(
                controller: searchCtrl, autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search $label...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
                onChanged: (q) => setDlg(() {
                  filtered = options.where((s) => s.toLowerCase().contains(q.toLowerCase())).toList();
                }),
              ),
              const SizedBox(height: 8),
              Expanded(child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) => InkWell(
                  onTap: () { onChanged(filtered[i]); Navigator.pop(ctx); },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                    child: Row(children: [
                      if (current == filtered[i]) ...[
                        const Icon(Icons.check, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                      ],
                      Expanded(child: Text(filtered[i], style: TextStyle(
                        fontSize: 12,
                        color: current == filtered[i] ? AppColors.primary : AppColors.dark,
                        fontWeight: current == filtered[i] ? FontWeight.w600 : FontWeight.normal,
                      ))),
                    ]),
                  ),
                ),
              )),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const YellowAppBar(title: 'Shop', subtitle: 'Free delivery over R650'),

            // ── Taxonomy filter banner (shown when arriving from Find → Shop Products) ──
            if (_taxSkus != null && _taxSkus!.isNotEmpty)
              Container(
                color: AppColors.primary.withOpacity(0.12),
                padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                child: Row(children: [
                  const Icon(Icons.filter_alt, size: 14, color: AppColors.dark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Filtered by health condition (${_taxSkus!.length} products)',
                      style: const TextStyle(fontSize: 11, color: AppColors.dark, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() { _taxSkus = null; }),
                    child: const Icon(Icons.close, size: 16, color: AppColors.dark),
                  ),
                ]),
              ),

            const SizedBox(height: 12),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 44,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
                child: TextField(
                  controller: _searchController,
                  onChanged: _setSearch,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search by name, ingredient, category... (use , or ;)',
                    hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                    suffixIcon: _search.isNotEmpty
                        ? GestureDetector(
                            onTap: () { _searchController.clear(); _setSearch(''); },
                            child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary))
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Type + Brand dropdowns
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Brand (left)
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _brandFilter != 'All'
                              ? AppColors.primary : Colors.grey.shade200),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.03), blurRadius: 4)],
                      ),
                      child: GestureDetector(
                        onTap: () => _showSearchDropdown(
                          context, 'Brand', _brandOptions, _brandFilter,
                          _setBrandFilter),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          child: Row(children: [
                            Expanded(child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: const TextStyle(fontSize: 12),
                                children: [
                                  TextSpan(
                                    text: 'Brand: ',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.normal),
                                  ),
                                  TextSpan(
                                    text: _brandFilter == 'All' ? 'All' : _brandFilter,
                                    style: TextStyle(
                                        color: _brandFilter != 'All' ? AppColors.dark : AppColors.textSecondary,
                                        fontWeight: _brandFilter != 'All' ? FontWeight.w600 : FontWeight.normal),
                                  ),
                                ],
                              ),
                            )),
                            _brandFilter != 'All'
                                ? GestureDetector(
                                    onTap: () => _setBrandFilter('All'),
                                    child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary))
                                : const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Type (right)
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _catFilter != 'All'
                              ? AppColors.primary : Colors.grey.shade200),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.03), blurRadius: 4)],
                      ),
                      child: GestureDetector(
                        onTap: () => _showSearchDropdown(
                          context, 'Type', _catOptions, _catFilter,
                          _setCatFilter),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          child: Row(children: [
                            Expanded(child: RichText(
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                style: const TextStyle(fontSize: 12),
                                children: [
                                  TextSpan(
                                    text: 'Type: ',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.normal),
                                  ),
                                  TextSpan(
                                    text: _catFilter == 'All' ? 'All' : _catFilter,
                                    style: TextStyle(
                                        color: _catFilter != 'All' ? AppColors.dark : AppColors.textSecondary,
                                        fontWeight: _catFilter != 'All' ? FontWeight.w600 : FontWeight.normal),
                                  ),
                                ],
                              ),
                            )),
                            _catFilter != 'All'
                                ? GestureDetector(
                                    onTap: () => _setCatFilter('All'),
                                    child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary))
                                : const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ],
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
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final p = _filtered[i];
                              return _ProductCard(
                                product: p,
                                onTap: () => Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => ProductDetailScreenDB(product: p))),
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
    final name     = product['name']        ?? '';
    final type     = product['type']        ?? '';
    final category = product['product_type'] ?? '';
    final brand    = product['brand']       ?? '';
    final desc     = product['description'] ?? '';
    final price    = num.tryParse(product['price']?.toString() ?? '0')?.toDouble() ?? 0.0;
    final imageUrl = product['image_url']   ?? '';
    final isComp   = type == 'Component';
    final isExercise = type == 'Exercise Support';
    final stock    = product['stock'] as int?;
    final inStock  = stock == null || stock > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Small image left
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60, height: 60,
                child: imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(isComp))
                    : _placeholder(isComp),
              ),
            ),
            const SizedBox(width: 12),
            // Info - centre
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.dark),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isComp ? AppColors.lightGreen : AppColors.lightYellow,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(isComp ? 'Component' : 'Herbal Remedies',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isComp ? AppColors.herbGreen : AppColors.dark)),
                      ),
                    ],
                  ),
                  if (category.isNotEmpty || brand.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [if (category.isNotEmpty) category, if (brand.isNotEmpty) brand].join(' · '),
                      style: AppTextStyles.caption,
                    ),
                  ],
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(desc,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 4),
                  Text('R${price.toInt()}',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.dark)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Add button right
            ElevatedButton(
              onPressed: inStock ? onTap : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: inStock ? AppColors.primary : Colors.grey.shade200,
                foregroundColor: inStock ? AppColors.dark : Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(inStock ? '+ Add' : 'Out',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(bool isComp) {
    return Container(
      color: isComp ? AppColors.lightGreen : AppColors.lightYellow,
      child: Icon(isComp ? Icons.eco : Icons.science,
          size: 28,
          color: isComp ? AppColors.herbGreen : AppColors.primary),
    );
  }
}