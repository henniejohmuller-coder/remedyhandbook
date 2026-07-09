import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';

class AdminSubmissionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> submission;
  final VoidCallback onStatusChanged;

  const AdminSubmissionDetailScreen({
    super.key,
    required this.submission,
    required this.onStatusChanged,
  });

  @override
  State<AdminSubmissionDetailScreen> createState() => _AdminSubmissionDetailScreenState();
}

class _AdminSubmissionDetailScreenState extends State<AdminSubmissionDetailScreen> {
  bool _editing = false;
  bool _saving = false;

  late TextEditingController _nameController;
  late TextEditingController _componentController;
  late TextEditingController _illnessController;
  late TextEditingController _categoryController;
  late TextEditingController _subCategoryController;
  late TextEditingController _symptomsController;
  late TextEditingController _organController;
  late TextEditingController _countryController;
  late TextEditingController _ingredientsController;
  late TextEditingController _plantPartController;
  late TextEditingController _prepTypeController;
  late TextEditingController _difficultyController;
  late TextEditingController _prepTimeController;
  late TextEditingController _functionController;
  late TextEditingController _mechanismController;
  late TextEditingController _constituentController;
  late TextEditingController _cautionsController;
  late TextEditingController _clinicalUrlController;

  @override
  void initState() {
    super.initState();
    final s = widget.submission;
    // Handle both remedy_submissions (recipe_name) and remedies (name) field names
    _nameController        = TextEditingController(text: s['recipe_name'] ?? s['name'] ?? '');
    _componentController   = TextEditingController(text: s['primary_component'] ?? s['component'] ?? '');
    _illnessController     = TextEditingController(text: s['illness'] ?? s['illness_name'] ?? '');
    _categoryController    = TextEditingController(text: s['category'] ?? s['category_name'] ?? '');
    _subCategoryController = TextEditingController(text: s['sub_category'] ?? s['sub_category_name'] ?? '');
    _symptomsController    = TextEditingController(text: s['symptoms'] ?? s['symptom_name'] ?? '');
    _organController       = TextEditingController(text: s['organ'] ?? s['organ_name'] ?? '');
    _countryController     = TextEditingController(text: s['country'] ?? s['origin'] ?? '');
    _ingredientsController = TextEditingController(text: s['ingredients'] ?? '');
    _plantPartController   = TextEditingController(text: s['plant_part'] ?? '');
    _prepTypeController    = TextEditingController(text: s['prep_type'] ?? '');
    _difficultyController  = TextEditingController(text: s['difficulty'] ?? '');
    _prepTimeController    = TextEditingController(text: s['prep_time']?.toString() ?? '');
    _functionController    = TextEditingController(text: s['remedy_function'] ?? s['function'] ?? '');
    _mechanismController   = TextEditingController(text: s['mechanism'] ?? '');
    _constituentController = TextEditingController(text: s['main_constituent'] ?? s['constituent'] ?? '');
    _cautionsController    = TextEditingController(text: s['cautions'] ?? '');
    _clinicalUrlController = TextEditingController(text: s['clinical_study_url'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _componentController.dispose();
    _illnessController.dispose();
    _categoryController.dispose();
    _subCategoryController.dispose();
    _symptomsController.dispose();
    _organController.dispose();
    _countryController.dispose();
    _ingredientsController.dispose();
    _plantPartController.dispose();
    _prepTypeController.dispose();
    _difficultyController.dispose();
    _prepTimeController.dispose();
    _functionController.dispose();
    _mechanismController.dispose();
    _constituentController.dispose();
    _cautionsController.dispose();
    _clinicalUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    setState(() => _saving = true);
    try {
      await SupabaseService.supabase.from('remedy_submissions').update({
        'recipe_name':       _nameController.text.trim(),
        'primary_component': _componentController.text.trim(),
        'illness':           _illnessController.text.trim(),
        'category':          _categoryController.text.trim(),
        'sub_category':      _subCategoryController.text.trim(),
        'symptoms':          _symptomsController.text.trim(),
        'organ':             _organController.text.trim(),
        'country':           _countryController.text.trim(),
        'ingredients':       _ingredientsController.text.trim(),
        'plant_part':        _plantPartController.text.trim(),
        'prep_type':         _prepTypeController.text.trim(),
        'difficulty':        _difficultyController.text.trim(),
        'prep_time':         int.tryParse(_prepTimeController.text.trim()),
        'remedy_function':   _functionController.text.trim(),
        'mechanism':         _mechanismController.text.trim(),
        'main_constituent':  _constituentController.text.trim(),
        'cautions':          _cautionsController.text.trim(),
        'clinical_study_url': _clinicalUrlController.text.trim(),
      }).eq('id', widget.submission['id']);

      setState(() { _editing = false; _saving = false; });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Changes saved!'), backgroundColor: Colors.green),
        );
        widget.onStatusChanged();
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _approve() async {
    try {
      // Save edits first if editing
      if (_editing) await _saveChanges();

      // Copy to remedies
      final rawDiff = _difficultyController.text.trim();
      final difficulty = ['Easy', 'Medium', 'Hard'].contains(rawDiff) ? rawDiff : 'Easy';

      await SupabaseService.supabase.from('remedies').insert({
        'name':               _nameController.text.trim(),
        'component':          _componentController.text.trim(),
        'origin':             _countryController.text.trim(),
        'function':           _functionController.text.trim(),
        'mechanism':          _mechanismController.text.trim(),
        'constituent':        _constituentController.text.trim(),
        'plant_part':         _plantPartController.text.trim(),
        'prep_type':          _prepTypeController.text.trim(),
        'difficulty':         difficulty,
        'prep_time':          int.tryParse(_prepTimeController.text.trim()),
        'ingredients':        _ingredientsController.text.trim(),
        'cautions':           _cautionsController.text.trim(),
        'clinical_study_url': _clinicalUrlController.text.trim(),
        'image_url':          widget.submission['image_url'],
        'submitted_by':       widget.submission['user_id'],
        'approved_by':        SupabaseService.currentUser?.id,
        'status':             'approved',
      });

      await SupabaseService.updateSubmissionStatus(widget.submission['id'], 'approved');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Remedy approved and added to recipes!'), backgroundColor: Colors.green),
        );
        widget.onStatusChanged();
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showRejectDialog() {
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject submission', style: AppTextStyles.heading3),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Add a note explaining why (optional):', style: AppTextStyles.caption),
          const SizedBox(height: 10),
          TextField(controller: notesController, maxLines: 3,
              decoration: const InputDecoration(hintText: 'Reason for rejection...')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await SupabaseService.updateSubmissionStatus(
                  widget.submission['id'], 'rejected', notes: notesController.text);
              widget.onStatusChanged();
              if (context.mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.submission['status'] ?? 'pending';
    final author = widget.submission['submitted_by_name'] ?? widget.submission['submitted_by_email'] ?? 'Unknown';
    final date   = widget.submission['submitted_at']?.toString().substring(0, 10) ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            YellowAppBar(
              title: _nameController.text,
              subtitle: 'Submission by $author',
              showBack: true,
              actions: [
                GestureDetector(
                  onTap: () {
                    if (_editing) {
                      _saveChanges();
                    } else {
                      setState(() => _editing = true);
                    }
                  },
                  child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                      : Icon(_editing ? Icons.check_circle : Icons.edit_outlined,
                          color: AppColors.dark, size: 22),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status + date
                    Row(children: [
                      TagBadge(
                        label: status[0].toUpperCase() + status.substring(1).replaceAll('_', ' '),
                        color: status == 'approved' ? AppColors.lightGreen
                            : status == 'rejected' ? const Color(0xFFFFEBEE)
                            : AppColors.levelBadge,
                      ),
                      const SizedBox(width: 8),
                      Text('Submitted $date', style: AppTextStyles.caption),
                    ]),
                    const SizedBox(height: 16),

                    // Image
                    if (widget.submission['image_url'] != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(widget.submission['image_url'],
                          width: double.infinity, height: 160, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                      ),
                      const SizedBox(height: 16),
                    ],

                    _buildSection('BASIC INFO', [
                      _editRow('Recipe name', _nameController),
                      _editRow('Primary component', _componentController),
                      _editRow('Country', _countryController),
                    ]),

                    _buildSection('CLASSIFICATION', [
                      _editRow('Illness', _illnessController),
                      _editRow('Category', _categoryController),
                      _editRow('Sub-category', _subCategoryController),
                      _editRow('Symptoms', _symptomsController),
                      _editRow('Organ', _organController),
                    ]),

                    _buildSection('PREPARATION', [
                      _editRow('Ingredients', _ingredientsController, maxLines: 3),
                      _editRow('Plant part', _plantPartController),
                      _editRow('Prep type', _prepTypeController),
                      _editRow('Difficulty', _difficultyController),
                      _editRow('Prep time', _prepTimeController),
                    ]),

                    // Instructions
                    if (widget.submission['instructions'] != null) ...[
                      const SectionLabel('INSTRUCTIONS'),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: (widget.submission['instructions'] as List).asMap().entries.map((e) {
                            final step = e.value is Map ? e.value['text'] ?? '' : e.value.toString();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Container(
                                  width: 24, height: 24,
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                  child: Center(child: Text('${e.key + 1}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.dark))),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(step, style: AppTextStyles.body)),
                              ]),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    _buildSection('DETAILS', [
                      _editRow('Function', _functionController),
                      _editRow('Mechanism', _mechanismController),
                      _editRow('Main constituent', _constituentController),
                      _editRow('Cautions', _cautionsController, maxLines: 2),
                      _editRow('Clinical study URL', _clinicalUrlController),
                    ]),

                    const SizedBox(height: 20),

                    // Action buttons (only for pending/in_review)
                    if (status == 'pending' || status == 'in_review') ...[
                      Row(children: [
                        Expanded(child: ElevatedButton.icon(
                          onPressed: _approve,
                          icon: const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green, foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: OutlinedButton.icon(
                          onPressed: _showRejectDialog,
                          icon: const Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                          label: const Text('Reject', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            side: const BorderSide(color: Colors.red),
                          ),
                        )),
                      ]),
                    ],
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

  Widget _buildSection(String title, List<Widget> rows) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionLabel(title),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Column(children: rows),
      ),
      const SizedBox(height: 4),
    ]);
  }

  Widget _editRow(String label, TextEditingController controller, {int maxLines = 1}) {
    final value = controller.text;
    if (!_editing && value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: AppTextStyles.caption)),
        Expanded(
          child: _editing
              ? TextField(
                  controller: controller, maxLines: maxLines,
                  style: AppTextStyles.body,
                  decoration: const InputDecoration(
                    isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: UnderlineInputBorder(),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                )
              : Text(value, style: AppTextStyles.body),
        ),
      ]),
    );
  }
}
