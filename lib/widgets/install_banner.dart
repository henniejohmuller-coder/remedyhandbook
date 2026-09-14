import "dart:async";
import "package:flutter/material.dart";
import "../theme/app_theme.dart";
import "../utils/pwa_install.dart";

class InstallBanner extends StatefulWidget {
  const InstallBanner({super.key});

  @override
  State<InstallBanner> createState() => _InstallBannerState();
}

class _InstallBannerState extends State<InstallBanner> {
  bool _dismissed = false;
  bool _canInstall = false;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = PwaInstall.canInstallStream.listen((can) {
      if (mounted) setState(() => _canInstall = can);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || PwaInstall.isStandalone) {
      return const SizedBox.shrink();
    }

    if (PwaInstall.isIOS) {
      return _bannerShell(
        icon: Icons.ios_share,
        text: "Add Remedy Handbook to your Home Screen: tap the Share icon, then \"Add to Home Screen\".",
        actionLabel: null,
        onAction: null,
      );
    }

    if (!_canInstall) {
      return const SizedBox.shrink();
    }

    return _bannerShell(
      icon: Icons.add_to_home_screen,
      text: "Enjoying this? Add Remedy Handbook to your home screen.",
      actionLabel: "Add",
      onAction: () => PwaInstall.promptInstall(),
    );
  }

  Widget _bannerShell({
    required IconData icon,
    required String text,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _dismissed = true),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
