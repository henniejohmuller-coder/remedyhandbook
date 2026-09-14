import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';

class PolicyScreen extends StatefulWidget {
  const PolicyScreen({super.key});

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  String _content = '';
  String _updatedAt = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.supabase
          .from('app_content').select().eq('key', 'terms').single();
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
            title: 'Terms & Conditions',
            subtitle: 'Please read carefully',
            showBack: true,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Last updated
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: AppColors.lightYellow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.primary)),
                        child: Row(children: [
                          const Icon(Icons.info_outline, size: 16, color: AppColors.dark),
                          const SizedBox(width: 8),
                          Text('Last updated: $_updatedAt',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark)),
                        ]),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _content.isNotEmpty ? _content : 'Terms and conditions will be added here.',
                        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.7),
                      ),
                      const SizedBox(height: 32),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }
}
