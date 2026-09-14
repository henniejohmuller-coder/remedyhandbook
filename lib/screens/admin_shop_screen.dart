import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
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
      final data = await SupabaseService.supabase
          .from('products')
          .select()
          .order('type', ascending: true)
          .order('name', ascending: true);
      setState(() {
        _products = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete item?', style: AppTextStyles.heading3),
        content: Text('Delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white,
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.supabase.from('order_items')
          .update({'product_id': null}).eq('product_id', id);
      await SupabaseService.supabase.from('products').delete().eq('id', id);
      SupabaseService.clearProductsCache();
      ShopScreen.reload();
      _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted'), backgroundColor: Colors.green,
            duration: Duration(seconds: 2)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red));
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _filter == 'All' ? _products
        : _products.where((p) => p['type'] == _filter).toList();
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((p) =>
          (p['name'] ?? '').toString().toLowerCase().contains(q) ||
          (p['description'] ?? '').toString().toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _ShopItemForm(
              product: null,
              onSaved: () { ShopScreen.reload(); _load(); },
            ),
          );
        },
        backgroundColor: AppColors.dark,
        child: const Icon(Icons.add, color: AppColors.primary),
      ),
      body: SafeArea(child: Column(children: [
        YellowAppBar(title: 'Manage Shop Items', subtitle: 'Add · Edit · Delete', showBack: true),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () => setState(() {
                            _search = ''; _searchController.clear();
                          }))
                      : null,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _filter,
              items: ['All', 'Component', 'Remedy']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _filter = v ?? 'All'),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _filtered.isEmpty
                  ? const Center(child: Text('No items', style: AppTextStyles.caption))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final p = _filtered[i];
                          final imageUrl = p['image_url'] ?? '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(
                                  color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 60, height: 60, color: Colors.grey.shade100,
                                  child: imageUrl.isNotEmpty
                                      ? Image.network(imageUrl, width: 60, height: 60,
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.inventory_2_outlined))
                                      : const Icon(Icons.inventory_2_outlined),
                                ),
                              ),
                              title: Text(p['name'] ?? '', style: AppTextStyles.heading3),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p['description'] ?? '', style: AppTextStyles.caption,
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text('${p['type']} · R${p['price']}',
                                      style: AppTextStyles.caption),
                                ],
                              ),
                              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined,
                                      color: AppColors.dark, size: 20),
                                  onPressed: () async {
                                    await showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => _ShopItemForm(
                                        product: p,
                                        onSaved: () { ShopScreen.reload(); _load(); },
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red, size: 20),
                                  onPressed: () => _delete(
                                      p['id'].toString(), p['name'] ?? ''),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ])),
    );
  }
}

// ── Shop Item Form ─────────────────────────────────────────────────────────────
class _ShopItemForm extends StatefulWidget {
  final Map<String, dynamic>? product;
  final VoidCallback onSaved;
  const _ShopItemForm({required this.product, required this.onSaved});
  @override
  State<_ShopItemForm> createState() => _ShopItemFormState();
}

