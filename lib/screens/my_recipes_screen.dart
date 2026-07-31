import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import 'recipe_detail_screen.dart';

class MyRecipesScreen extends StatefulWidget {
  const MyRecipesScreen({super.key});

  @override
  State<MyRecipesScreen> createState() => _MyRecipesScreenState();
}

class _MyRecipesScreenState extends State<MyRecipesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _saved       = [];
  List<Map<String, dynamic>> _submissions = [];
  List<Map<String, dynamic>> _orders      = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final userId = SupabaseService.currentUser?.id;
      print('Loading data for user: $userId');
      final results = await Future.wait([
        SupabaseService.getSavedRemedies(),
        SupabaseService.getMySubmissions(),
        SupabaseService.getOrders(),
      ]);
      print('Saved: ${results[0].length}, Submissions: ${results[1].length}, Orders: ${results[2].length}');
      if (!mounted) return;
      setState(() {
        _saved       = results[0];
        _submissions = results[1];
        _orders      = results[2];
        _loading     = false;
      });
    } catch (e) {
      print('Error loading my recipes: $e');
      if (!mounted) return;
      setState(() => _loading = false);
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
            const YellowAppBar(title: 'My Recipes', subtitle: 'Favourites · Submissions · Orders'),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.dark,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicator: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: [
                    Tab(text: 'Favourites (${_saved.length})'),
                    Tab(text: 'Submissions (${_submissions.length})'),
                    Tab(text: 'Orders (${_orders.length})'),
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
                        _SavedTab(saved: _saved, onRefresh: _loadData),
                        _SubmissionsTab(submissions: _submissions, onRefresh: _loadData),
                        _OrdersTab(orders: _orders, onRefresh: _loadData),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Saved Tab ─────────────────────────────────────────────────────────────

class _SavedTab extends StatelessWidget {
  final List<Map<String, dynamic>> saved;
  final VoidCallback onRefresh;
  const _SavedTab({required this.saved, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (saved.isEmpty) {
      return _EmptyState(icon: Icons.bookmark_border, message: 'No favourites yet',
          hint: 'Tap the bookmark on any remedy to save it', onRefresh: onRefresh);
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: saved.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final item      = saved[i];
          final remedy    = item['remedies_full'] ?? item;
          final remedyId  = (remedy['id'] ?? item['remedy_id'])?.toString() ?? '';
          final name      = remedy['name'] ?? '';
          final component = remedy['component'] ?? '';
          final origin    = remedy['origin'] ?? '';
          final rating    = ((remedy['avg_user_rating'] ?? 0.0) as num).toDouble();
          final votes     = (remedy['total_votes'] ?? 0) as int;
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => RecipeDetailScreenDB(remedy: remedy))),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text(name, style: AppTextStyles.heading3, overflow: TextOverflow.ellipsis)),
                  Row(children: [
                    GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Remove saved remedy?', style: AppTextStyles.heading3),
                            content: Text('Remove "$name" from your saved recipes?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                                    foregroundColor: Colors.white, elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          await SupabaseService.unsaveRemedy(remedyId);
                          onRefresh();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.favorite, color: AppColors.primary, size: 20),
                  ]),
                ]),
                Text('$component${origin.isNotEmpty ? ' · $origin' : ''}', style: AppTextStyles.caption),
                const SizedBox(height: 6),
                StarRating(rating: rating, votes: votes),
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ── Submissions Tab ───────────────────────────────────────────────────────

class _SubmissionsTab extends StatelessWidget {
  final List<Map<String, dynamic>> submissions;
  final VoidCallback onRefresh;
  const _SubmissionsTab({required this.submissions, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (submissions.isEmpty) {
      return _EmptyState(icon: Icons.edit_note, message: 'No submissions yet',
          hint: 'Submit a remedy to share your knowledge', onRefresh: onRefresh);
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: submissions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final s = submissions[i];
          final status = s['status'] ?? 'pending';
          Color statusColor;
          switch (status) {
            case 'approved':  statusColor = AppColors.lightGreen; break;
            case 'rejected':  statusColor = const Color(0xFFFFEBEE); break;
            case 'in_review': statusColor = Colors.blue.shade50; break;
            default:          statusColor = AppColors.levelBadge;
          }
          return GestureDetector(
            onTap: status != 'approved' ? null : () {
              SupabaseService.getRemedies(search: s['recipe_name']).then((remedies) {
                if (remedies.isNotEmpty && context.mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => RecipeDetailScreenDB(remedy: remedies.first)));
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: status == 'approved' ? Border.all(color: AppColors.primary.withOpacity(0.4)) : null,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Text(s['recipe_name'] ?? '', style: AppTextStyles.heading3, overflow: TextOverflow.ellipsis)),
                  Row(children: [
                    TagBadge(
                      label: status[0].toUpperCase() + status.substring(1).replaceAll('_', ' '),
                      color: statusColor,
                    ),
                    // Show delete only for pending or rejected
                    if (status == 'pending' || status == 'rejected') ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              title: const Text('Delete submission?', style: AppTextStyles.heading3),
                              content: Text('Delete "${s['recipe_name']}"? This cannot be undone.'),
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
                          if (confirm == true && context.mounted) {
                            await SupabaseService.supabase
                                .from('remedy_submissions').delete().eq('id', s['id']);
                            onRefresh();
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        ),
                      ),
                    ],
                  ]),
                ]),
                const SizedBox(height: 4),
                Text('${s['primary_component'] ?? ''}${s['country'] != null ? ' · ${s['country']}' : ''}',
                    style: AppTextStyles.caption),
                const SizedBox(height: 4),
                Text('Submitted: ${s['submitted_at']?.toString().substring(0, 10) ?? ''}',
                    style: AppTextStyles.caption),
                if (s['review_notes'] != null && (s['review_notes'] as String).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.note_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(s['review_notes'], style: AppTextStyles.caption)),
                    ]),
                  ),
                ],
                if (status == 'approved') ...[
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Row(children: [
                      Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                      SizedBox(width: 4),
                      Text('Tap to view recipe', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ]),
                    GestureDetector(
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: const Text('Delete recipe?', style: AppTextStyles.heading3),
                            content: Text('Permanently delete "${s['recipe_name'] ?? s['name'] ?? ''}"? This cannot be undone.'),
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
                        if (confirm == true && context.mounted) {
                          try {
                            // Delete from remedies table if approved (has remedy_id)
                            final remedyId = s['remedy_id'];
                            if (remedyId != null) {
                              await SupabaseService.supabase
                                  .from('remedy_instructions').delete().eq('remedy_id', remedyId);
                              await SupabaseService.supabase
                                  .from('remedies').delete().eq('id', remedyId);
                            }
                            // Delete the submission record too
                            await SupabaseService.supabase
                                .from('remedy_submissions').delete().eq('id', s['id']);
                            onRefresh();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                            }
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.delete_outline, size: 14, color: Colors.red),
                          SizedBox(width: 4),
                          Text('Delete', style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ]),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }
}

