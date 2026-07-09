import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import 'preparation_screen_db.dart';
import 'product_detail_screen_db.dart';
import 'admin_remedy_edit_screen.dart';

class RecipeDetailScreenDB extends StatefulWidget {
  final Map<String, dynamic> remedy;
  const RecipeDetailScreenDB({super.key, required this.remedy});

  @override
  State<RecipeDetailScreenDB> createState() => _RecipeDetailScreenDBState();
}

class _RecipeDetailScreenDBState extends State<RecipeDetailScreenDB> {
  int _selectedRating = 0;
  bool _submitted = false;
  final TextEditingController _reviewController = TextEditingController();
  final List<String> _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];
  bool _isSaved = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkSaved();
    _checkAdmin();
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _checkSaved() async {
    final saved = await SupabaseService.isRemedySaved(widget.remedy['id']);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _checkAdmin() async {
    final user = SupabaseService.supabase.auth.currentUser;
    if (user == null) return;
    final admin = await SupabaseService.isAdmin(user.id);
    if (mounted) setState(() => _isAdmin = admin);
  }

  Future<void> _toggleSave() async {
    if (_isSaved) {
      await SupabaseService.unsaveRemedy(widget.remedy['id']);
    } else {
      await SupabaseService.saveRemedy(widget.remedy['id']);
    }
    setState(() => _isSaved = !_isSaved);
  }

  void _goToProduct(BuildContext context, bool isHerb) async {
    try {
      final products = await SupabaseService.getProducts();
      final product = products.firstWhere(
        (p) => p['linked_remedy_id'] == widget.remedy['id'] &&
               (isHerb ? p['type'] == 'Component' : p['type'] == 'Remedy'),
        orElse: () => products.isNotEmpty ? products.first : {},
      );
      if (product.isNotEmpty && context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreenDB(product: product)));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final r           = widget.remedy;
    final name        = r['name'] ?? '';
    final component   = r['component'] ?? '';
    final origin      = r['origin'] ?? '';
    final category    = r['category_name'] ?? r['category'] ?? '';
    final rating      = ((r['avg_user_rating'] ?? 0.0) as num).toDouble();
    final votes       = (r['total_votes'] ?? 0) as int;
    final efficacy    = (r['efficacy'] ?? 0) as int;
    final tradition   = (r['tradition_rating'] ?? 0) as int;
    final validation  = (r['validation_level'] ?? 1) as int;
    final instructions = r['remedy_instructions'] as List? ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            YellowAppBar(
              title: name,
              subtitle: '$component${origin.isNotEmpty ? ' · $origin' : ''}',
              showBack: true,
              actions: [
                if (_isAdmin)
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminRemedyEditScreen(
                          remedy: widget.remedy,
                          onSaved: () {
                            Navigator.pop(context);
                            RecipesScreen.reload();
                          },
                        ),
                      ),
                    ),
                    child: const Icon(Icons.edit_outlined, size: 22, color: AppColors.dark),
                  ),
                if (_isAdmin) const SizedBox(width: 12),
                GestureDetector(
                  onTap: _toggleSave,
                  child: Icon(
                    _isSaved ? Icons.favorite : Icons.favorite_border,
                    color: _isSaved ? Colors.red : AppColors.dark,
                    size: 22,
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
                    if (category.isNotEmpty)
                      TagBadge(
                        label: category,
                        color: category == 'Cancer' ? const Color(0xFFFFECB3) : AppColors.lightGreen,
                        textColor: category == 'Cancer' ? Colors.orange.shade800 : Colors.green.shade700,
                      ),
                    const SizedBox(height: 12),
                    // Image
                    r['image_url'] != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(r['image_url'], height: 120, width: double.infinity, fit: BoxFit.cover),
                          )
                        : const HerbIconPlaceholder(size: 120, icon: Icons.eco),
                    const SizedBox(height: 12),
                    // Rating
                    Row(children: [
                      StarRating(rating: rating, votes: votes),
                      const SizedBox(width: 8),
                      if (efficacy > 0) Text('· $efficacy%', style: AppTextStyles.caption),
                    ]),
                    const SizedBox(height: 16),
                    // Buy buttons
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.dark, borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Expanded(child: _BuyCard(
                          title: 'Buy Component', subtitle: component,
                          price: 'View', onTap: () => _goToProduct(context, true),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _BuyCard(
                          title: 'Buy Remedy', subtitle: 'Pre-made remedy',
                          price: 'View', isYellow: true, onTap: () => _goToProduct(context, false),
                        )),
                      ]),
                    ),
                    // Overview
                    if (r['function'] != null || r['mechanism'] != null) ...[
                      const SectionLabel('OVERVIEW'),
                      _infoCard([
                        if (r['function'] != null) InfoRow(label: 'Function', value: r['function']),
                        if (r['mechanism'] != null) InfoRow(label: 'Mechanism', value: r['mechanism']),
                        if (r['constituent'] != null) InfoRow(label: 'Constituent', value: r['constituent']),
                      ]),
                    ],
                    // Preparation
                    const SectionLabel('PREPARATION'),
                    _infoCard([
                      if (r['prep_type'] != null) InfoRow(label: 'Prep type', value: r['prep_type']),
                      if (r['difficulty'] != null) InfoRow(label: 'Difficulty',
                          valueWidget: TagBadge(label: r['difficulty'], color: AppColors.lightGreen, textColor: Colors.green.shade700)),
                      if (r['prep_time'] != null) InfoRow(label: 'Prep time', value: formatPrepTime(r['prep_time'])),
                    ]),
                    const SizedBox(height: 10),
                    // View preparation guide
                    if (instructions.isNotEmpty)
                      OutlinedButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => PreparationScreenDB(remedy: r))),
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
                      InfoRow(label: 'Traditional use', valueWidget: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...List.generate(5, (i) => Icon(i < tradition ? Icons.star : Icons.star_border,
                              size: 14, color: i < tradition ? AppColors.starColor : Colors.grey.shade300)),
                          const SizedBox(width: 4),
                          Text('$tradition/5', style: AppTextStyles.caption),
                        ],
                      )),
                      InfoRow(label: 'Validation', valueWidget: TagBadge(label: 'Level $validation', color: AppColors.levelBadge)),
                      if (efficacy > 0) InfoRow(label: 'Efficacy', value: '$efficacy%'),
                    ]),
                    if (r['efficacy_ref'] != null &&
                        r['efficacy_ref'].toString().trim().isNotEmpty) ...[
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
                                final u = Uri.tryParse(r['efficacy_ref'].toString().trim());
                                if (u != null) await launchUrl(u, mode: LaunchMode.externalApplication);
                              },
                              child: Text(
                                r['efficacy_ref'].toString().trim(),
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
                    if (r['clinical_study_url'] != null &&
                        r['clinical_study_url'].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Builder(builder: (_) {
                        final urls = r['clinical_study_url']
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
                    if (r['avoid_in_pregnancy'] == true) ...[
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
                        decoration: BoxDecoration(color: AppColors.lightGreen, borderRadius: BorderRadius.circular(12)),
                        child: Column(children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 36),
                          const SizedBox(height: 8),
                          const Text('Thank you for your review!', style: AppTextStyles.heading3),
                          Row(mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) => Icon(
                              i < _selectedRating ? Icons.star : Icons.star_border,
                              color: AppColors.starColor, size: 22))),
                        ]),
                      )
                    else ...[
                      const Text('Rate this remedy', style: AppTextStyles.body),
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
                          Text(_labels[_selectedRating],
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
                      ]),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _reviewController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Share experience...',
                          filled: true, fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Submit review',
                        onPressed: _selectedRating == 0 ? () {} : () async {
                          await SupabaseService.submitReview(
                            remedyId: widget.remedy['id'],
                            rating: _selectedRating,
                            comment: _reviewController.text,
                          );
                          setState(() => _submitted = true);
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
        color: Colors.white, borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Column(children: rows),
    );
  }
}

class _BuyCard extends StatelessWidget {
  final String title, subtitle, price;
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isYellow ? AppColors.dark : Colors.white)),
          Text(subtitle, style: TextStyle(fontSize: 11, color: isYellow ? AppColors.dark.withOpacity(0.7) : Colors.white70, height: 1.3), maxLines: 2),
          const SizedBox(height: 4),
          Text(price, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isYellow ? AppColors.dark : Colors.white)),
        ]),
      ),
    );
  }
}
