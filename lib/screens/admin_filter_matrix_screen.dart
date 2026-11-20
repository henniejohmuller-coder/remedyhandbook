import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/filter_matrix_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'dart:async';

class AdminFilterMatrixScreen extends StatefulWidget {
  const AdminFilterMatrixScreen({super.key});

  @override
  State<AdminFilterMatrixScreen> createState() => _AdminFilterMatrixScreenState();
}

class _AdminFilterMatrixScreenState extends State<AdminFilterMatrixScreen> {
  // ”” All filter_matrix rows ”””””””””””””””””””””””””””””””””””””””””””””””””
  List<Map<String, dynamic>> _allRows = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  // ”” Lookup lists (independent ” not cascading) ”””””””””””””””””””””””””””””
  List<String> _categoryList    = [];
  List<String> _subcategoryList = [];
  List<String> _illnessList     = [];
  List<String> _symptomList     = [];

  // ”” New row selections ”””””””””””””””””””””””””””””””””””””””””””””””””””””
  String? _newCategory;
  String? _newSubcategory;
  String? _newIllness;
  String? _newSymptom;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _searchController.addListener(_applySearch);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      // Load filter_matrix rows
      final List<Map<String, dynamic>> allRows = [];
      int from = 0;
      while (true) {
        final page = await SupabaseService.supabase
            .from('filter_matrix')
            .select('id, category, subcategory, illness, symptom')
            .order('category').order('subcategory').order('illness').order('symptom')
            .range(from, from + 999);
        final list = List<Map<String, dynamic>>.from(page);
        allRows.addAll(list);
        if (list.length < 1000) break;
        from += 1000;
      }

      // Load independent lookup lists
      final cats  = await SupabaseService.supabase.from('categories').select('name').eq('active', true).order('name', ascending: true);
      final subs  = await SupabaseService.supabase.from('sub_categories').select('name').eq('active', true).order('name', ascending: true);
      final ills  = await SupabaseService.supabase.from('illnesses').select('name').eq('active', true).order('name', ascending: true);
      final syms  = await SupabaseService.supabase.from('symptoms').select('name').eq('active', true).order('name', ascending: true);

      if (!mounted) return;
      setState(() {
        _allRows       = allRows;
        _filtered      = allRows;
        _categoryList    = (cats  as List).map((r) => r['name'].toString()).toList();
        _subcategoryList = (subs  as List).map((r) => r['name'].toString()).toList();
        _illnessList     = (ills  as List).map((r) => r['name'].toString()).toList();
        _symptomList     = (syms  as List).map((r) => r['name'].toString()).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySearch() {
    final q = _searchController.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty ? _allRows : _allRows.where((r) =>
        r['category'].toString().toLowerCase().contains(q) ||
        r['subcategory'].toString().toLowerCase().contains(q) ||
        r['illness'].toString().toLowerCase().contains(q) ||
        r['symptom'].toString().toLowerCase().contains(q)
      ).toList();
    });
  }

  Future<void> _addRow() async {
    if (_newCategory == null || _newSubcategory == null ||
        _newIllness == null || _newSymptom == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select all 4 fields')));
      return;
    }
    setState(() => _saving = true);
    try {
      // Add to filter_matrix
      await SupabaseService.supabase.from('filter_matrix').upsert({
        'category':    _newCategory,
        'subcategory': _newSubcategory,
        'illness':     _newIllness,
        'symptom':     _newSymptom,
      }, onConflict: 'category,subcategory,illness,symptom');

      // Sync to lookup tables if new values
      await _syncToLookup('categories',     'name', _newCategory!);
      await _syncToLookup('sub_categories', 'name', _newSubcategory!);
      await _syncToLookup('illnesses',      'name', _newIllness!);
      await _syncToLookup('symptoms',       'name', _newSymptom!);

      setState(() {
        _newCategory = _newSubcategory = _newIllness = _newSymptom = null;
      });
      await _loadAll();
      FilterMatrixPicker.triggerReload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Row added!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _syncToLookup(String table, String col, String value) async {
    try {
      final exists = await SupabaseService.supabase
          .from(table).select(col).eq(col, value).limit(1);
      if ((exists as List).isEmpty) {
        await SupabaseService.supabase.from(table).insert({col: value, 'active': true});
      }
    } catch (_) {}
  }

  Future<void> _openTopProductsPicker(Map<String, dynamic> row) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TopProductsPicker(
        category:    row['category'].toString(),
        subcategory: row['subcategory'].toString(),
        illness:     row['illness'].toString(),
        symptom:     row['symptom'].toString(),
      ),
    );
  }