// ── Orders Tab ────────────────────────────────────────────────────────────

class _OrdersTab extends StatelessWidget {
  final List<Map<String, dynamic>> orders;
  final VoidCallback onRefresh;
  const _OrdersTab({required this.orders, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return _EmptyState(icon: Icons.shopping_bag_outlined, message: 'No orders yet',
          hint: 'Your order history will appear here', onRefresh: onRefresh);
    }
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final o = orders[i];
          final status = o['status'] ?? 'paid';
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(o['order_number'] ?? '', style: AppTextStyles.heading3),
                TagBadge(
                  label: status[0].toUpperCase() + status.substring(1),
                  color: AppColors.lightGreen,
                  textColor: Colors.green.shade700,
                ),
              ]),
              const SizedBox(height: 4),
              Text('${o['created_at']?.toString().substring(0, 10) ?? ''} · R${o['total'] ?? '0'}',
                  style: AppTextStyles.caption),
            ]),
          );
        },
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String hint;
  final VoidCallback onRefresh;
  const _EmptyState({required this.icon, required this.message, required this.hint, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 48, color: AppColors.textSecondary),
        const SizedBox(height: 8),
        Text(message, style: AppTextStyles.heading3),
        const SizedBox(height: 4),
        Text(hint, style: AppTextStyles.caption, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        TextButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh, size: 16), label: const Text('Refresh')),
      ]),
    );
  }
}
