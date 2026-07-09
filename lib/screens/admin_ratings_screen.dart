import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';

class AdminRatingsScreen extends StatefulWidget {
  const AdminRatingsScreen({super.key});

  @override
  State<AdminRatingsScreen> createState() => _AdminRatingsScreenState();
}

class _AdminRatingsScreenState extends State<AdminRatingsScreen> {
  List<Map<String, dynamic>> _remedies = [];
  bool _loading = true;
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.supabase
          .from('remedies')
          .select('id, name, component, tradition_rating, validation_level, efficacy, avg_user_rating, total_votes')
          .eq('status', 'approved')
          .order('name');
      setState(() {
        _remedies = (data as List).cast<Map<String, dynamic>>();
        _loading  = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.isEmpty) return _remedies;
    return _remedies.where((r) =>
        (r['name'] ?? '').toString().toLowerCase().contains(_search.toLowerCase()) ||
        (r['component'] ?? '').toString().toLowerCase().contains(_search.toLowerCase())
    ).toList();
  }

  void _openEditor(Map<String, dynamic> remedy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RatingsEditor(
        remedy: remedy,
        onSaved: () { Navigator.pop(context); _load(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          const YellowAppBar(
            title: 'Manage Ratings',
            subtitle: 'Traditional · Validation · Efficacy',
            showBack: true,
          ),
          const SizedBox(height: 12),

          // Info banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.lightYellow, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.dark),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'User ratings are auto-calculated from reviews.\nSet Traditional, Validation and Efficacy manually.',
                  style: TextStyle(fontSize: 12, color: AppColors.dark),
                )),
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Search remedies...',
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                  suffixIcon: _search.isNotEmpty
                      ? GestureDetector(
                          onTap: () { _searchController.clear(); setState(() => _search = ''); },
                          child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary))
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final r = _filtered[i];
                        final tradition  = (r['tradition_rating'] ?? 0) as int;
                        final validation = (r['validation_level'] ?? 1) as int;
                        final efficacy   = (r['efficacy'] ?? 0) as int;
                        final avgRating  = ((r['avg_user_rating'] ?? 0.0) as num).toDouble();
                        final votes      = (r['total_votes'] ?? 0) as int;

                        return GestureDetector(
                          onTap: () => _openEditor(r),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white, borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Expanded(child: Text(r['name'] ?? '',
                                    style: AppTextStyles.heading3, overflow: TextOverflow.ellipsis)),
                                const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                              ]),
                              Text(r['component'] ?? '', style: AppTextStyles.caption),
                              const SizedBox(height: 8),
                              // Ratings row
                              Row(children: [
                                _RatingChip(label: 'Traditional', value: '$tradition/5', color: AppColors.levelBadge),
                                const SizedBox(width: 6),
                                _RatingChip(label: 'Validation', value: '$validation/5', color: AppColors.lightGreen),
                                const SizedBox(width: 6),
                                _RatingChip(label: 'Efficacy', value: efficacy > 0 ? '$efficacy%' : '-', color: const Color(0xFFE3F2FD)),
                              ]),
                              const SizedBox(height: 6),
                              Row(children: [
                                const Icon(Icons.star, size: 14, color: AppColors.starColor),
                                const SizedBox(width: 4),
                                Text('${avgRating.toStringAsFixed(1)} ($votes reviews)',
                                    style: AppTextStyles.caption),
                              ]),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _RatingChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
      child: Column(children: [
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.dark)),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
      ]),
    );
  }
}

// ── Ratings Editor Bottom Sheet ───────────────────────────────────────────

class _RatingsEditor extends StatefulWidget {
  final Map<String, dynamic> remedy;
  final VoidCallback onSaved;
  const _RatingsEditor({required this.remedy, required this.onSaved});

  @override
  State<_RatingsEditor> createState() => _RatingsEditorState();
}

class _RatingsEditorState extends State<_RatingsEditor> {
  bool _saving = false;
  int _tradition  = 0;
  int _validation = 1;
  int _efficacy   = 0;
  double _avgRating = 0;
  int _votes = 0;

  @override
  void initState() {
    super.initState();
    _tradition  = (widget.remedy['tradition_rating'] ?? 0) as int;
    _validation = (widget.remedy['validation_level'] ?? 1) as int;
    _efficacy   = (widget.remedy['efficacy'] ?? 0) as int;
    _avgRating  = ((widget.remedy['avg_user_rating'] ?? 0.0) as num).toDouble();
    _votes      = (widget.remedy['total_votes'] ?? 0) as int;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SupabaseService.supabase.from('remedies').update({
        'tradition_rating': _tradition,
        'validation_level': _validation,
        'efficacy':         _efficacy,
        'updated_at':       DateTime.now().toIso8601String(),
      }).eq('id', widget.remedy['id']);
      widget.onSaved();
    } catch (e) {
      setState(() => _saving = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text(widget.remedy['name'] ?? '', style: AppTextStyles.heading2),
        Text(widget.remedy['component'] ?? '', style: AppTextStyles.caption),
        const SizedBox(height: 20),

        // User rating (read-only)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.people_outline, size: 20, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('User Rating (auto-calculated)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 4),
              Row(children: [
                ...List.generate(5, (i) => Icon(
                  i < _avgRating.round() ? Icons.star : Icons.star_border,
                  size: 18, color: AppColors.starColor)),
                const SizedBox(width: 6),
                Text('${_avgRating.toStringAsFixed(1)} · $_votes reviews',
                    style: AppTextStyles.caption),
              ]),
            ])),
          ]),
        ),
        const SizedBox(height: 16),

        // Traditional rating
        _buildSlider('Traditional Rating', '(Cultural / historical use)', _tradition, 5,
            onChanged: (v) => setState(() => _tradition = v),
            color: AppColors.levelBadge),
        const SizedBox(height: 16),

        // Validation level
        _buildSlider('Validation Level', '(Scientific evidence)', _validation, 5,
            onChanged: (v) => setState(() => _validation = v),
            color: AppColors.lightGreen),
        const SizedBox(height: 16),

        // Efficacy
        _buildSlider('Efficacy %', '(Reported effectiveness)', _efficacy, 100,
            onChanged: (v) => setState(() => _efficacy = v),
            color: const Color(0xFFE3F2FD),
            isPercent: true),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                : const Text('Save ratings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ])),
    );
  }

  Widget _buildSlider(String title, String subtitle, int value, int max,
      {required ValueChanged<int> onChanged, required Color color, bool isPercent = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.heading3),
          Text(subtitle, style: AppTextStyles.caption),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
          child: Text(isPercent ? '$value%' : '$value / $max',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dark)),
        ),
      ]),
      const SizedBox(height: 8),
      Slider(
        value: value.toDouble(),
        min: 0,
        max: max.toDouble(),
        divisions: max,
        activeColor: AppColors.primary,
        inactiveColor: Colors.grey.shade200,
        onChanged: (v) => onChanged(v.round()),
      ),
      // Visual dots for 0-5 scale
      if (!isPercent)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(max + 1, (i) => Text('$i',
                style: TextStyle(fontSize: 11, color: i == value ? AppColors.dark : AppColors.textSecondary,
                    fontWeight: i == value ? FontWeight.bold : FontWeight.normal)))),
    ]);
  }
}
