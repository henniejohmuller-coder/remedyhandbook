import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../screens/cart_screen.dart';
import 'navigation_guard.dart';

// Global cart count — call CartBadge.update(count) to refresh
class CartBadge {
  static final _notifier = ValueNotifier<int>(0);
  static ValueNotifier<int> get notifier => _notifier;
  static void update(int count) => _notifier.value = count;
}

// ── Bottom Navigation Bar ──────────────────────────────────────────────────

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  BottomNavigationBarItem _navItem(IconData outline, IconData filled, String label, int index) {
    return BottomNavigationBarItem(
      label: label,
      icon: Icon(outline),
      activeIcon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(filled, color: AppColors.dark, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.dark,
      unselectedItemColor: AppColors.textSecondary,
      selectedFontSize: 10,
      unselectedFontSize: 10,
      elevation: 8,
      items: [
        _navItem(Icons.home_outlined, Icons.home, 'Home', 0),
        _navItem(Icons.menu_book_outlined, Icons.menu_book, 'Recipes', 1),
        _navItem(Icons.storefront_outlined, Icons.storefront, 'Shop', 2),
        _navItem(Icons.add_circle_outline, Icons.add_circle, 'Submit', 3),
        _navItem(Icons.bookmark_border, Icons.bookmark, 'My Recipes', 4),
        _navItem(Icons.person_outline, Icons.person, 'Profile', 5),
      ],
    );
  }
}

// ── Yellow App Bar ────────────────────────────────────────────────────────

class YellowAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack; // custom back handler

  const YellowAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.showBack = false,
    this.onBack,
  });

  Future<void> _launchUrl() async {
    final uri = Uri.parse('https://www.MyHerb.co.za');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left — back arrow + title/subtitle/link
          Expanded(
            child: Row(
              children: [
                if (showBack) ...[
                  GestureDetector(
                    onTap: onBack ?? () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: AppColors.dark, size: 20),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                        fontFamily: 'Georgia',
                      ), softWrap: true),
                      if (subtitle != null)
                        Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.dark),
                            softWrap: true),
                      const SizedBox(height: 2),
                      GestureDetector(
                        onTap: _launchUrl,
                        child: const Text(
                          'www.MyHerb.co.za',
                          style: TextStyle(
                          fontSize: 11,
                          color: AppColors.dark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  ),
                ),
              ],
            ),
          ),
          // Right — extra actions + cart icon
          Row(
            children: [
              if (actions != null) ...actions!,
              if (actions != null) const SizedBox(width: 10),
              GestureDetector(
                onTap: () async {
                  final canNavigate = await NavigationGuard.shouldNavigate(context);
                  if (!canNavigate) return;
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: false).push(
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    );
                  }
                },
                child: Stack(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.shopping_cart_outlined, size: 26, color: AppColors.dark),
                    ),
                    Positioned(
                      right: 0, top: 0,
                      child: ValueListenableBuilder<int>(
                        valueListenable: CartBadge.notifier,
                        builder: (context, count, _) {
                          if (count == 0) return const SizedBox.shrink();
                          return Container(
                            width: 14, height: 14,
                            decoration: const BoxDecoration(color: AppColors.dark, shape: BoxShape.circle),
                            child: Center(
                              child: Text('$count',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary)),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Yellow Primary Button ─────────────────────────────────────────────────

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool fullWidth;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.dark,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: icon != null
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ])
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }
}

// ── Dark Button ───────────────────────────────────────────────────────────

class DarkButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  const DarkButton({super.key, required this.label, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.dark,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: icon != null
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 18),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ])
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ),
    );
  }
}

// ── Tag / Badge ───────────────────────────────────────────────────────────

class TagBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const TagBadge({
    super.key,
    required this.label,
    this.color = AppColors.tagCancer,
    this.textColor = AppColors.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

// ── Star Rating Row ───────────────────────────────────────────────────────

class StarRating extends StatelessWidget {
  final double rating;
  final int votes;
  final double size;

  const StarRating({super.key, required this.rating, this.votes = 0, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (i) => Icon(
          i < rating.floor() ? Icons.star : (i < rating ? Icons.star_half : Icons.star_border),
          color: AppColors.starColor,
          size: size,
        )),
        if (votes > 0) ...[
          const SizedBox(width: 4),
          Text('$rating · $votes votes', style: AppTextStyles.caption),
        ],
      ],
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────

class SectionLabel extends StatelessWidget {
  final String text;
  const SectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      )),
    );
  }
}

