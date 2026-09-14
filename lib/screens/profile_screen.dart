import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../widgets/navigation_guard.dart';
import '../services/supabase_service.dart';
import 'admin_content_screen.dart';
import 'admin_csv_upload_screen.dart';
import 'admin_ratings_screen.dart';
import 'admin_review_screen.dart';
import 'admin_shop_screen.dart';
import 'admin_shop_report_screen.dart';
import 'admin_purchase_report_screen.dart';
import 'admin_purchase_report_screen.dart';
import 'admin_shop_report_screen.dart';
import 'change_password_screen.dart';
import 'notifications_screen.dart';
import 'shipping_address_screen.dart';
import 'policy_screen.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _editing = false;
  bool _saving  = false;
  bool _isAdmin = false;

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _locationController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _countryController;
  late TextEditingController _avatarUrlController;

  @override
  void initState() {
    super.initState();
    _nameController      = TextEditingController();
    _phoneController     = TextEditingController();
    _locationController  = TextEditingController();
    _addressController   = TextEditingController();
    _cityController      = TextEditingController();
    _countryController   = TextEditingController();
    _avatarUrlController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;
      final profile = await SupabaseService.getProfile(userId);
      if (!mounted) return;
      setState(() {
        _profile             = profile;
        _isAdmin             = profile?['role'] == 'admin' || profile?['role'] == 'moderator';
        _nameController.text      = profile?['full_name'] ?? '';
        _phoneController.text     = profile?['phone'] ?? '';
        _locationController.text  = profile?['location'] ?? '';
        _addressController.text   = profile?['address'] ?? '';
        _cityController.text      = profile?['city'] ?? '';
        _countryController.text   = profile?['country'] ?? 'South Africa';
        _avatarUrlController.text = profile?['avatar_url'] ?? '';
        _loading             = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;
      await SupabaseService.updateProfile(userId, {
        'full_name':  _nameController.text.trim(),
        'phone':      _phoneController.text.trim(),
        'location':   _locationController.text.trim(),
        'address':    _addressController.text.trim(),
        'city':       _cityController.text.trim(),
        'country':    _countryController.text.trim(),
        'avatar_url': _avatarUrlController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      setState(() { _editing = false; _saving = false; });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profile updated!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showAvatarDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Profile picture URL', style: AppTextStyles.heading3),
        content: TextField(
          controller: _avatarUrlController,
          decoration: const InputDecoration(hintText: 'https://example.com/photo.jpg'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () { setState(() {}); Navigator.pop(ctx); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                foregroundColor: AppColors.dark, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Set'),
          ),
        ],
      ),
    );
  }

  String get _initials {
    final name = _nameController.text;
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  String get _joinedDate {
    final joined = _profile?['joined_at']?.toString();
    if (joined == null) return '';
    final date = DateTime.tryParse(joined);
    if (date == null) return '';
    const months = ['January','February','March','April','May','June',
                    'July','August','September','October','November','December'];
    return '${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final email  = SupabaseService.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            YellowAppBar(
              title: 'Profile',
              subtitle: _isAdmin ? 'Your account' : 'Your account',
              actions: [
                if (_isAdmin)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.dark, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Admin', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                GestureDetector(
                  onTap: () {
                    if (_editing) {
                      _saveProfile();
                    } else {
                      if (!mounted) return;
                      setState(() => _editing = true);
                    }
                  },
                  child: _saving
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                      : Icon(
                          _editing ? Icons.check_circle : Icons.edit_outlined,
                          color: AppColors.dark, size: 22,
                        ),
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Center(
                      child: Column(children: [
                        const SizedBox(height: 8),
                        Stack(children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.dark, shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary, width: 3),
                            ),
                            child: _avatarUrlController.text.isNotEmpty
                                ? ClipOval(child: Image.network(_avatarUrlController.text,
                                    width: 80, height: 80, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Center(child: Text(_initials,
                                        style: const TextStyle(color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.bold)))))
                                : Center(child: Text(_initials, style: const TextStyle(
                                    color: AppColors.primary, fontSize: 28, fontWeight: FontWeight.bold))),
                          ),
                          if (_editing)
                            Positioned(bottom: 0, right: 0,
                              child: GestureDetector(
                                onTap: () => _showAvatarDialog(),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt, size: 14, color: AppColors.dark),
                                ),
                              )),
                        ]),
                        const SizedBox(height: 10),
                        Text(_nameController.text.isNotEmpty ? _nameController.text : email,
                            style: AppTextStyles.heading2),
                        if (_joinedDate.isNotEmpty)
                          Text('Member since $_joinedDate', style: AppTextStyles.caption),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    // Personal details
                    const SectionLabel('PERSONAL DETAILS'),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                      ),
                      child: Column(children: [
                        _ProfileField(
                          icon: Icons.person_outline, label: 'Full name',
                          value: _nameController.text,
                          controller: _nameController, editing: _editing,
                        ),
                        const Divider(height: 16),
                        _ProfileField(
                          icon: Icons.email_outlined, label: 'Email',
                          value: email, editing: false, isLocked: true,
                        ),
                        const Divider(height: 16),
                        _ProfileField(
                          icon: Icons.phone_outlined, label: 'Phone',
                          value: _phoneController.text,
                          controller: _phoneController, editing: _editing,
                        ),
                        const Divider(height: 16),
                        _ProfileField(
                          icon: Icons.home_outlined, label: 'Address',
                          value: _addressController.text,
                          controller: _addressController, editing: _editing,
                        ),
                        const Divider(height: 16),
                        Row(children: [
                          Expanded(child: _ProfileField(
                            icon: Icons.location_city_outlined, label: 'City',
                            value: _cityController.text,
                            controller: _cityController, editing: _editing,
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: _ProfileField(
                            icon: Icons.flag_outlined, label: 'Country',
                            value: _countryController.text,
                            controller: _countryController, editing: _editing,
                          )),
                        ]),
                        const Divider(height: 16),
                        _ProfileField(
                          icon: Icons.location_on_outlined, label: 'Location / Region',
                          value: _locationController.text,
                          controller: _locationController, editing: _editing,
                        ),
                        const Divider(height: 16),
                        _ProfileField(
                          icon: Icons.shield_outlined, label: 'Role',
                          value: (_profile?['role'] ?? 'user').toString().toUpperCase(),
                          editing: false, isLocked: true,
                        ),
                      ]),
                    ),

                    // Account
                    const SectionLabel('ACCOUNT'),
                    Material(
                      color: Colors.white, borderRadius: BorderRadius.circular(12), elevation: 1, shadowColor: Colors.black12,
                      child: Column(children: [
                        _MenuRow(icon: Icons.lock_outline, label: 'Change password',
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen()))),
                        const Divider(height: 1, indent: 48),
                        _MenuRow(icon: Icons.notifications_outlined, label: 'Notifications',
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
                        const Divider(height: 1, indent: 48),
                        _MenuRow(icon: Icons.local_shipping_outlined, label: 'Default shipping address',
                              onTap: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const ShippingAddressScreen()))),
                        const Divider(height: 1, indent: 48),
                        _MenuRow(icon: Icons.help_outline, label: 'Help & Support',
                              onTap: () async {
                                final content = await SupabaseService.getAppContent('help_support');
                                if (!context.mounted) return;
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Text('Help & Support', style: AppTextStyles.heading3),
                                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                                      const Icon(Icons.support_agent, size: 48, color: AppColors.primary),
                                      const SizedBox(height: 12),
                                      const Text('Need help? Email us at:', style: AppTextStyles.caption, textAlign: TextAlign.center),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(color: AppColors.lightYellow,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.primary)),
                                        child: Text(content.isNotEmpty ? content : 'support@remedyhandbook.com',
                                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.dark)),
                                      ),
                                      const SizedBox(height: 8),
                                      const Text('We typically respond within 24 hours.', style: AppTextStyles.caption, textAlign: TextAlign.center),
                                    ]),
                                    actions: [ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                                          foregroundColor: AppColors.dark, elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                      child: const Text('Got it'),
                                    )],
                                  ),
                                );
                              }),
                        const Divider(height: 1, indent: 48),
                        _MenuRow(
                          icon: Icons.gavel,
                          label: 'Terms & Conditions',
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PolicyScreen())),
                        ),
                        const Divider(height: 1, indent: 48),
                        _MenuRow(icon: Icons.info_outline, label: 'About',
                              onTap: () async {
                                final content = await SupabaseService.getAppContent('about');
                                if (!context.mounted) return;
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    title: const Text('About Remedy Handbook', style: AppTextStyles.heading3),
                                    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
                                      Container(
                                        width: 64, height: 64,
                                        decoration: BoxDecoration(color: AppColors.dark, borderRadius: BorderRadius.circular(16)),
                                        child: const Center(child: Icon(Icons.eco, color: AppColors.primary, size: 36)),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(content.isNotEmpty ? content :
                                          'Remedy Handbook is your trusted guide to the world of herbal medicine.',
                                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
                                          textAlign: TextAlign.center),
                                      const SizedBox(height: 16),
                                      const Text('Version 1.0.0', style: AppTextStyles.caption),
                                      const Text('© 2026 RemedyHandbook.com', style: AppTextStyles.caption),
                                    ])),
                                    actions: [ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                                          foregroundColor: AppColors.dark, elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                      child: const Text('Close'),
                                    )],
                                  ),
                                );
                              }),
                      ]),
                    ),

                    // Admin section
                    if (_isAdmin) ...[
                      const SectionLabel('ADMIN'),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary, width: 1.5),
                        ),
                        child: Material(
                          color: Colors.white, borderRadius: BorderRadius.circular(11), elevation: 0,
                          child: Column(children: [
                            _MenuRow(
                              icon: Icons.upload_file_outlined,
                              label: 'Bulk CSV upload',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCsvUploadScreen())),
                            ),
                            const Divider(height: 1, indent: 48),
                            _MenuRow(
                              icon: Icons.rate_review_outlined,
                              label: 'Review submissions',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReviewScreen())),
                            ),
                            const Divider(height: 1, indent: 48),
                            _MenuRow(
                              icon: Icons.storefront_outlined,
                              label: 'Manage shop items',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminShopScreen())),
                            ),
                            const Divider(height: 1, indent: 48),
                            _MenuRow(
                              icon: Icons.receipt_long,
                              label: 'Shop Report',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminShopReportScreen())),
                            ),
                            const Divider(height: 1, indent: 48),
                            _MenuRow(
                              icon: Icons.shopping_basket_outlined,
                              label: 'Purchase Report',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPurchaseReportScreen())),
                            ),
                            const Divider(height: 1, indent: 48),
                            _MenuRow(
                              icon: Icons.star_half_outlined,
                              label: 'Manage ratings',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRatingsScreen())),
                            ),
                            const Divider(height: 1, indent: 48),
                            _MenuRow(
                              icon: Icons.edit_document,
                              label: 'Edit app content',
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminContentScreen())),
                            ),
                          ]),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    // Sign out
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          NavigationGuard.clear();
                          await SupabaseService.signOut();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (r) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.logout, size: 18, color: Colors.red),
                        label: const Text('Sign out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          side: const BorderSide(color: Colors.red),
                        ),
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

// ── Profile Field ─────────────────────────────────────────────────────────
class _ProfileField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextEditingController? controller;
  final bool editing;
  final bool isLocked;

  const _ProfileField({
    required this.icon, required this.label, required this.value,
    this.controller, this.editing = false, this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.textSecondary),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: AppTextStyles.label),
          const SizedBox(height: 2),
          editing && !isLocked && controller != null
              ? TextField(
                  controller: controller,
                  style: AppTextStyles.body,
                  decoration: const InputDecoration(
                    isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: UnderlineInputBorder(),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                  ),
                )
              : Text(value.isNotEmpty ? value : '—', style: AppTextStyles.body),
        ]),
      ),
      if (isLocked) const Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
    ]);
  }
}

// ── Menu Row ──────────────────────────────────────────────────────────────
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  const _MenuRow({required this.icon, required this.label, this.badge, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, size: 20, color: AppColors.dark),
      title: Text(label, style: AppTextStyles.body),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
            child: Text(badge!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.dark)),
          ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
      ]),
    );
  }
}

