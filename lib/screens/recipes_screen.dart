import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import 'recipe_detail_screen.dart';
import 'shop_screen.dart';
import 'product_detail_screen.dart';
class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});

  // Static callback so other screens can trigger a reload
  static VoidCallback? _reloadCallback;
  static void reload() => _reloadCallback?.call();

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
  List<String> _searchTerms = [];    // committed search chips (AND logic)
  bool _filtersExpanded = false;
  bool _loading = true;
  String _encouragement = '';
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
    RecipesScreen._reloadCallback = _loadData;
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _pulseAnimation  = Tween<double>(begin: 0.0, end: 6.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _runPulse();
    _loadData();
    SupabaseService.getAppContent('home_encouragement').then((text) {
      if (mounted) setState(() => _encouragement = text);
    });
  }

  @override
  void dispose() {
    RecipesScreen._reloadCallback = null;
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runPulse() async {
    for (int i = 0; i < 2; i++) {
      if (!mounted) return;
      await _pulseController.forward();
      if (!mounted) return;
      await _pulseController.reverse();
    }
  }

  // Lightweight refresh — only reload remedies, keep filters/lookups cached
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

      // Live search field — filters as you type
      if (_searchQuery.isNotEmpty) {
        final terms = _searchQuery.split(RegExp(r'[;\s]+')).map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toList();
        final fields = [r['name'], component, r['illness_name'], r['category_name'], r['sub_category_name'], r['symptom_name'], r['organ_name'], r['origin'], r['function'], r['mechanism'], r['constituent']]
            .map((v) => (v ?? '').toString().toLowerCase()).toList();
        final matches = terms.any((term) => fields.any((field) => field.contains(term)));
        if (!matches) return false;
      }
      // Committed search terms — ALL must match (AND logic)
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
    for (final t in _searchTerms) chips.add('🔍 "$t" ×');
    if (_searchQuery.isNotEmpty) chips.add('🔍 "$_searchQuery" ×');
    // One chip per individually selected item — not per field
    for (final v in _splitCsv(_selectedType))        chips.add('$v ×');
    for (final v in _splitCsv(_selectedIllness))     chips.add('$v ×');
    for (final v in _splitCsv(_selectedHerb))        chips.add('$v ×');
    for (final v in _splitCsv(_selectedCategory))    chips.add('$v ×');
    for (final v in _splitCsv(_selectedSubCategory)) chips.add('$v ×');
    for (final v in _splitCsv(_selectedSymptom))     chips.add('$v ×');
    for (final v in _splitCsv(_selectedOrgan))       chips.add('$v ×');
    for (final v in _splitCsv(_selectedCountry))     chips.add('$v ×');
    if (_minValidation > 0) chips.add('Validation $_minValidation+ ×');
    if (_minTraditional > 0) chips.add('Traditional $_minTraditional+ ×');
    if (_minUserRating > 0) chips.add('Rating $_minUserRating+ ×');
    if (_difficulty != 'All') chips.add('$_difficulty ×');
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
      if (chip.startsWith('🔍 "') && chip.endsWith('" ×')) {
        final term = chip.substring(4, chip.length - 3);
        if (_searchTerms.contains(term)) _searchTerms.remove(term);
        else { _searchQuery = ''; _searchController.clear(); }
        return;
      }
      if (chip.startsWith('Validation'))  { _minValidation = 0; return; }
      if (chip.startsWith('Traditional')) { _minTraditional = 0; return; }
      if (chip.startsWith('Rating'))      { _minUserRating = 0; return; }
      if (chip == '$_difficulty ×')       { _difficulty = 'All'; return; }

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
            // Filter Remedies button (left) + Search bar (right)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filter Remedies button — pulsing glow, words stacked vertically
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return GestureDetector(
                        onTap: () {
                          if (!mounted) return;
                          setState(() => _filtersExpanded = !_filtersExpanded);
                          if (_pulseController.isAnimating) _pulseController.stop();
                        },
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: AppColors.dark,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: _filtersExpanded
                                ? [BoxShadow(color: AppColors.primary.withOpacity(0.8), blurRadius: 0, spreadRadius: 2)]
                                : [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.6),
                                      blurRadius: _pulseAnimation.value,
                                      spreadRadius: _pulseAnimation.value * 0.5,
                                    ),
                                  ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune, size: 16, color: AppColors.primary),
                              const SizedBox(width: 5),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _filtersExpanded ? 'Hide' : 'Filter',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary, height: 1.2),
                                  ),
                                  Text(
                                    _filtersExpanded ? 'Filters' : 'Remedies',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary, height: 1.2),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  // Search bar + guideline stacked on the right
                  Expanded(
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
                                  ? 'Search, press Enter to pin filter…'
                                  : 'Add another filter…',
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
                ],
              ),
            ),
            // Active chips — always visible
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
                        chip.endsWith(' ×') ? chip.substring(0, chip.length - 2) : chip,
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
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.primary,
                      child: CustomScrollView(
                        slivers: [
                          // Filter panel
                          if (_filtersExpanded)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                                child: _buildFilterRows(),
                              ),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 12)),
                          // Results count — always shows total and filtered
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

  Widget _buildFilterRows() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(
        children: [
          // Type
          MultiPickField(
            label: 'Type',
            value: _selectedType,
            options: const ['Medicinal', 'Lifestyle'],
            customHint: '',
            onChanged: (v) => setState(() => _selectedType = v),
            allowCustom: false,
          ),
          const Divider(height: 16),
          // Primary Component
          MultiPickField(
            label: 'Primary component',
            value: _selectedHerb,
            options: _herbs,
            customHint: '',
            onChanged: (v) => setState(() => _selectedHerb = v),
            allowCustom: false,
          ),
          const Divider(height: 16),
          // Illness
          MultiPickField(
            label: 'Illness',
            value: _selectedIllness,
            options: _illnesses,
            customHint: '',
            onChanged: (v) => setState(() => _selectedIllness = v),
            allowCustom: false,
          ),
          const Divider(height: 16),
          // Category
          MultiPickField(
            label: 'Category',
            value: _selectedCategory,
            options: _categories,
            customHint: '',
            onChanged: (v) => setState(() => _selectedCategory = v),
            allowCustom: false,
          ),
          const Divider(height: 16),
          // Sub-Category
          MultiPickField(
            label: 'Sub-category',
            value: _selectedSubCategory,
            options: _subCategories,
            customHint: '',
            onChanged: (v) => setState(() => _selectedSubCategory = v),
            allowCustom: false,
          ),
          const Divider(height: 16),
          // Symptoms
          MultiPickField(
            label: 'Symptoms',
            value: _selectedSymptom,
            options: _symptoms,
            customHint: '',
            onChanged: (v) => setState(() => _selectedSymptom = v),
            allowCustom: false,
          ),
          const Divider(height: 16),
          // Organ
          MultiPickField(
            label: 'Organ',
            value: _selectedOrgan,
            options: _organs,
            customHint: '',
            onChanged: (v) => setState(() => _selectedOrgan = v),
            allowCustom: false,
          ),
          const Divider(height: 16),
          // Country
          MultiPickField(
            label: 'Country of origin',
            value: _selectedCountry,
            options: _countries,
            customHint: '',
            onChanged: (v) => setState(() => _selectedCountry = v),
            allowCustom: false,
          ),
          const Divider(height: 16),
          _StarFilterRow(
            label: 'Traditional',
            value: _minTraditional,
            tooltip: 'Historical & cultural use',
            descriptions: const ['Any', 'Rarely used', 'Some tradition', 'Moderate use', 'Widely used', 'Deep-rooted tradition'],
            onChanged: (v) => setState(() => _minTraditional = v),
          ),
          const SizedBox(height: 10),
          _StarFilterRow(
            label: 'Validation',
            value: _minValidation,
            tooltip: 'Scientific evidence level',
            descriptions: const ['Any', 'Folk knowledge only', 'Anecdotal evidence', 'Small studies exist', 'Clinical studies', 'Strong peer-reviewed'],
            onChanged: (v) => setState(() => _minValidation = v),
          ),
          const SizedBox(height: 10),
          _StarFilterRow(
            label: 'User rating',
            value: _minUserRating,
            tooltip: 'Community rating',
            descriptions: const ['Any', '1+ stars', '2+ stars', '3+ stars', '4+ stars', '5 stars only'],
            onChanged: (v) => setState(() => _minUserRating = v),
          ),
          const Divider(height: 16),
          // Difficulty
          Row(
            children: [
              const SizedBox(width: 90, child: Text('Difficulty', style: AppTextStyles.caption)),
              ..._difficulties.map((d) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _difficulty = d),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _difficulty == d ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(d, style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _difficulty == d ? AppColors.dark : AppColors.textSecondary,
                    )),
                  ),
                ),
              )).toList(),
            ],
          ),
          const Divider(height: 16),
          // ── Count + Clear ─────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Text(
                  _filtered.length == _allRemedies.length
                      ? '${_allRemedies.length} remedies available'
                      : '${_filtered.length} of ${_allRemedies.length} remedies found',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.dark),
                ),
              ),
              if (_activeChips.isNotEmpty)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _selectedType        = '';
                    _selectedIllness     = '';
                    _selectedHerb        = '';
                    _selectedCategory    = '';
                    _selectedSubCategory = '';
                    _selectedSymptom     = '';
                    _selectedOrgan       = '';
                    _selectedCountry     = '';
                    _difficulty          = 'All';
                    _minValidation       = 0;
                    _minTraditional      = 0;
                    _minUserRating       = 0;
                    _searchTerms         = [];
                    _searchQuery         = '';
                    _searchController.clear();
                  }),
                  icon: const Icon(Icons.clear_all, size: 16, color: AppColors.dark),
                  label: const Text('Clear all',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark)),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: Size.zero,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tappable Star Filter Row ──────────────────────────────────────────────