// ── Info Row ──────────────────────────────────────────────────────────────

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? valueWidget;

  const InfoRow({super.key, required this.label, this.value = '', this.valueWidget});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed-width label — never shrinks
          SizedBox(
            width: 110,
            child: Text(label, style: AppTextStyles.caption),
          ),
          // Value fills remaining width and wraps long text
          Expanded(
            child: valueWidget ??
                Text(
                  value,
                  style: AppTextStyles.body,
                  softWrap: true,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Search Bar ────────────────────────────────────────────────────────────

class AppSearchBar extends StatelessWidget {
  final String hint;
  final VoidCallback? onTap;
  final TextEditingController? controller;

  const AppSearchBar({super.key, this.hint = 'Search...', this.onTap, this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        onTap: onTap,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.caption,
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ── Herb Icon Placeholder ─────────────────────────────────────────────────

// ── Robust image widget with loading, error and fallback ─────────────────────
class RemedyImage extends StatefulWidget {
  final String? url;
  final double width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const RemedyImage({
    super.key,
    required this.url,
    this.width = 120,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  State<RemedyImage> createState() => _RemedyImageState();
}

class _RemedyImageState extends State<RemedyImage> {
  bool _failed = false;

  String? _sanitiseUrl(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final url = raw.trim();
    if (!url.startsWith('http')) return null;
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final url = _sanitiseUrl(widget.url);
    final radius = widget.borderRadius ?? BorderRadius.circular(10);
    final placeholder = ClipRRect(
      borderRadius: radius,
      child: Container(
        width: widget.width, height: widget.height ?? widget.width,
        color: AppColors.lightGreen,
        child: const Center(child: Icon(Icons.eco, color: AppColors.herbGreen, size: 32)),
      ),
    );

    if (url == null || _failed) return placeholder;

    return ClipRRect(
      borderRadius: radius,
      child: Image.network(
        url,
        width: widget.width,
        height: widget.height ?? widget.width,
        fit: widget.fit,
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return Container(
            width: widget.width, height: widget.height ?? widget.width,
            color: AppColors.lightGreen,
            child: Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null,
                color: AppColors.primary, strokeWidth: 2,
              ),
            ),
          );
        },
        errorBuilder: (ctx, error, stack) {
          // Try once more with a slight delay then give up
          if (!_failed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _failed = true);
            });
          }
          return placeholder;
        },
      ),
    );
  }
}

class HerbIconPlaceholder extends StatelessWidget {
  final double size;
  final IconData icon;

  const HerbIconPlaceholder({super.key, this.size = 80, this.icon = Icons.eco});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: size * 0.5, color: AppColors.herbGreen),
    );
  }
}

// ── Encouragement Banner ─────────────────────────────────────────────────

class EncouragementBanner extends StatelessWidget {
  final String text;
  const EncouragementBanner({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1C1E), Color(0xFF2C2C2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        const Icon(Icons.eco, color: AppColors.primary, size: 28),
        const SizedBox(width: 12),
        Expanded(child: Text(
          text,
          style: const TextStyle(
            color: Colors.white, fontSize: 14,
            fontWeight: FontWeight.w600, height: 1.4,
            fontStyle: FontStyle.italic,
          ),
        )),
      ]),
    );
  }
}

// ── Multi-Select Pick Field ──────────────────────────────────────────────────
class MultiPickField extends StatefulWidget {
  final String label;
  final String value;
  final List<String> options;
  final String customHint;
  final ValueChanged<String> onChanged;
  final bool allowCustom;

  const MultiPickField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.customHint,
    required this.onChanged,
    this.allowCustom = true,
  });

  @override
  State<MultiPickField> createState() => _MultiPickFieldState();
}

class _MultiPickFieldState extends State<MultiPickField> {
  bool _showCustom = false;
  final _customController = TextEditingController();

  List<String> get _selected => widget.value
      .split(RegExp(r'[,;]'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  void _addItem(String item) {
    final clean = item.trim();
    if (clean.isEmpty) return;
    final current = _selected;
    if (!current.contains(clean)) {
      current.add(clean);
      widget.onChanged(current.join(', '));
    }
  }

  void _removeItem(String item) {
    final current = _selected..remove(item);
    widget.onChanged(current.join(', '));
  }

  void _confirmCustom() {
    final text = _customController.text.trim();
    if (text.isEmpty) return;
    _addItem(text);
    _customController.clear();
    setState(() => _showCustom = false);
  }

  void _openSearchPicker(BuildContext context, List<String> options) {
    final searchCtrl = TextEditingController();
    List<String> filtered = List.from(options);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search ${widget.label.toLowerCase()}…',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                onChanged: (v) {
                  setModal(() {
                    filtered = options
                        .where((o) => o.toLowerCase().contains(v.toLowerCase()))
                        .toList();
                  });
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(children: [
                ...filtered.map((o) => ListTile(
                  dense: true,
                  title: Text(o, style: AppTextStyles.body),
                  onTap: () { Navigator.pop(ctx); _addItem(o); },
                )),
                if (widget.allowCustom)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.add, color: AppColors.primary, size: 18),
                    title: const Text('Not in list — enter manually',
                        style: TextStyle(color: AppColors.dark,
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() => _showCustom = true);
                    },
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final realOptions = widget.options
        .where((o) =>
            !o.toLowerCase().startsWith('select') &&
            o != 'Not in list — enter manually' &&
            o != 'All')
        .where((o) => !selected.contains(o))
        .toSet()
        .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        if (selected.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: selected.map((item) => Chip(
              label: Text(item, style: const TextStyle(fontSize: 12)),
              backgroundColor: AppColors.lightYellow,
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () => _removeItem(item),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            )).toList(),
          ),
          const SizedBox(height: 6),
        ],
        if (!_showCustom)
          GestureDetector(
            onTap: () => _openSearchPicker(context, realOptions),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.search, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  selected.isEmpty ? 'Search and select…' : '+ Add another…',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                )),
                const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
              ]),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.lightYellow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(children: [
              const Icon(Icons.edit, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _customController,
                  decoration: InputDecoration(
                    hintText: widget.customHint,
                    hintStyle: AppTextStyles.caption,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _confirmCustom(),
                ),
              ),
              if (_customController.text.isNotEmpty)
                GestureDetector(
                  onTap: _confirmCustom,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 16),
                  ),
                ),
              GestureDetector(
                onTap: () => setState(() {
                  _showCustom = false;
                  _customController.clear();
                }),
                child: const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.close, size: 16, color: AppColors.textSecondary),
                ),
              ),
            ]),
          ),
        if (_showCustom)
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 4),
            child: Text(
              'Type your answer and tap ✓ to confirm',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
            ),
          ),
      ],
    );
  }
}