class _ShopItemFormState extends State<_ShopItemForm> {
  bool _saving = false;
  bool _uploadingImage = false;
  String _type = 'Component';

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _imageController;
  late TextEditingController _stockController;
  late TextEditingController _deliveryController;
  late TextEditingController _costController;
  late TextEditingController _categoryController;
  late TextEditingController _brandController;
  late TextEditingController _primaryHerbController;
  late TextEditingController _mainConstituentController;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _type               = p?['type'] ?? 'Component';
    _nameController     = TextEditingController(text: p?['name'] ?? '');
    _descController     = TextEditingController(text: p?['description'] ?? '');
    _priceController    = TextEditingController(text: p?['price']?.toString() ?? '');
    _imageController    = TextEditingController(text: p?['image_url'] ?? '');
    _stockController    = TextEditingController(text: p?['stock']?.toString() ?? '');
    _deliveryController = TextEditingController(text: p?['delivery_cost']?.toString() ?? '');
    _costController     = TextEditingController(text: p?['cost_price']?.toString() ?? '');
    _categoryController = TextEditingController(text: p?['category'] ?? '');
    _brandController    = TextEditingController(text: p?['brand'] ?? '');
    _primaryHerbController    = TextEditingController(text: p?['primary_herb'] ?? '');
    _mainConstituentController = TextEditingController(text: p?['main_constituent'] ?? '');
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
    _categoryController.dispose();
    _brandController.dispose();
    _primaryHerbController.dispose();
    _mainConstituentController.dispose();
    super.dispose();
  }

  // ── Image Upload ─────────────────────────────────────────────────────────────
  Future<void> _pickAndUploadImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    final size = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Choose image size'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _sizeOption(ctx, 250, 'Small (250×250)', 'Thumbnail size'),
          const SizedBox(height: 8),
          _sizeOption(ctx, 512, 'Medium (512×512)', 'Recommended for shop'),
          const SizedBox(height: 8),
          _sizeOption(ctx, 800, 'Large (800×800)', 'High quality'),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
      ),
    );
    if (size == null) return;

    setState(() => _uploadingImage = true);
    try {
      final decoded = img.decodeImage(file.bytes!);
      if (decoded == null) throw Exception('Could not decode image');
      // Resize to max 800px on longest side — no cropping, full image preserved
      final resized = img.copyResize(decoded,
          width: decoded.width > decoded.height ? size : null,
          height: decoded.height >= decoded.width ? size : null);
      final bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 90));
      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'product_$ts.jpg';
      await SupabaseService.supabase.storage.from('shop-images')
          .uploadBinary(fileName, bytes,
              fileOptions: FileOptions(contentType: 'image/jpeg', upsert: true));
      final url = SupabaseService.supabase.storage
          .from('shop-images').getPublicUrl(fileName);
      setState(() { _imageController.text = url; _uploadingImage = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Uploaded ($size px) — adjust zoom below'),
              backgroundColor: Colors.green));
        // Auto-open zoom tool so user can crop immediately
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) _showZoomPreview();
      }
    } catch (e) {
      setState(() => _uploadingImage = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _sizeOption(BuildContext ctx, int size, String label, String desc) =>
      InkWell(
        onTap: () => Navigator.pop(ctx, size),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.amber.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            const Icon(Icons.photo_size_select_large, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
          ]),
        ),
      );

  Future<void> _deleteImage() async {
    final url = _imageController.text.trim();
    if (url.isEmpty) return;
    final ctx = context;
    final confirmed = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete image?'),
        content: const Text('Remove this image? If uploaded to storage it will also be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (url.contains('shop-images')) {
      try {
        final fileName = Uri.parse(url).pathSegments.last;
        await SupabaseService.supabase.storage.from('shop-images').remove([fileName]);
      } catch (_) {}
    }
    setState(() => _imageController.clear());
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image deleted'), backgroundColor: Colors.orange));
  }

  void _showZoomPreview() {
    final url = _imageController.text.trim();
    if (url.isEmpty) return;
    double zoom = 5.0;
    final repaintKey = GlobalKey();
    const cropSize = 300.0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Dialog(
          backgroundColor: Colors.black87,
          insetPadding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text('Image is always centred. Adjust zoom and tap Save.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                  textAlign: TextAlign.center),
            ),
            RepaintBoundary(
              key: repaintKey,
              child: SizedBox(
                width: cropSize, height: cropSize,
                child: ClipRect(
                  child: Container(
                    color: Colors.white,
                    child: Center(
                      child: Transform.scale(
                        scale: 0.2 + (zoom / 10) * 1.6,
                        child: Image.network(url,
                          width: cropSize, height: cropSize, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.broken_image, color: Colors.grey, size: 48)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Zoom', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('${zoom.round()} / 10',
                      style: const TextStyle(color: Colors.white,
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
                Row(children: [
                  IconButton(
                    onPressed: () {
                      if (zoom > 0) setModal(() => zoom = (zoom - 1).clamp(0, 10));
                    },
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.white70)),
                  Expanded(child: Slider(
                    value: zoom, min: 0, max: 10, divisions: 10,
                    activeColor: AppColors.primary, inactiveColor: Colors.white24,
                    label: zoom.round().toString(),
                    onChanged: (v) => setModal(() => zoom = v.roundToDouble()),
                  )),
                  IconButton(
                    onPressed: () {
                      if (zoom < 10) setModal(() => zoom = (zoom + 1).clamp(0, 10));
                    },
                    icon: const Icon(Icons.add_circle_outline, color: Colors.white70)),
                ]),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(11, (i) => Text('$i',
                      style: TextStyle(
                          color: zoom.round() == i ? AppColors.primary : Colors.white38,
                          fontSize: 10,
                          fontWeight: zoom.round() == i ? FontWeight.w700 : FontWeight.normal))),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(children: [
                TextButton(
                  onPressed: () => setModal(() => zoom = 5.0),
                  child: const Text('Reset (5)', style: TextStyle(color: Colors.white54))),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54))),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    // Capture BEFORE closing dialog
                    try {
                      final boundary = repaintKey.currentContext
                          ?.findRenderObject() as RenderRepaintBoundary?;
                      if (boundary == null) {
                        Navigator.pop(ctx);
                        return;
                      }
                      final image = await boundary.toImage(pixelRatio: 2.0);
                      final byteData = await image.toByteData(
                          format: ui.ImageByteFormat.png);
                      Navigator.pop(ctx);
                      if (byteData == null) return;
                      await _uploadCapturedImage(byteData.buffer.asUint8List());
                    } catch (e) {
                      Navigator.pop(ctx);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Capture failed: $e'),
                            backgroundColor: Colors.red));
                    }
                  },
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.dark)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _uploadCapturedImage(Uint8List bytes) async {
    setState(() => _uploadingImage = true);
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'product_crop_$ts.png';
      await SupabaseService.supabase.storage.from('shop-images')
          .uploadBinary(fileName, bytes,
              fileOptions: FileOptions(contentType: 'image/png', upsert: true));
      final newUrl = SupabaseService.supabase.storage
          .from('shop-images').getPublicUrl(fileName);
      setState(() { _imageController.text = newUrl; _uploadingImage = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image saved!'), backgroundColor: Colors.green));
    } catch (e) {
      setState(() => _uploadingImage = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red));
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        'name':          _nameController.text.trim(),
        'description':   _descController.text.trim(),
        'type':          _type,
        'price':         double.tryParse(_priceController.text) ?? 0,
        'cost_price':    double.tryParse(_costController.text) ?? 0,
        'image_url':     _imageController.text.trim(),
        'stock':         int.tryParse(_stockController.text) ?? 0,
        'delivery_cost': double.tryParse(_deliveryController.text) ?? 0,
        'category':      _categoryController.text.trim(),
        'brand':         _brandController.text.trim(),
        'primary_herb':  _primaryHerbController.text.trim(),
        'main_constituent': _mainConstituentController.text.trim(),
      };
      if (widget.product == null) {
        await SupabaseService.supabase.from('products').insert(data);
      } else {
        await SupabaseService.supabase.from('products')
            .update(data).eq('id', widget.product!['id']);
      }
      SupabaseService.clearProductsCache();
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _field(String label, String hint, TextEditingController controller,
      {bool isNumber = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.caption,
            isDense: true,
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 16),
          Text(widget.product == null ? 'Add Shop Item' : 'Edit Shop Item',
              style: AppTextStyles.heading2),
          const SizedBox(height: 16),

          // Type selector
          Row(children: ['Component', 'Remedy'].map((t) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(t),
              selected: _type == t,
              onSelected: (_) => setState(() => _type = t),
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                  color: _type == t ? AppColors.dark : AppColors.textSecondary,
                  fontWeight: _type == t ? FontWeight.w700 : FontWeight.normal),
            ),
          )).toList()),
          const SizedBox(height: 12),

          _field('Name *', 'e.g. Buchu Tincture', _nameController),
          const SizedBox(height: 10),
          _field('Description', 'e.g. Raw herb � 100g', _descController),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field('Primary Herb', 'e.g. Hawthorn', _primaryHerbController)),
            const SizedBox(width: 10),
            Expanded(child: _field('Main Constituent', 'e.g. Flavonoids', _mainConstituentController)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field('Category', 'e.g. Tinctures', _categoryController)),
            const SizedBox(width: 10),
            Expanded(child: _field('Brand', 'e.g. MyHerb', _brandController)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field('Sell price (R)', 'e.g. 150', _priceController, isNumber: true)),
            const SizedBox(width: 10),
            Expanded(child: _field('Cost price (R)', 'e.g. 45', _costController, isNumber: true)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field('Stock qty', 'e.g. 100', _stockController, isNumber: true)),
            const SizedBox(width: 10),
            Expanded(child: _field('Delivery cost (R)', 'e.g. 60', _deliveryController, isNumber: true)),
          ]),
          const SizedBox(height: 10),

          // Image — URL or upload
          const Text('Image', style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: TextField(
              controller: _imageController,
              decoration: InputDecoration(
                hintText: 'https://... or upload below',
                hintStyle: AppTextStyles.caption,
                isDense: true, filled: true, fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() {}),
            )),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _uploadingImage ? null : _pickAndUploadImage,
              icon: _uploadingImage
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                  : const Icon(Icons.upload, size: 18),
              label: const Text('Upload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dark, foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                elevation: 0,
              ),
            ),
          ]),

          // Image preview with zoom + delete
          if (_imageController.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Stack(children: [
              GestureDetector(
                onTap: _showZoomPreview,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    color: Colors.grey.shade50,
                    child: Image.network(_imageController.text,
                      height: 120, width: double.infinity, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                  ),
                ),
              ),
              Positioned(top: 6, right: 6, child: Row(children: [
                GestureDetector(
                  onTap: _showZoomPreview,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.zoom_in, color: Colors.white, size: 18))),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _deleteImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 18))),
              ])),
            ]),
          ],

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dark, foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                  : Text(widget.product == null ? 'Add Item' : 'Save Changes',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }
}





