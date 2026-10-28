import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/filter_matrix_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class AdminFilterMatrixScreen extends StatefulWidget {
  const AdminFilterMatrixScreen({super.key});

  @override
  State<AdminFilterMatrixScreen> createState() => _AdminFilterMatrixScreenState();
}

class _AdminFilterMatrixScreenState extends State<AdminFilterMatrixScreen> {
  // â”€â”€ All filter_matrix rows â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<Map<String, dynamic>> _allRows = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchController = TextEditingController();

  // â”€â”€ Lookup lists (independent â€” not cascading) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  List<String> _categoryList    = [];
  List<String> _subcategoryList = [];
  List<String> _illnessList     = [];
  List<String> _symptomList     = [];

  // â”€â”€ New row selections â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                          // â”€â”€ Add new row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                                  'All 4 dropdowns are independent â€” select any combination or add new values.',
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
                                      '${_newCategory ?? '?'} â€º ${_newSubcategory ?? '?'} â€º ${_newIllness ?? '?'} â€º ${_newSymptom ?? '?'}',
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

                          // â”€â”€ Search â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

                          // â”€â”€ Table rows â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                                        '${row['category']} â€º ${row['subcategory']}',
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
                                IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 16, color: Colors.red),
                                  onPressed: () => showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete row?',
                                          style: TextStyle(fontSize: 14)),
                                      content: Text(
                                          '${row['illness']} â€º ${row['symptom']}',
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
                                'Showing first 200 â€” use search to narrow down.',
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

// â”€â”€ Independent dropdown with + button to add new value â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
