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

  // Live stats from DB
  int _remedyCount   = 0;
  int _categoryCount = 0;
  int _studyCount    = 0;
  int _countryCount  = 0;
  bool _statsLoaded  = false;

  @override
  void initState() {
    super.initState();
    _loadEncouragement();
    _loadStats();
  }

  Future<void> _loadEncouragement() async {
    final text    = await SupabaseService.getAppContent('home_encouragement');
    final tagline = await SupabaseService.getAppContent('home_tagline');
    if (mounted) setState(() {
      _encouragement = text;
      if (tagline.isNotEmpty) _tagline = tagline;
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
      print('Stats load error: $e');
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
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildHeroCard(),
                    const SizedBox(height: 8),
                    if (_encouragement.isNotEmpty)
                      EncouragementBanner(text: _encouragement),
                    const SizedBox(height: 8),
                    _buildStatsGrid(),
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: 'Search remedies',
                      icon: Icons.search,
                      onPressed: () => widget.onTabSwitch?.call(1), // switch to Recipes tab
                    ),
                    const SizedBox(height: 12),
                    DarkButton(
                      label: 'Shop Components and Remedies',
                      icon: Icons.shopping_basket_outlined,
                      onPressed: () => widget.onTabSwitch?.call(2), // switch to Shop tab
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
    return const YellowAppBar(
      title: 'Remedy Handbook',
      subtitle: 'Your natural health companion',
      actions: [Icon(Icons.more_horiz, color: AppColors.dark)],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          const Icon(Icons.eco, size: 48, color: AppColors.herbGreen),
          const SizedBox(height: 12),
          Text(
            _tagline,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, color: AppColors.dark, height: 1.4),
          ),
          const SizedBox(height: 10),
          const Text(
            'Welcome to our community. Explore\nevidence-rated herbal remedies.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _StatCard(value: _statsLoaded ? '$_remedyCount'   : '...', label: 'Remedies'),
        _StatCard(value: _statsLoaded ? '$_categoryCount' : '...', label: 'Categories'),
        _StatCard(value: _statsLoaded ? '$_studyCount'    : '...', label: 'Studies'),
        _StatCard(value: _statsLoaded ? '$_countryCount'  : '...', label: 'Countries'),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.dark)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
