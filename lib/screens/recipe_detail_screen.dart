import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/navigation_guard.dart';
import '../models/models.dart';
import '../services/supabase_service.dart';
import 'preparation_screen.dart';
import 'product_detail_screen.dart';
import 'recipes_screen.dart';
import 'admin_remedy_edit_screen.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Remedy remedy;
  const RecipeDetailScreen({super.key, required this.remedy});

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  int _selectedRating = 0;
  bool _submitted = false;
  final TextEditingController _reviewController = TextEditingController();
  final List<String> _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  Remedy get remedy => widget.remedy;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  void _goToProduct(BuildContext context, bool isHerb) {
    final product = sampleProducts.firstWhere(
      (p) => p.linkedRemedy == remedy.name &&
             (isHerb ? p.type.contains('Raw herb') : p.type.contains('remedy')),
      orElse: () => sampleProducts.first,
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            YellowAppBar(
              title: remedy.name,
              subtitle: '${remedy.herb} · ${remedy.origin}',
              showBack: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Herb image
                    const HerbIconPlaceholder(size: 120, icon: Icons.eco),
                    const SizedBox(height: 12),
                    // Rating
                    Row(children: [
                      StarRating(rating: remedy.rating, votes: remedy.votes),
                      const SizedBox(width: 8),
                      if (remedy.efficacy > 0)
                        Text('· ${remedy.efficacy}%', style: AppTextStyles.caption),
                    ]),
                    const SizedBox(height: 16),
                    // Buy buttons card
                    Builder(builder: (context) {
                      final herb = sampleProducts.firstWhere(
                        (p) => p.linkedRemedy == remedy.name && p.type.contains('Raw herb'),
                        orElse: () => sampleProducts.first,
                      );
                      final remedyProduct = sampleProducts.firstWhere(
                        (p) => p.linkedRemedy == remedy.name && p.type.contains('remedy'),
                        orElse: () => sampleProducts[1],
                      );
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.dark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _BuyCard(
                                title: 'Buy Herb',
                                subtitle: '${remedy.herb}\n${herb.type.replaceAll('Raw herb · ', '')}',
                                price: 'R${herb.price.toInt()}',
                                onTap: () => _goToProduct(context, true),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _BuyCard(
                                title: 'Buy Remedy',
                                subtitle: 'Pre-made\nremedy',
                                price: 'R${remedyProduct.price.toInt()}',
                                isYellow: true,
                                onTap: () => _goToProduct(context, false),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    // Added to cart banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.lightGreen,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        const SizedBox(width: 8),
                        const Text('Added to cart!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13)),
                      ]),
                    ),
                    // Overview
                    const SectionLabel('OVERVIEW'),
                    _infoCard([
                      InfoRow(label: 'Function', value: remedy.function),
                      InfoRow(label: 'Mechanism', value: remedy.mechanism),
                      InfoRow(label: 'Constituent', value: remedy.constituent),
                    ]),
                    // Preparation
                    const SectionLabel('PREPARATION'),
                    _infoCard([
                      InfoRow(label: 'Prep type', value: remedy.prepType),
                      InfoRow(label: 'Difficulty', valueWidget: TagBadge(label: remedy.difficulty, color: AppColors.lightGreen, textColor: Colors.green.shade700)),
                      InfoRow(label: 'Prep time', value: remedy.prepTimeDisplay),
                    ]),
                    const SizedBox(height: 10),
                    // Preparation guide button — right under preparation block
                    OutlinedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PreparationScreen(remedy: remedy))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.list_alt_outlined, size: 16, color: AppColors.dark),
                          SizedBox(width: 8),
                          Text('View preparation guide', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    // Evidence
                    const SectionLabel('EVIDENCE'),
                    _infoCard([
                      InfoRow(
                        label: 'Traditional use',
                        valueWidget: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...List.generate(5, (i) => Icon(
                              i < remedy.traditionRating ? Icons.star : Icons.star_border,
                              size: 14,
                              color: i < remedy.traditionRating ? AppColors.starColor : Colors.grey.shade300,
                            )),
                            const SizedBox(width: 4),
                            Text('${remedy.traditionRating}/5', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      InfoRow(
                        label: 'Validation',
                        valueWidget: TagBadge(label: 'Level ${remedy.validationLevel}', color: AppColors.levelBadge),
                      ),
                      InfoRow(label: 'Efficacy', value: remedy.efficacy > 0 ? '${remedy.efficacy}%' : '-'),
                    ]),
                    const SizedBox(height: 8),
                    // Static model — clinical study text in black
                    const Text(
                      'Clinical study reference available',
                      style: TextStyle(fontSize: 12, color: Colors.black),
                    ),
                    if (remedy.avoidInPregnancy) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
                        child: const Row(children: [
                          Icon(Icons.warning_amber, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Text('Avoid in pregnancy.', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                    // Community reviews
                    const SectionLabel('COMMUNITY REVIEWS'),
                    if (_submitted)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 36),
                          const SizedBox(height: 8),
                          const Text('Thank you for your review!', style: AppTextStyles.heading3),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) => Icon(
                              i < _selectedRating ? Icons.star : Icons.star_border,
                              color: AppColors.starColor, size: 22,
                            )),
                          ),
                        ]),
                      )
                    else ...[
                      const Text('Rate this remedy', style: AppTextStyles.body),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ...List.generate(5, (i) => GestureDetector(
                            onTap: () => setState(() => _selectedRating = i + 1),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Icon(
                                i < _selectedRating ? Icons.star : Icons.star_border,
                                color: i < _selectedRating ? AppColors.starColor : Colors.grey.shade300,
                                size: 32,
                              ),
                            ),
                          )),
                          const SizedBox(width: 8),
                          if (_selectedRating > 0)
                            Text(_labels[_selectedRating],
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _reviewController,
                        decoration: InputDecoration(
                          hintText: 'Share experience...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Submit review',
                        onPressed: _selectedRating == 0 ? () {} : () {
                          SupabaseService.submitReview(
                            remedyId: widget.remedy.id,
                            rating: _selectedRating,
                            comment: '',
                          ).then((_) {
                            if (mounted) setState(() => _submitted = true);
                          }).catchError((e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                            }
                          });
                        },
                      ),
                      if (_selectedRating == 0)
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Center(child: Text('Tap a star to rate', style: AppTextStyles.caption)),
                        ),
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

  Widget _infoCard(List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(children: rows),
    );
  }
}


