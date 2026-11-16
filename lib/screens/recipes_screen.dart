import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import '../models/filter_state.dart';
import 'category_screen.dart';
import 'recipe_detail_screen.dart';
import 'shop_screen.dart';
import 'product_detail_screen.dart';
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  // Static callback so other screens can trigger a reload
  static VoidCallback? _reloadCallback;
  static void reload() => _reloadCallback?.call();

  // Static callback for applying filters from Category screen
  static void Function(FilterState)? _applyFiltersCallback;
  static void applyFilters(FilterState fs) => _applyFiltersCallback?.call(fs);

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen>
    with SingleTickerProviderStateMixin {
  // ── Legacy multi-select filter strings (kept for search chips) ────────────
  String _selectedType        = '';
  String _selectedOrgan       = '';
  String _selectedCountry     = '';
  String _selectedHerb        = '';
  int _minValidation  = 0;
  int _minTraditional = 0;
  int _minUserRating  = 0;
  String _difficulty  = 'All';

  // ── Cascading dropdowns (mirror CategoryScreen logic) ────────────────────
  String? _selCategory;
  String? _selSubcategory;
  String? _selIllness;
  String? _selSymptom;
  bool _filterExpanded = false; // collapsible panel state

  // ── Filter-matrix rows (loaded once, drives cascading options) ───────────
  List<Map<String, dynamic>> _matrixRows = [];

  // ── Derived cascading options (same logic as CategoryScreen) ─────────────
  List<String> get _catOptions =>
      _sorted(_matrixRows.map((r) => r['category'].toString()).toSet());

  List<String> get _subOptions {
    var rows = _matrixRows;
    if (_selCategory != null) rows = rows.where((r) => r['category'] == _selCategory).toList();
    return _sorted(rows.map((r) => r['subcategory'].toString()).toSet());
  }

  List<String> get _illnessOptions {
    var rows = _matrixRows;
    if (_selCategory    != null) rows = rows.where((r) => r['category']    == _selCategory).toList();
    if (_selSubcategory != null) rows = rows.where((r) => r['subcategory'] == _selSubcategory).toList();
    return _sorted(rows.map((r) => r['illness'].toString()).toSet());
  }

  List<String> get _symptomOptions {
    var rows = _matrixRows;
    if (_selCategory    != null) rows = rows.where((r) => r['category']    == _selCategory).toList();
    if (_selSubcategory != null) rows = rows.where((r) => r['subcategory'] == _selSubcategory).toList();
    if (_selIllness     != null) rows = rows.where((r) => r['illness']     == _selIllness).toList();
    return _sorted(rows.map((r) => r['symptom'].toString()).toSet());
  }

  List<String> _sorted(Set<String> items) =>
      items.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  bool get _hasMatrixFilter =>
      _selCategory != null || _selSubcategory != null ||
      _selIllness  != null || _selSymptom     != null;

  // ── Search ────────────────────────────────────────────────────────────────
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  List<String> _searchTerms = [];
  FilterState _activeFilters = const FilterState();
  bool _loading = true;
  String _encouragement = '';
  final TextEditingController _searchController = TextEditingController();

  // ── Data ──────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _allRemedies = [];
  Map<String, Set<String>> _remedyProductIds = {};
  // Legacy flat lists (kept for herb/organ/country dropdowns)
  List<String> _organs     = ['All'];
  List<String> _countries  = ['All'];
  List<String> _herbs      = ['All'];

  @override
  void initState() {
    super.initState();
    RecipesScreen._applyFiltersCallback = (fs) {
      if (mounted) setState(() => _activeFilters = fs);
    };
    RecipesScreen._reloadCallback = _loadData;
    _runPulse();
    _loadData();
    SupabaseService.getAppContent('home_encouragement').then((text) {
      if (mounted) setState(() => _encouragement = text);
    });
  }

  @override
  void dispose() {
    RecipesScreen._reloadCallback = null;
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _runPulse() async {
    for (int i = 0; i < 2; i++) {
      if (!mounted) return;
      if (!mounted) return;
    }
  }

  // Lightweight refresh - only reload remedies, keep filters/lookups cached
  Future<void> _refreshRemediesOnly() async {
    try {
      final remedies = await SupabaseService.getRemedies();
      final products = await SupabaseService.getProducts();
      if (!mounted) return;
      setState(() {
        _allRemedies = remedies.map((r) => {
          ...r,
          '_has_component': products.any((p) => (p['linked_remedy_id']?.toString() == r['id']?.toString() || _remedyProductIds[r['id']?.toString()]?.contains(p['id']?.toString()) == true) && p['type'] == 'Component'),
          '_has_remedy':    products.any((p) => (p['linked_remedy_id']?.toString() == r['id']?.toString() || _remedyProductIds[r['id']?.toString()]?.contains(p['id']?.toString()) == true) && p['type'] == 'Remedy'),
        }).toList();
      });
    } catch (_) {}
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      // ── 2 queries instead of 11: remedies + filter matrix ────────────────
      final results = await Future.wait<dynamic>([
        SupabaseService.getRemedies(),
        _loadFilterMatrix(),
      ]);

      if (!mounted) return;
      final remedies = results[0] as List<Map<String, dynamic>>;
      setState(() {
        _allRemedies = remedies.map((r) => {...r,
          '_has_component': false, // filled in by background product load
          '_has_remedy':    false,
        }).toList();
        // Derive organs/countries/herbs from loaded remedies (no extra queries)
        final orgSet  = remedies.map((r) => (r['organ_name'] ?? '').toString().trim()).where((v) => v.isNotEmpty).toSet();
        final ctrySet = remedies.map((r) => (r['origin']     ?? '').toString().trim()).where((v) => v.isNotEmpty).toSet();
        final herbSet = remedies.map((r) => (r['component']  ?? '').toString().trim()).where((v) => v.isNotEmpty).toSet();
        _organs    = ['All', ...orgSet.toList()..sort()];
        _countries = ['All', ...ctrySet.toList()..sort()];
        _herbs     = ['All', ...herbSet.toList()..sort()];
        _loading = false;
      });

      // Load products in the background — buy buttons fill in after ~1 s
      _loadProductsBackground();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  /// Loads filter_matrix with pagination (same as CategoryScreen).
  Future<List<Map<String, dynamic>>> _loadFilterMatrix() async {
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
    if (mounted) setState(() => _matrixRows = all);
    return all;
  }

  /// Background product load — does NOT block the initial screen render.
  Future<void> _loadProductsBackground() async {
    try {
      final products = await SupabaseService.getProducts();
      final rpList = await SupabaseService.supabase
          .from('remedy_products').select('remedy_id, product_id');
      final Map<String, Set<String>> rpMap = {};
      for (final rp in rpList) {
        final rid = rp['remedy_id']?.toString() ?? '';
        final pid = rp['product_id']?.toString() ?? '';
        rpMap.putIfAbsent(rid, () => <String>{}).add(pid);
      }
      if (!mounted) return;
      setState(() {
        _remedyProductIds = rpMap;
        _allRemedies = _allRemedies.map((r) => {
          ...r,
          '_has_component': products.any((p) =>
              (p['linked_remedy_id']?.toString() == r['id']?.toString() ||
               rpMap[r['id']?.toString()]?.contains(p['id']?.toString()) == true) &&
              p['type'] == 'Component'),
          '_has_remedy': products.any((p) =>
              (p['linked_remedy_id']?.toString() == r['id']?.toString() ||
               rpMap[r['id']?.toString()]?.contains(p['id']?.toString()) == true) &&
              p['type'] == 'Remedy'),
        }).toList();
      });
    } catch (_) {}
  }

  // Multi-select filter match: true if no filter is set, or if ANY selected
  // chip overlaps with ANY value already on the remedy (remedy fields may
  // themselves hold several comma-separated values).
  bool _matchesMulti(dynamic remedyValue, String selectedCsv) {
    if (selectedCsv.trim().isEmpty) return true;
    final remedyItems = (remedyValue ?? '').toString()
        .split(RegExp(r'[,;]')).map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty).toSet();
    final selectedItems = selectedCsv
        .split(RegExp(r'[,;]')).map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty);
    return selectedItems.any((s) => remedyItems.contains(s));
  }

  List<Map<String, dynamic>> get _filtered {
    return _allRemedies.where((r) {
      final component   = (r['component'] ?? '').toString().toLowerCase();
      final category    = (r['category_name'] ?? '').toString();

      // ── Filter matrix filters from Category screen ───────────────────────
      if (!_activeFilters.isEmpty) {
        if (_activeFilters.category != null &&
            (r['filter_category'] ?? '').toString().toLowerCase() != _activeFilters.category!.toLowerCase()) return false;
        if (_activeFilters.subcategory != null &&
            (r['filter_subcategory'] ?? '').toString().toLowerCase() != _activeFilters.subcategory!.toLowerCase()) return false;
        if (_activeFilters.illness != null &&
            (r['filter_illness'] ?? '').toString().toLowerCase() != _activeFilters.illness!.toLowerCase()) return false;
        if (_activeFilters.symptom != null) {
          final rawSyms = r['filter_symptoms'];
          List<String> syms = [];
          if (rawSyms is List) {
            syms = rawSyms.map((s) => s.toString().toLowerCase().trim()).toList();
          }
          if (!syms.any((s) => s == _activeFilters.symptom!.toLowerCase().trim())) return false;
        }
      }

      // ── In-screen cascading dropdown filters (same field matching) ───────
      if (_hasMatrixFilter) {
        if (_selCategory != null &&
            (r['filter_category'] ?? '').toString().toLowerCase() != _selCategory!.toLowerCase()) return false;
        if (_selSubcategory != null &&
            (r['filter_subcategory'] ?? '').toString().toLowerCase() != _selSubcategory!.toLowerCase()) return false;
        if (_selIllness != null &&
            (r['filter_illness'] ?? '').toString().toLowerCase() != _selIllness!.toLowerCase()) return false;
        if (_selSymptom != null) {
          final rawSyms = r['filter_symptoms'];
          List<String> syms = [];
          if (rawSyms is List) {
            syms = rawSyms.map((s) => s.toString().toLowerCase().trim()).toList();
          }
          if (!syms.any((s) => s == _selSymptom!.toLowerCase().trim())) return false;
        }
      }

      // Live search field  filters as you type
      if (_searchQuery.isNotEmpty) {
        final terms = _searchQuery.split(RegExp(r'[;\s]+')).map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toList();
        final fields = [r['name'], component, r['illness_name'], r['category_name'], r['sub_category_name'], r['symptom_name'], r['organ_name'], r['origin'], r['function'], r['mechanism'], r['constituent']]
            .map((v) => (v ?? '').toString().toLowerCase()).toList();
        final matches = terms.any((term) => fields.any((field) => field.contains(term)));
        if (!matches) return false;
      }
      // Committed search terms  ALL must match (AND logic)
      for (final term in _searchTerms) {
        final q = term.toLowerCase();
        final matches =
          (r['name']             ?? '').toString().toLowerCase().contains(q) ||
          component.contains(q) ||
          (r['illness_name']     ?? '').toString().toLowerCase().contains(q) ||
          (r['category_name']    ?? '').toString().toLowerCase().contains(q) ||
          (r['sub_category_name']?? '').toString().toLowerCase().contains(q) ||
          (r['symptom_name']     ?? '').toString().toLowerCase().contains(q) ||
          (r['organ_name']       ?? '').toString().toLowerCase().contains(q) ||
          (r['origin']           ?? '').toString().toLowerCase().contains(q) ||
          (r['function']         ?? '').toString().toLowerCase().contains(q) ||
          (r['mechanism']        ?? '').toString().toLowerCase().contains(q) ||
          (r['constituent']      ?? '').toString().toLowerCase().contains(q);
        if (!matches) return false;
      }

      if (!_matchesMulti(r['type'], _selectedType)) return false;
      if (_selectedHerb.trim().isNotEmpty &&
          !_selectedHerb.split(RegExp(r'[,;]')).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty)
              .any((s) => component.contains(s))) return false;
      if (!_matchesMulti(r['organ_name'], _selectedOrgan)) return false;
      if (!_matchesMulti(r['origin'], _selectedCountry)) return false;
      if (_minValidation  > 0 && (r['validation_level']  ?? 0) < _minValidation) return false;
      if (_minTraditional > 0 && (r['tradition_rating']  ?? 0) < _minTraditional) return false;
      if (_minUserRating  > 0 && ((r['avg_user_rating']  ?? 0.0) as num) < _minUserRating) return false;
      if (_difficulty != 'All' && (r['difficulty'] ?? '').toString().toLowerCase() != _difficulty.toLowerCase()) return false;
      return true;
    }).toList()
      ..sort((a, b) => (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString()));
  }

  List<String> get _activeChips {
    final chips = <String>[];
    for (final t in _searchTerms) chips.add('Search: $t x');
    if (_searchQuery.isNotEmpty) chips.add('Search: $_searchQuery x');
    for (final v in _splitCsv(_selectedType))   chips.add('$v x');
    for (final v in _splitCsv(_selectedHerb))   chips.add('$v x');
    for (final v in _splitCsv(_selectedOrgan))  chips.add('$v x');
    for (final v in _splitCsv(_selectedCountry))chips.add('$v x');
    if (_minValidation  > 0) chips.add('Validation $_minValidation+ x');
    if (_minTraditional > 0) chips.add('Traditional $_minTraditional+ x');
    if (_minUserRating  > 0) chips.add('Rating $_minUserRating+ x');
    if (_difficulty != 'All') chips.add('$_difficulty x');
    return chips;
  }

  List<String> _splitCsv(String csv) => csv
      .split(RegExp(r'[,;]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  String _removeFromCsv(String csv, String item) =>
      _splitCsv(csv).where((e) => e != item).join(', ');

  void _removeChip(String chip) {
    if (!mounted) return;
    setState(() {
      if (chip.startsWith('Search: ')) {
        final term = chip.substring(4, chip.length - 3);
        if (_searchTerms.contains(term)) _searchTerms.remove(term);
        else { _searchQuery = ''; _searchController.clear(); }
        return;
      }
      if (chip.startsWith('Validation'))  { _minValidation = 0; return; }
      if (chip.startsWith('Traditional')) { _minTraditional = 0; return; }
      if (chip.startsWith('Rating'))      { _minUserRating = 0; return; }
      if (chip == '$_difficulty x')       { _difficulty = 'All'; return; }

      final item = chip.substring(0, chip.length - 2);
      if (_splitCsv(_selectedType).contains(item))    { _selectedType    = _removeFromCsv(_selectedType, item);    return; }
      if (_splitCsv(_selectedHerb).contains(item))    { _selectedHerb    = _removeFromCsv(_selectedHerb, item);    return; }
      if (_splitCsv(_selectedOrgan).contains(item))   { _selectedOrgan   = _removeFromCsv(_selectedOrgan, item);   return; }
      if (_splitCsv(_selectedCountry).contains(item)) { _selectedCountry = _removeFromCsv(_selectedCountry, item); return; }
    });
  }

  void _goToProduct(BuildContext context, Map<String, dynamic> remedy, bool isHerb) {
    final primaryHerb = remedy['primary_herb']?.toString().isNotEmpty == true ? remedy['primary_herb']!.toString() : remedy['component']?.toString() ?? '';
    final mainConstituent = remedy['main_constituent']?.toString().isNotEmpty == true ? remedy['main_constituent']!.toString() : remedy['constituent']?.toString() ?? '';
    final type = isHerb ? 'Components' : 'Remedies';
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ShopScreen(
        initialPrimaryHerb: primaryHerb,
        initialMainConstituent: mainConstituent,
        initialType: type,
      )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            YellowAppBar(
              title: 'Recipes',
              subtitle: '${_filtered.length} remedies - evidence-rated',
            ),
            if (_encouragement.isNotEmpty)
              EncouragementBanner(text: _encouragement),
            const SizedBox(height: 12),
            // Active filter chips from Category screen
            if (!_activeFilters.isEmpty)
              _ActiveFilterBar(
                filters: _activeFilters,
                onEdit: () async {
                  final result = await Navigator.of(context).push<FilterState>(
                    MaterialPageRoute(builder: (_) => CategoryScreen(initialFilters: _activeFilters)),
                  );
                  if (result != null && mounted) setState(() => _activeFilters = result);
                },
                onClear: () => setState(() => _activeFilters = const FilterState()),
                onRemoveTier: (tier) {
                  setState(() {
                    switch (tier) {
                      case 1: _activeFilters = _activeFilters.withoutBelow(0); break;
                      case 2: _activeFilters = _activeFilters.copyWith(clearSubcategory: true, clearIllness: true, clearSymptom: true); break;
                      case 3: _activeFilters = _activeFilters.copyWith(clearIllness: true, clearSymptom: true); break;
                      case 4: _activeFilters = _activeFilters.copyWith(clearSymptom: true); break;
                    }
                  });
                },
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (v) {
                        final term = v.trim();
                        if (term.isNotEmpty && !_searchTerms.contains(term)) {
                          setState(() {
                            _searchTerms.add(term);
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        } else {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        }
                      },
                      decoration: InputDecoration(
                        hintText: _searchTerms.isEmpty
                            ? 'Search remedies, press Enter to pin filter'
                            : 'Add another filter',
                        hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () => setState(() { _searchQuery = ''; _searchController.clear(); }),
                                child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary))
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (_activeChips.isEmpty && !_hasMatrixFilter)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 2),
                      child: Text(
                        'Type a keyword - press Enter to pin - tap chip to remove',
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
            // ── Cascading filter panel ──────────────────────────────────────
            if (_matrixRows.isNotEmpty)
              _CascadingFilterPanel(
                expanded: _filterExpanded,
                onToggle: () => setState(() => _filterExpanded = !_filterExpanded),
                selCategory:    _selCategory,
                selSubcategory: _selSubcategory,
                selIllness:     _selIllness,
                selSymptom:     _selSymptom,
                catOptions:     _catOptions,
                subOptions:     _subOptions,
                illnessOptions: _illnessOptions,
                symptomOptions: _symptomOptions,
                onCategoryChanged: (v) => setState(() {
                  _selCategory    = v;
                  _selSubcategory = null;
                  _selIllness     = null;
                  _selSymptom     = null;
                }),
                onSubChanged: (v) => setState(() {
                  _selSubcategory = v;
                  _selIllness     = null;
                  _selSymptom     = null;
                }),
                onIllnessChanged: (v) => setState(() {
                  _selIllness = v;
                  _selSymptom = null;
                }),
                onSymptomChanged: (v) => setState(() => _selSymptom = v),
                onClear: () => setState(() {
                  _selCategory = _selSubcategory = _selIllness = _selSymptom = null;
                }),
                matchCount: _filtered.length,
              ),
            // Active chips - always visible
            if (_activeChips.isNotEmpty) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: _activeChips.map((chip) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InputChip(
                      label: Text(
                        chip.endsWith(' x') ? chip.substring(0, chip.length - 2) : chip,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark),
                      ),
                      backgroundColor: AppColors.primary,
                      deleteIconColor: AppColors.dark,
                      side: BorderSide.none,
                      onDeleted: () => _removeChip(chip),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )).toList(),
                ),
              ),
            ],
            // Collapsible filter panel + recipe list in one scroll view
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : Stack(
                      children: [
                        RefreshIndicator(
                          onRefresh: _loadData,
                          color: AppColors.primary,
                          child: CustomScrollView(
                            controller: _scrollController,
                            slivers: [
                            const SliverToBoxAdapter(child: SizedBox(height: 12)),
                            // Results count - always shows total and filtered
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  _filtered.length == _allRemedies.length
                                      ? '${_allRemedies.length} ${_allRemedies.length == 1 ? 'remedy' : 'remedies'} available'
                                      : '${_filtered.length} of ${_allRemedies.length} ${_allRemedies.length == 1 ? 'remedy' : 'remedies'} found',
                                  style: AppTextStyles.caption,
                                ),
                              ),
                            ),
                            const SliverToBoxAdapter(child: SizedBox(height: 8)),
                            // Recipe list
                            if (_filtered.isEmpty)
                              SliverToBoxAdapter(
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(height: 40),
                                      const Text('No remedies match your filters', style: AppTextStyles.caption),
                                      const SizedBox(height: 12),
                                      TextButton.icon(
                                        onPressed: _loadData,
                                        icon: const Icon(Icons.refresh, size: 16),
                                        label: const Text('Refresh'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, i) {
                                      final remedy = _filtered[i];
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: _RemedyCardDB(
                                          remedy: remedy,
                                          onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => RecipeDetailScreenDB(remedy: remedy)),
                                          ).then((_) => _refreshRemediesOnly()),
                                          hasComponent: remedy['_has_component'] == true,
                                          hasRemedy:    remedy['_has_remedy'] == true,
                                          onBuyHerb:   () => _goToProduct(context, remedy, true),
                                          onBuyRemedy: () => _goToProduct(context, remedy, false),
                                        ),
                                      );
                                    },
                                    childCount: _filtered.length,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    // A-Z index slider
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 20,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#'.split('');
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: letters.map((letter) {
                              final hasMatch = _filtered.any((r) {
                                final name = (r['name'] ?? '').toString().toUpperCase();
                                if (letter == '#') return name.isNotEmpty && !RegExp(r'[A-Z]').hasMatch(name[0]);
                                return name.startsWith(letter);
                              });
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    final idx = _filtered.indexWhere((r) {
                                      final name = (r['name'] ?? '').toString().toUpperCase();
                                      if (letter == '#') return name.isNotEmpty && !RegExp(r'[A-Z]').hasMatch(name[0]);
                                      return name.startsWith(letter);
                                    });
                                    if (idx >= 0) {
                                      _scrollController.animateTo(
                                        idx * 180.0,
                                        duration: const Duration(milliseconds: 300),
                                        curve: Curves.easeOut,
                                      );
                                    }
                                  },
                                  child: Center(
                                    child: Text(
                                      letter,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: hasMatch ? AppColors.dark : Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
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


// ── Cascading Filter Panel ─────────────────────────────────────────────────
class _CascadingFilterPanel extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final String? selCategory;
  final String? selSubcategory;
  final String? selIllness;
  final String? selSymptom;
  final List<String> catOptions;
  final List<String> subOptions;
  final List<String> illnessOptions;
  final List<String> symptomOptions;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onSubChanged;
  final ValueChanged<String?> onIllnessChanged;
  final ValueChanged<String?> onSymptomChanged;
  final VoidCallback onClear;
  final int matchCount;

  const _CascadingFilterPanel({
    required this.expanded,
    required this.onToggle,
    required this.selCategory,
    required this.selSubcategory,
    required this.selIllness,
    required this.selSymptom,
    required this.catOptions,
    required this.subOptions,
    required this.illnessOptions,
    required this.symptomOptions,
    required this.onCategoryChanged,
    required this.onSubChanged,
    required this.onIllnessChanged,
    required this.onSymptomChanged,
    required this.onClear,
    required this.matchCount,
  });

  bool get _hasFilter =>
      selCategory != null || selSubcategory != null ||
      selIllness  != null || selSymptom     != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
      ),
      child: Column(
        children: [
          // Header row — always visible
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 16, color: AppColors.dark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _hasFilter
                        ? Wrap(
                            spacing: 4, runSpacing: 2,
                            children: [
                              if (selCategory    != null) _miniChip(selCategory!),
                              if (selSubcategory != null) _miniChip(selSubcategory!),
                              if (selIllness     != null) _miniChip(selIllness!),
                              if (selSymptom     != null) _miniChip(selSymptom!),
                            ],
                          )
                        : Text(
                            'Filter by category, illness or symptom',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                  ),
                  if (_hasFilter) ...[
                    Text(
                      '$matchCount found',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.dark),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onClear,
                      child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Icon(
                    expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18, color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // Expandable dropdown rows
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  _dropRow('Category', selCategory, catOptions, onCategoryChanged),
                  const SizedBox(height: 8),
                  _dropRow('Sub-category', selSubcategory, subOptions, onSubChanged),
                  const SizedBox(height: 8),
                  _dropRow('Illness', selIllness, illnessOptions, onIllnessChanged),
                  const SizedBox(height: 8),
                  _dropRow('Symptom', selSymptom, symptomOptions, onSymptomChanged),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.3),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.dark)),
  );

  Widget _dropRow(String label, String? value, List<String> options, ValueChanged<String?> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: value != null ? AppColors.primary.withOpacity(0.15) : AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: value != null ? AppColors.primary.withOpacity(0.5) : Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: Text(
                  options.isEmpty ? 'No options' : 'All',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                isDense: true,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: AppColors.textSecondary),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('All', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  ...options.map((o) => DropdownMenuItem<String>(
                    value: o,
                    child: Text(o, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// -- Tappable Star Filter Row ----------------------------------------------


class _RemedyCardDB extends StatelessWidget {
  final Map<String, dynamic> remedy;
  final VoidCallback onTap;
  final VoidCallback onBuyHerb;
  final VoidCallback onBuyRemedy;
  final bool hasComponent;
  final bool hasRemedy;

  const _RemedyCardDB({
    required this.remedy,
    required this.onTap,
    required this.onBuyHerb,
    required this.onBuyRemedy,
    this.hasComponent = false,
    this.hasRemedy = false,
  });

  Widget _buildRatingRow(String label, int stars, {bool showNumber = false, String number = ''}) {
    return Row(children: [
      SizedBox(width: 70, child: Text(label, style: AppTextStyles.label)),
      ...List.generate(5, (i) => Icon(
        i < stars ? Icons.star : Icons.star_border,
        size: 13,
        color: i < stars ? AppColors.starColor : Colors.grey.shade300,
      )),
      if (showNumber) ...[const SizedBox(width: 4), Text(number, style: AppTextStyles.caption)],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final name       = remedy['name'] ?? '';
    final component  = remedy['component'] ?? '';
    final origin     = remedy['origin'] ?? '';
    final category   = remedy['category_name'] ?? remedy['category'] ?? '';
    final tradition  = (remedy['tradition_rating'] ?? 0) as int;
    final validation = (remedy['validation_level'] ?? 1) as int;
    final rating     = ((remedy['avg_user_rating'] ?? 0.0) as num).toDouble();
    final votes      = (remedy['total_votes'] ?? 0) as int;
    final difficulty = remedy['difficulty'] ?? '';
    final imageUrl   = remedy['image_url'] ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name always on top - full width so long names wrap freely
            Text(name,
                style: AppTextStyles.heading3,
                softWrap: true),
            const SizedBox(height: 6),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left - description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$component${origin.isNotEmpty ? ' - $origin' : ''}', style: AppTextStyles.caption),
                        const SizedBox(height: 8),
                        _buildRatingRow('Traditional', tradition),
                        const SizedBox(height: 4),
                        _buildRatingRow('Validation', validation),
                        const SizedBox(height: 4),
                        _buildRatingRow('User rating', rating.round(),
                            showNumber: true, number: '${rating.toStringAsFixed(1)} - $votes votes'),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          TagBadge(label: 'Level $validation', color: AppColors.levelBadge),
                          if (difficulty.isNotEmpty)
                            TagBadge(label: difficulty, color: AppColors.lightGreen, textColor: Colors.green.shade700),
                          if (category.isNotEmpty)
                            TagBadge(
                              label: category,
                              color: category == 'Cancer' ? const Color(0xFFFFECB3) : AppColors.lightYellow,
                              textColor: category == 'Cancer' ? Colors.orange.shade800 : AppColors.dark,
                            ),
                          if ((remedy['efficacy'] ?? 0) > 0)
                            TagBadge(
                              label: '${remedy['efficacy']}% efficacy',
                              color: const Color(0xFFE8F5E9),
                              textColor: Color(0xFF2E7D32),
                            ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right - image stretches full height
                  RemedyImage(
                    url: imageUrl,
                    width: 120,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onBuyHerb,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: const BorderSide(color: AppColors.dark),
                  ),
                  child: Text('Buy Component',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.dark)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: onBuyRemedy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.dark,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Buy Remedy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// -- Rating Row ------------------------------------------------------------

class _RatingRow extends StatelessWidget {
  final String label;
  final int stars;
  final int max;
  final bool showNumber;
  final String number;

  const _RatingRow({
    required this.label,
    required this.stars,
    required this.max,
    this.showNumber = false,
    this.number = '',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: AppTextStyles.label)),
        ...List.generate(max, (i) => Icon(
          i < stars ? Icons.star : Icons.star_border,
          size: 13,
          color: i < stars ? AppColors.starColor : Colors.grey.shade300,
        )),
        if (showNumber) ...[
          const SizedBox(width: 4),
          Text(number, style: AppTextStyles.caption),
        ],
      ],
    );
  }
}












// - Active Filter Bar --------------------------------------------------------
class _ActiveFilterBar extends StatelessWidget {
  final FilterState filters;
  final VoidCallback onEdit;
  final VoidCallback onClear;
  final ValueChanged<int> onRemoveTier;

  const _ActiveFilterBar({
    required this.filters,
    required this.onEdit,
    required this.onClear,
    required this.onRemoveTier,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (filters.category != null)
                  _chip(filters.category!, () => onRemoveTier(1)),
                if (filters.subcategory != null)
                  _chip(filters.subcategory!, () => onRemoveTier(2)),
                if (filters.illness != null)
                  _chip(filters.illness!, () => onRemoveTier(3)),
                if (filters.symptom != null)
                  _chip(filters.symptom!, () => onRemoveTier(4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onEdit,
            child: const Text('Back to Find',
                style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close, size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onRemove) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.primary.withOpacity(0.4)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(fontSize: 10, color: AppColors.primary)),
      const SizedBox(width: 4),
      GestureDetector(
        onTap: onRemove,
        child: const Icon(Icons.close, size: 10, color: AppColors.primary),
      ),
    ]),
  );
}
