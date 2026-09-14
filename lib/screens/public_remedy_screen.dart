import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../widgets/shared_widgets.dart";
import "../widgets/install_banner.dart";
import "../services/supabase_service.dart";
import "login_screen.dart";

class PublicRemedyScreen extends StatefulWidget {
  final String remedyId;
  const PublicRemedyScreen({super.key, required this.remedyId});

  @override
  State<PublicRemedyScreen> createState() => _PublicRemedyScreenState();
}

class _PublicRemedyScreenState extends State<PublicRemedyScreen> {
  Map<String, dynamic>? _remedy;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final remedy = await SupabaseService.getRemedyById(widget.remedyId);
      if (!mounted) return;
      setState(() {
        _remedy = remedy;
        _loading = false;
        _notFound = remedy == null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _notFound = true; });
    }
  }

  void _goToSignUp() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_notFound || _remedy == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off, size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 12),
                  const Text("Remedy not found", style: AppTextStyles.heading3),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _goToSignUp, child: const Text("Go to Remedy Handbook")),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final remedy = _remedy!;
    final name = remedy["name"] ?? "";
    final component = remedy["component"] ?? "";
    final origin = remedy["origin"] ?? "";
    final imageUrl = remedy["image_url"]?.toString() ?? "";
    final rating = ((remedy["avg_user_rating"] ?? 0.0) as num).toDouble();
    final votes = (remedy["total_votes"] ?? 0) as int;
    final instructions = (remedy["remedy_instructions"] as List?) ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            YellowAppBar(title: name, subtitle: "$component · $origin", showBack: false),
            const InstallBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    RemedyImage(url: imageUrl, width: double.infinity, height: 200),
                    const SizedBox(height: 12),
                    Text(name, style: AppTextStyles.heading2),
                    const SizedBox(height: 4),
                    StarRating(rating: rating, votes: votes),
                    const SizedBox(height: 16),
                    if (instructions.isNotEmpty) ...[
                      const Text("How to prepare", style: AppTextStyles.heading3),
                      const SizedBox(height: 8),
                      ...instructions.map((step) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(step["instruction_text"]?.toString() ?? "", style: AppTextStyles.body),
                      )),
                    ],
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Want more remedies?", style: AppTextStyles.heading3),
                          const SizedBox(height: 6),
                          const Text(
                            "Sign up to browse the full remedy library, save favourites, and order products.",
                            style: AppTextStyles.body,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(onPressed: _goToSignUp, child: const Text("Sign up / Log in")),
                          ),
                        ],
                      ),
                    ),
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
}