// ── Shop product card (recipe detail — up to 3 per type) ─────────────────────
class _ShopProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool isYellow;
  final VoidCallback onTap;

  const _ShopProductCard({
    required this.product,
    required this.isYellow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name     = product['name']?.toString() ?? '';
    final price    = ((product['price'] ?? 0) as num).toInt();
    final imageUrl = product['image_url']?.toString() ?? '';
    final type     = product['type']?.toString() ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isYellow ? AppColors.primary : AppColors.dark, width: 1.2),
        ),
        child: Column(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, height: 56, width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const HerbIconPlaceholder(size: 56))
                : const HerbIconPlaceholder(size: 56),
          ),
          const SizedBox(height: 4),
          Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
          Text('R$price', style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isYellow ? AppColors.primary : AppColors.dark,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              type == 'Component' ? 'Buy Component' : 'Buy Remedy',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isYellow ? AppColors.dark : AppColors.primary,
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _BuyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final bool isYellow;
  final VoidCallback onTap;

  const _BuyCard({required this.title, required this.subtitle, required this.price, this.isYellow = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isYellow ? AppColors.primary : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isYellow ? AppColors.dark : Colors.white)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: isYellow ? AppColors.dark.withOpacity(0.7) : Colors.white70, height: 1.3)),
            const SizedBox(height: 4),
            Text(price, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isYellow ? AppColors.dark : Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DB VERSION — uses Map<String, dynamic> from Supabase
// ═══════════════════════════════════════════════════════════════════════════

class RecipeDetailScreenDB extends StatefulWidget {
  final Map<String, dynamic> remedy;
  const RecipeDetailScreenDB({super.key, required this.remedy});

  @override
  State<RecipeDetailScreenDB> createState() => _RecipeDetailScreenDBState();
}

class _RecipeDetailScreenDBState extends State<RecipeDetailScreenDB> {
  int _selectedRating = 0;
  bool _submitted = false;
  bool _hasComponent = false;
  bool _hasRemedy = false;
  List<Map<String,dynamic>> _linkedComponents = [];
  List<Map<String,dynamic>> _linkedRemedies   = [];
  bool _isEditing = false;
  String? _existingReviewId;
  int     _reviewTab      = 0;   // 0 = write review, 1 = all reviews
  List    _allReviews     = [];
  bool    _reviewsLoading = false;
  late Map<String, dynamic> _remedy;
  bool _isAdmin           = false;
  bool _remedyInitialized = false;
  bool _instructionsLoaded = false;
  List<String> _instructions = [];
  DateTime _lastReload    = DateTime.fromMillisecondsSinceEpoch(0);
  final TextEditingController _reviewController = TextEditingController();
  final List<String> _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void initState() {
    super.initState();
    _remedy = Map<String, dynamic>.from(widget.remedy);
    _remedyInitialized = true;
    _checkProducts();
    _loadExistingReview();
    _checkAdmin();
    _loadInstructions();
    Future.microtask(() => _reloadRemedy());
  }

  Future<void> _loadInstructions() async {
    if (_instructionsLoaded) return;
    _instructionsLoaded = true;
    try {
      final remedyId = _remedy['id']?.toString();
      if (remedyId == null) return;
      final data = await SupabaseService.supabase
          .from('remedy_instructions')
          .select()
          .eq('remedy_id', remedyId)
          .order('step_number', ascending: true);
      if (mounted) {
        // Deduplicate by step_number — keep first occurrence only
        final seen = <int>{};
        final deduped = (data as List).where((s) {
          final n = (s['step_number'] ?? 0) as int;
          return seen.add(n);
        }).toList();
        setState(() {
          _instructions = deduped
              .map((s) => s['instruction']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
        });
      }
    } catch (_) {
      final raw = _remedy['remedy_instructions'];
      if (raw != null && mounted) {
        final list = List.from(raw as List)
          ..sort((a, b) => ((a['step_number'] ?? 0) as int).compareTo((b['step_number'] ?? 0) as int));
        final seen = <int>{};
        setState(() => _instructions = list
            .where((s) => seen.add((s['step_number'] ?? 0) as int))
            .map((s) => s['instruction']?.toString() ?? '')
            .toList());
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Intentionally empty — initState microtask handles initial load.
    // Reloading here cascades rebuilds to PreparationScreenDB causing duplicate steps.
  }

  Future<void> _reloadRemedy() async {
    try {
      final remedyId = _remedy['id'];
      if (remedyId == null) return;
      final data = await SupabaseService.supabase
          .from('remedies')
          .select()
          .eq('id', remedyId)
          .single();
      if (mounted) setState(() => _remedy = {..._remedy, ...data});
    } catch (e) {
      print('reloadRemedy error: $e');
    }
  }

  Future<void> _checkAdmin() async {
    final user = SupabaseService.supabase.auth.currentUser;
    if (user == null) return;
    final admin = await SupabaseService.isAdmin(user.id);
    if (mounted) setState(() => _isAdmin = admin);
  }

  Future<void> _loadExistingReview() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;
      final remedyId = _remedy['id'];
      final data = await SupabaseService.supabase
          .from('remedy_reviews')
          .select()
          .eq('remedy_id', remedyId)
          .eq('user_id', userId)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _existingReviewId = data['id']?.toString();
          _selectedRating   = (data['rating'] ?? 0) as int;
          _reviewController.text = data['comment'] ?? '';
          _submitted = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAllReviews() async {
    if (_reviewsLoading) return;
    setState(() => _reviewsLoading = true);
    try {
      final remedyId = _remedy['id'];
      final data = await SupabaseService.supabase
          .from('remedy_reviews')
          .select('rating, comment, created_at, user_id')
          .eq('remedy_id', remedyId)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) setState(() {
        _allReviews     = data as List;
        _reviewsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _submitReview() async {
    try {
      await SupabaseService.submitReview(
        remedyId: _remedy['id'].toString(),
        rating: _selectedRating,
        comment: _reviewController.text.trim(),
      );
      setState(() { _submitted = true; _isEditing = false; });
      // Reload fresh data after RPC completes
      final fresh = await SupabaseService.supabase
          .from('remedies')
          .select()
          .eq('id', _remedy['id'])
          .single();
      if (mounted) setState(() => _remedy = {..._remedy, ...fresh});
      RecipesScreen.reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Review saved!'),
              backgroundColor: Colors.green, duration: Duration(seconds: 2)));
      }
    } catch (e) {
      print('submitReview error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving review: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _checkProducts() async {
    try {
      final remedyId = _remedy['id']?.toString() ?? '';
      if (remedyId.isEmpty) return;
      // Query directly — getProducts() may filter out already-linked items
      final data = await SupabaseService.supabase
          .from('products')
          .select()
          .eq('linked_remedy_id', remedyId)
          .order('name', ascending: true);
      final all = (data as List).cast<Map<String, dynamic>>();
      setState(() {
        _linkedComponents = all.where((p) => p['type'] == 'Component').toList();
        _linkedRemedies   = all.where((p) => p['type'] == 'Remedy').toList();
        _hasComponent     = _linkedComponents.isNotEmpty;
        _hasRemedy        = _linkedRemedies.isNotEmpty;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _goToProduct(BuildContext context, bool isHerb) async {
    try {
      final remedyId = _remedy['id']?.toString() ?? '';
      final products = await SupabaseService.getProducts();
      final linked = products.where(
        (p) => p['linked_remedy_id']?.toString() == remedyId &&
               (isHerb ? p['type'] == 'Component' : p['type'] == 'Remedy'),
      ).toList();
      if (linked.isNotEmpty && context.mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ProductDetailScreenDB(
            product: linked.first,
            linkedRemedyId: _remedy['id']?.toString(),
          )));
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isHerb ? 'No component product linked yet.' : 'No remedy product linked yet.'),
          backgroundColor: AppColors.dark,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String get name       => _remedy['name'] ?? '';
  String get component  => _remedy['component'] ?? '';
  String get origin     => _remedy['origin'] ?? '';
  String get category   => _remedy['category_name'] ?? _remedy['category'] ?? '';
  double get rating     => ((_remedy['avg_user_rating'] ?? 0.0) as num).toDouble();
  int    get votes      => (_remedy['total_votes'] ?? 0) as int;
  int    get efficacy   => (_remedy['efficacy'] ?? 0) as int;
  int    get validation => (_remedy['validation_level'] ?? 1) as int;
  int    get tradition  => (_remedy['tradition_rating'] ?? 0) as int;
  String get difficulty => _remedy['difficulty'] ?? '';
  int    get prepTime   => ((_remedy['prep_time'] as num?)?.toInt() ?? 0);
  String get prepType   => _remedy['prep_type'] ?? '';
  String get plantPart  => _remedy['plant_part'] ?? '';
  String get ingredients => _remedy['ingredients'] ?? '';
  String get servings   => _remedy['servings']?.toString() ?? '';
  String get function_  => _remedy['function'] ?? '';
  String get mechanism  => _remedy['mechanism'] ?? '';
  String get constituent => _remedy['constituent'] ?? '';
  String get dosage     => _remedy['dosage'] ?? '';
  String get tip        => _remedy['tip'] ?? '';
  bool   get avoidPregnancy => _remedy['avoid_in_pregnancy'] == true;
  String get imageUrl   => _remedy['image_url'] ?? '';

  List<String> get instructions => _instructions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            YellowAppBar(
              title: name,
              subtitle: '$component · $origin',
              showBack: true,
              actions: [
                if (_isAdmin)
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => AdminRemedyEditScreen(
                        remedy: _remedy,
                        onSaved: () { Navigator.pop(context); _reloadRemedy(); RecipesScreen.reload(); },
                      ),
                    )),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.edit_outlined, size: 22, color: AppColors.dark),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Top row: image left, encouragement right
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Left — component image
                          RemedyImage(
                            url: imageUrl,
                            width: 160,
                            height: 160,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          const SizedBox(width: 12),
                          // Right — encouragement or placeholder
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                              ),
                              child: (_remedy['encouragement'] ?? '').toString().isNotEmpty
                                  ? Center(
                                      child: Text(
                                        _remedy['encouragement'].toString(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: AppColors.dark,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          height: 1.6,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.eco, color: AppColors.herbGreen, size: 28),
                                          const SizedBox(height: 8),
                                          Text(name, style: const TextStyle(
                                              color: AppColors.dark, fontWeight: FontWeight.w700, fontSize: 14),
                                              textAlign: TextAlign.center),
                                          const SizedBox(height: 4),
                                          Text(component, style: const TextStyle(
                                              color: AppColors.textSecondary, fontSize: 12),
                                              textAlign: TextAlign.center),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Rating row
                    Row(children: [
                      StarRating(rating: rating, votes: votes),
                      const SizedBox(width: 8),
                      if (efficacy > 0)
                        Text('· $efficacy%', style: AppTextStyles.caption),
                    ]),
                    const SizedBox(height: 12),
                    // ── Buy buttons ──────────────────────────────────
                    Row(children: [
                      Expanded(child: OutlinedButton(
                        onPressed: _hasComponent
                            ? () => _goToProduct(context, true) : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          side: BorderSide(
                              color: _hasComponent
                                  ? AppColors.dark : Colors.grey.shade300),
                        ),
                        child: Text('Buy Component',
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: _hasComponent
                                  ? AppColors.dark : Colors.grey.shade400)),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: ElevatedButton(
                        onPressed: _hasRemedy
                            ? () => _goToProduct(context, false) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hasRemedy
                              ? AppColors.primary : Colors.grey.shade200,
                          foregroundColor: _hasRemedy
                              ? AppColors.dark : Colors.grey.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: const Text('Buy Remedy',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      )),
                    ]),
                    // Overview
                    const SectionLabel('OVERVIEW'),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // Function heading + text
                        if (function_.isNotEmpty) ...[
                          const Text('Function', style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Text(function_, style: AppTextStyles.body),
                        ],
                        // Mechanism
                        if (mechanism.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          const Text('Mechanism', style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Text(mechanism, style: AppTextStyles.body),
                        ],
                        // Constituent
                        if (constituent.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          const Text('Main Constituent', style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Text(constituent, style: AppTextStyles.body),
                        ],
                        // Country of origin
                        if ((_remedy['origin'] ?? '').toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          const Text('Country of Origin', style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(_remedy['origin'].toString(), style: AppTextStyles.body),
                          ]),
                        ],
                        if (function_.isEmpty && mechanism.isEmpty && constituent.isEmpty && (_remedy['origin'] ?? '').toString().isEmpty)
                          const Text('No overview information available.', style: AppTextStyles.caption),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PreparationScreenDB(
                            remedy: _remedy,
                            hasRated: _submitted,
                            existingRating: _selectedRating,
                          ))).then((_) async {
            await Future.delayed(const Duration(milliseconds: 1000));
            await _loadExistingReview();
            await _reloadRemedy();
            RecipesScreen.reload();
          }),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                        Icon(Icons.list_alt_outlined, size: 16, color: AppColors.dark),
                        SizedBox(width: 8),
                        Text('View preparation guide', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    // Evidence
                    const SectionLabel('EVIDENCE'),
                    _infoCard([
                      InfoRow(label: 'Traditional use',
                          valueWidget: Row(mainAxisSize: MainAxisSize.min, children: [
                            ...List.generate(5, (i) => Icon(
                              i < tradition ? Icons.star : Icons.star_border,
                              size: 14, color: i < tradition ? AppColors.starColor : Colors.grey.shade300)),
                            const SizedBox(width: 4),
                            Text('$tradition/5', style: AppTextStyles.caption),
                          ])),
                      InfoRow(label: 'Validation',
                          valueWidget: TagBadge(label: 'Level $validation', color: AppColors.levelBadge)),
                      if (efficacy > 0) InfoRow(label: 'Efficacy', value: '$efficacy%'),
                    ]),
                    if (_remedy['efficacy_ref'] != null &&
                        _remedy['efficacy_ref'].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Efficacy study:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final u = Uri.tryParse(_remedy['efficacy_ref'].toString().trim());
                                if (u != null) await launchUrl(u, mode: LaunchMode.externalApplication);
                              },
                              child: Text(
                                _remedy['efficacy_ref'].toString().trim(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_remedy['clinical_study_url'] != null &&
                        _remedy['clinical_study_url'].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Builder(builder: (_) {
                        final urls = _remedy['clinical_study_url']
                            .toString().trim().split('\n')
                            .where((u) => u.trim().isNotEmpty)
                            .take(10).toList();
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Clinical studies:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: urls.map((url) => Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: GestureDetector(
                                    onTap: () async {
                                      final u = Uri.tryParse(url.trim());
                                      if (u != null) await launchUrl(u, mode: LaunchMode.externalApplication);
                                    },
                                    child: Text(
                                      url.trim(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black,
                                            ),
                                    ),
                                  ),
                                )).toList(),
                              ),
                            ),
                          ],
                        );
                      }),
                    ],
                    if (avoidPregnancy) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
                        child: const Row(children: [
                          Icon(Icons.warning_amber, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Text('Avoid in pregnancy.', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                    // ── Community reviews — tabbed ─────────────────────
                    const SizedBox(height: 8),
                    Row(children: [
                      // Tab 1: Community Review (write)
                      GestureDetector(
                        onTap: () => setState(() => _reviewTab = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _reviewTab == 0 ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _reviewTab == 0 ? AppColors.primary : Colors.grey.shade300),
                          ),
                          child: Text('Community Review',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: _reviewTab == 0 ? AppColors.dark : AppColors.textSecondary,
                            )),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tab 2: View all reviews
                      GestureDetector(
                        onTap: () {
                          setState(() => _reviewTab = 1);
                          _loadAllReviews();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _reviewTab == 1 ? AppColors.primary : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _reviewTab == 1 ? AppColors.primary : Colors.grey.shade300),
                          ),
                          child: Text('View all reviews',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: _reviewTab == 1 ? AppColors.dark : AppColors.textSecondary,
                            )),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    // ── Tab 2: All reviews list ──────────────────────────
                    if (_reviewTab == 1) ...[
                      if (_reviewsLoading)
                        const Center(child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ))
                      else if (_allReviews.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(child: Text('No reviews yet — be the first!',
                              style: AppTextStyles.caption)),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _allReviews.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r       = _allReviews[i];
                            final rating  = (r['rating'] ?? 0) as int;
                            final comment = r['comment']?.toString() ?? '';
                            final date    = r['created_at']?.toString().substring(0, 10) ?? '';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    ...List.generate(5, (s) => Icon(
                                      s < rating ? Icons.star : Icons.star_border,
                                      color: AppColors.starColor, size: 16)),
                                    const Spacer(),
                                    Text(date, style: AppTextStyles.caption),
                                  ]),
                                  if (comment.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(comment, style: AppTextStyles.body),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                    // ── Tab 1: Write / edit review ───────────────────────
                    if (_reviewTab == 0) ...[
                    if (_submitted && !_isEditing)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(12)),
                        child: Column(children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 36),
                          const SizedBox(height: 8),
                          const Text('Your review', style: AppTextStyles.heading3),
                          const SizedBox(height: 4),
                          Row(mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(5, (i) => Icon(
                                i < _selectedRating ? Icons.star : Icons.star_border,
                                color: AppColors.starColor, size: 22))),
                          if (_reviewController.text.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(_reviewController.text, style: AppTextStyles.caption, textAlign: TextAlign.center),
                          ],
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: () => setState(() => _isEditing = true),
                            icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.dark),
                            label: const Text('Edit review', style: TextStyle(color: AppColors.dark, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              side: const BorderSide(color: AppColors.dark),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ]),
                      )
                    else ...[
                      Text(_submitted ? 'Edit your review' : 'Rate this remedy', style: AppTextStyles.body),
                      const SizedBox(height: 8),
                      Row(children: [
                        ...List.generate(5, (i) => GestureDetector(
                          onTap: () => setState(() => _selectedRating = i + 1),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Icon(
                              i < _selectedRating ? Icons.star : Icons.star_border,
                              color: i < _selectedRating ? AppColors.starColor : Colors.grey.shade300,
                              size: 32,
                            ),
                          ),
                        )),
                        const SizedBox(width: 8),
                        if (_selectedRating > 0)
                          Text(_labels[_selectedRating], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
                      ]),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _reviewController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Share your experience...',
                          filled: true, fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _selectedRating == 0 ? null : _submitReview,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
                            disabledBackgroundColor: Colors.grey.shade200,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: Text(_existingReviewId != null ? 'Update review' : 'Submit review',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                      ),
                    ],
                    ], // end if (_reviewTab == 0)
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

  Widget _infoCard(List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(children: rows),
    );
  }
}

// ── Preparation Screen DB version ─────────────────────────────────────────

class PreparationScreenDB extends StatefulWidget {
  final Map<String, dynamic> remedy;
  final bool hasRated;
  final int existingRating;
  const PreparationScreenDB({
    super.key,
    required this.remedy,
    this.hasRated = false,
    this.existingRating = 0,
  });

  @override
  State<PreparationScreenDB> createState() => _PreparationScreenDBState();
}

class _PreparationScreenDBState extends State<PreparationScreenDB> {
  bool _hasPromptedRating = false;
  late bool _hasAlreadyRated;
  List<String> _instructions = [];
  bool _instructionsLoaded   = false;

  @override
  void initState() {
    super.initState();
    _hasAlreadyRated = widget.hasRated;
    if (!_hasAlreadyRated) {
      NavigationGuard.register((ctx) => _showRatingPopup(ctx));
    }
    _loadInstructions();
  }

  Future<void> _loadInstructions() async {
    if (_instructionsLoaded) return;
    _instructionsLoaded = true;
    try {
      final remedyId = widget.remedy['id']?.toString();
      if (remedyId == null) return;
      final data = await SupabaseService.supabase
          .from('remedy_instructions')
          .select()
          .eq('remedy_id', remedyId)
          .order('step_number', ascending: true);
      if (mounted) {
        final seen = <int>{};
        final deduped = (data as List).where((s) {
          final n = (s['step_number'] ?? 0) as int;
          return seen.add(n);
        }).toList();
        setState(() {
          _instructions = deduped
              .map((s) => s['instruction']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
        });
      }
    } catch (_) {
      final raw = widget.remedy['remedy_instructions'];
      if (raw != null) {
        final list = List.from(raw as List)
          ..sort((a, b) => ((a['step_number'] ?? 0) as int).compareTo((b['step_number'] ?? 0) as int));
        final seen = <int>{};
        if (mounted) setState(() => _instructions = list
            .where((s) => seen.add((s['step_number'] ?? 0) as int))
            .map((s) => s['instruction']?.toString() ?? '')
            .toList());
      }
    }
  }

  List<String> get instructions => _instructions;

  @override
  void dispose() {
    NavigationGuard.clear();
    super.dispose();
  }

  Future<bool> _showRatingPopup(BuildContext ctx) async {
    if (_hasAlreadyRated || _hasPromptedRating) return true;
    setState(() => _hasPromptedRating = true);
    final result = await showDialog<bool>(
      context: ctx, barrierDismissible: false,
      builder: (_) => _RatingDialogDB(remedyName: widget.remedy['name'] ?? ''),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final should = await _showRatingPopup(context);
        if (should && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              YellowAppBar(
                title: widget.remedy['name'] ?? '',
                subtitle: 'Preparation guide',
                showBack: true,
                onBack: () async {
                  final should = await _showRatingPopup(context);
                  if (should && context.mounted) Navigator.pop(context);
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionLabel('PREPARATION'),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          // Plant Part
                          if (widget.remedy['plant_part'] != null && widget.remedy['plant_part'].toString().isNotEmpty) ...[
                            const Text('Plant Part', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            Text(widget.remedy['plant_part'].toString(), style: AppTextStyles.body),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                          ],
                          // Prep Type
                          if (widget.remedy['prep_type'] != null && widget.remedy['prep_type'].toString().isNotEmpty) ...[
                            const Text('Preparation Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            Text(widget.remedy['prep_type'].toString(), style: AppTextStyles.body),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                          ],
                          // Difficulty + Prep time
                          if (widget.remedy['difficulty'] != null || widget.remedy['prep_time'] != null) ...[
                            Row(children: [
                              if (widget.remedy['difficulty'] != null) ...[
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('Difficulty', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  TagBadge(label: widget.remedy['difficulty'], color: AppColors.lightGreen, textColor: Colors.green.shade700),
                                ]),
                                const SizedBox(width: 24),
                              ],
                              if (widget.remedy['prep_time'] != null)
                                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('Prep Time', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  Text(formatPrepTime(widget.remedy['prep_time']), style: AppTextStyles.body),
                                ]),
                            ]),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                          ],
                          // Ingredients
                          if (widget.remedy['ingredients'] != null && widget.remedy['ingredients'].toString().isNotEmpty) ...[
                            const Text('Ingredients', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
                            const SizedBox(height: 6),
                            Text(widget.remedy['ingredients'].toString(), style: AppTextStyles.body),
                            if (widget.remedy['servings'] != null) ...[
                              const SizedBox(height: 8),
                              Row(children: [
                                const Icon(Icons.local_dining_outlined, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text('Serves: ${widget.remedy['servings']}', style: AppTextStyles.caption),
                              ]),
                            ],
                          ],
                        ]),
                      ),
                      const SectionLabel('STEP-BY-STEP INSTRUCTIONS'),
                      if (instructions.isEmpty)
                        const Text('No instructions available.', style: AppTextStyles.caption)
                      else
                        ...instructions.asMap().entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              width: 28, height: 28,
                              decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                              child: Center(child: Text('${e.key + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.dark))),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: Padding(padding: const EdgeInsets.only(top: 4),
                                child: Text(e.value, style: AppTextStyles.body))),
                          ]),
                        )),
                      if (widget.remedy['dosage'] != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.lightYellow, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFE082))),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.access_time, size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Typical dosage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.dark)),
                              const SizedBox(height: 4),
                              Text(widget.remedy['dosage'], style: const TextStyle(fontSize: 12, color: AppColors.dark, height: 1.4)),
                            ])),
                          ]),
                        ),
                      ],
                      if (widget.remedy['tip'] != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.lightbulb_outline, size: 18, color: Colors.green),
                            const SizedBox(width: 10),
                            Expanded(child: Text('💡 Tip: ${widget.remedy['tip']}', style: const TextStyle(fontSize: 12, color: AppColors.dark, height: 1.4))),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _RateRemedySectionDB(
                        remedyId: widget.remedy['id'] ?? '',
                        remedyName: widget.remedy['name'] ?? '',
                        initialRating: widget.existingRating,
                        alreadyRated: widget.hasRated,
                        onInteracted: () => setState(() => _hasAlreadyRated = true),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingDialogDB extends StatefulWidget {
  final String remedyName;
  const _RatingDialogDB({required this.remedyName});
  @override
  State<_RatingDialogDB> createState() => _RatingDialogDBState();
}

class _RatingDialogDBState extends State<_RatingDialogDB> {
  int _rating = 0;
  final _commentController = TextEditingController();
  final List<String> _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void dispose() { _commentController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.eco, size: 36, color: AppColors.herbGreen),
          const SizedBox(height: 12),
          const Text('Before you go!', style: AppTextStyles.heading2),
          const SizedBox(height: 6),
          Text('How was the preparation guide\nfor ${widget.remedyName}?',
              textAlign: TextAlign.center, style: AppTextStyles.caption),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(i < _rating ? Icons.star : Icons.star_border,
                        color: i < _rating ? AppColors.starColor : Colors.grey.shade300, size: 40)),
              ))),
          if (_rating > 0) ...[
            const SizedBox(height: 6),
            Text(_labels[_rating], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Share your experience (optional)...',
              hintStyle: AppTextStyles.caption,
              filled: true, fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context, true),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const Text('Skip', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: _rating == 0 ? null : () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
                disabledBackgroundColor: Colors.grey.shade200,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w700)),
            )),
          ]),
          if (_rating == 0) ...[
            const SizedBox(height: 8),
            const Text('Tap a star to rate', style: AppTextStyles.caption),
          ],
        ]),
      ),
    );
  }
}

