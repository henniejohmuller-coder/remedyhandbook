import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import 'admin_remedy_edit_screen.dart';

class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key});

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _pending   = [];
  List<Map<String, dynamic>> _inReview  = [];
  List<Map<String, dynamic>> _approved  = [];
  List<Map<String, dynamic>> _rejected  = [];
  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getSubmissionsForReview(),
        SupabaseService.supabase.from('remedies_full').select('*, remedy_instructions(*)').eq('status', 'approved'),
        SupabaseService.supabase.from('remedies').select('*, remedy_instructions(*)').eq('status', 'rejected'),
        SupabaseService.supabase.from('remedies').select('*, remedy_instructions(*)').eq('status', 'pending'),
        SupabaseService.supabase.from('remedies').select('*, remedy_instructions(*)').eq('status', 'in_review'),
      ]);

      final submissions      = results[0] as List<Map<String, dynamic>>;
      final approvedRemedies = (results[1] as List).cast<Map<String, dynamic>>();
      final rejectedRemedies = (results[2] as List).cast<Map<String, dynamic>>();
      final pendingRemedies  = (results[3] as List).cast<Map<String, dynamic>>();
      final inReviewRemedies = (results[4] as List).cast<Map<String, dynamic>>();

      setState(() {
        _pending  = [...submissions.where((s) => s['status'] == 'pending'), ...pendingRemedies];
        _inReview = [...submissions.where((s) => s['status'] == 'in_review'), ...inReviewRemedies];
        _approved = approvedRemedies;
        _rejected = [...submissions.where((s) => s['status'] == 'rejected'), ...rejectedRemedies];
        _loading  = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  // Convert submission to remedy-like map for edit screen
  Map<String, dynamic> _toRemedyMap(Map<String, dynamic> s) {
    if (!s.containsKey('recipe_name')) return s;
    return {
      'id':               s['id'],
      'name':             s['recipe_name'] ?? '',
      'component':        s['primary_component'] ?? '',
      'origin':           s['country'],
      'function':         s['remedy_function'],
      'mechanism':        s['mechanism'],
      'constituent':      s['main_constituent'],
      'plant_part':       s['plant_part'],
      'prep_type':        s['prep_type'],
      'difficulty':       s['difficulty'],
      'prep_time':        s['prep_time'],
      'servings':         s['servings'],
      'ingredients':      s['ingredients'],
      'dosage':           s['dosage'],
      'tip':              s['tip'],
      'cautions':         s['cautions'],
      'clinical_study_url': s['clinical_study_url'],
      'efficacy_ref':     s['efficacy_ref'],
      'tradition_rating': s['tradition_rating'] ?? 0,
      'validation_level': s['validation_level'] ?? 1,
      'efficacy':         s['efficacy'] ?? 0,
      'encouragement':    s['encouragement'],
      'image_url':        s['image_url'],
      'status':           s['status'] ?? 'pending',
      'illness_name':     s['illness'],
      'category_name':    s['category'],
      'sub_category_name': s['sub_category'],
      'symptom_name':     s['symptoms'],
      'organ_name':       s['organ'],
      'user_id':          s['user_id'],
      'remedy_instructions': s['instructions'] is List
          ? (s['instructions'] as List).asMap().entries.map((e) {
              final item = e.value;
              return {
                'step_number': item is Map ? (item['step'] ?? e.key + 1) : e.key + 1,
                'instruction': item is Map ? (item['text'] ?? '') : item.toString(),
              };
            }).toList()
          : [],
      '_is_submission': true,
    };
  }

  void _openEditScreen(Map<String, dynamic> s) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AdminRemedyEditScreen(
        remedy: _toRemedyMap(s),
        onSaved: _loadData,
      ),
    ));
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> list, {bool isRemedy = false}) {
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((item) {
      // Search across every meaningful field in the remedy/submission
      final fields = [
        item['name'],
        item['recipe_name'],
        item['component'],
        item['primary_component'],
        item['illness_name'],
        item['illness'],
        item['category_name'],
        item['category'],
        item['sub_category_name'],
        item['sub_category'],
        item['symptom_name'],
        item['symptoms'],
        item['organ_name'],
        item['organ'],
        item['origin'],
        item['country'],
        item['type'],
        item['plant_part'],
        item['prep_type'],
        item['difficulty'],
        item['function'],
        item['mechanism'],
        item['constituent'],
        item['ingredients'],
        item['dosage'],
        item['tip'],
        item['encouragement'],
        item['submitted_by'],
        item['approved_by'],
      ];
      return fields.any((f) => (f ?? '').toString().toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const YellowAppBar(title: 'Admin review', subtitle: 'Manage all remedies', showBack: true),

            // Stats row
            if (!_loading)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(children: [
                  _StatChip(value: '${_pending.length}',  label: 'Pending',   color: AppColors.primary,         onTap: () => _tabController.animateTo(0)),
                  const SizedBox(width: 8),
                  _StatChip(value: '${_inReview.length}', label: 'In review', color: Colors.blue.shade100,       onTap: () => _tabController.animateTo(1)),
                  const SizedBox(width: 8),
                  _StatChip(value: '${_approved.length}', label: 'Approved',  color: AppColors.lightGreen,       onTap: () => _tabController.animateTo(2)),
                  const SizedBox(width: 8),
                  _StatChip(value: '${_rejected.length}', label: 'Rejected',  color: const Color(0xFFFFEBEE),    onTap: () => _tabController.animateTo(3)),
                ]),
              ),
            const SizedBox(height: 12),

            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search remedies...',
                    hintStyle: AppTextStyles.caption,
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? GestureDetector(
                            onTap: () { _searchController.clear(); setState(() => _searchQuery = ''); },
                            child: const Icon(Icons.close, size: 18, color: AppColors.textSecondary))
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Tab bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.dark,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  tabs: [
                    Tab(text: 'Pending (${_pending.length})'),
                    Tab(text: 'In review (${_inReview.length})'),
                    Tab(text: 'Approved (${_approved.length})'),
                    Tab(text: 'Rejected (${_rejected.length})'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        // Pending
                        _ItemList(items: _filter(_pending), onRefresh: _loadData, onTap: _openEditScreen),
                        // In review
                        _ItemList(items: _filter(_inReview), onRefresh: _loadData, onTap: _openEditScreen),
                        // Approved
                        _ItemList(items: _filter(_approved, isRemedy: true), onRefresh: _loadData, onTap: _openEditScreen, isRemedy: true),
                        // Rejected
                        _ItemList(items: _filter(_rejected), onRefresh: _loadData, onTap: _openEditScreen),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item List (used for all tabs) ─────────────────────────────────────────

class _ItemList extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback onRefresh;
  final Function(Map<String, dynamic>) onTap;
  final bool isRemedy;

  const _ItemList({
    required this.items,
    required this.onRefresh,
    required this.onTap,
    this.isRemedy = false,
  });

  Future<void> _confirmDelete(BuildContext context, Map<String, dynamic> item) async {
    final isSubmission = item.containsKey('recipe_name');
    final name = isSubmission ? (item['recipe_name'] ?? 'this item') : (item['name'] ?? 'this item');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete?', style: AppTextStyles.heading3),
        content: Text('Are you sure you want to delete "$name"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (isSubmission) {
          await SupabaseService.supabase.from('remedy_submissions').delete().eq('id', item['id']);
        } else {
          await SupabaseService.supabase.from('remedies').delete().eq('id', item['id']);
        }
        onRefresh();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Deleted successfully'), backgroundColor: Colors.green,
                duration: Duration(seconds: 2)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_outline, size: 48, color: AppColors.textSecondary),
        const SizedBox(height: 8),
        const Text('Nothing here', style: AppTextStyles.caption),
        const SizedBox(height: 12),
        TextButton.icon(onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
      ]));
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final item   = items[i];
          final isSubmission = item.containsKey('recipe_name');
          final name   = isSubmission ? (item['recipe_name'] ?? '') : (item['name'] ?? '');
          final comp   = isSubmission ? (item['primary_component'] ?? '') : (item['component'] ?? '');
          final status = item['status'] ?? 'pending';
          final date   = (item['submitted_at'] ?? item['updated_at'] ?? item['created_at'])?.toString().substring(0, 10) ?? '';

          Color statusColor;
          switch (status) {
            case 'approved':  statusColor = AppColors.lightGreen; break;
            case 'rejected':  statusColor = const Color(0xFFFFEBEE); break;
            case 'in_review': statusColor = Colors.blue.shade50; break;
            default:          statusColor = AppColors.levelBadge;
          }

          return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name.isNotEmpty ? name : 'Unnamed',
                      style: AppTextStyles.heading3, softWrap: true, overflow: TextOverflow.visible),
                  if (comp.isNotEmpty) Text(comp, style: AppTextStyles.caption),
                  if (date.isNotEmpty) Text(date, style: AppTextStyles.caption),
                ])),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  TagBadge(
                    label: status[0].toUpperCase() + status.substring(1).replaceAll('_', ' '),
                    color: statusColor,
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    GestureDetector(
                      onTap: () => onTap(item),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.edit_outlined, size: 15, color: AppColors.dark),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => _confirmDelete(context, item),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.delete_outline, size: 15, color: Colors.red),
                      ),
                    ),
                  ]),
                ]),
              ]),
            );
        },
      ),
    );
  }
}

// ── Stat Chip ─────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _StatChip({required this.value, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Column(children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.dark)),
            Text(label, style: AppTextStyles.caption),
            const Icon(Icons.arrow_forward_ios, size: 10, color: AppColors.textSecondary),
          ]),
        ),
      ),
    );
  }
}
