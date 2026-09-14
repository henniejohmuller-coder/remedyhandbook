import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/navigation_guard.dart';
import '../models/models.dart';

class PreparationScreen extends StatefulWidget {
  final Remedy remedy;
  const PreparationScreen({super.key, required this.remedy});

  @override
  State<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends State<PreparationScreen> {
  bool _hasPromptedRating = false;
  bool _hasAlreadyRated = false; // true if user rated or commented on the page

  @override
  void initState() {
    super.initState();
    NavigationGuard.register((ctx) => _showRatingPopup(ctx));
  }

  @override
  void dispose() {
    NavigationGuard.clear();
    super.dispose();
  }

  Future<bool> _showRatingPopup(BuildContext ctx) async {
    // Skip popup if user already interacted with rating on the page
    if (_hasAlreadyRated) return true;
    if (_hasPromptedRating) return true;
    setState(() => _hasPromptedRating = true);
    final result = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _RatingDialog(remedyName: widget.remedy.name),
    );
    return result ?? false;
  }

  Future<bool> _onWillPop() => _showRatingPopup(context);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              YellowAppBar(
                title: widget.remedy.name,
                subtitle: 'Preparation guide',
                showBack: true,
                onBack: () async {
                  final shouldPop = await _onWillPop();
                  if (shouldPop && context.mounted) Navigator.pop(context);
                },
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Preparation details
                      const SectionLabel('PREPARATION'),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                        ),
                        child: Column(
                          children: [
                            InfoRow(label: 'Plant part', value: widget.remedy.plantPart),
                            InfoRow(label: 'Prep type', value: widget.remedy.prepType),
                            InfoRow(
                              label: 'Difficulty',
                              valueWidget: TagBadge(
                                label: widget.remedy.difficulty,
                                color: AppColors.lightGreen,
                                textColor: Colors.green.shade700,
                              ),
                            ),
                            InfoRow(label: 'Prep time', value: widget.remedy.prepTimeDisplay),
                            InfoRow(label: 'Servings', value: widget.remedy.servings),
                            InfoRow(label: 'Ingredients', value: widget.remedy.ingredients),
                          ],
                        ),
                      ),
                      const SectionLabel('STEP-BY-STEP INSTRUCTIONS'),
                      ...widget.remedy.instructions.asMap().entries.map((e) =>
                        _StepItem(step: e.key + 1, text: e.value),
                      ),
                      const SizedBox(height: 16),
                      // Dosage card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.lightYellow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFE082)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.access_time, size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Typical dosage', style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.dark,
                                  )),
                                  const SizedBox(height: 4),
                                  Text(widget.remedy.dosage, style: const TextStyle(
                                    fontSize: 12, color: AppColors.dark, height: 1.4,
                                  )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Tip card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.lightGreen,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline, size: 18, color: Colors.green),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '💡 Tip: ${widget.remedy.tip}',
                                style: const TextStyle(fontSize: 12, color: AppColors.dark, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Rate this remedy
                      _RateRemedySection(
                        remedyName: widget.remedy.name,
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

// ── Step Item ─────────────────────────────────────────────────────────────

class _StepItem extends StatelessWidget {
  final int step;
  final String text;
  const _StepItem({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: Center(child: Text('$step', style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.dark,
            ))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(text, style: AppTextStyles.body),
          )),
        ],
      ),
    );
  }
}

// ── Rate This Remedy Section ──────────────────────────────────────────────

class _RateRemedySection extends StatefulWidget {
  final String remedyName;
  final VoidCallback? onInteracted;

  const _RateRemedySection({
    required this.remedyName,
    this.onInteracted,
  });

  @override
  State<_RateRemedySection> createState() => _RateRemedySectionState();
}

class _RateRemedySectionState extends State<_RateRemedySection> {
  int _hoverRating = 0;
  int _selectedRating = 0;
  bool _submitted = false;
  final TextEditingController _reviewController = TextEditingController();

  final List<String> _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: _submitted ? _buildThankYou() : _buildForm(),
    );
  }

  Widget _buildForm() {
    final displayRating = _hoverRating > 0 ? _hoverRating : _selectedRating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Rate this remedy', style: AppTextStyles.heading3),
        const SizedBox(height: 4),
        Text('Did the preparation guide for ${widget.remedyName} help?', style: AppTextStyles.caption),
        const SizedBox(height: 14),
        Row(
          children: [
            ...List.generate(5, (i) => GestureDetector(
              onTap: () {
                setState(() => _selectedRating = i + 1);
                widget.onInteracted?.call();
              },
              child: MouseRegion(
                onEnter: (_) => setState(() => _hoverRating = i + 1),
                onExit: (_) => setState(() => _hoverRating = 0),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    i < displayRating ? Icons.star : Icons.star_border,
                    color: i < displayRating ? AppColors.starColor : Colors.grey.shade300,
                    size: 36,
                  ),
                ),
              ),
            )),
            const SizedBox(width: 8),
            if (displayRating > 0)
              Text(_labels[displayRating], style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark,
              )),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _reviewController,
          maxLines: 3,
          onChanged: (_) => widget.onInteracted?.call(),
          decoration: InputDecoration(
            hintText: 'Share your experience with this preparation...',
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _selectedRating == 0 ? null : () => setState(() => _submitted = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.dark,
              disabledBackgroundColor: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Submit review', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          ),
        ),
        if (_selectedRating == 0)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Center(child: Text('Select a star rating to submit', style: AppTextStyles.caption)),
          ),
      ],
    );
  }

  Widget _buildThankYou() {
    return Column(
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 40),
        const SizedBox(height: 10),
        const Text('Thank you for your review!', style: AppTextStyles.heading3),
        const SizedBox(height: 4),
        Text('You rated this $_selectedRating out of 5 stars', style: AppTextStyles.caption),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) => Icon(
            i < _selectedRating ? Icons.star : Icons.star_border,
            color: i < _selectedRating ? AppColors.starColor : Colors.grey.shade300,
            size: 24,
          )),
        ),
      ],
    );
  }
}

// ── Rating Popup Dialog ───────────────────────────────────────────────────

class _RatingDialog extends StatefulWidget {
  final String remedyName;
  const _RatingDialog({required this.remedyName});

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  final List<String> _labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            const Icon(Icons.eco, size: 36, color: AppColors.herbGreen),
            const SizedBox(height: 12),
            const Text('Before you go!', style: AppTextStyles.heading2),
            const SizedBox(height: 6),
            Text(
              'How was the preparation guide\nfor ${widget.remedyName}?',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 20),
            // Stars
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < _rating ? Icons.star : Icons.star_border,
                    color: i < _rating ? AppColors.starColor : Colors.grey.shade300,
                    size: 40,
                  ),
                ),
              )),
            ),
            if (_rating > 0) ...[
              const SizedBox(height: 6),
              Text(
                _labels[_rating],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dark,
                ),
              ),
            ],
            const SizedBox(height: 16),
            // Comment box
            TextField(
              controller: _commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Share your experience (optional)...',
                hintStyle: AppTextStyles.caption,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Buttons
            Row(
              children: [
                // No thanks
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: const Text('Skip', style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    )),
                  ),
                ),
                const SizedBox(width: 12),
                // Submit
                Expanded(
                  child: ElevatedButton(
                    onPressed: _rating == 0 ? null : () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.dark,
                      disabledBackgroundColor: Colors.grey.shade200,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            if (_rating == 0) ...[
              const SizedBox(height: 8),
              const Text('Tap a star to rate', style: AppTextStyles.caption),
            ],
          ],
        ),
      ),
    );
  }
}