class _RateRemedySectionDB extends StatefulWidget {
  final String remedyId;
  final String remedyName;
  final int initialRating;
  final bool alreadyRated;
  final VoidCallback? onInteracted;
  const _RateRemedySectionDB({
    required this.remedyId,
    required this.remedyName,
    this.initialRating = 0,
    this.alreadyRated = false,
    this.onInteracted,
  });
  @override
  State<_RateRemedySectionDB> createState() => _RateRemedySectionDBState();
}

class _RateRemedySectionDBState extends State<_RateRemedySectionDB> {
  int _selectedRating = 0;
  bool _submitted = false;
  bool _isEditing = false;
  final _reviewController = TextEditingController();
  final List<String> _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void initState() {
    super.initState();
    _selectedRating = widget.initialRating;
    _submitted = widget.alreadyRated;
  }

  @override
  void dispose() { _reviewController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
      child: (_submitted && !_isEditing) ? Column(children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 40),
        const SizedBox(height: 10),
        const Text('Your rating', style: AppTextStyles.heading3),
        Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) => Icon(
              i < _selectedRating ? Icons.star : Icons.star_border,
              color: AppColors.starColor, size: 24))),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => setState(() => _isEditing = true),
          icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.dark),
          label: const Text('Edit rating', style: TextStyle(color: AppColors.dark, fontSize: 12)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            side: const BorderSide(color: AppColors.dark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ]) : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_submitted ? 'Edit your rating' : 'Rate this remedy', style: AppTextStyles.heading3),
        const SizedBox(height: 4),
        Text('Did the preparation guide for ${widget.remedyName} help?', style: AppTextStyles.caption),
        const SizedBox(height: 14),
        Row(children: [
          ...List.generate(5, (i) => GestureDetector(
            onTap: () { setState(() => _selectedRating = i + 1); widget.onInteracted?.call(); },
            child: Padding(padding: const EdgeInsets.only(right: 6),
                child: Icon(i < _selectedRating ? Icons.star : Icons.star_border,
                    color: i < _selectedRating ? AppColors.starColor : Colors.grey.shade300, size: 36)),
          )),
          if (_selectedRating > 0) ...[
            const SizedBox(width: 8),
            Text(_labels[_selectedRating], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
          ],
        ]),
        const SizedBox(height: 14),
        TextField(
          controller: _reviewController, maxLines: 3,
          onChanged: (_) => widget.onInteracted?.call(),
          decoration: InputDecoration(
            hintText: 'Share your experience...',
            filled: true, fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _selectedRating == 0 ? null : () async {
            await SupabaseService.submitReview(
              remedyId: widget.remedyId,
              rating: _selectedRating,
              comment: _reviewController.text,
              isPreparation: true,
            );
            setState(() { _submitted = true; _isEditing = false; });
            widget.onInteracted?.call();
            // Don't reload recipes here - too expensive, done on navigate back
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
            disabledBackgroundColor: Colors.grey.shade200,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0,
          ),
          child: Text(_submitted ? 'Update rating' : 'Submit review',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        )),
        if (_selectedRating == 0)
          const Padding(padding: EdgeInsets.only(top: 6),
              child: Center(child: Text('Select a star rating to submit', style: AppTextStyles.caption))),
      ]),
    );
  }
}
