import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import 'product_detail_screen.dart';

class ShopScreen extends StatefulWidget {
  final String? initialPrimaryHerb;
  final String? initialMainConstituent;
  final String? initialType;

  const ShopScreen({
    super.key,
    this.initialPrimaryHerb,
    this.initialMainConstituent,
    this.initialType,
  });

  static VoidCallback? _reloadCallback;
  static void reload() => _reloadCallback?.call();

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String _filter            = 'All';
  String _search            = '';
  String _herbSearch        = '';
  String _constituentSearch = '';
  String _catFilter         = 'All';
  String _brandFilter       = 'All';
  List<Map<String, dynamic>> _products = [];
  List<String> _catOptions   = ['All'];
  List<String> _brandOptions = ['All'];
  bool _loading = true;
  final _searchController      = TextEditingController();
  final _herbController        = TextEditingController();
  final _constituentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ShopScreen._reloadCallback = _loadProducts;
    // Pre-populate Primary Herb box
    if (widget.initialPrimaryHerb != null && widget.initialPrimaryHerb!.isNotEmpty) {
      _herbSearch = widget.initialPrimaryHerb!;
      _herbController.text = widget.initialPrimaryHerb!;
    }
    // Pre-populate Constituent box
    if (widget.initialMainConstituent != null && widget.initialMainConstituent!.isNotEmpty) {
      _constituentSearch = widget.initialMainConstituent!;
      _constituentController.text = widget.initialMainConstituent!;
    }
    // Pre-select tab
    if (widget.initialType == 'Component') _filter = 'Components';
    if (widget.initialType == 'Remedy')    _filter = 'Remedies';
    _loadProducts();
  }

  @override
  void dispose() {
    ShopScreen._reloadCallback = null;
    _searchController.dispose();
    _herbController.dispose();
    _constituentController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getProducts();
      if (!mounted) return;
      final _catList = data.map((p) => (p['category'] ?? '').toString().trim()).where((c) => c.isNotEmpty).toSet().toList()..sort();
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
          || (_filter == 'Components' && type == 'Component')
          || (_filter == 'Remedies'   && type == 'Remedy');

      // Search all data fields — product matches if ANY term found in ANY field
      final bool matchSearch;
      if (terms.isEmpty) {
        matchSearch = true;
      } else {
        final fields = [
          p['name']        ?? '',
          p['description'] ?? '',
          p['category']    ?? '',
          p['type']        ?? '',
        ].map((f) => f.toString().toLowerCase()).toList();

        // Either/or — match if ANY term appears in ANY field
        matchSearch = terms.any(
          (term) => fields.any((field) => field.contains(term)),
        );
      }

      // Primary Herb box � comma/semicolon terms searched against name field
      final herbTerms = _herbSearch
          .split(RegExp(r'[,;]'))
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList();
      final matchHerb = herbTerms.isEmpty
          || herbTerms.any((t) => (p['name'] ?? '').toString().toLowerCase().contains(t));

      // Constituent box � comma/semicolon terms searched against description field
      final constTerms = _constituentSearch
          .split(RegExp(r'[,;]'))
          .map((t) => t.trim().toLowerCase())
          .where((t) => t.isNotEmpty)
          .toList();
      final matchConstituent = constTerms.isEmpty
          || constTerms.any((t) => (p['description'] ?? '').toString().toLowerCase().contains(t));

      // Category dropdown filter
      final matchCat = _catFilter == 'All'
          || (p['category'] ?? '').toString().trim().toLowerCase()
              == _catFilter.toLowerCase();

      // Brand dropdown filter
      final matchBrand = _brandFilter == 'All'
          || (p['brand'] ?? '').toString().trim().toLowerCase()
              == _brandFilter.toLowerCase();

      return matchFilter && matchSearch && matchHerb && matchConstituent && matchCat && matchBrand;
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
                    hintText: 'Search by name, ingredient, category... (use , or ;)',
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
            const SizedBox(height: 10),

            // -- Primary Herb + Constituent filter boxes ------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Primary Herb
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _herbSearch.isNotEmpty
                              ? AppColors.primary : Colors.grey.shade200),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.03), blurRadius: 4)],
                      ),
                      child: TextField(
                        controller: _herbController,
                        onChanged: (v) => setState(() => _herbSearch = v),
                        style: const TextStyle(fontSize: 12, color: AppColors.dark),
                        decoration: InputDecoration(
                          hintText: 'Primary Herb',
                          hintStyle: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                          prefixIcon: const Icon(Icons.eco_outlined,
                              size: 16, color: AppColors.textSecondary),
                          suffixIcon: _herbSearch.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _herbController.clear();
                                    setState(() => _herbSearch = '');
                                  },
                                  child: const Icon(Icons.close,
                                      size: 14, color: AppColors.textSecondary))
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Constituent
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _constituentSearch.isNotEmpty
                              ? AppColors.primary : Colors.grey.shade200),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.03), blurRadius: 4)],
                      ),
                      child: TextField(
                        controller: _constituentController,
                        onChanged: (v) => setState(() => _constituentSearch = v),
                        style: const TextStyle(fontSize: 12, color: AppColors.dark),
                        decoration: InputDecoration(
                          hintText: 'Constituent',
                          hintStyle: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                          prefixIcon: const Icon(Icons.science_outlined,
                              size: 16, color: AppColors.textSecondary),
                          suffixIcon: _constituentSearch.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _constituentController.clear();
                                    setState(() => _constituentSearch = '');
                                  },
                                  child: const Icon(Icons.close,
                                      size: 14, color: AppColors.textSecondary))
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Category + Brand dropdowns
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Category
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _catFilter != 'All'
                              ? AppColors.primary : Colors.grey.shade200),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.03), blurRadius: 4)],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _catOptions.contains(_catFilter) ? _catFilter : 'All',
                          isExpanded: true,
                          style: const TextStyle(fontSize: 12, color: AppColors.dark),
                          hint: const Text('Category', style: TextStyle(fontSize: 12)),
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          onChanged: (v) => setState(() => _catFilter = v ?? 'All'),
                          items: _catOptions.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                          )).toList(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Brand
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _brandFilter != 'All'
                              ? AppColors.primary : Colors.grey.shade200),
                        boxShadow: [BoxShadow(
                            color: Colors.black.withOpacity(0.03), blurRadius: 4)],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _brandOptions.contains(_brandFilter) ? _brandFilter : 'All',
                          isExpanded: true,
                          style: const TextStyle(fontSize: 12, color: AppColors.dark),
                          hint: const Text('Brand', style: TextStyle(fontSize: 12)),
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          onChanged: (v) => setState(() => _brandFilter = v ?? 'All'),
                          items: _brandOptions.map((b) => DropdownMenuItem(
                            value: b,
                            child: Text(b, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12)),
                          )).toList(),
                        ),
                      ),
                    ),
                  ),
                  // Clear button when either active
                  if (_catFilter != 'All' || _brandFilter != 'All') ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() {
                        _catFilter   = 'All';
                        _brandFilter = 'All';
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.clear, size: 16, color: AppColors.dark),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

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
    final category = product['category']    ?? '';
    final desc     = product['description'] ?? '';
    final price    = num.tryParse(product['price']?.toString() ?? '0')?.toDouble() ?? 0.0;
    final imageUrl = product['image_url']   ?? '';
    final isComp   = type == 'Component';
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
                        child: Text(isComp ? 'Component' : 'Remedy',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isComp ? AppColors.herbGreen : AppColors.dark)),
                      ),
                    ],
                  ),
                  if (category.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(category, style: AppTextStyles.caption),
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