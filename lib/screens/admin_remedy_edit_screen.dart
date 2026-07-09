import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/image_search.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import 'recipes_screen.dart';
import 'shop_screen.dart';

class AdminRemedyEditScreen extends StatefulWidget {
  final Map<String, dynamic> remedy;
  final VoidCallback onSaved;
  const AdminRemedyEditScreen({super.key, required this.remedy, required this.onSaved});

  @override
  State<AdminRemedyEditScreen> createState() => _AdminRemedyEditScreenState();
}

class _AdminRemedyEditScreenState extends State<AdminRemedyEditScreen> {
  final _imageUrlController = TextEditingController();
  final _encouragementController = TextEditingController();
  final _customComponentController = TextEditingController();
  final _customIllnessController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _customSubCategoryController = TextEditingController();
  final _customSymptomController = TextEditingController();
  final _customOrganController = TextEditingController();
  final _customCountryController = TextEditingController();
  final _customPlantPartController = TextEditingController();
  final _customPrepTypeController = TextEditingController();

  // Named text field controllers
  final _recipeNameController      = TextEditingController();
  final _ingredientsController     = TextEditingController();
  final _remedyFunctionController  = TextEditingController();
  final _mechanismController       = TextEditingController();
  final _constituentController     = TextEditingController();
  final _cautionsController        = TextEditingController();
  final _clinicalUrlController     = TextEditingController();
  final _efficacyRefController     = TextEditingController();
  final _prepTimeController        = TextEditingController();
  final _difficultyController      = TextEditingController();

  bool _loading = false;
  bool _submitted = false;
  bool _instructionsLoaded = false;
  String _status = 'approved';
  List<Map<String, dynamic>> _linkedProducts = [];
  bool _savingShopItems = false;
  int _traditionRating = 0;
  int _validationLevel = 1;
  int _efficacy        = 0;

  // Kept for backward compat (populate from existing data)
  final _compNameController  = TextEditingController();
  final _compDescController  = TextEditingController();
  final _compPriceController = TextEditingController();
  final _compImageController = TextEditingController();
  final _remNameController   = TextEditingController();
  final _remDescController   = TextEditingController();
  final _remPriceController  = TextEditingController();
  final _remImageController  = TextEditingController();

  String _previewUrl = '';
  bool _urlError = false;
  String _selectedComponent = '';
  bool _showCustomComponent = false;
  String _selectedType    = '';
  String _selectedIllness = '';
  bool _showCustomIllness = false;
  String? _confirmedCustomIllness;
  String _selectedCategory = '';
  bool _showCustomCategory = false;
  String? _confirmedCustomCategory;
  String _selectedSubCategory = '';
  bool _showCustomSubCategory = false;
  String? _confirmedCustomSubCategory;
  String _selectedSymptom = '';
  bool _showCustomSymptom = false;
  String? _confirmedCustomSymptom;
  String _selectedOrgan = '';
  bool _showCustomOrgan = false;
  String? _confirmedCustomOrgan;
  String _selectedCountry = '';
  bool _showCustomCountry = false;
  String? _confirmedCustomCountry;
  String? _confirmedCustomComponent;
  String _selectedPlantPart = '';
  bool _showCustomPlantPart = false;
  String _selectedPrepType = '';
  bool _showCustomPrepType = false;

  // Dynamic lookup lists loaded from DB
  List<String> _illnessList     = ['Select illness'];
  List<String> _categoryList    = ['Select category'];
  List<String> _subCategoryList = ['Select sub-category'];
  List<String> _symptomList     = ['Select symptom'];
  List<String> _organList       = ['Select organ'];
  List<String> _countryList     = ['Select country'];
  List<String> _componentList        = ['Select component'];
  List<String> _plantPartList   = ['Select'];
  List<String> _prepTypeList    = ['Select'];
  List<String> _difficultyList  = ['Easy','Medium','Hard'];
  bool _lookupsLoaded = false;

  // Auto-numbered instruction steps
  final List<TextEditingController> _stepControllers = [];

