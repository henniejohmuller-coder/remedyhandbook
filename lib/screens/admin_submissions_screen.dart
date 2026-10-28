import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'admin_remedy_edit_screen.dart';

class AdminSubmissionsScreen extends StatefulWidget {
  const AdminSubmissionsScreen({super.key});

  @override
  State<AdminSubmissionsScreen> createState() => _AdminSubmissionsScreenState();
}

class _AdminSubmissionsScreenState extends State<AdminSubmissionsScreen> {
  List<Map<String, dynamic>> _submissions = [];
  bool _loading = true;
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.supabase
          .from('remedy_submissions')
          .select()
          .eq('status', _filter)
          .order('submitted_at', ascending: false);
      if (mounted) setState(() {
        _submissions = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve(Map<String, dynamic> sub) async {
    try {
      // Copy submission to remedies table
      final remedy = {
        'name':              sub['recipe_name'],
        'component':         sub['primary_component'],
        'illness_name':      sub['illness'],
        'category_name':     sub['category'],
        'sub_category_name': sub['sub_category'],
        'symptom_name':      sub['symptoms'],
        'organ_name':        sub['organ'],
        'origin':            sub['country'],
        'plant_part':        sub['plant_part'],
        'prep_type':         sub['prep_type'],
        'prep_time':         sub['prep_time'],
        'difficulty':        sub['difficulty'],
        'ingredients':       sub['ingredients'],
        'function':          sub['remedy_function'],
        'mechanism':         sub['mechanism'],
        'constituent':       sub['main_constituent'],
        'cautions':          sub['cautions'],
        'clinical_study_url': sub['clinical_study_url'],
        'image_url':         sub['image_url'],
        'encouragement':     sub['encouragement'],
        'tradition_rating':  sub['tradition_rating'],
        'validation_level':  sub['validation_level'],
        'filter_category':   sub['filter_category'],
        'filter_subcategory': sub['filter_subcategory'],
        'filter_illness':    sub['filter_illness'],
        'filter_symptoms':   sub['filter_symptoms'],
        'submitted_by':      sub['user_id'],
        'status':            'approved',
      };
      await SupabaseService.supabase.from('remedies').insert(remedy);
      await SupabaseService.supabase.from('remedy_submissions')
          .update({'status': 'approved', 'reviewed_at': DateTime.now().toIso8601String()})
          .eq('id', sub['id']);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remedy approved!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _reject(Map<String, dynamic> sub) async {
    try {
      await SupabaseService.supabase.from('remedy_submissions')
          .update({'status': 'rejected', 'reviewed_at': DateTime.now().toIso8601String()})
          .eq('id', sub['id']);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submission rejected')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    }
  }

  void _openNewRecipe() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => AdminRemedyEditScreen(remedy: {'status': 'pending', 'name': ''}, onSaved: () {}),
    )).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewRecipe,
        backgroundColor: AppColors.dark,
        foregroundColor: AppColors.primary,
        icon: const Icon(Icons.add),
        label: const Text('New Recipe', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const YellowAppBar(
              title: 'Submissions',
              subtitle: 'Review and approve submitted remedies',
              showBack: true,
            ),
            // Filter tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                _FilterTab('Pending', 'pending', _filter, (v) {
                  setState(() => _filter = v);
                  _load();
                }),
                const SizedBox(width: 8),
                _FilterTab('Approved', 'approved', _filter, (v) {
                  setState(() => _filter = v);
                  _load();
                }),
                const SizedBox(width: 8),
                _FilterTab('Rejected', 'rejected', _filter, (v) {
                  setState(() => _filter = v);
                  _load();
                }),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _submissions.isEmpty
                      ? Center(child: Text('No $_filter submissions',
                          style: const TextStyle(color: AppColors.textSecondary)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _submissions.length,
                          itemBuilder: (_, i) => _SubmissionCard(
                            sub: _submissions[i],
                            onApprove: _filter == 'pending' ? () => _approve(_submissions[i]) : null,
                            onReject: _filter == 'pending' ? () => _reject(_submissions[i]) : null,
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTab extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final ValueChanged<String> onTap;

  const _FilterTab(this.label, this.value, this.current, this.onTap);

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.dark : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(
            fontSize: 12,
            color: selected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final Map<String, dynamic> sub;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const _SubmissionCard({required this.sub, this.onApprove, this.onReject});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sub['recipe_name'] ?? 'Unnamed',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                  color: AppColors.dark)),
          const SizedBox(height: 4),
          Text('${sub['category'] ?? ''} â€º ${sub['illness'] ?? ''}',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          if (sub['submitted_at'] != null) ...[
            const SizedBox(height: 2),
            Text('Submitted: ${sub['submitted_at'].toString().substring(0, 10)}',
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
          if (onApprove != null || onReject != null) ...[
            const SizedBox(height: 10),
            Row(children: [
              if (onApprove != null)
                Expanded(child: ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dark,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Approve', style: TextStyle(fontSize: 12)),
                )),
              if (onApprove != null && onReject != null)
                const SizedBox(width: 8),
              if (onReject != null)
                Expanded(child: OutlinedButton(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Reject', style: TextStyle(fontSize: 12)),
                )),
            ]),
          ],
        ],
      ),
    );
  }
}
