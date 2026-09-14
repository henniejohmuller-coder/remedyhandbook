import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/image_search.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';

class SubmitRemedyScreen extends StatefulWidget {
  const SubmitRemedyScreen({super.key});

  @override
  State<SubmitRemedyScreen> createState() => _SubmitRemedyScreenState();
}

class _SubmitRemedyScreenState extends State<SubmitRemedyScreen> {
  final _imageUrlController = TextEditingController();
  final _customHerbController = TextEditingController();
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
  final _prepTimeController        = TextEditingController();
  final _difficultyController      = TextEditingController();

  bool _loading = false;
  bool _submitted = false;
  bool _lookupsLoading = true;

  // Dynamic lookup lists
  List<String> _illnessList     = ['Select illness'];
  List<String> _categoryList    = ['Select category'];
  List<String> _subCategoryList = ['Select sub-category'];
  List<String> _symptomList     = ['Select symptom'];
  List<String> _organList       = ['Select organ'];
  List<String> _countryList     = ['Select country'];
  List<String> _herbList        = ['Select component'];
  List<String> _plantPartList   = ['Select'];
  List<String> _prepTypeList    = ['Select'];
  List<String> _difficultyList  = ['Easy', 'Medium', 'Hard'];

  @override
  void initState() {
    super.initState();
    _loadLookups();
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
      if (!mounted) return;
      setState(() {
        _illnessList     = ['Select illness', ..._flattenValues(results[0] as List, 'name'), 'Not in list — enter manually'];
        _categoryList     = ['Select category', ..._flattenValues(results[1] as List, 'name'), 'Not in list — enter manually'];
        _subCategoryList     = ['Select sub-category', ..._flattenValues(results[2] as List, 'name'), 'Not in list — enter manually'];
        _symptomList     = ['Select symptom', ..._flattenValues(results[3] as List, 'name'), 'Not in list — enter manually'];
        _organList     = ['Select organ', ..._flattenValues(results[4] as List, 'name'), 'Not in list — enter manually'];
        _countryList     = ['Select country', ..._flattenValues(results[5] as List, 'name'), 'Not in list — enter manually'];
        _herbList        = ['Select component',   ..._flattenValues(results[6] as List, 'common_name'), 'Not in list — enter manually'];
        _plantPartList = ['Select', ..._flattenValues(results[7] as List, 'name')];
        _prepTypeList  = ['Select', ..._flattenValues(results[8] as List, 'name')];
        if ((results[9] as List).isNotEmpty) _difficultyList = _flattenValues(results[9] as List, 'name');
        else _difficultyList = ['Easy', 'Medium', 'Hard'];
        _lookupsLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _lookupsLoading = false);
    }
  }

  String _previewUrl = '';
  bool _urlError = false;
  String _selectedHerb = '';
  bool _showCustomHerb = false;
  String _selectedType    = '';
  String _selectedIllness = '';
  bool _showCustomIllness = false;
  String _selectedCategory = '';
  bool _showCustomCategory = false;
  String _selectedSubCategory = '';
  bool _showCustomSubCategory = false;
  String _selectedSymptom = '';
  bool _showCustomSymptom = false;
  String _selectedOrgan = '';
  bool _showCustomOrgan = false;
  String _selectedCountry = '';
  bool _showCustomCountry = false;
  String _selectedPlantPart = '';
  bool _showCustomPlantPart = false;
  String _selectedPrepType = '';
  bool _showCustomPrepType = false;