  @override
  void initState() {
    super.initState();
    _populateFromRemedy();
    _loadLookups();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInstructionsOnce());
  }

    // Splits any combined values (e.g. "Cancer, Diabetes") into atomic,
  // deduplicated, alphabetically-sorted items. Used when building picklists
  // directly from raw Supabase rows (legacy CSV-imported lookup rows may
  // contain several values crammed into a single row).
  List<String> _flattenValues(List rows, String key) {
    final flat = <String>{};
    for (final e in rows) {
      final raw = (e[key]?.toString()) ?? '';
      flat.addAll(raw.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty));
    }
    final list = flat.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  Future<void> _loadLookups() async {
    try {
      final results = await Future.wait([
        SupabaseService.supabase.from('illnesses').select('name').eq('active', true).order('name', ascending: true),
        SupabaseService.supabase.from('categories').select('name').eq('active', true).order('name', ascending: true),
        SupabaseService.supabase.from('sub_categories').select('name').eq('active', true).order('name', ascending: true),
        SupabaseService.supabase.from('symptoms').select('name').eq('active', true).order('name', ascending: true),
        SupabaseService.supabase.from('organs').select('name').eq('active', true).order('name', ascending: true),
        SupabaseService.supabase.from('countries').select('name').eq('active', true).order('name', ascending: true),
        SupabaseService.supabase.from('components').select('common_name').eq('active', true).order('common_name', ascending: true),
        SupabaseService.supabase.from('plant_parts').select('name').eq('active', true).order('name', ascending: true),
        SupabaseService.supabase.from('prep_types').select('name').eq('active', true).order('name', ascending: true),
        SupabaseService.supabase.from('difficulties').select('name').eq('active', true).order('name', ascending: true),
      ]);
      if (mounted) setState(() {
        _illnessList     = ['Select illness',     ..._flattenValues(results[0] as List, 'name'),     'Not in list — enter manually'];
        _categoryList    = ['Select category',    ..._flattenValues(results[1] as List, 'name'),    'Not in list — enter manually'];
        _subCategoryList = ['Select sub-category',..._flattenValues(results[2] as List, 'name'), 'Not in list — enter manually'];
        _symptomList     = ['Select symptom',     ..._flattenValues(results[3] as List, 'name'),     'Not in list — enter manually'];
        _organList       = ['Select organ',       ..._flattenValues(results[4] as List, 'name'),       'Not in list — enter manually'];
        _countryList     = ['Select country',     ..._flattenValues(results[5] as List, 'name'),     'Not in list — enter manually'];
        _componentList        = ['Select component',   ..._flattenValues(results[6] as List, 'common_name'), 'Not in list — enter manually'];
        if ((results[7] as List).isNotEmpty) _plantPartList = _flattenValues(results[7] as List, 'name');
        if ((results[8] as List).isNotEmpty) _prepTypeList  = _flattenValues(results[8] as List, 'name');
        if ((results[9] as List).isNotEmpty) _difficultyList = _flattenValues(results[9] as List, 'name');
        _lookupsLoaded   = true;
      });
    } catch (e) {
      print('Lookup load error: $e');
    }
  }

  Future<void> _loadInstructionsOnce() async {
    if (_instructionsLoaded) return;
    _instructionsLoaded = true;
    final r = widget.remedy;
    final remedyId = r['id'];
    final isSubmission = r['_is_submission'] == true;

    if (!isSubmission && remedyId != null) {
      try {
        final data = await SupabaseService.supabase
            .from('remedy_instructions')
            .select()
            .eq('remedy_id', remedyId)
            .order('step_number', ascending: true);
        final steps = (data as List).cast<Map<String, dynamic>>();
        if (mounted) {
          for (final c in _stepControllers) { c.dispose(); }
          _stepControllers.clear();
          if (steps.isNotEmpty) {
            for (final step in steps) {
              _stepControllers.add(TextEditingController(text: step['instruction'] ?? ''));
            }
          } else {
            _stepControllers.add(TextEditingController());
          }
          setState(() {});
        }
      } catch (_) {
        if (_stepControllers.isEmpty) {
          _stepControllers.add(TextEditingController());
          if (mounted) setState(() {});
        }
      }
    } else {
      // Submission — use instructions field (JSON array saved in submissions)
      final raw = r['instructions'] as List? ?? r['remedy_instructions'] as List?;
      for (final c in _stepControllers) { c.dispose(); }
      _stepControllers.clear();
      if (raw != null && raw.isNotEmpty) {
        final sorted = List.from(raw)..sort((a, b) =>
            ((a['step_number'] ?? 0) as int).compareTo((b['step_number'] ?? 0) as int));
        for (final step in sorted) {
          _stepControllers.add(TextEditingController(
              text: step['instruction'] ?? step['text'] ?? ''));
        }
      } else {
        _stepControllers.add(TextEditingController());
      }
      if (mounted) setState(() {});
    }
  }

  void _populateFromRemedy() {
    final r = widget.remedy;
    _status = r['status'] ?? 'approved';
    _traditionRating = (r['tradition_rating'] ?? 0) as int;
    _validationLevel = (r['validation_level'] ?? 1) as int;
    _efficacy        = (r['efficacy'] ?? 0) as int;
    _efficacyRefController.text     = r['efficacy_ref']?.toString() ?? '';
    _recipeNameController.text   = r['name'] ?? '';
    _ingredientsController.text  = r['ingredients'] ?? '';
    _remedyFunctionController.text = r['function'] ?? '';
    _mechanismController.text    = r['mechanism'] ?? '';
    _constituentController.text  = r['constituent'] ?? '';
    _cautionsController.text     = r['cautions'] ?? '';
    // Normalise to one URL per line — handles both CSV (comma-separated)
    // and DB (newline-separated) formats on load.
    _clinicalUrlController.text  = _normaliseUrls(r['clinical_study_url'] ?? '');
    _prepTimeController.text     = formatPrepTime(r['prep_time']);
    _previewUrl                  = r['image_url'] ?? '';
    _imageUrlController.text     = _previewUrl;
    _encouragementController.text = r['encouragement'] ?? '';

    // Multi-select fields — load raw CSV value directly.
    // MultiPickField parses/splits it; no need to match against the option list.
    _selectedType        = r['type']?.toString() ?? '';
    _selectedComponent   = r['component']?.toString() ?? '';
    _selectedIllness     = r['illness_name']?.toString() ?? '';
    _selectedCategory    = r['category_name']?.toString() ?? '';
    _selectedSubCategory = r['sub_category_name']?.toString() ?? '';
    _selectedSymptom     = r['symptom_name']?.toString() ?? '';
    _selectedOrgan       = r['organ_name']?.toString() ?? '';
    _selectedCountry     = r['origin']?.toString() ?? '';
    _selectedPlantPart   = r['plant_part']?.toString() ?? '';
    _selectedPrepType    = r['prep_type']?.toString() ?? '';

    // Load linked products
    final remedyIdForProducts = r['id'];
    if (remedyIdForProducts != null) {
      SupabaseService.supabase.from('products')
          .select().eq('linked_remedy_id', remedyIdForProducts)
          .then((data) {
        if (mounted) setState(() => _linkedProducts = (data as List).cast<Map<String, dynamic>>());
      });
    }
  }

  void _openProductPicker({required String type}) async {
    // Fetch ALL products of this type — not filtered by linked_remedy_id,
    // so all 3 slots can be selected regardless of prior linking.
    final data = await SupabaseService.supabase
        .from('products')
        .select()
        .eq('type', type)
        .order('name', ascending: true);
    final filtered = (data as List).cast<Map<String, dynamic>>();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductPickerSheet(
        products: filtered,
        linkedIds: _linkedProducts.map((p) => p['id'].toString()).toList(),
        onSelect: (product) async {
          Navigator.pop(context);
          await SupabaseService.supabase.from('products')
              .update({'linked_remedy_id': widget.remedy['id']}).eq('id', product['id']);
          ShopScreen.reload();
          final updated = await SupabaseService.supabase.from('products')
              .select().eq('linked_remedy_id', widget.remedy['id']);
          setState(() => _linkedProducts = (updated as List).cast<Map<String, dynamic>>());
        },
      ),
    );
  }

  Future<void> _unlinkProduct(String productId) async {
    await SupabaseService.supabase.from('products')
        .update({'linked_remedy_id': null}).eq('id', productId);
    ShopScreen.reload();
    setState(() => _linkedProducts.removeWhere((p) => p['id'].toString() == productId));
  }

  // ── URL normaliser ────────────────────────────────────────────────────────
  // Accepts URLs separated by commas, semicolons, or newlines and returns
  // them one per line, ready for the multi-line clinical URL field.
  String _normaliseUrls(String raw) {
    if (raw.trim().isEmpty) return '';
    // Split on comma or semicolon that sits between two URLs
    // (i.e. followed by http, ignoring whitespace)
    final parts = raw
        .split(RegExp(r'[,;\n]+'))
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .toList();
    return parts.join('\n');
  }

  Widget _buildRatingSlider(String title, String subtitle, int value, int max,
      Color color, ValueChanged<int> onChanged, {bool isPercent = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.heading3),
          Text(subtitle, style: AppTextStyles.caption),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: Text(isPercent ? '$value%' : '$value / $max',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.dark)),
        ),
      ]),
      Slider(
        value: value.toDouble(), min: 0, max: max.toDouble(),
        divisions: max, activeColor: AppColors.primary,
        inactiveColor: Colors.grey.shade200,
        onChanged: (v) => onChanged(v.round()),
      ),
      if (!isPercent)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(max + 1, (i) => Text('$i',
                style: TextStyle(fontSize: 11,
                    color: i == value ? AppColors.dark : AppColors.textSecondary,
                    fontWeight: i == value ? FontWeight.bold : FontWeight.normal)))),
    ]);
  }

  void _addStep() {
    setState(() => _stepControllers.add(TextEditingController()));
  }

  void _removeStep(int index) {
    if (_stepControllers.length > 1) {
      setState(() {
        _stepControllers[index].dispose();
        _stepControllers.removeAt(index);
      });
    }
  }

  void _onUrlChanged(String val) {
    setState(() {
      _previewUrl = val.trim();
      _urlError = false;
    });
  }

  void _onImageError() {
    setState(() => _urlError = true);
  }

  @override
  void dispose() {
    _encouragementController.dispose();
    _imageUrlController.dispose();
    _customComponentController.dispose();
    _customIllnessController.dispose();
    _customCategoryController.dispose();
    _customSubCategoryController.dispose();
    _customSymptomController.dispose();
    _customOrganController.dispose();
    _customCountryController.dispose();
    _customPlantPartController.dispose();
    _customPrepTypeController.dispose();
    _recipeNameController.dispose();
    _ingredientsController.dispose();
    _remedyFunctionController.dispose();
    _mechanismController.dispose();
    _constituentController.dispose();
    _cautionsController.dispose();
    _clinicalUrlController.dispose();
    _efficacyRefController.dispose();
    _prepTimeController.dispose();
    _difficultyController.dispose();
    for (final c in _stepControllers) c.dispose();
    _compNameController.dispose();
    _compDescController.dispose();
    _compPriceController.dispose();
    _compImageController.dispose();
    _remNameController.dispose();
    _remDescController.dispose();
    _remPriceController.dispose();
    _remImageController.dispose();
    super.dispose();
  }

  // ── Submit to Supabase ────────────────────────────────────────
  Future<void> _saveShopItems() async {
    final remedyId = widget.remedy['id'];
    setState(() => _savingShopItems = true);
    try {
      // Component product
      if (_compNameController.text.isNotEmpty && _compPriceController.text.isNotEmpty) {
        // Check if product already exists for this remedy + type
        final existing = await SupabaseService.supabase.from('products')
            .select().eq('linked_remedy_id', remedyId).eq('type', 'Component');
        final data = {
          'name':             _compNameController.text.trim(),
          'type':             'Component',
          'description':      _compDescController.text.trim(),
          'price':            double.tryParse(_compPriceController.text) ?? 0,
          'image_url':        _compImageController.text.trim(),
          'linked_remedy_id': remedyId,
          'active':           true,
        };
        if ((existing as List).isNotEmpty) {
          await SupabaseService.supabase.from('products').update(data).eq('id', existing.first['id']);
        } else {
          await SupabaseService.supabase.from('products').insert(data);
        }
      }

      // Remedy product
      if (_remNameController.text.isNotEmpty && _remPriceController.text.isNotEmpty) {
        final existing = await SupabaseService.supabase.from('products')
            .select().eq('linked_remedy_id', remedyId).eq('type', 'Remedy');
        final data = {
          'name':             _remNameController.text.trim(),
          'type':             'Remedy',
          'description':      _remDescController.text.trim(),
          'price':            double.tryParse(_remPriceController.text) ?? 0,
          'image_url':        _remImageController.text.trim(),
          'linked_remedy_id': remedyId,
          'active':           true,
        };
        if ((existing as List).isNotEmpty) {
          await SupabaseService.supabase.from('products').update(data).eq('id', existing.first['id']);
        } else {
          await SupabaseService.supabase.from('products').insert(data);
        }
      }

      setState(() => _savingShopItems = false);
      ShopScreen.reload();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Shop items saved!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      setState(() => _savingShopItems = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Widget _statusBtn(String value, String label, Color color) {
    final isSelected = _status == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _status = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.black26 : Colors.grey.shade200,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : [],
          ),
          child: Column(children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 16,
              color: isSelected ? AppColors.dark : Colors.grey.shade400,
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w400,
              color: isSelected ? AppColors.dark : AppColors.textSecondary,
            )),
          ]),
        ),
      ),
    );
  }

  /// Inserts any manually-entered lookup values into their respective tables
  /// so they appear in future dropdowns for all users.
  Future<void> _upsertCustomLookups() async {
    final db = SupabaseService.supabase;

    // Multi-select fields can now hold several comma-separated values.
    // Insert any value not already in the lookup table — _safeInsertLookup
    // is a no-op for values that already exist, so this is always safe.
    Future<void> insertAll(String table, String col, String csv) async {
      for (final v in csv.split(RegExp(r'[,;]')).map((e) => e.trim()).where((e) => e.isNotEmpty)) {
        await _safeInsertLookup(db, table, col, v);
      }
    }

    await insertAll('illnesses',      'name',        _selectedIllness);
    await insertAll('categories',     'name',        _selectedCategory);
    await insertAll('sub_categories', 'name',        _selectedSubCategory);
    await insertAll('symptoms',       'name',        _selectedSymptom);
    await insertAll('organs',         'name',        _selectedOrgan);
    await insertAll('countries',      'name',        _selectedCountry);
    await insertAll('components',     'common_name', _selectedComponent);
    await insertAll('plant_parts',    'name',        _selectedPlantPart);
    await insertAll('prep_types',     'name',        _selectedPrepType);

    // Reload lists so new entries appear in dropdowns immediately
    await _loadLookups();
  }

  // Inserts a custom lookup value only if it does not already exist.
  // Avoids on_conflict=name which requires a DB unique index.
  Future<void> _safeInsertLookup(
      dynamic db, String table, String col, String? val) async {
    if (val == null || val.trim().isEmpty) return;
    try {
      final existing = await db
          .from(table)
          .select('id')
          .eq(col, val.trim())
          .maybeSingle();
      if (existing == null) {
        await db.from(table).insert({col: val.trim(), 'active': true});
      }
    } catch (e) {
      // Non-critical — lookup tables are supplementary; save still proceeds.
      debugPrint('Lookup insert skipped ($table.$col): $e');
    }
  }

  Future<void> _submitRemedy() async {
    if (_recipeNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a recipe name'), backgroundColor: Colors.red),
      );
      return;
    }
    // Get component — comma-separated multi-select value
    final component = _selectedComponent.trim();
    if (component.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a primary component'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // Build instructions matching remedy_instructions table columns
      final instructions = _stepControllers
          .asMap()
          .entries
          .where((e) => e.value.text.trim().isNotEmpty)
          .map((e) => {
            'step_number': e.key + 1,
            'instruction': e.value.text.trim(),
          })
          .toList()
          ..sort((a, b) => (a['step_number'] as int).compareTo(b['step_number'] as int));

      final remedyId = widget.remedy['id'];
      final isSubmission = widget.remedy['_is_submission'] == true;

      // Upsert any custom lookup values so they appear in future dropdowns
      await _upsertCustomLookups();

      if (isSubmission) {
        // Save back to remedy_submissions table
        await SupabaseService.supabase.from('remedy_submissions').update({
          'recipe_name':       _recipeNameController.text.trim(),
          'primary_component': component,
          'illness':           (_selectedIllness.isEmpty ? null : _selectedIllness),
          'category':          (_selectedCategory.isEmpty ? null : _selectedCategory),
          'sub_category':      (_selectedSubCategory.isEmpty ? null : _selectedSubCategory),
          'symptoms':          (_selectedSymptom.isEmpty ? null : _selectedSymptom),
          'organ':             (_selectedOrgan.isEmpty ? null : _selectedOrgan),
          'country':           (_selectedCountry.isEmpty ? null : _selectedCountry),
          'ingredients':       _ingredientsController.text.trim(),
          'plant_part':        (_selectedPlantPart.isEmpty ? null : _selectedPlantPart),
          'prep_type':         (_selectedPrepType.isEmpty ? null : _selectedPrepType),
          'difficulty':        _difficultyController.text.isEmpty ? null : _difficultyController.text,
          'prep_time':         int.tryParse(_prepTimeController.text.trim()),
          'remedy_function':   _remedyFunctionController.text.trim(),
          'mechanism':         _mechanismController.text.trim(),
          'main_constituent':  _constituentController.text.trim(),
          'cautions':          _cautionsController.text.trim(),
          'clinical_study_url': _clinicalUrlController.text.trim(),
          'efficacy_ref':       _efficacyRefController.text.trim(),
          'image_url':         _previewUrl.isNotEmpty ? _previewUrl : null,
          'status':            _status,
          'instructions':      instructions,
        }).eq('id', remedyId);

        // If approved → copy to remedies table + save instructions
        if (_status == 'approved') {
          final rawDiff = _difficultyController.text.trim();
          final difficulty = ['Easy', 'Medium', 'Hard'].contains(rawDiff) ? rawDiff : 'Easy';
          final newRemedy = await SupabaseService.supabase.from('remedies').insert({
            'name':               _recipeNameController.text.trim(),
            'component':          component,
            'origin':             (_selectedCountry.isEmpty ? null : _selectedCountry),
            'type':               (_selectedType.isEmpty ? null : _selectedType),
        'illness_name':       (_selectedIllness.isEmpty ? null : _selectedIllness),
            'category_name':      (_selectedCategory.isEmpty ? null : _selectedCategory),
            'sub_category_name':  (_selectedSubCategory.isEmpty ? null : _selectedSubCategory),
            'symptom_name':       (_selectedSymptom.isEmpty ? null : _selectedSymptom),
            'organ_name':         (_selectedOrgan.isEmpty ? null : _selectedOrgan),
            'function':           _remedyFunctionController.text.trim(),
            'mechanism':          _mechanismController.text.trim(),
            'constituent':        _constituentController.text.trim(),
            'plant_part':         (_selectedPlantPart.isEmpty ? null : _selectedPlantPart),
            'prep_type':          (_selectedPrepType.isEmpty ? null : _selectedPrepType),
            'difficulty':         difficulty,
            'prep_time':          int.tryParse(_prepTimeController.text.trim()),
            'ingredients':        _ingredientsController.text.trim(),
            'cautions':           _cautionsController.text.trim(),
            'clinical_study_url': _clinicalUrlController.text.trim(),
            'efficacy_ref':       _efficacyRefController.text.trim(),
            'image_url':          _previewUrl.isNotEmpty ? _previewUrl : null,
            'encouragement':      _encouragementController.text.trim(),
            'tradition_rating':   _traditionRating,
            'validation_level':   _validationLevel,
            'efficacy':           _efficacy,
            'submitted_by':       widget.remedy['user_id'],
            'approved_by':        SupabaseService.currentUser?.id,
            'status':             'approved',
          }).select().single();

          // Save instructions to remedy_instructions table
          if (instructions.isNotEmpty && newRemedy['id'] != null) {
            await SupabaseService.supabase.from('remedy_instructions').insert(
              instructions.map((s) => {...s, 'remedy_id': newRemedy['id']}).toList());
          }
        }
      } else {
        // Save to remedies table
        if (remedyId == null) {
          throw Exception('Remedy ID is missing');
        }

        // Atomically replace all instructions via RPC — prevents duplicates
        final steps = instructions.map((s) => {
          'step_number': s['step_number'],
          'instruction': s['instruction'],
        }).toList();
        await SupabaseService.supabase.rpc('replace_remedy_instructions', params: {
          'p_remedy_id': remedyId,
          'p_steps':     steps,
        });
        await SupabaseService.supabase.from('remedies').update({
          'name':               _recipeNameController.text.trim(),
          'component':          component,
          'origin':             (_selectedCountry.isEmpty ? null : _selectedCountry),
          'type':               (_selectedType.isEmpty ? null : _selectedType),
        'illness_name':       (_selectedIllness.isEmpty ? null : _selectedIllness),
          'category_name':      (_selectedCategory.isEmpty ? null : _selectedCategory),
          'sub_category_name':  (_selectedSubCategory.isEmpty ? null : _selectedSubCategory),
          'symptom_name':       (_selectedSymptom.isEmpty ? null : _selectedSymptom),
          'organ_name':         (_selectedOrgan.isEmpty ? null : _selectedOrgan),
          'ingredients':        _ingredientsController.text.trim(),
          'plant_part':         (_selectedPlantPart.isEmpty ? null : _selectedPlantPart),
          'prep_type':          (_selectedPrepType.isEmpty ? null : _selectedPrepType),
          'difficulty':         _difficultyController.text.isEmpty ? null : _difficultyController.text,
          'prep_time':          int.tryParse(_prepTimeController.text.trim()),
          'function':           _remedyFunctionController.text.trim(),
          'mechanism':          _mechanismController.text.trim(),
          'constituent':        _constituentController.text.trim(),
          'cautions':           _cautionsController.text.trim(),
          'clinical_study_url': _clinicalUrlController.text.trim(),
          'efficacy_ref':       _efficacyRefController.text.trim(),
          'image_url':          _previewUrl.isNotEmpty ? _previewUrl : null,
          'encouragement':      _encouragementController.text.trim(),
          'tradition_rating':   _traditionRating,
          'validation_level':   _validationLevel,
          'efficacy':           _efficacy,
          'status':             _status,
          'updated_at':         DateTime.now().toIso8601String(),
        }).eq('id', remedyId);
      }

      setState(() { _submitted = true; _loading = false; _instructionsLoaded = false; });
      widget.onSaved();

      // Reload recipes page and clear product cache
      RecipesScreen.reload();
      SupabaseService.clearProductsCache();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_status == 'approved'
              ? '✅ Approved! Recipe is now live on the Recipes page.'
              : '✅ Saved with status: ${_status.replaceAll('_', ' ')}'),
          backgroundColor: _status == 'approved' ? Colors.green : AppColors.primary,
          duration: const Duration(seconds: 4),
        ));
        if (_status == 'approved') Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
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
              title: 'Edit Remedy',
              subtitle: 'Edit & manage remedy',
              showBack: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Ratings ───────────────────────────────────────
                  const SectionLabel('RATINGS'),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                    ),
                    child: Column(children: [
                      // Traditional Rating
                      _buildRatingSlider(
                        'Traditional Rating', '(Cultural / historical use)',
                        _traditionRating, 5, AppColors.levelBadge,
                        (v) => setState(() => _traditionRating = v),
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      // Validation Level
                      _buildRatingSlider(
                        'Validation Level', '(Scientific evidence)',
                        _validationLevel, 5, AppColors.lightGreen,
                        (v) => setState(() => _validationLevel = v),
                      ),
                      const SizedBox(height: 10),
                      // Clinical study URLs — up to 10 entries, one per line
                      // keyboardType.multiline + newline action = Enter key adds a new line
                      TextField(
                        controller: _clinicalUrlController,
                        maxLines: 10,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Clinical study URL(s)',
                          hintText: 'https://pubmed.ncbi.nlm.nih.gov/...\nAdd one URL per line (up to 10)',
                          labelStyle: AppTextStyles.caption,
                          hintStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                      const SizedBox(height: 14),
                      // Efficacy
                      _buildRatingSlider(
                        'Efficacy %', '(Reported effectiveness)',
                        _efficacy, 100, const Color(0xFFE3F2FD),
                        (v) => setState(() => _efficacy = v),
                        isPercent: true,
                      ),
                      const SizedBox(height: 10),
                      // Efficacy reference URL — single source for this efficacy %
                      TextField(
                        controller: _efficacyRefController,
                        maxLines: 1,
                        keyboardType: TextInputType.url,
                        style: const TextStyle(fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'Efficacy reference URL',
                          hintText: 'https://pubmed.ncbi.nlm.nih.gov/...',
                          labelStyle: AppTextStyles.caption,
                          hintStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey.shade200)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // ── Encouragement Block ───────────────────────────
                  const SectionLabel('REMEDY ENCOURAGEMENT'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightYellow, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline, size: 14, color: AppColors.dark),
                      SizedBox(width: 8),
                      Expanded(child: Text(
                        'This text appears above the image on THIS remedy\'s detail page only.',
                        style: TextStyle(fontSize: 11, color: AppColors.dark),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _encouragementController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g. "Nature has given us everything we need to heal..."',
                      hintStyle: AppTextStyles.caption,
                      filled: true, fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade200)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Status Selector ───────────────────────────────
                  const SectionLabel('STATUS'),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                    ),
                    child: Column(children: [
                      Row(children: [
                        _statusBtn('pending',   'Pending',   AppColors.levelBadge),
                        const SizedBox(width: 8),
                        _statusBtn('in_review', 'In review', Colors.blue.shade100),
                        const SizedBox(width: 8),
                        _statusBtn('approved',  'Approved',  AppColors.lightGreen),
                        const SizedBox(width: 8),
                        _statusBtn('rejected',  'Rejected',  const Color(0xFFFFEBEE)),
                      ]),
                      if (_status == 'approved') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(8)),
                          child: const Row(children: [
                            Icon(Icons.info_outline, size: 14, color: Colors.green),
                            SizedBox(width: 6),
                            Expanded(child: Text(
                              'Saving as Approved will publish to the Recipes page.',
                              style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.w500),
                            )),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                      controller: _recipeNameController,
                      decoration: const InputDecoration(
                        labelText: 'Recipe name *',
                        hintText: 'e.g. Cape Aloe Detox Tea',
                        labelStyle: AppTextStyles.caption,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Type — Medicinal or Lifestyle
                    MultiPickField(
                      label: 'Type',
                      value: _selectedType,
                      options: const ['Medicinal', 'Lifestyle'],
                      customHint: 'e.g. Medicinal',
                      onChanged: (v) => setState(() => _selectedType = v),
                    ),
                    const SizedBox(height: 10),
                    // Illness — multi-select
                    MultiPickField(
                      label: 'Illness *',
                      value: _selectedIllness,
                      options: _illnessList,
                      customHint: 'e.g. Chronic fatigue syndrome',
                      onChanged: (v) => setState(() => _selectedIllness = v),
                    ),
                    const SizedBox(height: 10),
                    // Category — multi-select
                    MultiPickField(
                      label: 'Category *',
                      value: _selectedCategory,
                      options: _categoryList,
                      customHint: 'e.g. Autoimmune support',
                      onChanged: (v) => setState(() => _selectedCategory = v),
                    ),
                    const SizedBox(height: 10),
                    // Sub-category — multi-select
                    MultiPickField(
                      label: 'Sub-category',
                      value: _selectedSubCategory,
                      options: _subCategoryList,
                      customHint: 'e.g. Small intestine',
                      onChanged: (v) => setState(() => _selectedSubCategory = v),
                    ),
                    const SizedBox(height: 10),
                    // Symptoms — multi-select
                    MultiPickField(
                      label: 'Symptoms',
                      value: _selectedSymptom,
                      options: _symptomList,
                      customHint: 'e.g. Night sweats',
                      onChanged: (v) => setState(() => _selectedSymptom = v),
                    ),
                    const SizedBox(height: 10),
                    // Organ — multi-select
                    MultiPickField(
                      label: 'Organ',
                      value: _selectedOrgan,
                      options: _organList,
                      customHint: 'e.g. Gallbladder',
                      onChanged: (v) => setState(() => _selectedOrgan = v),
                    ),
                    const SizedBox(height: 10),
                    // Primary herb / component — multi-select
                    MultiPickField(
                      label: 'Primary herb / component',
                      value: _selectedComponent,
                      options: _componentList,
                      customHint: 'e.g. Centella asiatica (Gotu Kola)',
                      onChanged: (v) => setState(() => _selectedComponent = v),
                    ),
                    const SizedBox(height: 10),
                    // Country — multi-select
                    MultiPickField(
                      label: 'Country of origin',
                      value: _selectedCountry,
                      options: _countryList,
                      customHint: 'e.g. Madagascar',
                      onChanged: (v) => setState(() => _selectedCountry = v),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _ingredientsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Ingredients *',
                        hintText: 'List all ingredients...',
                        labelStyle: AppTextStyles.caption,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Plant part — multi-select
                    MultiPickField(
                      label: 'Plant part',
                      value: _selectedPlantPart,
                      options: _plantPartList,
                      customHint: 'e.g. Sap',
                      onChanged: (v) => setState(() => _selectedPlantPart = v),
                    ),
                    const SizedBox(height: 10),
                    // Prep type — multi-select
                    MultiPickField(
                      label: 'Prep type',
                      value: _selectedPrepType,
                      options: _prepTypeList,
                      customHint: 'e.g. Steam inhalation',
                      onChanged: (v) => setState(() => _selectedPrepType = v),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      // Difficulty is a fixed 3-value enum — no DB lookup,
                      // so it can never crash from duplicate/garbage data.
                      value: const ['Easy', 'Medium', 'Hard'].contains(_difficultyController.text)
                          ? _difficultyController.text : 'Medium',
                      decoration: const InputDecoration(labelText: 'Difficulty', labelStyle: AppTextStyles.caption),
                      items: const ['Easy', 'Medium', 'Hard'].map((o) => DropdownMenuItem(
                          value: o, child: Text(o, style: AppTextStyles.body))).toList(),
                      onChanged: (v) => setState(() => _difficultyController.text = v ?? 'Medium'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _prepTimeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Prep time', hintText: 'minutes (e.g. 15)',
                          labelStyle: AppTextStyles.caption),
                    ),
                    const SizedBox(height: 10),
                    // Auto-numbered instructions
                    const Text('Instructions *', style: AppTextStyles.heading3),
                    const SizedBox(height: 4),
                    const Text('Each step is automatically numbered', style: AppTextStyles.caption),
                    const SizedBox(height: 10),
                    ..._stepControllers.asMap().entries.map((entry) {
                      final i = entry.key;
                      final controller = entry.value;
                      return Padding(
                        key: ValueKey('step_$i\_${_stepControllers.length}'),
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Step number circle
                            Container(
                              width: 28, height: 28,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('${i + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.dark,
                                  )),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Step text input
                            Expanded(
                              child: TextField(
                                key: ValueKey('step_field_$i\_${controller.hashCode}'),
                                controller: controller,
                                decoration: InputDecoration(
                                  hintText: 'Describe step ${i + 1}...',
                                  hintStyle: AppTextStyles.caption,
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                ),
                                maxLines: 2,
                              ),
                            ),
                            // Remove step button
                            if (_stepControllers.length > 1) ...[
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _removeStep(i),
                                child: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 22),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    // Add step button
                    GestureDetector(
                      onTap: _addStep,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.lightYellow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline, size: 18, color: AppColors.dark),
                            SizedBox(width: 6),
                            Text('Add step', style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.dark,
                            )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: _remedyFunctionController, decoration: const InputDecoration(labelText: 'Remedy function *', hintText: 'e.g. Liver detox', labelStyle: AppTextStyles.caption)),
                    const SizedBox(height: 10),
                    TextField(controller: _mechanismController, decoration: const InputDecoration(labelText: 'Mechanism', hintText: 'How does it work?', labelStyle: AppTextStyles.caption)),
                    const SizedBox(height: 10),
                    TextField(controller: _constituentController, decoration: const InputDecoration(labelText: 'Main constituent', hintText: 'e.g. Silymarin', labelStyle: AppTextStyles.caption)),
                    const SizedBox(height: 10),
                    TextField(controller: _cautionsController, decoration: const InputDecoration(labelText: 'Cautions *', hintText: 'Safety warnings...', labelStyle: AppTextStyles.caption)),
                    const SizedBox(height: 10),
                    const SizedBox(height: 16),

                    // ── Image Section ─────────────────────────────────────
                    const Text('Herb image', style: AppTextStyles.heading3),
                    const SizedBox(height: 4),
                    const Text('Upload a photo or paste an image URL', style: AppTextStyles.caption),
                    const SizedBox(height: 12),

                    // Image preview box
                    _buildImagePreview(),
                    const SizedBox(height: 12),

                    // Two options side by side
                    Row(
                      children: [
                        // Upload button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.upload_outlined, size: 18, color: AppColors.dark),
                            label: const Text('Upload photo',
                                style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.w600, fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              side: const BorderSide(color: AppColors.dark),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // OR divider
                        const Text('or', style: AppTextStyles.caption),
                        const SizedBox(width: 10),
                        // Paste URL button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showUrlDialog,
                            icon: const Icon(Icons.link, size: 18, color: AppColors.dark),
                            label: const Text('Paste URL',
                                style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.w600, fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              side: const BorderSide(color: AppColors.dark),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Show current URL if set
                    if (_previewUrl.isNotEmpty && !_urlError) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, size: 14, color: Colors.green),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _previewUrl,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() { _previewUrl = ''; _imageUrlController.clear(); }),
                            child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                    if (_urlError) ...[
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.error_outline, size: 14, color: Colors.red),
                          SizedBox(width: 6),
                          Text('Could not load image from this URL', style: TextStyle(fontSize: 11, color: Colors.red)),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ── Add Shop Items ────────────────────────────────────
                    const SectionLabel('SHOP ITEMS'),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                        // ── Buy Components (up to 3) ────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: AppColors.dark, borderRadius: BorderRadius.circular(8)),
                          child: const Text('Buy Components',
                              style: TextStyle(color: AppColors.primary,
                                  fontWeight: FontWeight.w700, fontSize: 11)),
                        ),
                        const SizedBox(height: 10),
                        Builder(builder: (_) {
                          final comps = _linkedProducts
                              .where((p) => p['type'] == 'Component').toList();
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...List.generate(3, (i) {
                                if (i < comps.length) {
                                  final p = comps[i];
                                  return Expanded(child: Padding(
                                    padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                                    child: Column(children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: p['image_url'] != null && p['image_url'].isNotEmpty
                                            ? Image.network(p['image_url'], height: 64,
                                                width: double.infinity, fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const HerbIconPlaceholder(size: 64))
                                            : const HerbIconPlaceholder(size: 64),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(p['name'] ?? '', style: AppTextStyles.heading3,
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center),
                                      Text('R${((p['price'] ?? 0) as num).toInt()}',
                                          style: AppTextStyles.caption),
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () => _unlinkProduct(p['id'].toString()),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFFFFEBEE),
                                              borderRadius: BorderRadius.circular(6)),
                                          child: const Text('Remove',
                                              style: TextStyle(fontSize: 10,
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                      ),
                                    ]),
                                  ));
                                }
                                // Empty slot — show Select if < 3 linked
                                if (comps.length < 3) {
                                  return Expanded(child: Padding(
                                    padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                                    child: OutlinedButton(
                                      onPressed: () => _openProductPicker(type: 'Component'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        side: BorderSide(color: Colors.grey.shade300),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add, size: 18, color: AppColors.dark),
                                          SizedBox(height: 2),
                                          Text('Select', style: TextStyle(
                                              fontSize: 10, color: AppColors.dark)),
                                        ],
                                      ),
                                    ),
                                  ));
                                }
                                return const Expanded(child: SizedBox.shrink());
                              }),
                            ],
                          );
                        }),

                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 16),

                        // ── Buy Remedies (up to 3) ──────────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                              color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                          child: const Text('Buy Remedies',
                              style: TextStyle(color: AppColors.dark,
                                  fontWeight: FontWeight.w700, fontSize: 11)),
                        ),
                        const SizedBox(height: 10),
                        Builder(builder: (_) {
                          final rems = _linkedProducts
                              .where((p) => p['type'] == 'Remedy').toList();
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...List.generate(3, (i) {
                                if (i < rems.length) {
                                  final p = rems[i];
                                  return Expanded(child: Padding(
                                    padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                                    child: Column(children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: p['image_url'] != null && p['image_url'].isNotEmpty
                                            ? Image.network(p['image_url'], height: 64,
                                                width: double.infinity, fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const HerbIconPlaceholder(size: 64))
                                            : const HerbIconPlaceholder(size: 64),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(p['name'] ?? '', style: AppTextStyles.heading3,
                                          maxLines: 1, overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center),
                                      Text('R${((p['price'] ?? 0) as num).toInt()}',
                                          style: AppTextStyles.caption),
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: () => _unlinkProduct(p['id'].toString()),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFFFFEBEE),
                                              borderRadius: BorderRadius.circular(6)),
                                          child: const Text('Remove',
                                              style: TextStyle(fontSize: 10,
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.w600)),
                                        ),
                                      ),
                                    ]),
                                  ));
                                }
                                if (rems.length < 3) {
                                  return Expanded(child: Padding(
                                    padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                                    child: OutlinedButton(
                                      onPressed: () => _openProductPicker(type: 'Remedy'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        side: BorderSide(color: Colors.grey.shade300),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.add, size: 18, color: AppColors.dark),
                                          SizedBox(height: 2),
                                          Text('Select', style: TextStyle(
                                              fontSize: 10, color: AppColors.dark)),
                                        ],
                                      ),
                                    ),
                                  ));
                                }
                                return const Expanded(child: SizedBox.shrink());
                              }),
                            ],
                          );
                        }),

                      ]),
                    ),

                    const SizedBox(height: 20),
                    if (_submitted)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Column(children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 40),
                          const SizedBox(height: 8),
                          const Text('Remedy submitted!', style: AppTextStyles.heading3),
                          const SizedBox(height: 4),
                          const Text('Your remedy is pending review by our admin team.',
                              textAlign: TextAlign.center, style: AppTextStyles.caption),
                        ]),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submitRemedy,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.dark,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: _loading
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                              : const Text('Save changes',
                                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Image Preview ─────────────────────────────────────────────────────

  Widget _buildImagePreview() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _previewUrl.isNotEmpty && !_urlError
              ? Colors.green.shade300
              : Colors.grey.shade200,
          width: 1.5,
        ),
      ),
      child: _previewUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.network(
                _previewUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                },
                errorBuilder: (context, error, stackTrace) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _onImageError());
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.broken_image_outlined, size: 40, color: AppColors.textSecondary),
                      SizedBox(height: 8),
                      Text('Could not load image', style: AppTextStyles.caption),
                    ],
                  );
                },
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.eco, size: 48, color: AppColors.herbGreen),
                SizedBox(height: 8),
                Text('No image selected', style: AppTextStyles.caption),
                SizedBox(height: 4),
                Text('Upload a photo or paste a URL below',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
    );
  }

  // ── Upload Photo (web: shows dialog; mobile: would use image_picker) ──

  void _pickImage() {
    // On web Flutter, file picking requires dart:html
    // Show a helpful message directing to URL option
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Upload photo', style: AppTextStyles.heading3),
        content: const Text(
          'File upload works on mobile devices.\n\nFor the web version, please paste an image URL instead.',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(ctx); _showUrlDialog(); },
            child: const Text('Paste URL instead', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.dark)),
          ),
        ],
      ),
    );
  }

  // ── Paste URL Dialog ──────────────────────────────────────────────────

  void _showUrlDialog() {
    final tempController = TextEditingController(text: _previewUrl);
    final searchController = TextEditingController(
        text: _recipeNameController.text.trim().isNotEmpty
            ? _recipeNameController.text.trim()
            : (_selectedComponent != 'Select component' ? _selectedComponent : ''));
    String? foundUrl;
    bool searching = false;
    String? searchError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Image URL', style: AppTextStyles.heading3),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Wikipedia search section ─────────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.lightYellow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Search Wikipedia',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Herb or plant name',
                              prefixIcon: Icon(Icons.search, size: 16),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: searching ? null : () async {
                            final q = searchController.text.trim();
                            if (q.isEmpty) return;
                            setS(() { searching = true; searchError = null; foundUrl = null; });
                            final url = await findWikimediaImage(q);
                            setS(() {
                              searching = false;
                              if (url != null) {
                                foundUrl = url;
                                tempController.text = url;
                              } else {
                                searchError = 'No image found — try a different name';
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.dark,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          child: searching
                              ? const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                              : const Text('Find', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ]),
                      if (searchError != null) ...[
                        const SizedBox(height: 6),
                        Text(searchError!, style: const TextStyle(fontSize: 11, color: Colors.red)),
                      ],
                      if (foundUrl != null) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(foundUrl!, width: 56, height: 56,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image, size: 40)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(foundUrl!,
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                maxLines: 3, overflow: TextOverflow.ellipsis),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Row(children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('or paste directly', style: AppTextStyles.caption),
                  ),
                  Expanded(child: Divider()),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: tempController,
                  decoration: const InputDecoration(
                    hintText: 'https://upload.wikimedia.org/...',
                    prefixIcon: Icon(Icons.link, size: 18),
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setS(() { foundUrl = null; }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _onUrlChanged(tempController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.dark,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Use this image', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Smart Dropdown with Manual Entry ─────────────────────────────────

  Widget _buildSmartDropdown({
    required String label,
    required String value,
    required List<String> options,
    required bool showCustom,
    required TextEditingController customController,
    required String customHint,
    required ValueChanged<String?> onChanged,
    VoidCallback? onConfirm,
  }) {
    // Always ensure value is valid to prevent dropdown crash
    final dropdownValue = (showCustom || !options.contains(value))
        ? options.first
        : value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show confirmed custom value as a chip if set
        if (!showCustom && !options.contains(value) && value != options.first) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.lightYellow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(value, style: AppTextStyles.body)),
                GestureDetector(
                  onTap: () => onChanged(options.first),
                  child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => onChanged(options.first),
            child: Text('Change selection', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ] else ...[
          DropdownButtonFormField<String>(
            value: dropdownValue,
            decoration: InputDecoration(
              labelText: label,
              labelStyle: AppTextStyles.caption,
            ),
            isExpanded: true,
            items: options.map((o) => DropdownMenuItem(
              value: o,
              child: Text(
                o,
                style: o == 'Not in list — enter manually'
                    ? const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)
                    : AppTextStyles.body,
                overflow: TextOverflow.ellipsis,
              ),
            )).toList(),
            onChanged: onChanged,
          ),
          if (showCustom) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.lightYellow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: customController,
                      decoration: InputDecoration(
                        hintText: customHint,
                        hintStyle: AppTextStyles.caption,
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) {
                        if (customController.text.isNotEmpty && onConfirm != null) onConfirm();
                      },
                    ),
                  ),
                  // Tappable green tick to confirm
                  if (customController.text.isNotEmpty)
                    GestureDetector(
                      onTap: onConfirm,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Type your answer and tap ✓ to confirm',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ],
    );
  }

  // ── Herb / Component Selector ─────────────────────────────────────────

  Widget _buildComponentSelector() {
    final herbs = _componentList.isNotEmpty ? _componentList : [
      'Select component',
      'Agathosma betulina (Buchu)', 'Aloe ferox (Cape Aloe)',
      'Artemisia afra (African Wormwood)', 'Aspalathus linearis (Rooibos)',
      'Boswellia serrata (Frankincense)', 'Cannabis sativa (Hemp)',
      'Centella asiatica (Gotu Kola)', 'Curcuma longa (Turmeric)',
      'Echinacea purpurea', 'Ginkgo biloba', 'Glycyrrhiza glabra (Liquorice)',
      'Harpagophytum procumbens (Devils Claw)', 'Hypoxis hemerocallidea (African Potato)',
      'Moringa oleifera', 'Pelargonium sidoides (Umckaloabo)',
      'Sceletium tortuosum (Kanna)', 'Silybum marianum (Milk Thistle)',
      'Sutherlandia frutescens (Cancer Bush)', 'Withania somnifera (Ashwagandha)',
      'Zingiber officinale (Ginger)', 'Not in list — enter manually',
    ];

    // Confirmed custom value: show chip (same pattern as _buildSmartDropdown)
    final isConfirmedCustom = !_showCustomComponent &&
        _selectedComponent != 'Select component' &&
        !herbs.contains(_selectedComponent);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isConfirmedCustom) ...[
          // Confirmed chip — mirrors _buildSmartDropdown confirmed state
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.lightYellow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_selectedComponent, style: AppTextStyles.body)),
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedComponent = 'Select component';
                    _showCustomComponent = false;
                    _customComponentController.clear();
                  }),
                  child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() {
              _showCustomComponent = true;
              // Re-populate controller so the user can edit the confirmed value
              _customComponentController.text = _selectedComponent;
              _selectedComponent = 'Select component';
            }),
            child: Text('Change selection',
                style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ),
        ] else ...[
          DropdownButtonFormField<String>(
            value: _showCustomComponent || !herbs.contains(_selectedComponent)
                ? 'Select component'
                : _selectedComponent,
            decoration: const InputDecoration(
              labelText: 'Primary component *',
              labelStyle: AppTextStyles.caption,
            ),
            isExpanded: true,
            items: herbs.map((h) => DropdownMenuItem(
              value: h,
              child: Text(h,
                style: h == 'Not in list — enter manually'
                    ? const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)
                    : AppTextStyles.body,
                overflow: TextOverflow.ellipsis,
              ),
            )).toList(),
            onChanged: (v) {
              setState(() {
                _selectedComponent = v!;
                _showCustomComponent = v == 'Not in list — enter manually';
                if (_showCustomComponent) _customComponentController.clear();
              });
            },
          ),
          // Manual input — shown when "Not in list" is selected
          if (_showCustomComponent) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.lightYellow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _customComponentController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Leonotis leonurus (Wild Dagga)',
                        hintStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) {
                        if (_customComponentController.text.isNotEmpty) {
                          setState(() {
                            _confirmedCustomComponent = _customComponentController.text.trim();
                            _selectedComponent = _customComponentController.text.trim();
                            _showCustomComponent = false;
                          });
                        }
                      },
                    ),
                  ),
                  if (_customComponentController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() {
                        _confirmedCustomComponent = _customComponentController.text.trim();
                        _selectedComponent = _customComponentController.text.trim();
                        _showCustomComponent = false;
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.check, color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Include both common name and Latin name where possible',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ],
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Widget _shopField(String label, String hint, TextEditingController controller, {bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        hintStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    );
  }

  Widget _field(String label, String hint, {int maxLines = 1}) {
    return TextField(
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint, labelStyle: AppTextStyles.caption),
    );
  }

  Widget _dropdown(String label, List<String> options) {
    return DropdownButtonFormField<String>(
      value: options.first,
      decoration: InputDecoration(labelText: label, labelStyle: AppTextStyles.caption),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: AppTextStyles.body))).toList(),
      onChanged: (_) {},
    );
  }
}

