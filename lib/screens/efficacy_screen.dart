import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';

class EfficacyScreen extends StatefulWidget {
  const EfficacyScreen({super.key});

  @override
  State<EfficacyScreen> createState() => _EfficacyScreenState();
}

class _EfficacyScreenState extends State<EfficacyScreen> {
  String _content   = '';
  String _updatedAt = '';
  bool   _loading   = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.supabase
          .from('app_content')
          .select('content, updated_at')
          .eq('key', 'efficacy_evaluation')
          .single();
      setState(() {
        _content   = data['content'] ?? '';
        _updatedAt = data['updated_at']?.toString().substring(0, 10) ?? '';
        _loading   = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          const YellowAppBar(
            title: 'Efficacy Evaluation',
            subtitle: 'How effectiveness is measured',
            showBack: true,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // Last updated badge — same style as T&C
                      if (_updatedAt.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.lightYellow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary),
                          ),
                          child: Row(children: [
                            const Icon(Icons.info_outline, size: 16, color: AppColors.dark),
                            const SizedBox(width: 8),
                            Text('Last updated: $_updatedAt',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark)),
                          ]),
                        ),

                      const SizedBox(height: 20),

                      // Content from Supabase
                      Text(
                        _content.isNotEmpty ? _content : _defaultContent,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textSecondary, height: 1.7),
                      ),

                      const SizedBox(height: 32),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }

  // Fallback content shown if Supabase row does not yet exist
  static const String _defaultContent = '''
Efficacy Scale: 0–100
Where 100 = equivalent effectiveness to a standard pharmaceutical drug for the same condition.

HOW EACH SCORE IS DETERMINED

Step 1 — Find the best available clinical study for that herb or constituent matched to its specific illness. Not just any study — it must reference the condition the remedy treats.

Step 2 — Assess the quality of that study using this hierarchy:
  • Cochrane systematic review or meta-analysis — Highest
  • Multiple RCTs (randomised controlled trials) — Very high
  • Single well-designed RCT — High
  • Systematic review without RCT — Moderate-high
  • Phase I/II clinical trial — Moderate
  • Human observational or pilot study — Moderate-low
  • Animal in vivo study — Low
  • In vitro (cell culture only) — Very low
  • Traditional use only, no study — Baseline

SCORE BANDS

85–100  Cochrane review OR multiple RCTs showing drug-equivalent outcomes
         Example: Peppermint for IBS (Cochrane), St. John's Wort for depression

75–84   Systematic review + 2 or more RCTs with clear clinical outcomes
         Example: Garlic for blood pressure, Willow Bark for pain

65–74   1 or more well-designed RCTs with statistically significant outcomes
         Example: Ashwagandha for stress, Elderberry for flu duration

55–64   Clinical pilot study or observational study with clinical endpoints
         Example: Dandelion as diuretic, Slippery Elm for acid reflux

40–54   Pharmacological studies + one small clinical study
         Example: Burdock alterative, Rooibos antioxidant

30–39   Traditional use + in vitro or animal studies only
         Example: Bistort astringent, Blue Flag

15–25   Unsafe or toxic at therapeutic dose, or no valid clinical claim
         Example: Milkweed Latex, Pennyroyal, Tamboti

0       No supporting study found at all

WHAT THE EFFICACY REFERENCE URL POINTS TO

The URL linked to each remedy's efficacy score is the single best published study that directly supports the score. It must:
  1. Use the same preparation (tea, tincture, extract) where possible
  2. Test against the same illness the remedy is listed for
  3. Be the highest quality study available from PubMed, PMC, Cochrane, MDPI, or Oxford Academic

IMPORTANT CAVEAT

The score reflects relative effectiveness based on published evidence strength — not a pharmaceutical equivalence claim. A score of 80 means the evidence quality is strong and outcomes are clinically meaningful, not that the herb is literally 80% as potent as a drug by weight or dose. It is an evidence confidence score as much as an efficacy score.

This is why two herbs can have the same score for different reasons. Mistletoe scores 88 because of Cochrane-reviewed human RCTs in oncology. Garlic scores 90 because of multiple meta-analyses on blood pressure showing statistically equivalent outcomes to low-dose ACE inhibitors.''';
}
