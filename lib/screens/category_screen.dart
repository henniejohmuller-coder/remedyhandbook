import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../models/filter_state.dart';
import 'shop_screen.dart';

// ─── Toggle enum ────────────────────────────────────────────────────────────
enum _FindMode { herbal, products }

class CategoryScreen extends StatefulWidget {
  final FilterState? initialFilters;
  final Function(FilterState)? onResult;
  const CategoryScreen({super.key, this.initialFilters, this.onResult});

  // Persist filter state across tab switches
  static String? _savedCategory;
  static String? _savedSubcategory;
  static String? _savedIllness;
  static String? _savedSymptom;
  static Map<String, dynamic>? _savedRow;
  static _FindMode _savedMode = _FindMode.herbal;

  static void clearSaved() {
    _savedCategory = _savedSubcategory = _savedIllness = _savedSymptom = null;
    _savedRow = null;
    _savedMode = _FindMode.herbal;
  }

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  // ── Mode toggle ─────────────────────────────────────────────────────────
  _FindMode _mode = CategoryScreen._savedMode;

  // ── Matrix rows loaded once ─────────────────────────────────────────────
  List<Map<String, dynamic>> _allRows           = [];   // herbal filter_matrix (taxonomy only)
  List<Map<String, dynamic>> _productRows       = [];   // deduplicated product taxonomy rows
  List<Map<String, dynamic>> _allProductSkuRows = [];   // raw filter_matrix rows with SKUs (for SKU lookup)
  List<Map<String, dynamic>> _remedies          = [];
  bool _loading = true;

  // Count caches for herbal mode
  List<Map<String, dynamic>> _rowsWithRemedies = [];
  Map<String, int> _rowCountCache = {};
  Map<String, int> _catCountCache = {};
  Map<String, int> _subCountCache = {};
  Map<String, int> _illCountCache = {};
  Map<String, int> _symCountCache = {};

  // Count caches for products mode
  Map<String, int> _prodRowCountCache = {};
  Map<String, int> _prodCatCountCache = {};
  Map<String, int> _prodSubCountCache = {};
  Map<String, int> _prodIllCountCache = {};
  Map<String, int> _prodSymCountCache = {};

  // ── Dropdown selections ─────────────────────────────────────────────────
  String? _selCategory;
  String? _selSubcategory;
  String? _selIllness;
  String? _selSymptom;
  Map<String, dynamic>? _selectedRow;

  // ── Active row source based on mode ────────────────────────────────────
  List<Map<String, dynamic>> get _activeAllRows =>
      _mode == _FindMode.herbal ? _rowsWithRemedies : _productRowsWithProducts;

  List<Map<String, dynamic>> _productRowsWithProducts = [];

  // ── Derived dropdown options ────────────────────────────────────────────
  List<String> get _categories =>
      _sorted(_activeAllRows.map((r) => r['category'].toString()).toSet());

  List<String> get _subcategories {
    var rows = _activeAllRows;
    if (_selCategory != null) rows = rows.where((r) => r['category'] == _selCategory).toList();
    return _sorted(rows.map((r) => r['subcategory'].toString()).toSet());
  }

  List<String> get _illnesses {
    var rows = _activeAllRows;
    if (_selCategory    != null) rows = rows.where((r) => r['category']    == _selCategory).toList();
    if (_selSubcategory != null) rows = rows.where((r) => r['subcategory'] == _selSubcategory).toList();
    return _sorted(rows.map((r) => r['illness'].toString()).toSet());
  }

  List<String> get _symptoms {
    var rows = _activeAllRows;
    if (_selCategory    != null) rows = rows.where((r) => r['category']    == _selCategory).toList();
    if (_selSubcategory != null) rows = rows.where((r) => r['subcategory'] == _selSubcategory).toList();
    if (_selIllness     != null) rows = rows.where((r) => r['illness']     == _selIllness).toList();
    return _sorted(rows.map((r) => r['symptom'].toString()).toSet());
  }