  Future<void> _deleteRow(int id) async {
    try {
      await SupabaseService.supabase.from('filter_matrix').delete().eq('id', id);
      await _loadAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Row deleted')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const YellowAppBar(
              title: 'Filter Matrix Manager',
              subtitle: 'Add and manage filter combinations',
              showBack: true,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ”” Add new row ””””””””””””””””””””””””””””””””””
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.lightYellow,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Add New Filter Combination',
                                    style: TextStyle(fontSize: 14,
                                        fontWeight: FontWeight.w600, color: AppColors.dark)),
                                const SizedBox(height: 4),
                                const Text(
                                  'All 4 dropdowns are independent ” select any combination or add new values.',
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 10),
                                _IndependentDropdown(
                                  label: 'Category',
                                  value: _newCategory,
                                  items: _categoryList,
                                  onChanged: (v) => setState(() => _newCategory = v),
                                  onNewAdded: (v) => setState(() {
                                    _newCategory = v;
                                    if (!_categoryList.contains(v)) _categoryList.add(v);
                                    _categoryList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                                  }),
                                ),
                                const SizedBox(height: 8),
                                _IndependentDropdown(
                                  label: 'Subcategory',
                                  value: _newSubcategory,
                                  items: _subcategoryList,
                                  onChanged: (v) => setState(() => _newSubcategory = v),
                                  onNewAdded: (v) => setState(() {
                                    _newSubcategory = v;
                                    if (!_subcategoryList.contains(v)) _subcategoryList.add(v);
                                    _subcategoryList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                                  }),
                                ),
                                const SizedBox(height: 8),
                                _IndependentDropdown(
                                  label: 'Illness',
                                  value: _newIllness,
                                  items: _illnessList,
                                  onChanged: (v) => setState(() => _newIllness = v),
                                  onNewAdded: (v) => setState(() {
                                    _newIllness = v;
                                    if (!_illnessList.contains(v)) _illnessList.add(v);
                                    _illnessList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                                  }),
                                ),
                                const SizedBox(height: 8),
                                _IndependentDropdown(
                                  label: 'Symptom',
                                  value: _newSymptom,
                                  items: _symptomList,
                                  onChanged: (v) => setState(() => _newSymptom = v),
                                  onNewAdded: (v) => setState(() {
                                    _newSymptom = v;
                                    if (!_symptomList.contains(v)) _symptomList.add(v);
                                    _symptomList.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                                  }),
                                ),
                                const SizedBox(height: 12),
                                // Summary of selection
                                if (_newCategory != null || _newSubcategory != null ||
                                    _newIllness != null || _newSymptom != null)
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${_newCategory ?? '?'} > ${_newSubcategory ?? '?'} > ${_newIllness ?? '?'} > ${_newSymptom ?? '?'}',
                                      style: const TextStyle(fontSize: 11,
                                          color: AppColors.dark, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _saving ? null : _addRow,
                                    icon: _saving
                                        ? const SizedBox(width: 14, height: 14,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2, color: AppColors.dark))
                                        : const Icon(Icons.add, size: 16),
                                    label: Text(_saving ? 'Adding...' : 'Add to Filter Matrix'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.dark,
                                      foregroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ”” Search ”””””””””””””””””””””””””””””””””””””””
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search filter matrix...',
                              prefixIcon: const Icon(Icons.search, size: 18,
                                  color: AppColors.textSecondary),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              isDense: true,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('${_filtered.length} of ${_allRows.length} rows',
                              style: const TextStyle(fontSize: 11,
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 8),

                          // ”” Table rows ”””””””””””””””””””””””””””””””””””
                          ..._filtered.take(200).map((row) => Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${row['category']} > ${row['subcategory']}',
                                        style: const TextStyle(fontSize: 10,
                                            color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        '${row['illness']}',
                                        style: const TextStyle(fontSize: 10,
                                            color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        '${row['symptom']}',
                                        style: const TextStyle(fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: AppColors.dark),
                                      ),
                                    ],
                                  ),
                                ),
                                // Top products button
                                IconButton(
                                  icon: const Icon(Icons.star_outline,
                                      size: 16, color: AppColors.primary),
                                  tooltip: 'Set top 5 shop products',
                                  onPressed: () => _openTopProductsPicker(row),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 16, color: Colors.red),
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete row?',
                                          style: TextStyle(fontSize: 14)),
                                      content: Text(
                                          '${row['illness']} > ${row['symptom']}',
                                          style: const TextStyle(fontSize: 12)),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(ctx);
                                            _deleteRow(row['id'] as int);
                                          },
                                          child: const Text('Delete',
                                              style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          )),
                          if (_filtered.length > 200)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Showing first 200 ” use search to narrow down.',
                                style: const TextStyle(fontSize: 11,
                                    color: AppColors.textSecondary),
                              ),
                            ),
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

