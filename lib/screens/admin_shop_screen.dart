import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import 'shop_screen.dart';

class AdminShopScreen extends StatefulWidget {
  const AdminShopScreen({super.key});

  @override
  State<AdminShopScreen> createState() => _AdminShopScreenState();
}

class _AdminShopScreenState extends State<AdminShopScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String _filter = 'All';
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.getProducts();
      setState(() { _products = data; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    return _products.where((p) {
      final type  = (p['type'] ?? '').toString();
      final name  = (p['name'] ?? '').toString().toLowerCase();
      final matchFilter = _filter == 'All'
          || (_filter == 'Components' && type == 'Component')
          || (_filter == 'Remedies'   && type == 'Remedy');
      final matchSearch = _search.isEmpty || name.contains(_search.toLowerCase());
      return matchFilter && matchSearch;
    }).toList();
  }

  void _openForm({Map<String, dynamic>? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShopItemForm(
        product: product,
        onSaved: () { Navigator.pop(context); SupabaseService.clearProductsCache(); ShopScreen.reload(); _load(); },
      ),
    );
  }

  Future<void> _delete(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete item?', style: AppTextStyles.heading3),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await SupabaseService.supabase.from('products').delete().eq('id', id);
        SupabaseService.clearProductsCache();
        ShopScreen.reload();
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Item deleted'), backgroundColor: Colors.green,
                duration: Duration(seconds: 2)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: AppColors.dark),
      ),
      body: SafeArea(
        child: Column(
          children: [
            YellowAppBar(
              title: 'Shop Items',
              subtitle: 'Add · Edit · Delete',
              showBack: true,
              actions: [
                Text('${_products.length} items',
                    style: AppTextStyles.caption),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 12),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search shop items...',
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

            // Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: ['All', 'Components', 'Remedies'].map((tab) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filter = tab),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: _filter == tab ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _filter == tab ? AppColors.primary : Colors.grey.shade200),
                    ),
                    child: Text(tab, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: _filter == tab ? AppColors.dark : AppColors.textSecondary)),
                  ),
                ),
              )).toList()),
            ),
            const SizedBox(height: 12),

            // List
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filtered.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.storefront_outlined, size: 48, color: AppColors.textSecondary),
                          const SizedBox(height: 8),
                          const Text('No shop items yet', style: AppTextStyles.heading3),
                          const SizedBox(height: 4),
                          const Text('Tap + to add a new item', style: AppTextStyles.caption),
                        ]))
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.primary,
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final p       = _filtered[i];
                              final name    = p['name'] ?? '';
                              final type    = p['type'] ?? '';
                              final price   = ((p['price'] ?? 0) as num).toDouble();
                              final imageUrl = p['image_url'] ?? '';
                              final desc    = p['description'] ?? '';
                              final isComp  = type == 'Component';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                                child: Row(children: [
                                  // Image
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _imgPlaceholder(isComp))
                                        : _imgPlaceholder(isComp),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(name, style: AppTextStyles.heading3, overflow: TextOverflow.ellipsis),
                                    Text(desc, style: AppTextStyles.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      TagBadge(
                                        label: type,
                                        color: isComp ? AppColors.lightGreen : AppColors.levelBadge,
                                      ),
                                      const SizedBox(width: 8),
                                      Text('R${price.toInt()}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark)),
                                    ]),
                                  ])),
                                  const SizedBox(width: 8),
                                  // Actions
                                  Column(children: [
                                    GestureDetector(
                                      onTap: () => _openForm(product: p),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                                        child: const Icon(Icons.edit_outlined, size: 18, color: AppColors.dark),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: () => _delete(p['id'].toString(), name),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
                                        child: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                      ),
                                    ),
                                  ]),
                                ]),
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

  Widget _imgPlaceholder(bool isComp) {
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(
        color: isComp ? AppColors.lightGreen : AppColors.lightYellow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(isComp ? Icons.eco : Icons.science, size: 28,
          color: isComp ? AppColors.herbGreen : AppColors.primary),
    );
  }
}