  // ── Filter matrix rows shown in table ──────────────────────────────────
  List<Map<String, dynamic>> get _filteredRows {
    var rows = _activeAllRows;
    if (_selCategory    != null) rows = rows.where((r) => r['category']    == _selCategory).toList();
    if (_selSubcategory != null) rows = rows.where((r) => r['subcategory'] == _selSubcategory).toList();
    if (_selIllness     != null) rows = rows.where((r) => r['illness']     == _selIllness).toList();
    if (_selSymptom     != null) rows = rows.where((r) => r['symptom']     == _selSymptom).toList();
    return rows;
  }

  String _normalize(dynamic v) =>
      (v ?? '').toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  // ── Build herbal count caches ────────────────────────────────────────────
  void _buildCountCaches() {
    final rowCount = <String, int>{};
    final catCount = <String, int>{};
    final subCount = <String, int>{};
    final illCount = <String, int>{};
    final symCount = <String, int>{};

    for (final rem in _remedies) {
      final cat  = _normalize(rem['filter_category']);
      final sub  = _normalize(rem['filter_subcategory']);
      final ill  = _normalize(rem['filter_illness']);
      final symsRaw = rem['filter_symptoms'];
      final syms = symsRaw is List
          ? symsRaw.map((s) => _normalize(s)).toList()
          : <String>[];

      catCount[cat] = (catCount[cat] ?? 0) + 1;
      final subKey = '$cat|$sub';
      subCount[subKey] = (subCount[subKey] ?? 0) + 1;
      final illKey = '$cat|$sub|$ill';
      illCount[illKey] = (illCount[illKey] ?? 0) + 1;

      for (final sym in syms) {
        final symKey = '$cat|$sub|$ill|$sym';
        symCount[symKey] = (symCount[symKey] ?? 0) + 1;
        rowCount[symKey] = (rowCount[symKey] ?? 0) + 1;
      }
    }

    final filtered = _allRows.where((row) {
      final key = '${_normalize(row['category'])}|${_normalize(row['subcategory'])}|${_normalize(row['illness'])}|${_normalize(row['symptom'])}';
      return (rowCount[key] ?? 0) > 0;
    }).toList();

    _rowCountCache    = rowCount;
    _catCountCache    = catCount;
    _subCountCache    = subCount;
    _illCountCache    = illCount;
    _symCountCache    = symCount;
    _rowsWithRemedies = filtered;
  }

  // ── Build products count caches ──────────────────────────────────────────
  void _buildProductCountCaches(List<Map<String, dynamic>> products) {
    final rowCount = <String, int>{};
    final catCount = <String, int>{};
    final subCount = <String, int>{};
    final illCount = <String, int>{};
    final symCount = <String, int>{};

    for (final p in products) {
      final cat = _normalize(p['category']);
      final sub = _normalize(p['subcategory']);
      final ill = _normalize(p['illness']);
      final sym = _normalize(p['symptom']);

      if (cat.isEmpty) continue;

      catCount[cat] = (catCount[cat] ?? 0) + 1;
      final subKey = '$cat|$sub';
      subCount[subKey] = (subCount[subKey] ?? 0) + 1;
      final illKey = '$cat|$sub|$ill';
      illCount[illKey] = (illCount[illKey] ?? 0) + 1;
      final symKey = '$cat|$sub|$ill|$sym';
      symCount[symKey] = (symCount[symKey] ?? 0) + 1;
      rowCount[symKey] = (rowCount[symKey] ?? 0) + 1;
    }

    _prodRowCountCache = rowCount;
    _prodCatCountCache = catCount;
    _prodSubCountCache = subCount;
    _prodIllCountCache = illCount;
    _prodSymCountCache = symCount;

    // Pre-filter product rows to those with count > 0
    _productRowsWithProducts = _productRows.where((row) {
      final key = '${_normalize(row['category'])}|${_normalize(row['subcategory'])}|${_normalize(row['illness'])}|${_normalize(row['symptom'])}';
      return (rowCount[key] ?? 0) > 0;
    }).toList();
  }

