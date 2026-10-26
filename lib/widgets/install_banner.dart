import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/pwa_install.dart';

class InstallBanner extends StatefulWidget {
  const InstallBanner({super.key});

  @override
  State<InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends State<InstallBanner> {
  bool _dismissed = false;
  bool _canInstall = false;
  StreamSubscription<bool>? _sub;

  static const _kKey = 'rhInstallDismiss';

  @override
  void initState() {
    super.initState();
    _checkDismissed();
    _sub = PwaInstall.canInstallStream.listen((can) {
      if (mounted) setState(() => _canInstall = can);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _checkDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final until = prefs.getInt(_kKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (mounted) setState(() => _dismissed = now < until);
    } catch (_) {}
  }

  Future<void> _dismiss() async {
    // Dismiss until midnight tonight
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kKey, midnight.millisecondsSinceEpoch);
    } catch (_) {}
    if (mounted) setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || PwaInstall.isStandalone) return const SizedBox.shrink();

    if (PwaInstall.isIOS) {
      return _bannerShell(
        icon: Icons.ios_share,
        text: 'Tap Share then Add to Home Screen to install the app.',
        actionLabel: null,
        onAction: null,
      );
    }

    if (_canInstall) {
      return _bannerShell(
        icon: Icons.add_to_home_screen,
        text: 'Get the app for the best experience',
        actionLabel: 'Install',
        onAction: () => PwaInstall.promptInstall(),
      );
    }

    // Fallback — always show with download link
    return _bannerShell(
      icon: Icons.phone_android_outlined,
      text: 'Get the app for the best experience',
      actionLabel: 'Install App',
      onAction: null,
    );
  }

  Widget _bannerShell({
    required IconData icon,
    required String text,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      color: AppColors.dark,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(actionLabel,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.dark,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _dismiss,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child:
                  Icon(Icons.close, size: 16, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