// ── Product Picker Sheet ──────────────────────────────────────────────────

class _ProductPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final List<String> linkedIds;
  final Function(Map<String, dynamic>) onSelect;

  const _ProductPickerSheet({
    required this.products,
    required this.linkedIds,
    required this.onSelect,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    return widget.products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      return _search.isEmpty || name.contains(_search.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        const SizedBox(height: 12),
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Text('Select shop item', style: AppTextStyles.heading2),
            const Spacer(),
            GestureDetector(onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, size: 20, color: AppColors.textSecondary)),
          ]),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
              filled: true, fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _filtered.isEmpty
              ? const Center(child: Text('No products found', style: AppTextStyles.caption))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final p = _filtered[i];
                    final isLinked = widget.linkedIds.contains(p['id'].toString());
                    final name     = p['name'] ?? '';
                    final type     = p['type'] ?? '';
                    final price    = ((p['price'] ?? 0) as num).toDouble();
                    final imageUrl = p['image_url'] ?? '';

                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: imageUrl.isNotEmpty
                              ? Image.network(imageUrl, width: 44, height: 44, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const HerbIconPlaceholder(size: 44))
                              : const HerbIconPlaceholder(size: 44),
                        ),
                        title: Text(name, style: AppTextStyles.heading3),
                        subtitle: Text('$type · R${price.toInt()}', style: AppTextStyles.caption),
                        trailing: isLinked
                            ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                            : const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 20),
                        onTap: isLinked ? null : () => widget.onSelect(p),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}