// ── Top Products Picker ────────────────────────────────────────────────────────
/// Bottom-sheet that lets the admin set up to 5 ranked shop products for a
/// specific filter_matrix taxonomy combination.
class _TopProductsPicker extends StatefulWidget {
  final String category, subcategory, illness, symptom;
  const _TopProductsPicker({
    required this.category, required this.subcategory,
    required this.illness,  required this.symptom,
  });
  @override
  State<_TopProductsPicker> createState() => _TopProductsPickerState();
}

class _TopProductsPickerState extends State<_TopProductsPicker> {
  // slots[0] = rank 1, slots[4] = rank 5; null = empty
  final List<Map<String, dynamic>?> _slots = List.filled(5, null);
  List<Map<String, dynamic>> _allProducts = [];
  bool _loading = true;
  bool _saving  = false;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      // Existing featured products for this combination
      final existing = await SupabaseService.supabase
          .from('filter_matrix_featured_products')
          .select('rank, product_id, products(id, name, sku, brand)')
          .eq('category',    widget.category)
          .eq('subcategory', widget.subcategory)
          .eq('illness',     widget.illness)
          .eq('symptom',     widget.symptom)
          .order('rank');

      // All active products for the picker
      final prods = await SupabaseService.getProducts();

      if (!mounted) return;
      final newSlots = List<Map<String, dynamic>?>.filled(5, null);
      for (final e in (existing as List)) {
        final rank = (e['rank'] as int) - 1; // 0-indexed
        if (rank >= 0 && rank < 5) newSlots[rank] = e['products'] as Map<String, dynamic>?;
      }
      setState(() {
        _allProducts = prods;
        for (int i = 0; i < 5; i++) _slots[i] = newSlots[i];
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    final q = _search.toLowerCase();
    // Exclude already-slotted products
    final slottedIds = _slots.whereType<Map<String, dynamic>>().map((p) => p['id']).toSet();
    return _allProducts.where((p) {
      if (slottedIds.contains(p['id'])) return false;
      if (q.isEmpty) return true;
      return (p['name'] ?? '').toString().toLowerCase().contains(q) ||
             (p['sku']  ?? '').toString().toLowerCase().contains(q) ||
             (p['brand'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  void _assignToSlot(int slotIndex, Map<String, dynamic> product) {
    setState(() => _slots[slotIndex] = product);
  }

  void _clearSlot(int slotIndex) {
    setState(() => _slots[slotIndex] = null);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Delete all existing entries for this combination
      await SupabaseService.supabase
          .from('filter_matrix_featured_products')
          .delete()
          .eq('category',    widget.category)
          .eq('subcategory', widget.subcategory)
          .eq('illness',     widget.illness)
          .eq('symptom',     widget.symptom);

      // Insert non-null slots
      final inserts = <Map<String, dynamic>>[];
      for (int i = 0; i < 5; i++) {
        final p = _slots[i];
        if (p == null) continue;
        inserts.add({
          'category':    widget.category,
          'subcategory': widget.subcategory,
          'illness':     widget.illness,
          'symptom':     widget.symptom,
          'rank':        i + 1,
          'product_id':  p['id'],
        });
      }
      if (inserts.isNotEmpty) {
        await SupabaseService.supabase
            .from('filter_matrix_featured_products')
            .insert(inserts);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Top products saved!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filled = _slots.where((s) => s != null).length;
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.star, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Top Shop Products',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.dark)),
                ),
                TextButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ]),
              Text(
                '${widget.illness} › ${widget.symptom}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          const Divider(height: 1),

          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
          else
            Expanded(child: ListView(controller: scrollCtrl, padding: const EdgeInsets.all(16), children: [
              // ── 5 ranked slots ───────────────────────────────────────────
              const Text('Rank order (tap × to clear a slot)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark)),
              const SizedBox(height: 8),
              ...List.generate(5, (i) {
                final p = _slots[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: p != null ? AppColors.lightYellow : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: p != null ? AppColors.primary : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: p != null ? AppColors.primary : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text('${i + 1}',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: p != null ? AppColors.dark : AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: p != null
                          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p['name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark), maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('${p['sku'] ?? ''}${(p['brand'] ?? '').isNotEmpty ? ' · ${p['brand']}' : ''}',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                            ])
                          : Text('Empty — tap a product below to assign',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    ),
                    if (p != null)
                      GestureDetector(
                        onTap: () => _clearSlot(i),
                        child: const Icon(Icons.close, size: 16, color: Colors.red),
                      ),
                  ]),
                );
              }),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),

              // ── Product picker ───────────────────────────────────────────
              Row(children: [
                const Expanded(
                  child: Text('All products',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark)),
                ),
                Text('$filled / 5 filled',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search by name, SKU or brand…',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  isDense: true,
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),

              // Find first empty slot index
              ..._filteredProducts.take(50).map((p) {
                final firstEmpty = _slots.indexWhere((s) => s == null);
                return GestureDetector(
                  onTap: firstEmpty == -1 ? null : () => _assignToSlot(firstEmpty, p),
                  child: Opacity(
                    opacity: firstEmpty == -1 ? 0.4 : 1.0,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(children: [
                        const Icon(Icons.add_circle_outline, size: 14, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p['name'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.dark), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text('${p['sku'] ?? ''}${(p['brand'] ?? '').isNotEmpty ? ' · ${p['brand']}' : ''}',
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ])),
                        Text('R${p['price'] ?? ''}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ]),
                    ),
                  ),
                );
              }),
              if (_filteredProducts.length > 50)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Showing first 50 — use search to narrow down.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ),
            ])),
        ]),
      ),
    );
  }
}

// ── Independent dropdown with + button to add new value ───────────────────────
class _IndependentDropdown extends StatefulWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onNewAdded;

  const _IndependentDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.onNewAdded,
  });

  @override
  State<_IndependentDropdown> createState() => _IndependentDropdownState();
}

