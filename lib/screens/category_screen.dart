import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';
import '../models/filter_state.dart';

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

  static void clearSaved() {
    _savedCategory = _savedSubcategory = _savedIllness = _savedSymptom = null;
    _savedRow = null;
  }

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  // ÃƒÆ’¢ÃƒÆ’¢ All matrix rows loaded once ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢
  List<Map<String, dynamic>> _allRows   = [];
  List<Map<String, dynamic>> _remedies  = [];
  bool _loading = true;

  // Pre-computed count caches — built once after data loads
  List<Map<String, dynamic>> _rowsWithRemedies = []; // _allRows filtered to count > 0
  Map<String, int> _rowCountCache  = {};  // "cat|sub|ill|sym" -> count
  Map<String, int> _catCountCache  = {};  // category -> count
  Map<String, int> _subCountCache  = {};  // "cat|sub" -> count
  Map<String, int> _illCountCache  = {};  // "cat|sub|ill" -> count
  Map<String, int> _symCountCache  = {};  // "cat|sub|ill|sym" -> count

  // ÃƒÆ’¢ÃƒÆ’¢ Dropdown selections ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢
  String? _selCategory;
  String? _selSubcategory;
  String? _selIllness;
  String? _selSymptom;

  // ÃƒÆ’¢ÃƒÆ’¢ Selected filter set (the row the user tapped) ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢
  Map<String, dynamic>? _selectedRow;

  // ÃƒÆ’¢ÃƒÆ’¢ Derived dropdown options ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢
  List<String> get _categories =>
      _sorted(_rowsWithRemedies.map((r) => r['category'].toString()).toSet());

  List<String> get _subcategories {
    var rows = _rowsWithRemedies;
    if (_selCategory != null) rows = rows.where((r) => r['category'] == _selCategory).toList();
    return _sorted(rows.map((r) => r['subcategory'].toString()).toSet());
  }

  List<String> get _illnesses {
    var rows = _rowsWithRemedies;
    if (_selCategory    != null) rows = rows.where((r) => r['category']    == _selCategory).toList();
    if (_selSubcategory != null) rows = rows.where((r) => r['subcategory'] == _selSubcategory).toList();
    return _sorted(rows.map((r) => r['illness'].toString()).toSet());
  }

  List<String> get _symptoms {
    var rows = _rowsWithRemedies;
    if (_selCategory    != null) rows = rows.where((r) => r['category']    == _selCategory).toList();
    if (_selSubcategory != null) rows = rows.where((r) => r['subcategory'] == _selSubcategory).toList();
    if (_selIllness     != null) rows = rows.where((r) => r['illness']     == _selIllness).toList();
    return _sorted(rows.map((r) => r['symptom'].toString()).toSet());
  }

  // ÃƒÆ’¢ÃƒÆ’¢ Filter matrix rows shown in table ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢
  List<Map<String, dynamic>> get _filteredRows {
    // Use pre-filtered list (count > 0 already guaranteed)
    var rows = _rowsWithRemedies;
    if (_selCategory    != null) rows = rows.where((r) => r['category']    == _selCategory).toList();
    if (_selSubcategory != null) rows = rows.where((r) => r['subcategory'] == _selSubcategory).toList();
    if (_selIllness     != null) rows = rows.where((r) => r['illness']     == _selIllness).toList();
    if (_selSymptom     != null) rows = rows.where((r) => r['symptom']     == _selSymptom).toList();
    return rows;
  }


  String _normalize(dynamic value) =>
      (value ?? '').toString().trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  // Build all count caches once after data loads — O(n) instead of O(n*m) per render
  void _buildCountCaches() {
    final rowCount  = <String, int>{};
    final catCount  = <String, int>{};
    final subCount  = <String, int>{};
    final illCount  = <String, int>{};
    final symCount  = <String, int>{};

    for (final rem in _remedies) {
      final cat = _normalize(rem['filter_category']);
      final sub = _normalize(rem['filter_subcategory']);
      final ill = _normalize(rem['filter_illness']);
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

        final rowKey = '$cat|$sub|$ill|$sym';
        rowCount[rowKey] = (rowCount[rowKey] ?? 0) + 1;
      }
    }

    // Pre-filter rows that have at least one matching remedy
    final filtered = _allRows.where((row) {
      final key = '${_normalize(row['category'])}|${_normalize(row['subcategory'])}|${_normalize(row['illness'])}|${_normalize(row['symptom'])}';
      return (rowCount[key] ?? 0) > 0;
    }).toList();

    _rowCountCache  = rowCount;
    _catCountCache  = catCount;
    _subCountCache  = subCount;
    _illCountCache  = illCount;
    _symCountCache  = symCount;
    _rowsWithRemedies = filtered;
  }

  int _countForCategory(String cat) =>
      _catCountCache[_normalize(cat)] ?? 0;

  int _countForSubcategory(String sub) {
    final catKey = _selCategory != null ? _normalize(_selCategory) : '';
    final subKey = '$catKey|${_normalize(sub)}';
    return _subCountCache[subKey] ?? (_selCategory == null ? (_catCountCache.entries
        .where((e) => e.key.endsWith('|${_normalize(sub)}'))
        .fold(0, (s, e) => s + e.value)) : 0);
  }

  int _countForIllness(String ill) {
    final catKey = _normalize(_selCategory ?? '');
    final subKey = _normalize(_selSubcategory ?? '');
    final illKey = '$catKey|$subKey|${_normalize(ill)}';
    return _illCountCache[illKey] ?? 0;
  }

  int _countForSymptom(String sym) {
    final catKey = _normalize(_selCategory ?? '');
    final subKey = _normalize(_selSubcategory ?? '');
    final illKey = _normalize(_selIllness ?? '');
    final symKey = '$catKey|$subKey|$illKey|${_normalize(sym)}';
    return _symCountCache[symKey] ?? 0;
  }

  int _countForRow(Map<String, dynamic> row) {
    final key = '${_normalize(row['category'])}|${_normalize(row['subcategory'])}|${_normalize(row['illness'])}|${_normalize(row['symptom'])}';
    return _rowCountCache[key] ?? 0;
  }

  List<String> _sorted(Set<String> items) =>
      items.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  bool get _hasFilter =>
      _selCategory != null || _selSubcategory != null ||
      _selIllness  != null || _selSymptom     != null;

  @override
  void initState() {
    super.initState();
    _loadMatrix();
    // Restore saved state if no initial filters provided
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

  Future<void> _loadMatrix() async {
    setState(() => _loading = true);
    try {
      // Load in pages to avoid row limit
      final List<Map<String, dynamic>> all = [];
      int from = 0;
      const pageSize = 1000;
      while (true) {
        final page = await SupabaseService.supabase
            .from('filter_matrix')
            .select('category, subcategory, illness, symptom')
            .order('category', ascending: true)
            .order('subcategory', ascending: true)
            .order('illness', ascending: true)
            .order('symptom', ascending: true)
            .range(from, from + pageSize - 1);
        final pageList = List<Map<String, dynamic>>.from(page);
        all.addAll(pageList);
        if (pageList.length < pageSize) break;
        from += pageSize;
      }
      if (!mounted) return;
      // Load remedies for counts
      // Paginated remedy fetch
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
      setState(() {
        _allRows   = all;
        _remedies  = allRemedies;
        _loading = false;
        _buildCountCaches();
      });
    } catch (e, st) {
      debugPrint('ERROR loading matrix/remedies: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onCategoryChanged(String? val) {
    setState(() {
      _selCategory    = val;
      _selSubcategory = null;
      _selIllness     = null;
      _selSymptom     = null;
      _selectedRow    = null;
    });
  }

  void _onSubcategoryChanged(String? val) {
    setState(() {
      _selSubcategory = val;
      _selIllness     = null;
      _selSymptom     = null;
      _selectedRow    = null;
    });
  }

  void _onIllnessChanged(String? val) {
    setState(() {
      _selIllness  = val;
      _selSymptom  = null;
      _selectedRow = null;
    });
  }

  void _onSymptomChanged(String? val) {
    setState(() {
      _selSymptom  = val;
      _selectedRow = null;
    });
  }

  void _onRowTap(Map<String, dynamic> row) {
    setState(() {
      _selectedRow    = row;
      _selCategory    = row['category']?.toString();
      _selSubcategory = row['subcategory']?.toString();
      _selIllness     = row['illness']?.toString();
      _selSymptom     = row['symptom']?.toString();
    });
  }

  void _saveState() {
    CategoryScreen._savedCategory    = _selCategory;
    CategoryScreen._savedSubcategory = _selSubcategory;
    CategoryScreen._savedIllness     = _selIllness;
    CategoryScreen._savedSymptom     = _selSymptom;
    CategoryScreen._savedRow         = _selectedRow;
  }

  void _clearAll() {
    setState(() {
      _selCategory    = null;
      _selSubcategory = null;
      _selIllness     = null;
      _selSymptom     = null;
      _selectedRow    = null;
    });
    CategoryScreen.clearSaved();
  }

  void _goToRemedies() {
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
            // ÃƒÆ’¢ÃƒÆ’¢ Header ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢
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
                        Text('Find a Remedy',
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


            // ── Filter dropdowns (separate panel above table) ─────────────────────
            if (!_loading)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Symptom | Illness
                    Row(
                      children: [
                        Expanded(child: _Dropdown(
                          label: 'Symptom',
                          value: _selSymptom,
                          items: _symptoms,
                          onChanged: _onSymptomChanged,
                          enabled: _symptoms.isNotEmpty,
                          counts: Map.fromEntries(_symptoms.map((s) => MapEntry(s, _countForSymptom(s)))),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: _Dropdown(
                          label: 'Illness',
                          value: _selIllness,
                          items: _illnesses,
                          onChanged: _onIllnessChanged,
                          enabled: _illnesses.isNotEmpty,
                          counts: Map.fromEntries(_illnesses.map((i) => MapEntry(i, _countForIllness(i)))),
                        )),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Row 2: Category | Subcategory
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
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _hasFilter
                              ? '${filtered.length} result${filtered.length == 1 ? '' : 's'} — tap a row to select'
                              : 'All ${_allRows.length} entries — use filters above',
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

            // ── Filter matrix table ────────────────────────────────────────────────
            if (!_loading)
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('No results for this filter combination',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))
                    : Column(
                        children: [
                          // Simple table header — plain labels, no dropdowns
                          Container(
                            color: AppColors.dark,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            child: Row(
                              children: [
                                _headerCell('Symptom',     flex: 3),
                                _headerCell('Illness',     flex: 3),
                                _headerCell('Subcategory', flex: 3),
                                _headerCell('Category',    flex: 3),
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
                          // Table rows — Symptom | Illness | Subcategory | Category
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
                                            row['symptom']?.toString() ?? '',
                                            style: TextStyle(fontSize: 11, color: AppColors.dark,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal),
                                          )),
                                          if (isSelected)
                                            const Icon(Icons.check_circle,
                                                size: 14, color: AppColors.primary),
                                        ])),
                                        Expanded(flex: 3, child: Text(
                                          row['illness']?.toString() ?? '',
                                          style: TextStyle(fontSize: 11, color: AppColors.dark,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal),
                                        )),
                                        Expanded(flex: 3, child: Text(
                                          row['subcategory']?.toString() ?? '',
                                          style: TextStyle(fontSize: 11, color: AppColors.dark,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal),
                                        )),
                                        Expanded(flex: 3, child: Text(
                                          row['category']?.toString() ?? '',
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

            // ÃƒÆ’¢ÃƒÆ’¢ Bottom bar ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢
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
                            future: SupabaseService.getFilteredRemedyCount(
                              category:    _selCategory,
                              subcategory: _selSubcategory,
                              illness:     _selIllness,
                              symptom:     _selSymptom,
                            ),
                            builder: (context, snap) {
                              final count = snap.data ?? 0;
                              return Text(
                                '$count recipe${count == 1 ? '' : 's'} matching',
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
                    onTap: _hasFilter ? _goToRemedies : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: _hasFilter ? AppColors.dark : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Go to Remedies',
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

// ÃƒÆ’¢ÃƒÆ’¢ Dropdown widget ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢ÃƒÆ’¢
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
              // Clear option
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