class _StarFilterRow extends StatelessWidget {
  final String label;
  final int value;
  final String tooltip;
  final List<String> descriptions;
  final Function(int) onChanged;

  const _StarFilterRow({
    required this.label,
    required this.value,
    required this.tooltip,
    required this.descriptions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 90,
              child: Row(children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(width: 4),
                Tooltip(message: tooltip, child: const Icon(Icons.info_outline, size: 12, color: AppColors.textSecondary)),
              ]),
            ),
            ...List.generate(5, (i) => GestureDetector(
              onTap: () => onChanged(value == i + 1 ? 0 : i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  i < value ? Icons.star : Icons.star_border,
                  size: 22,
                  color: i < value ? AppColors.starColor : Colors.grey.shade300,
                ),
              ),
            )),
            const SizedBox(width: 8),
            Text(
              value == 0 ? 'Any' : '$value+',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: value > 0 ? AppColors.dark : AppColors.textSecondary),
            ),
          ],
        ),
        if (value > 0)
          Padding(
            padding: const EdgeInsets.only(left: 90, top: 2),
            child: Text(descriptions[value],
                style: const TextStyle(fontSize: 11, color: AppColors.primary, fontStyle: FontStyle.italic)),
          ),
      ],
    );
  }
}

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
            // Name always on top — full width so long names wrap freely
            Text(name,
                style: AppTextStyles.heading3,
                softWrap: true),
            const SizedBox(height: 6),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left — description
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
                  // Right — image stretches full height
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

// ── Rating Row ────────────────────────────────────────────────────────────

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