  // ── Count helpers ────────────────────────────────────────────────────────
  int _countForCategory(String cat) {
    final cache = _mode == _FindMode.herbal ? _catCountCache : _prodCatCountCache;
    return cache[_normalize(cat)] ?? 0;
  }

  int _countForSubcategory(String sub) {
    final cache = _mode == _FindMode.herbal ? _subCountCache : _prodSubCountCache;
    final catKey = _selCategory != null ? _normalize(_selCategory) : '';
    return cache['$catKey|${_normalize(sub)}'] ?? 0;
  }

  int _countForIllness(String ill) {
    final cache = _mode == _FindMode.herbal ? _illCountCache : _prodIllCountCache;
    final catKey = _normalize(_selCategory ?? '');
    final subKey = _normalize(_selSubcategory ?? '');
    return cache['$catKey|$subKey|${_normalize(ill)}'] ?? 0;
  }

  int _countForSymptom(String sym) {
    final cache = _mode == _FindMode.herbal ? _symCountCache : _prodSymCountCache;
    final catKey = _normalize(_selCategory ?? '');
    final subKey = _normalize(_selSubcategory ?? '');
    final illKey = _normalize(_selIllness ?? '');
    return cache['$catKey|$subKey|$illKey|${_normalize(sym)}'] ?? 0;
  }

  int _countForRow(Map<String, dynamic> row) {
    final cache = _mode == _FindMode.herbal ? _rowCountCache : _prodRowCountCache;
    final key = '${_normalize(row['category'])}|${_normalize(row['subcategory'])}|${_normalize(row['illness'])}|${_normalize(row['symptom'])}';
    return cache[key] ?? 0;
  }

  List<String> _sorted(Set<String> items) =>
      items.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  bool get _hasFilter =>
      _selCategory != null || _selSubcategory != null ||
      _selIllness  != null || _selSymptom     != null;