  // Auto-numbered instruction steps
  final List<TextEditingController> _stepControllers = [TextEditingController()];

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
    _imageUrlController.dispose();
    _customHerbController.dispose();
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
    _prepTimeController.dispose();
    _difficultyController.dispose();
    for (final c in _stepControllers) c.dispose();
    super.dispose();
  }

  // ── Submit to Supabase ────────────────────────────────────────
  void _clearForm() {
    setState(() {
      _recipeNameController.clear();
      _ingredientsController.clear();
      _remedyFunctionController.clear();
      _mechanismController.clear();
      _constituentController.clear();
      _cautionsController.clear();
      _clinicalUrlController.clear();
      _imageUrlController.clear();
      _prepTimeController.clear();
      _difficultyController.clear();
      _selectedType         = '';
      _selectedIllness      = '';
      _selectedCategory     = '';
      _selectedSubCategory  = '';
      _selectedSymptom      = '';
      _selectedOrgan        = '';
      _selectedHerb         = '';
      _selectedCountry      = '';
      _selectedPlantPart    = '';
      _selectedPrepType     = '';
      for (final c in _stepControllers) { c.clear(); }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Form cleared'),
          backgroundColor: AppColors.dark, duration: Duration(seconds: 2)));
  }

  Future<void> _submitRemedy() async {
    if (_recipeNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a recipe name'), backgroundColor: Colors.red),
      );
      return;
    }
    final component = _selectedHerb.trim();
    if (component.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a primary component'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // Build instructions as JSON array
      final instructions = _stepControllers
          .asMap()
          .entries
          .where((e) => e.value.text.isNotEmpty)
          .map((e) => {'step_number': e.key + 1, 'instruction': e.value.text})
          .toList();

      await SupabaseService.submitRemedy({
        'recipe_name':       _recipeNameController.text.trim(),
        'type':              (_selectedType.isEmpty ? null : _selectedType),
        'illness':           (_selectedIllness.isEmpty ? null : _selectedIllness),
        'category':          (_selectedCategory.isEmpty ? null : _selectedCategory),
        'sub_category':      (_selectedSubCategory.isEmpty ? null : _selectedSubCategory),
        'symptoms':          (_selectedSymptom.isEmpty ? null : _selectedSymptom),
        'organ':             (_selectedOrgan.isEmpty ? null : _selectedOrgan),
        'primary_component': component,
        'country':           (_selectedCountry.isEmpty ? null : _selectedCountry),
        'ingredients':       _ingredientsController.text.trim(),
        'plant_part':        (_selectedPlantPart.isEmpty ? null : _selectedPlantPart),
        'prep_type':         (_selectedPrepType.isEmpty ? null : _selectedPrepType),
        'difficulty':        _difficultyController.text.isEmpty ? null : _difficultyController.text,
        'prep_time':         int.tryParse(_prepTimeController.text.trim()),
        'instructions':      instructions,
        'remedy_function':   _remedyFunctionController.text.trim(),
        'mechanism':         _mechanismController.text.trim(),
        'main_constituent':  _constituentController.text.trim(),
        'cautions':          _cautionsController.text.trim(),
        'clinical_study_url': _clinicalUrlController.text.trim(),
        'image_url':         _previewUrl.isNotEmpty ? _previewUrl : null,
        'status':            'pending',
      });

      setState(() { _submitted = true; _loading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Remedy submitted for review!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lookupsLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            YellowAppBar(
              title: 'Submit a remedy',
              subtitle: 'Share your knowledge',
              showBack: true,
              actions: [
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Clear form?', style: AppTextStyles.heading3),
                      content: const Text('This will clear all entered data. Are you sure?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
                        ElevatedButton(
                          onPressed: () { Navigator.pop(ctx); _clearForm(); },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                              foregroundColor: Colors.white, elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Clear', style: TextStyle(
                    fontSize: 13, color: AppColors.dark, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _recipeNameController,
                      decoration: const InputDecoration(
                        labelText: 'Recipe name *',
                        hintText: 'e.g. Cape Aloe Detox Tea',
                        labelStyle: AppTextStyles.caption,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Type
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
                      label: 'Primary herb / component *',
                      value: _selectedHerb,
                      options: _herbList,
                      customHint: 'e.g. Centella asiatica (Gotu Kola)',
                      onChanged: (v) => setState(() => _selectedHerb = v),
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
                      customHint: 'e.g. Rhizome',
                      onChanged: (v) => setState(() => _selectedPlantPart = v),
                    ),
                    const SizedBox(height: 10),
                    MultiPickField(
                      label: 'Prep type',
                      value: _selectedPrepType,
                      options: _prepTypeList,
                      customHint: 'e.g. Steam inhalation',
                      onChanged: (v) => setState(() => _selectedPrepType = v),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _dropdown('Difficulty', _difficultyList)),
                      const SizedBox(width: 10),
                      Expanded(child: _field('Prep time', 'mins')),
                    ]),                    const SizedBox(height: 10),
                    // Auto-numbered instructions
                    const Text('Instructions *', style: AppTextStyles.heading3),
                    const SizedBox(height: 4),
                    const Text('Each step is automatically numbered', style: AppTextStyles.caption),
                    const SizedBox(height: 10),
                    ..._stepControllers.asMap().entries.map((entry) {
                      final i = entry.key;
                      final controller = entry.value;
                      return Padding(
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
                    TextField(controller: _clinicalUrlController, decoration: const InputDecoration(labelText: 'Clinical study URL', hintText: 'https://pubmed...', labelStyle: AppTextStyles.caption)),
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
                              : const Text('Submit for review',
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
            : (_customHerbController.text.trim()));
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
    // Always ensure dropdownValue is a valid option to prevent crash
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

  Widget _buildHerbSelector() {
    final herbs = [
      'Select component',
      'Agathosma betulina (Buchu)',
      'Aloe ferox (Cape Aloe)',
      'Artemisia afra (African Wormwood)',
      'Aspalathus linearis (Rooibos)',
      'Boswellia serrata (Frankincense)',
      'Cannabis sativa (Hemp)',
      'Centella asiatica (Gotu Kola)',
      'Curcuma longa (Turmeric)',
      'Echinacea purpurea',
      'Ginkgo biloba',
      'Glycyrrhiza glabra (Liquorice)',
      'Harpagophytum procumbens (Devils Claw)',
      'Hypoxis hemerocallidea (African Potato)',
      'Moringa oleifera',
      'Pelargonium sidoides (Umckaloabo)',
      'Sceletium tortuosum (Kanna)',
      'Silybum marianum (Milk Thistle)',
      'Sutherlandia frutescens (Cancer Bush)',
      'Withania somnifera (Ashwagandha)',
      'Zingiber officinale (Ginger)',
      'Not in list — enter manually',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: (_showCustomHerb || !herbs.contains(_selectedHerb)) 
              ? 'Select component' 
              : _selectedHerb,
          decoration: const InputDecoration(
            labelText: 'Primary herb *',
            labelStyle: AppTextStyles.caption,
          ),
          items: herbs.map((h) => DropdownMenuItem(
            value: h,
            child: Text(
              h,
              style: h == 'Not in list — enter manually'
                  ? const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)
                  : AppTextStyles.body,
            ),
          )).toList(),
          onChanged: (v) {
            setState(() {
              _selectedHerb = v!;
              _showCustomHerb = v == 'Not in list — enter manually';
              if (_showCustomHerb) _customHerbController.clear();
            });
          },
        ),
        // Manual input appears when "Not in list" is selected
        if (_showCustomHerb) ...[
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
                    controller: _customHerbController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Leonotis leonurus (Wild Dagga)',
                      hintStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => setState(() { _selectedHerb = _customHerbController.text; _showCustomHerb = false; }),
                  ),
                ),
                if (_customHerbController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() { _selectedHerb = _customHerbController.text; _showCustomHerb = false; }),
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
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  Widget _field(String label, String hint, {int maxLines = 1}) {
    return TextField(
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint, labelStyle: AppTextStyles.caption),
    );
  }

  Widget _dropdown(String label, List<String> options) {
    // Difficulty is a fixed enum — hardcode to remove any DB-duplicate risk.
    final uniqueOptions = label == 'Difficulty'
        ? const ['Easy', 'Medium', 'Hard']
        : options.toSet().toList();
    return DropdownButtonFormField<String>(
      value: uniqueOptions.first,
      decoration: InputDecoration(labelText: label, labelStyle: AppTextStyles.caption),
      items: uniqueOptions.map((o) => DropdownMenuItem(value: o, child: Text(o, style: AppTextStyles.body))).toList(),
      onChanged: (_) {},
    );
  }
}
