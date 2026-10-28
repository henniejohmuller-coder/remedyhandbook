import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Reusable bidirectional 4-tier filter picker loaded from filter_matrix table.
/// Pre-populates from existing values and calls [onChanged] on every selection.
class FilterMatrixPicker extends StatefulWidget {
  final String? initialCategory;
  final String? initialSubcategory;
  final String? initialIllness;
  final List<String>? initialSymptoms;
  final void Function(
    String? category,
    String? subcategory,
    String? illness,
    List<String> symptoms,
  ) onChanged;

  const FilterMatrixPicker({
    super.key,
    this.initialCategory,
    this.initialSubcategory,
    this.initialIllness,
    this.initialSymptoms,
    required this.onChanged,
  });

  @override
  State<FilterMatrixPicker> createState() => _FilterMatrixPickerState();
}

class _FilterMatrixPickerState extends State<FilterMatrixPicker> {
  // ── All rows ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _allRows = [];
  bool _loading = true;

  // ── Current selections ────────────────────────────────────────────────────
  String? _selCategory;
  String? _selSubcategory;
  String? _selIllness;
  List<String> _selSymptoms = [];

  // ── Derived options ───────────────────────────────────────────────────────
  List<String> get _categories =>
      _sorted(_allRows.map((r) => r['category'].toString()).toSet());

  List<String> get _subcategories {
    var rows = _allRows;
    if (_selCategory != null)
      rows = rows.where((r) => r['category'] == _selCategory).toList();
    return _sorted(rows.map((r) => r['subcategory'].toString()).toSet());
  }

  List<String> get _illnesses {
    var rows = _allRows;
    if (_selCategory != null)
      rows = rows.where((r) => r['category'] == _selCategory).toList();
    if (_selSubcategory != null)
      rows = rows.where((r) => r['subcategory'] == _selSubcategory).toList();
    return _sorted(rows.map((r) => r['illness'].toString()).toSet());
  }

  List<String> get _symptoms {
    var rows = _allRows;
    if (_selCategory != null)
      rows = rows.where((r) => r['category'] == _selCategory).toList();
    if (_selSubcategory != null)
      rows = rows.where((r) => r['subcategory'] == _selSubcategory).toList();
    if (_selIllness != null)
      rows = rows.where((r) => r['illness'] == _selIllness).toList();
    return _sorted(rows.map((r) => r['symptom'].toString()).toSet());
  }

  List<String> _sorted(Set<String> items) =>
      items.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  @override
  void initState() {
    super.initState();
    _selCategory    = widget.initialCategory;
    _selSubcategory = widget.initialSubcategory;
    _selIllness     = widget.initialIllness;
    _selSymptoms    = List<String>.from(widget.initialSymptoms ?? []);
    _loadMatrix();
  }

  Future<void> _loadMatrix() async {
    try {
      final List<Map<String, dynamic>> all = [];
      int from = 0;
      while (true) {
        final page = await SupabaseService.supabase
            .from('filter_matrix')
            .select('category, subcategory, illness, symptom')
            .order('category').order('subcategory').order('illness').order('symptom')
            .range(from, from + 999);
        final list = List<Map<String, dynamic>>.from(page);
        all.addAll(list);
        if (list.length < 1000) break;
        from += 1000;
      }
      if (!mounted) return;
      setState(() { _allRows = all; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notify() => widget.onChanged(
      _selCategory, _selSubcategory, _selIllness, _selSymptoms);

  void _onCategoryChanged(String? val) {
    setState(() {
      _selCategory    = val;
      _selSubcategory = null;
      _selIllness     = null;
      _selSymptoms    = [];
    });
    _notify();
  }

  void _onSubcategoryChanged(String? val) {
    setState(() {
      _selSubcategory = val;
      _selIllness     = null;
      _selSymptoms    = [];
    });
    _notify();
  }

  void _onIllnessChanged(String? val) {
    setState(() {
      _selIllness  = val;
      _selSymptoms = [];
    });
    _notify();
  }

  void _toggleSymptom(String sym) {
    setState(() {
      if (_selSymptoms.contains(sym)) {
        _selSymptoms.remove(sym);
      } else {
        _selSymptoms.add(sym);
      }
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ─────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.dark,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(children: [
            Icon(Icons.search, color: AppColors.primary, size: 16),
            SizedBox(width: 8),
            Text('Filter Matrix', style: TextStyle(
                color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(height: 10),

        // ── Category ───────────────────────────────────────────────────────
        _FmDropdown(
          label: 'Filter Category',
          value: _selCategory,
          items: _categories,
          onChanged: _onCategoryChanged,
        ),
        const SizedBox(height: 8),

        // ── Subcategory ────────────────────────────────────────────────────
        _FmDropdown(
          label: 'Filter Subcategory',
          value: _selSubcategory,
          items: _subcategories,
          onChanged: _onSubcategoryChanged,
          enabled: _categories.isNotEmpty,
        ),
        const SizedBox(height: 8),

        // ── Illness ────────────────────────────────────────────────────────
        _FmDropdown(
          label: 'Filter Illness',
          value: _selIllness,
          items: _illnesses,
          onChanged: _onIllnessChanged,
          enabled: _selSubcategory != null,
        ),
        const SizedBox(height: 8),

        // ── Symptoms ───────────────────────────────────────────────────────
        if (_selIllness != null && _symptoms.isNotEmpty) ...[
          const Text('Filter Symptoms',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _symptoms.map((sym) {
              final selected = _selSymptoms.contains(sym);
              return GestureDetector(
                onTap: () => _toggleSymptom(sym),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.dark : Colors.white,
                    border: Border.all(
                      color: selected ? AppColors.primary : Colors.grey.shade300,
                      width: selected ? 1.5 : 0.5,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(sym,
                      style: TextStyle(
                        fontSize: 11,
                        color: selected ? AppColors.primary : AppColors.dark,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      )),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 4),
          if (_selSymptoms.isNotEmpty)
            Text('${_selSymptoms.length} symptom${_selSymptoms.length == 1 ? '' : 's'} selected',
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],

        // ── Clear button ───────────────────────────────────────────────────
        if (_selCategory != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _selCategory = _selSubcategory = _selIllness = null;
                _selSymptoms = [];
              });
              _notify();
            },
            child: const Text('Clear filter selections',
                style: TextStyle(fontSize: 11, color: Colors.red,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }
}

// ── Dropdown helper ───────────────────────────────────────────────────────────
class _FmDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  const _FmDropdown({
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
        color: enabled ? Colors.white : Colors.grey.shade50,
        border: Border.all(
          color: effectiveValue != null ? AppColors.primary : Colors.grey.shade300,
          width: effectiveValue != null ? 1.5 : 0.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: effectiveValue,
          isExpanded: true,
          isDense: true,
          hint: Text(label,
              style: TextStyle(fontSize: 12,
                  color: enabled ? AppColors.textSecondary : Colors.grey.shade400)),
          style: const TextStyle(fontSize: 12, color: AppColors.dark),
          icon: Icon(Icons.keyboard_arrow_down, size: 16,
              color: enabled ? AppColors.dark : Colors.grey.shade400),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('— $label —',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
            ...items.map((item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: enabled ? onChanged : null,
          selectedItemBuilder: (_) => [
            Text('— $label —',
                style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
            ...items.map((item) => Text(item,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
