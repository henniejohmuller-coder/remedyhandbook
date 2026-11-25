import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onTabSwitch;
  const HomeScreen({super.key, this.onTabSwitch});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _encouragement = '';
  String _tagline       = '"Take your health into your\nown hands, today"';

  int _remedyCount   = 0;
  int _categoryCount = 0;
  int _studyCount    = 0;
  int _countryCount  = 0;
  bool _statsLoaded  = false;
  String _heroUrl    = '';
  double _discountPct = 0;

  @override
  void initState() {
    super.initState();
    _loadEncouragement();
    _loadStats();
    _loadDiscount();
  }

  Future<void> _loadDiscount() async {
    final userId = SupabaseService.supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await SupabaseService.supabase
          .from('profiles')
          .select('discount_pct')
          .eq('id', userId)
          .single();
      if (mounted) setState(() {
        _discountPct = ((data['discount_pct'] ?? 0) as num).toDouble();
      });
    } catch (_) {}
  }

  Future<void> _loadEncouragement() async {
    final text    = await SupabaseService.getAppContent('home_encouragement');
    final tagline = await SupabaseService.getAppContent('home_tagline');
    final heroUrl = await SupabaseService.getAppContent('home_hero_url');
    if (mounted) setState(() {
      _encouragement = text;
      if (tagline.isNotEmpty) _tagline = tagline;
      if (heroUrl.isNotEmpty) _heroUrl = heroUrl;
    });
  }

  Future<void> _loadStats() async {
    try {
      final db = SupabaseService.supabase;
      final remedyRes   = await db.from('remedies').select('id');
      final categoryRes = await db.from('categories').select('id').eq('active', true);
      final studyRes    = await db.from('remedies').select('id').neq('clinical_study_url', '');
      final countryRes  = await db.from('countries').select('id').eq('active', true);
      if (mounted) setState(() {
        _remedyCount   = (remedyRes   as List).length;
        _categoryCount = (categoryRes as List).length;
        _studyCount    = (studyRes    as List).length;
        _countryCount  = (countryRes  as List).length;
        _statsLoaded   = true;
      });
    } catch (e) {
      debugPrint('Stats load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildHeroCard(),
                    const SizedBox(height: 6),
                    if (_encouragement.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: EncouragementBanner(text: _encouragement),
                      ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _buildStatsRow(),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _NavButton(
                        label: 'Find Symptoms / Illness / Support',
                        icon: Icons.search_outlined,
                        onPressed: () => widget.onTabSwitch?.call(1),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _NavButton(
                        label: 'Search Herbal Remedies',
                        icon: Icons.menu_book_outlined,
                        onPressed: () => widget.onTabSwitch?.call(2),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _NavButton(
                        label: 'Search Shop Items',
                        icon: Icons.storefront_outlined,
                        onPressed: () => widget.onTabSwitch?.call(3),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const YellowAppBar(
          title: 'Remedy Handbook',
          subtitle: 'Your natural health companion',
          actions: [Icon(Icons.more_horiz, color: AppColors.dark)],
        ),
        if (_discountPct > 0)
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0.4, 0.0),
              child: Transform.rotate(
                angle: -0.52, // −30°
                child: _DiscountStamp(pct: _discountPct),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return SizedBox(
      width: double.infinity,
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background image â€” herbs on wooden table
          Image.network(
            _heroUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.dark,
              child: const Center(
                child: Icon(Icons.eco, size: 64, color: AppColors.primary),
              ),
            ),
          ),
          // Dark gradient overlay â€” stronger at bottom
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppColors.dark.withOpacity(0.3),
                  AppColors.dark.withOpacity(0.75),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Content at bottom
          Positioned(
            left: 20,
            right: 20,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.eco, size: 22, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Text('Remedy Handbook',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _tagline,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      height: 1.3),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Evidence-rated herbal remedies',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    final stats = [
      (_statsLoaded ? '$_remedyCount'   : '...', 'Herbal Remedies'),
      (_statsLoaded ? '$_categoryCount' : '...', 'Categories'),
      (_statsLoaded ? '$_studyCount'    : '...', 'Studies'),
      (_statsLoaded ? '$_countryCount'  : '...', 'Countries'),
    ];
    return Row(
      children: stats.asMap().entries.map((entry) {
        final i = entry.key;
        final s = entry.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 4, right: i == 3 ? 0 : 4),
            child: _StatCard(value: s.$1, label: s.$2),
          ),
        );
      }).toList(),
    );
  }
}

// ── Home nav button — icon on left, label on right ───────────────────────────
class _NavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  const _NavButton({required this.label, required this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.dark),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.dark)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.dark)),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Discount stamp ────────────────────────────────────────────────────────────
class _DiscountStamp extends StatelessWidget {
  final double pct;
  const _DiscountStamp({required this.pct});

  @override
  Widget build(BuildContext context) {
    final label = pct % 1 == 0 ? '${pct.toInt()}%' : '$pct%';
    return Opacity(
      opacity: 0.88,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFB71C1C), width: 2),
          borderRadius: BorderRadius.circular(3),
          color: Colors.transparent,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'EARLY SUPPORTER',
              style: TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w900,
                color: Color(0xFFB71C1C),
                letterSpacing: 1.0,
                height: 1.2,
              ),
            ),
            Text(
              '$label DISCOUNT',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Color(0xFFB71C1C),
                letterSpacing: 0.8,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
