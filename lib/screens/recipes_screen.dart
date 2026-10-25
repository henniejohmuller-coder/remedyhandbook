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
  String _selectedCategory    = '';
  String _selectedType        = '';
  String _selectedIllness     = '';
  String _selectedSubCategory = '';
  String _selectedSymptom     = '';
  String _selectedOrgan       = '';
  String _selectedCountry     = '';
  String _selectedHerb        = '';
  int _minValidation = 0;
  int _minTraditional = 0;
  int _minUserRating = 0;
  String _difficulty = 'All';
  String _searchQuery = '';          // live text in the search field
  final ScrollController _scrollController = ScrollController();
  List<String> _searchTerms = [];    // committed search chips (AND logic)
  FilterState _activeFilters = const FilterState();
  bool _loading = true;
  String _encouragement = '';
  final TextEditingController _searchController = TextEditingController();

  // Data from Supabase
  List<Map<String, dynamic>> _allRemedies = [];
  Map<String, Set<String>> _remedyProductIds = {};
  List<String> _categories    = ['All'];
  List<String> _illnesses     = ['All'];
  List<String> _subCategories = ['All'];
  List<String> _symptoms      = ['All'];
  List<String> _organs        = ['All'];
  List<String> _countries     = ['All'];
  List<String> _herbs         = ['All'];
  List<String> _difficulties  = ['All'];

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

  // Lightweight refresh â”€â€ only reload remedies, keep filters/lookups cached
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
      final results = await Future.wait<dynamic>([
        SupabaseService.getRemedies(),
        SupabaseService.getCategories(),
        SupabaseService.getSubCategories(),
        SupabaseService.getSymptoms(),
        SupabaseService.getOrgans(),
        SupabaseService.getComponents(),
        SupabaseService.getProducts(),
        SupabaseService.getIllnesses(),
        SupabaseService.getDifficulties(),
        SupabaseService.getCountries(),
        SupabaseService.supabase.from('remedy_products').select('remedy_id, product_id'),
      ]);

      final products = results[6] as List<Map<String, dynamic>>;
      final rpList = results[10] as List;
      _remedyProductIds = {};
      for (final rp in rpList) {
        final rid = rp['remedy_id']?.toString() ?? '';
        final pid = rp['product_id']?.toString() ?? '';
        _remedyProductIds.putIfAbsent(rid, () => <String>{}).add(pid);
      }

      if (!mounted) return;
      setState(() {
        _allRemedies  = (results[0] as List<Map<String, dynamic>>).map((r) => {
          ...r,
          '_has_component': products.any((p) => (p['linked_remedy_id']?.toString() == r['id']?.toString() || _remedyProductIds[r['id']?.toString()]?.contains(p['id']?.toString()) == true) && p['type'] == 'Component'),
          '_has_remedy':    products.any((p) => (p['linked_remedy_id']?.toString() == r['id']?.toString() || _remedyProductIds[r['id']?.toString()]?.contains(p['id']?.toString()) == true) && p['type'] == 'Remedy'),
        }).toList();
        void sortList(List<String> list) {
          final all = list.removeAt(0); // remove 'All'
          list.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
          list.insert(0, all); // put 'All' back at top
        }
        _categories      = ['All', ...(results[1] as List<String>).toSet()];
        _subCategories   = ['All', ...(results[2] as List<String>).toSet()];
        _symptoms        = ['All', ...(results[3] as List<String>).toSet()];
        _organs          = ['All', ...(results[4] as List<String>).toSet()];
        _herbs           = ['All', ...(results[5] as List<String>).toSet()];
        _illnesses       = ['All', ...(results[7] as List<String>).toSet()];
        _difficulties    = ['All', ...(results[8] as List<String>).toSet()];
        _countries       = ['All', ...(results[9] as List<String>).toSet()];
        for (final list in [_categories, _subCategories, _symptoms, _organs, _herbs, _illnesses, _countries]) {
          sortList(list);
        }
        final components = _allRemedies.map((r) => r['component'] as String? ?? '').toSet().where((c) => c.isNotEmpty).toList()..sort();
        for (final c in components) {
          if (!_herbs.contains(c)) _herbs.add(c);
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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

      // â”€â”€ Filter matrix filters from Category screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

      // Live search field â€” filters as you type
      if (_searchQuery.isNotEmpty) {
        final terms = _searchQuery.split(RegExp(r'[;\s]+')).map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toList();
        final fields = [r['name'], component, r['illness_name'], r['category_name'], r['sub_category_name'], r['symptom_name'], r['organ_name'], r['origin'], r['function'], r['mechanism'], r['constituent']]
            .map((v) => (v ?? '').toString().toLowerCase()).toList();
        final matches = terms.any((term) => fields.any((field) => field.contains(term)));
        if (!matches) return false;
      }
      // Committed search terms â€” ALL must match (AND logic)
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
      if (!_matchesMulti(r['illness_name'] ?? r['illness_display'], _selectedIllness)) return false;
      if (_selectedHerb.trim().isNotEmpty &&
          !_selectedHerb.split(RegExp(r'[,;]')).map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty)
              .any((s) => component.contains(s))) return false;
      if (!_matchesMulti(r['category_name'] ?? category, _selectedCategory)) return false;
      if (!_matchesMulti(r['sub_category_name'] ?? r['sub_category_display'], _selectedSubCategory)) return false;
      if (!_matchesMulti(r['symptom_name'], _selectedSymptom)) return false;
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
    // One chip per individually selected item â”€â€ not per field
    for (final v in _splitCsv(_selectedType))        chips.add('$v x');
    for (final v in _splitCsv(_selectedIllness))     chips.add('$v x');
    for (final v in _splitCsv(_selectedHerb))        chips.add('$v x');
    for (final v in _splitCsv(_selectedCategory))    chips.add('$v x');
    for (final v in _splitCsv(_selectedSubCategory)) chips.add('$v x');
    for (final v in _splitCsv(_selectedSymptom))     chips.add('$v x');
    for (final v in _splitCsv(_selectedOrgan))       chips.add('$v x');
    for (final v in _splitCsv(_selectedCountry))     chips.add('$v x');
    if (_minValidation > 0) chips.add('Validation $_minValidation+ x');
    if (_minTraditional > 0) chips.add('Traditional $_minTraditional+ x');
    if (_minUserRating > 0) chips.add('Rating $_minUserRating+ x');
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
      if (chip.startsWith('ðÅ¸â€ â”€') && chip.endsWith('â”€ x')) {
        final term = chip.substring(4, chip.length - 3);
        if (_searchTerms.contains(term)) _searchTerms.remove(term);
        else { _searchQuery = ''; _searchController.clear(); }
        return;
      }
      if (chip.startsWith('Validation'))  { _minValidation = 0; return; }
      if (chip.startsWith('Traditional')) { _minTraditional = 0; return; }
      if (chip.startsWith('Rating'))      { _minUserRating = 0; return; }
      if (chip == '$_difficulty x')       { _difficulty = 'All'; return; }

      // Strip trailing ' ×' to get the raw item text, then remove it from
      // whichever multi-select field currently contains it.
      final item = chip.substring(0, chip.length - 2);
      if (_splitCsv(_selectedType).contains(item))        { _selectedType        = _removeFromCsv(_selectedType, item);        return; }
      if (_splitCsv(_selectedIllness).contains(item))     { _selectedIllness     = _removeFromCsv(_selectedIllness, item);     return; }
      if (_splitCsv(_selectedHerb).contains(item))        { _selectedHerb        = _removeFromCsv(_selectedHerb, item);        return; }
      if (_splitCsv(_selectedCategory).contains(item))    { _selectedCategory    = _removeFromCsv(_selectedCategory, item);    return; }
      if (_splitCsv(_selectedSubCategory).contains(item)) { _selectedSubCategory = _removeFromCsv(_selectedSubCategory, item); return; }
      if (_splitCsv(_selectedSymptom).contains(item))     { _selectedSymptom     = _removeFromCsv(_selectedSymptom, item);     return; }
      if (_splitCsv(_selectedOrgan).contains(item))       { _selectedOrgan       = _removeFromCsv(_selectedOrgan, item);       return; }
      if (_splitCsv(_selectedCountry).contains(item))     { _selectedCountry     = _removeFromCsv(_selectedCountry, item);     return; }
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
              subtitle: '${_filtered.length} remedies · evidence-rated',
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
                            ? 'Search, press Enter to pin filterâ€¦'
                            : 'Add another filterâ€¦',
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
                  if (_activeChips.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 2),
                      child: Text(
                        'Type a keyword · press Enter to pin · tap chip to remove',
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
            // Active chips â”€â€ always visible
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
                            // Results count â”€â€ always shows total and filtered
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

  Widget _buildDropdownRow(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: AppTextStyles.caption)),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isDense: true,
                isExpanded: true,
                items: items.map((i) => DropdownMenuItem(
                  value: i,
                  child: Text(i, style: AppTextStyles.body, overflow: TextOverflow.ellipsis),
                )).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }

}

// â”€â€â”€â€â”€ Tappable Star Filter Row â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€


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
            // Name always on top â”€â€ full width so long names wrap freely
            Text(name,
                style: AppTextStyles.heading3,
                softWrap: true),
            const SizedBox(height: 6),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left â”€â€ description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$component${origin.isNotEmpty ? ' · $origin' : ''}', style: AppTextStyles.caption),
                        const SizedBox(height: 8),
                        _buildRatingRow('Traditional', tradition),
                        const SizedBox(height: 4),
                        _buildRatingRow('Validation', validation),
                        const SizedBox(height: 4),
                        _buildRatingRow('User rating', rating.round(),
                            showNumber: true, number: '${rating.toStringAsFixed(1)} · $votes votes'),
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
                  // Right â”€â€ image stretches full height
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

// â”€â€â”€â€â”€ Rating Row â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€â€â”€

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












// â”€â”€ Active Filter Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
            child: const Text('Edit',
                style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
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