// ── Shop Item Form (Bottom Sheet) ─────────────────────────────────────────

class _ShopItemForm extends StatefulWidget {
  final Map<String, dynamic>? product;
  final VoidCallback onSaved;
  const _ShopItemForm({this.product, required this.onSaved});

  @override
  State<_ShopItemForm> createState() => _ShopItemFormState();
}

class _ShopItemFormState extends State<_ShopItemForm> {
  bool _saving = false;
  String _type = 'Component';

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _imageController;
  late TextEditingController _stockController;
  late TextEditingController _deliveryController;
  late TextEditingController _costController;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _type            = p?['type'] ?? 'Component';
    _nameController  = TextEditingController(text: p?['name'] ?? '');
    _descController  = TextEditingController(text: p?['description'] ?? '');
    _priceController = TextEditingController(text: p?['price']?.toString() ?? '');
    _imageController = TextEditingController(text: p?['image_url'] ?? '');
    _stockController = TextEditingController(text: p?['stock']?.toString() ?? '');
    _deliveryController = TextEditingController(text: p?['delivery_cost']?.toString() ?? '');
    _costController = TextEditingController(text: p?['cost_price']?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    _stockController.dispose();
    _deliveryController.dispose();
    _costController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.isEmpty || _priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and price are required'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'name':        _nameController.text.trim(),
        'type':        _type,
        'description': _descController.text.trim(),
        'price':       double.tryParse(_priceController.text) ?? 0,
        'image_url':   _imageController.text.trim(),
        'active':      true,
      };
      // Only add optional fields if they have values
      if (_stockController.text.isNotEmpty)
        data['stock'] = int.tryParse(_stockController.text);
      if (_deliveryController.text.isNotEmpty)
        data['delivery_cost'] = double.tryParse(_deliveryController.text);
      if (_costController.text.isNotEmpty)
        data['cost_price'] = double.tryParse(_costController.text);
      if (widget.product != null) {
        await SupabaseService.supabase.from('products')
            .update(data).eq('id', widget.product!['id']);
      } else {
        await SupabaseService.supabase.from('products').insert(data);
      }
      widget.onSaved();
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          Text(isEdit ? 'Edit Shop Item' : 'New Shop Item', style: AppTextStyles.heading2),
          const SizedBox(height: 16),

          // Type selector
          const Text('Type', style: AppTextStyles.label),
          const SizedBox(height: 6),
          Row(children: ['Component', 'Remedy'].map((t) => Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _type = t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _type == t ? AppColors.primary : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _type == t ? AppColors.primary : Colors.grey.shade300),
                ),
                child: Text(t, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
                    color: _type == t ? AppColors.dark : AppColors.textSecondary)),
              ),
            ),
          )).toList()),
          const SizedBox(height: 12),

          _field('Name *', 'e.g. Aloe ferox', _nameController),
          const SizedBox(height: 10),
          _field('Description', 'e.g. Raw herb · 100g', _descController),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field('Sell price (R) *', 'e.g. 85', _priceController, isNumber: true)),
            const SizedBox(width: 10),
            Expanded(child: _field('Cost price (R)', 'e.g. 45', _costController, isNumber: true)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field('Stock qty', 'e.g. 50', _stockController, isNumber: true)),
            const SizedBox(width: 10),
            Expanded(child: _field('Delivery cost (R)', 'e.g. 85', _deliveryController, isNumber: true)),
          ]),
          const SizedBox(height: 10),
          _field('Image URL', 'https://...', _imageController),

          // Image preview
          if (_imageController.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(_imageController.text,
                height: 100, width: double.infinity, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            ),
          ],
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                  : Text(isEdit ? 'Save changes' : 'Add to shop',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, String hint, TextEditingController controller, {bool isNumber = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTextStyles.label),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        onChanged: (_) => setState(() {}),
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: hint, hintStyle: AppTextStyles.caption,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          filled: true, fillColor: AppColors.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        ),
      ),
    ]);
  }
}
