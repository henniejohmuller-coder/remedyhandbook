import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  bool _saving  = false;

  // Notification preferences
  bool _newRemedies      = true;
  bool _submissionUpdate = true;
  bool _orderUpdates     = true;
  bool _shopDeals        = false;
  bool _weeklyDigest     = false;
  bool _reviewReplies    = true;
  bool _adminAlerts      = false; // only shown to admins
  bool _isAdmin          = false;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    setState(() => _loading = true);
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) { setState(() => _loading = false); return; }
      final profile = await SupabaseService.getProfile(userId);
      final prefs   = profile?['notification_prefs'] as Map? ?? {};
      setState(() {
        _isAdmin          = profile?['role'] == 'admin' || profile?['role'] == 'moderator';
        _newRemedies      = prefs['new_remedies']      ?? true;
        _submissionUpdate = prefs['submission_update'] ?? true;
        _orderUpdates     = prefs['order_updates']     ?? true;
        _shopDeals        = prefs['shop_deals']        ?? false;
        _weeklyDigest     = prefs['weekly_digest']     ?? false;
        _reviewReplies    = prefs['review_replies']    ?? true;
        _adminAlerts      = prefs['admin_alerts']      ?? false;
        _loading          = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;
      await SupabaseService.updateProfile(userId, {
        'notification_prefs': {
          'new_remedies':      _newRemedies,
          'submission_update': _submissionUpdate,
          'order_updates':     _orderUpdates,
          'shop_deals':        _shopDeals,
          'weekly_digest':     _weeklyDigest,
          'review_replies':    _reviewReplies,
          'admin_alerts':      _adminAlerts,
        },
        'updated_at': DateTime.now().toIso8601String(),
      });
      setState(() => _saving = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Notification preferences saved!'),
              backgroundColor: Colors.green, duration: Duration(seconds: 2)));
      }
    } catch (e) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          YellowAppBar(
            title: 'Notifications',
            subtitle: 'Choose what to be notified about',
            showBack: true,
            actions: [
              GestureDetector(
                onTap: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                    : const Icon(Icons.check_circle, color: AppColors.dark, size: 22),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // Remedies
                      const SectionLabel('REMEDIES'),
                      _NotifCard(children: [
                        _NotifRow(
                          title: 'New remedies added',
                          subtitle: 'When new approved remedies are published',
                          value: _newRemedies,
                          onChanged: (v) => setState(() => _newRemedies = v),
                        ),
                        const Divider(height: 1),
                        _NotifRow(
                          title: 'Submission updates',
                          subtitle: 'When your submission status changes',
                          value: _submissionUpdate,
                          onChanged: (v) => setState(() => _submissionUpdate = v),
                        ),
                        const Divider(height: 1),
                        _NotifRow(
                          title: 'Review replies',
                          subtitle: 'When someone responds to your review',
                          value: _reviewReplies,
                          onChanged: (v) => setState(() => _reviewReplies = v),
                        ),
                      ]),

                      // Orders & Shop
                      const SectionLabel('ORDERS & SHOP'),
                      _NotifCard(children: [
                        _NotifRow(
                          title: 'Order updates',
                          subtitle: 'Shipping and delivery notifications',
                          value: _orderUpdates,
                          onChanged: (v) => setState(() => _orderUpdates = v),
                        ),
                        const Divider(height: 1),
                        _NotifRow(
                          title: 'Shop deals & promotions',
                          subtitle: 'Special offers and discounts',
                          value: _shopDeals,
                          onChanged: (v) => setState(() => _shopDeals = v),
                        ),
                      ]),

                      // General
                      const SectionLabel('GENERAL'),
                      _NotifCard(children: [
                        _NotifRow(
                          title: 'Weekly digest',
                          subtitle: 'A weekly summary of new content',
                          value: _weeklyDigest,
                          onChanged: (v) => setState(() => _weeklyDigest = v),
                        ),
                      ]),

                      // Admin
                      if (_isAdmin) ...[
                        const SectionLabel('ADMIN'),
                        _NotifCard(children: [
                          _NotifRow(
                            title: 'New submissions to review',
                            subtitle: 'When users submit new remedies',
                            value: _adminAlerts,
                            onChanged: (v) => setState(() => _adminAlerts = v),
                          ),
                        ]),
                      ],

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: _saving
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                              : const Text('Save preferences',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  final List<Widget> children;
  const _NotifCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Column(children: children),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _NotifRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppTextStyles.body),
          Text(subtitle, style: AppTextStyles.caption),
        ])),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: AppColors.primary,
          activeTrackColor: AppColors.dark,
        ),
      ]),
    );
  }
}