class _IndependentDropdownState extends State<_IndependentDropdown> {
  bool _addMode = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _confirm() {
    final v = _ctrl.text.trim();
    if (v.isNotEmpty) {
      widget.onNewAdded(v);
    }
    setState(() { _addMode = false; _ctrl.clear(); });
  }

  void _showSearchDialog() {
    final searchCtrl = TextEditingController();
    List<String> filtered = List.from(widget.items);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          title: Text('Select ${widget.label}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search ${widget.label}...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (q) => setDlg(() {
                    filtered = widget.items
                        .where((s) => s.toLowerCase().contains(q.toLowerCase()))
                        .toList();
                  }),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => InkWell(
                      onTap: () {
                        widget.onChanged(filtered[i]);
                        Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 10),
                        child: Row(children: [
                          if (widget.value == filtered[i])
                            const Icon(Icons.check, size: 14,
                                color: AppColors.primary),
                          if (widget.value == filtered[i])
                            const SizedBox(width: 4),
                          Expanded(
                            child: Text(filtered[i],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: widget.value == filtered[i]
                                      ? AppColors.primary : AppColors.dark,
                                  fontWeight: widget.value == filtered[i]
                                      ? FontWeight.w600 : FontWeight.normal,
                                )),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
                // Add new value button
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.add_circle_outline,
                      color: AppColors.primary, size: 18),
                  title: Text('Add new ${widget.label.toLowerCase()}',
                      style: const TextStyle(fontSize: 12,
                          color: AppColors.primary, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _addMode = true);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_addMode) {
      return Row(children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'New ${widget.label}',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 12),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _confirm(),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _confirm,
          child: const Icon(Icons.check, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => setState(() { _addMode = false; _ctrl.clear(); }),
          child: const Icon(Icons.close, color: Colors.red, size: 20),
        ),
      ]);
    }

    return GestureDetector(
      onTap: _showSearchDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: widget.value != null ? AppColors.primary : Colors.grey.shade300,
            width: widget.value != null ? 1.5 : 0.5,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              widget.value ?? widget.label,
              style: TextStyle(
                fontSize: 12,
                color: widget.value != null
                    ? AppColors.dark : AppColors.textSecondary,
                fontWeight: widget.value != null
                    ? FontWeight.w500 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.dark),
        ]),
      ),
    );
  }
}