  @override
  void initState() {
    super.initState();
    _mode = CategoryScreen._savedMode;
    _loadAll();
    final f = widget.initialFilters;
    if (f != null && !f.isEmpty) {
      _selCategory    = f.category;
      _selSubcategory = f.subcategory;
      _selIllness     = f.illness;
      _selSymptom     = f.symptom;
    } else {
      _selCategory    = CategoryScreen._savedCategory;
      _selSubcategory = CategoryScreen._savedSubcategory;
      _selIllness     = CategoryScreen._savedIllness;
      _selSymptom     = CategoryScreen._savedSymptom;
      _selectedRow    = CategoryScreen._savedRow;
    }
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      // Load herbal filter_matrix + remedies
      final List<Map<String, dynamic>> all = [];
      int from = 0;
      const pageSize = 1000;
      while (true) {
        final page = await SupabaseService.supabase
            .from('filter_matrix')
            .select('category, subcategory, illness, symptom')
            .order('category').order('subcategory').order('illness').order('symptom')
            .range(from, from + pageSize - 1);
        final pageList = List<Map<String, dynamic>>.from(page);
        all.addAll(pageList);
        if (pageList.length < pageSize) break;
        from += pageSize;
      }

      final List<Map<String, dynamic>> allRemedies = [];
      int remFrom = 0;
      while (true) {
        final remPage = await SupabaseService.supabase
            .from('remedies')
            .select('filter_category, filter_subcategory, filter_illness, filter_symptoms')
            .eq('status', 'approved')
            .range(remFrom, remFrom + 999);
        final remList = List<Map<String, dynamic>>.from(remPage);
        allRemedies.addAll(remList);
        if (remList.length < 1000) break;
        remFrom += 1000;
      }

      // Load products taxonomy matrix (deduplicated rows from filter_matrix SKU rows)
      final prodMatrix = await SupabaseService.getProductTaxonomyMatrix();

      // Load all filter_matrix rows with SKUs for count caches
      final List<Map<String, dynamic>> allProducts = [];
      int pFrom = 0;
      while (true) {
        final pPage = await SupabaseService.supabase
            .from('filter_matrix')
            .select('category, subcategory, illness, symptom, sku')
            .not('sku', 'is', null)
            .range(pFrom, pFrom + 999);
        final pList = List<Map<String, dynamic>>.from(pPage);
        allProducts.addAll(pList);
        if (pList.length < 1000) break;
        pFrom += 1000;
      }

      // Deduplicate taxonomy rows — filter_matrix has one row per SKU so the
      // same (category, subcategory, illness, symptom) tuple can appear many
      // times.  The Find table only needs unique taxonomy combinations.
      final seen = <String>{};
      final dedupedAll = <Map<String, dynamic>>[];
      for (final r in all) {
        final key = '${r['category']}|${r['subcategory']}|${r['illness']}|${r['symptom']}';
        if (seen.add(key)) dedupedAll.add(r);
      }

      if (!mounted) return;
      setState(() {
        _allRows           = dedupedAll;
        _remedies          = allRemedies;
        _productRows       = prodMatrix;
        _allProductSkuRows = allProducts;   // raw filter_matrix rows with sku
        _loading           = false;
        _buildCountCaches();
        _buildProductCountCaches(allProducts);
      });
    } catch (e, st) {
      debugPrint('ERROR loading matrix: $e\n$st');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onCategoryChanged(String? val) => setState(() {
    _selCategory = val; _selSubcategory = null;
    _selIllness = null; _selSymptom = null; _selectedRow = null;
  });

  void _onSubcategoryChanged(String? val) => setState(() {
    _selSubcategory = val; _selIllness = null;
    _selSymptom = null; _selectedRow = null;
  });

  void _onIllnessChanged(String? val) => setState(() {
    _selIllness = val; _selSymptom = null; _selectedRow = null;
  });

  void _onSymptomChanged(String? val) => setState(() {
    _selSymptom = val; _selectedRow = null;
  });

  void _onRowTap(Map<String, dynamic> row) => setState(() {
    _selectedRow    = row;
    _selCategory    = row['category']?.toString();
    _selSubcategory = row['subcategory']?.toString();
    _selIllness     = row['illness']?.toString();
    _selSymptom     = row['symptom']?.toString();
  });

  void _saveState() {
    CategoryScreen._savedCategory    = _selCategory;
    CategoryScreen._savedSubcategory = _selSubcategory;
    CategoryScreen._savedIllness     = _selIllness;
    CategoryScreen._savedSymptom     = _selSymptom;
    CategoryScreen._savedRow         = _selectedRow;
    CategoryScreen._savedMode        = _mode;
  }

  void _clearAll() {
    setState(() {
      _selCategory = null; _selSubcategory = null;
      _selIllness  = null; _selSymptom     = null;
      _selectedRow = null;
    });
    CategoryScreen.clearSaved();
    CategoryScreen._savedMode = _mode;
  }

  void _switchMode(_FindMode m) {
    if (_mode == m) return;
    setState(() {
      _mode = m;
      _selCategory = null; _selSubcategory = null;
      _selIllness  = null; _selSymptom     = null;
      _selectedRow = null;
    });
    CategoryScreen._savedMode = m;
  }

  void _goToRemedies() {
    _saveState();
    final fs = FilterState(
      category:    _selCategory,
      subcategory: _selSubcategory,
      illness:     _selIllness,
      symptom:     _selSymptom,
    );
    if (widget.onResult != null) {
      widget.onResult!(fs);
    } else {
      Navigator.of(context).pop(fs);
    }
  }

  void _goToProducts() {
    _saveState();
    // Collect matching SKUs from filter_matrix product rows already loaded
    final matchingSkus = _productRows.where((row) {
      if (_selCategory    != null && row['category']    != _selCategory)    return false;
      if (_selSubcategory != null && row['subcategory'] != _selSubcategory) return false;
      if (_selIllness     != null && row['illness']     != _selIllness)     return false;
      if (_selSymptom     != null && row['symptom']     != _selSymptom)     return false;
      return true;
    }).expand((row) {
      // _productRows is deduplicated taxonomy; we need SKUs from the full allProducts list
      return <String>[];
    }).toSet();

    // Use the full filter_matrix SKU data stored in allProducts (via count cache build)
    // Re-query SKUs matching the selected taxonomy from already-loaded data
    final skus = <String>{};
    // Note: _buildProductCountCaches receives the raw filter_matrix rows with SKUs
    // We need access to them here — pass via a local set built during load
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ShopScreen(
        initialTaxonomySkus: _taxSkusForSelection(),
        taxCategory:    _selCategory,
        taxSubcategory: _selSubcategory,
        taxIllness:     _selIllness,
        taxSymptom:     _selSymptom,
      )),
    );
  }

  Set<String> _taxSkusForSelection() {
    // Filter the loaded filter_matrix SKU rows by current selection
    final skus = <String>{};
    for (final row in _allProductSkuRows) {
      final cat = row['category']?.toString();
      final sub = row['subcategory']?.toString();
      final ill = row['illness']?.toString();
      final sym = row['symptom']?.toString();
      final sku = row['sku']?.toString();
      if (sku == null) continue;
      if (_selCategory    != null && cat != _selCategory)    continue;
      if (_selSubcategory != null && sub != _selSubcategory) continue;
      if (_selIllness     != null && ill != _selIllness)     continue;
      if (_selSymptom     != null && sym != _selSymptom)     continue;
      skus.add(sku);
    }
    return skus;
  }

  Widget _headerCell(String label, {int flex = 1}) => Expanded(
    flex: flex,
    child: Text(label,
        style: const TextStyle(
            fontSize: 10, color: Colors.white,
            fontWeight: FontWeight.w700, letterSpacing: 0.3)),
  );

  bool _rowSelected(Map<String, dynamic> row) =>
      _selectedRow != null &&
      _selectedRow!['category']    == row['category'] &&
      _selectedRow!['subcategory'] == row['subcategory'] &&
      _selectedRow!['illness']     == row['illness'] &&
      _selectedRow!['symptom']     == row['symptom'];

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRows;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Container(
              color: AppColors.dark,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Find',
                            style: TextStyle(color: AppColors.primary, fontSize: 18,
                                fontWeight: FontWeight.w600)),
                        Text('Select filters then tap a row',
                            style: TextStyle(color: Color(0x80FFFFFF), fontSize: 11)),
                      ],
                    ),
                  ),
                  if (_hasFilter)
                    GestureDetector(
                      onTap: _clearAll,
                      child: const Text('Clear all',
                          style: TextStyle(color: AppColors.primary, fontSize: 12)),
                    ),
                ],
              ),
            ),

            // ── Toggle cards: Herbal Remedies | Shop Products ─────────────
            Container(
              color: AppColors.dark,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(child: _ToggleCard(
                    label: 'Herbal Remedies',
                    icon: Icons.eco,
                    active: _mode == _FindMode.herbal,
                    onTap: () => _switchMode(_FindMode.herbal),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _ToggleCard(
                    label: 'Shop Products',
                    icon: Icons.shopping_bag_outlined,
                    active: _mode == _FindMode.products,
                    onTap: () => _switchMode(_FindMode.products),
                  )),
                ],
              ),
            ),

            // ── Filter dropdowns ───────────────────────────────────────────
            if (!_loading)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: _Dropdown(
                          label: 'Category',
                          value: _selCategory,
                          items: _categories,
                          onChanged: _onCategoryChanged,
                          counts: Map.fromEntries(_categories.map((c) => MapEntry(c, _countForCategory(c)))),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _Dropdown(
                          label: 'Subcategory',
                          value: _selSubcategory,
                          items: _subcategories,
                          onChanged: _onSubcategoryChanged,
                          enabled: _selCategory != null || _subcategories.isNotEmpty,
                          counts: Map.fromEntries(_subcategories.map((s) => MapEntry(s, _countForSubcategory(s)))),
                        )),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(child: _Dropdown(
                          label: 'Illness',
                          value: _selIllness,
                          items: _illnesses,
                          onChanged: _onIllnessChanged,
                          enabled: _illnesses.isNotEmpty,
                          counts: Map.fromEntries(_illnesses.map((i) => MapEntry(i, _countForIllness(i)))),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _Dropdown(
                          label: 'Symptom',
                          value: _selSymptom,
                          items: _symptoms,
                          onChanged: _onSymptomChanged,
                          enabled: _symptoms.isNotEmpty,
                          counts: Map.fromEntries(_symptoms.map((s) => MapEntry(s, _countForSymptom(s)))),
                        )),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _hasFilter
                              ? '${filtered.length} result${filtered.length == 1 ? '' : 's'} — tap a row to select'
                              : 'All ${_activeAllRows.length} entries — use filters above',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                        if (_hasFilter)
                          GestureDetector(
                            onTap: _clearAll,
                            child: const Text('Clear all',
                                style: TextStyle(fontSize: 11, color: Colors.red,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

            // ── Filter matrix table ────────────────────────────────────────
            if (!_loading)
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('No results for this filter combination',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))
                    : Column(
                        children: [
                          Container(
                            color: AppColors.dark,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            child: Row(
                              children: [
                                _headerCell('Category',    flex: 3),
                                _headerCell('Subcategory', flex: 3),
                                _headerCell('Illness',     flex: 3),
                                _headerCell('Symptom',     flex: 3),
                                const SizedBox(
                                  width: 32,
                                  child: Text('#',
                                    textAlign: TextAlign.right,
                                    style: TextStyle(fontSize: 10,
                                        color: Colors.white70, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final row = filtered[i];
                                final isSelected = _rowSelected(row);
                                return GestureDetector(
                                  onTap: () => _onRowTap(row),
                                  child: Container(
                                    color: isSelected
                                        ? AppColors.primary.withOpacity(0.15)
                                        : i.isEven ? Colors.white : AppColors.background,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 7),
                                    child: Row(
                                      children: [
                                        Expanded(flex: 3, child: Row(children: [
                                          Expanded(child: Text(
                                            row['category']?.toString() ?? '',
                                            style: TextStyle(fontSize: 11, color: AppColors.dark,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal),
                                          )),
                                          if (isSelected)
                                            const Icon(Icons.check_circle,
                                                size: 14, color: AppColors.primary),
                                        ])),
                                        Expanded(flex: 3, child: Text(
                                          row['subcategory']?.toString() ?? '',
                                          style: TextStyle(fontSize: 11, color: AppColors.dark,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal),
                                        )),
                                        Expanded(flex: 3, child: Text(
                                          row['illness']?.toString() ?? '',
                                          style: TextStyle(fontSize: 11, color: AppColors.dark,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal),
                                        )),
                                        Expanded(flex: 3, child: Text(
                                          row['symptom']?.toString() ?? '',
                                          style: TextStyle(fontSize: 11, color: AppColors.dark,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal),
                                        )),
                                        SizedBox(
                                          width: 32,
                                          child: Text('${_countForRow(row)}',
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(fontSize: 11,
                                                fontWeight: FontWeight.bold, color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),

            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator())),

            // ── Bottom action bar ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedRow != null
                              ? 'Filter set selected'
                              : _hasFilter
                                  ? '${_filteredRows.length} filter set${_filteredRows.length == 1 ? '' : 's'}'
                                  : 'Select filters above',
                          style: const TextStyle(fontSize: 13,
                              fontWeight: FontWeight.w600, color: AppColors.dark),
                        ),
                        if (_hasFilter || _selectedRow != null)
                          FutureBuilder<int>(
                            future: _mode == _FindMode.herbal
                                ? SupabaseService.getFilteredRemedyCount(
                                    category:    _selCategory,
                                    subcategory: _selSubcategory,
                                    illness:     _selIllness,
                                    symptom:     _selSymptom,
                                  )
                                : SupabaseService.getSkusForTaxonomy(
                                    category:    _selCategory,
                                    subcategory: _selSubcategory,
                                    illness:     _selIllness,
                                    symptom:     _selSymptom,
                                  ).then((skus) => skus.length),
                            builder: (context, snap) {
                              final count = snap.data ?? 0;
                              final noun = _mode == _FindMode.herbal ? 'recipe' : 'product';
                              return Text(
                                '$count ${noun}${count == 1 ? '' : 's'} matching',
                                style: const TextStyle(fontSize: 11,
                                    color: AppColors.textSecondary),
                              );
                            },
                          ),
                        if (_selectedRow != null)
                          Text(
                            '${_selectedRow!['category']} > ${_selectedRow!['symptom']}',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _hasFilter
                        ? (_mode == _FindMode.herbal ? _goToRemedies : _goToProducts)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: _hasFilter ? AppColors.dark : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _mode == _FindMode.herbal ? 'Go to Remedies' : 'Go to Products',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: _hasFilter ? AppColors.primary : Colors.grey.shade500)),
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_forward, size: 14,
                              color: _hasFilter ? AppColors.primary : Colors.grey.shade500),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Toggle card widget ───────────────────────────────────────────────────────
class _ToggleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _ToggleCard({required this.label, required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.primary : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16,
                color: active ? AppColors.dark : Colors.white60),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: active ? AppColors.dark : Colors.white60)),
          ],
        ),
      ),
    );
  }
}

// ─── Dropdown widget ───────────────────────────────────────────────────────────
class _Dropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final bool isDark;
  final Map<String, int> counts;

  _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.isDark = false,
    this.counts = const {},
  });

  void _showSearch(BuildContext context) {
    final searchCtrl = TextEditingController();
    List<String> filtered = List.from(items);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          title: Text('Select $label',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(children: [
              TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search $label...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 12),
                onChanged: (q) => setDlg(() {
                  filtered = items
                      .where((s) => s.toLowerCase().contains(q.toLowerCase()))
                      .toList();
                }),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () { onChanged(null); Navigator.pop(ctx); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(children: [
                    const Icon(Icons.clear, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text('All $label',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => InkWell(
                    onTap: () { onChanged(filtered[i]); Navigator.pop(ctx); },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      child: Row(children: [
                        if (value == filtered[i]) ...[
                          const Icon(Icons.check, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(filtered[i],
                              style: TextStyle(
                                fontSize: 12,
                                color: value == filtered[i] ? AppColors.primary : AppColors.dark,
                                fontWeight: value == filtered[i] ? FontWeight.w600 : FontWeight.normal,
                         )),
                        ),
                        if (counts.containsKey(filtered[i]))
                          Text('${counts[filtered[i]] ?? 0}',
                              style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
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
    final effectiveValue = (value != null && items.contains(value)) ? value : null;
    final textColor = isDark
        ? (effectiveValue != null ? AppColors.primary : Colors.white70)
        : (effectiveValue != null ? AppColors.dark
            : (enabled ? AppColors.textSecondary : Colors.grey.shade400));
    return GestureDetector(
      onTap: enabled ? () => _showSearch(context) : null,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: isDark ? null : BoxDecoration(
          color: enabled ? Colors.white : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: effectiveValue != null ? AppColors.primary : Colors.grey.shade300,
              width: effectiveValue != null ? 1.5 : 1.0),
          boxShadow: enabled ? [BoxShadow(
              color: Colors.black.withOpacity(0.04), blurRadius: 4)] : null,
        ),
        child: Row(children: [
          Expanded(
            child: Text(
              effectiveValue ?? label,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: effectiveValue != null ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (effectiveValue != null)
            GestureDetector(
              onTap: () => onChanged(null),
              child: Icon(Icons.close, size: 16,
                  color: isDark ? Colors.white70 : AppColors.dark),
            )
          else
            Icon(Icons.keyboard_arrow_down, size: 16,
                color: isDark ? Colors.white70 : (enabled ? AppColors.dark : Colors.grey.shade400)),
        ]),
      ),
    );
  }
}
