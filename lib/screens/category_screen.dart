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
  // Ã¢â€â‚¬Ã¢â€â‚¬ All matrix rows loaded once Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  List<Map<String, dynamic>> _allRows   = [];
  bool _loading = true;

  // Ã¢â€â‚¬Ã¢â€â‚¬ Dropdown selections Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  String? _selCategory;
  String? _selSubcategory;
  String? _selIllness;
  String? _selSymptom;

  // Ã¢â€â‚¬Ã¢â€â‚¬ Selected filter set (the row the user tapped) Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  Map<String, dynamic>? _selectedRow;

  // Ã¢â€â‚¬Ã¢â€â‚¬ Derived dropdown options Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  List<String> get _categories =>
      _sorted(_allRows.map((r) => r['category'].toString()).toSet());

  List<String> get _subcategories {
    var rows = _allRows;
    if (_selCategory != null) rows = rows.where((r) => r['category'] == _selCategory).toList();
    return _sorted(rows.map((r) => r['subcategory'].toString()).toSet());
  }

  List<String> get _illnesses {
    var rows = _allRows;
    if (_selCategory    != null) rows = rows.where((r) => r['category']    == _selCategory).toList();
    if (_selSubcategory != null) rows = rows.where((r) => r['subcategory'] == _selSubcategory).toList();
    return _sorted(rows.map((r) => r['illness'].toString()).toSet());
  }

  List<String> get _symptoms {
    var rows = _allRows;
    if (_selCategory    != null) rows = rows.where((r) => r['category']    == _selCategory).toList();
    if (_selSubcategory != null) rows = rows.where((r) => r['subcategory'] == _selSubcategory).toList();
    if (_selIllness     != null) rows = rows.where((r) => r['illness']     == _selIllness).toList();
    return _sorted(rows.map((r) => r['symptom'].toString()).toSet());
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ Filter matrix rows shown in table Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  List<Map<String, dynamic>> get _filteredRows {
    var rows = _allRows;
    if (_selCategory    != null) rows = rows.where((r) => r['category']    == _selCategory).toList();
    if (_selSubcategory != null) rows = rows.where((r) => r['subcategory'] == _selSubcategory).toList();
    if (_selIllness     != null) rows = rows.where((r) => r['illness']     == _selIllness).toList();
    if (_selSymptom     != null) rows = rows.where((r) => r['symptom']     == _selSymptom).toList();
    return rows;
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
      setState(() {
        _allRows = all;
        _loading = false;
      });
    } catch (e) {
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
            // Ã¢â€â‚¬Ã¢â€â‚¬ Header Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
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

            // Ã¢â€â‚¬Ã¢â€â‚¬ 4 Dropdown filters Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: _loading
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(color: AppColors.primary)))
                  : Column(
                      children: [
                        Row(children: [
                          Expanded(child: _Dropdown(
                            label: 'Category',
                            value: _selCategory,
                            items: _categories,
                            onChanged: _onCategoryChanged,
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: _Dropdown(
                            label: 'Subcategory',
                            value: _selSubcategory,
                            items: _subcategories,
                            onChanged: _onSubcategoryChanged,
                            enabled: _selCategory != null || _subcategories.isNotEmpty,
                          )),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: _Dropdown(
                            label: 'Illness',
                            value: _selIllness,
                            items: _illnesses,
                            onChanged: _onIllnessChanged,
                            enabled: _illnesses.isNotEmpty,
                          )),
                          const SizedBox(width: 8),
                          Expanded(child: _Dropdown(
                            label: 'Symptom',
                            value: _selSymptom,
                            items: _symptoms,
                            onChanged: _onSymptomChanged,
                            enabled: _symptoms.isNotEmpty,
                          )),
                        ]),
                      ],
                    ),
            ),

            // Ã¢â€â‚¬Ã¢â€â‚¬ Results count Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
            if (!_loading)
              Container(
                width: double.infinity,
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Expanded(
                       child: Text(
                         _hasFilter
                             ? '${filtered.length} filter set${filtered.length == 1 ? '' : 's'} - tap a row to select'
                             : 'All ${_allRows.length} filter sets - select a filter above',
                         style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                       ),
                     ),

                    if (_hasFilter)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: GestureDetector(
                          onTap: _clearAll,
                          child: const Text('Clear',
                              style: TextStyle(fontSize: 12, color: Colors.red,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                   ],
                 ),
              ),

            // Ã¢â€â‚¬Ã¢â€â‚¬ Filter matrix table Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
            if (!_loading)
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text('No results for this filter combination',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)))
                    : Column(
                        children: [
                          // Table header
                          Container(
                            color: AppColors.dark,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: const Row(
                              children: [
                                Expanded(flex: 3, child: Text('Category',
                                    style: TextStyle(color: AppColors.primary, fontSize: 10,
                                        fontWeight: FontWeight.w700))),
                                Expanded(flex: 3, child: Text('Subcategory',
                                    style: TextStyle(color: AppColors.primary, fontSize: 10,
                                        fontWeight: FontWeight.w700))),
                                Expanded(flex: 3, child: Text('Illness',
                                    style: TextStyle(color: AppColors.primary, fontSize: 10,
                                        fontWeight: FontWeight.w700))),
                                Expanded(flex: 3, child: Text('Symptom',
                                    style: TextStyle(color: AppColors.primary, fontSize: 10,
                                        fontWeight: FontWeight.w700))),
                              ],
                            ),
                          ),
                          // Table rows
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
                                        : i.isEven
                                            ? Colors.white
                                            : AppColors.background,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 7),
                                    child: Row(
                                      children: [
                                        Expanded(flex: 3, child: Text(
                                          row['category']?.toString() ?? '',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.dark,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.normal,
                                          ),
                                        )),
                                        Expanded(flex: 3, child: Text(
                                          row['subcategory']?.toString() ?? '',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.dark,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.normal,
                                          ),
                                        )),
                                        Expanded(flex: 3, child: Text(
                                          row['illness']?.toString() ?? '',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.dark,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.normal,
                                          ),
                                        )),
                                        Expanded(flex: 3, child: Row(
                                          children: [
                                            Expanded(child: Text(
                                              row['symptom']?.toString() ?? '',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.dark,
                                                fontWeight: isSelected
                                                    ? FontWeight.w700
                                                    : FontWeight.normal,
                                              ),
                                            )),
                                            if (isSelected)
                                              const Icon(Icons.check_circle,
                                                  size: 14, color: AppColors.primary),
                                          ],
                                        )),
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

            // Ã¢â€â‚¬Ã¢â€â‚¬ Bottom bar Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
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

// Ã¢â€â‚¬Ã¢â€â‚¬ Dropdown widget Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
class _Dropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveValue = (value != null && items.contains(value)) ? value : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.grey.shade100,
        border: Border.all(
            color: effectiveValue != null
                ? AppColors.primary
                : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isExpanded: true,
          isDense: true,
          hint: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: enabled ? AppColors.textSecondary : Colors.grey.shade400)),
          style: const TextStyle(fontSize: 11, color: AppColors.dark),
          icon: Icon(Icons.keyboard_arrow_down,
              size: 16,
              color: enabled ? AppColors.dark : Colors.grey.shade400),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('All $label',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ),
            ...items.map((item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: enabled ? onChanged : null,
          selectedItemBuilder: (context) => [
            Text('All $label',
                style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
            ...items.map((item) => Text(item,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
