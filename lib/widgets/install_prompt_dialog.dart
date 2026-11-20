import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../utils/pwa_install.dart';

/// Call this once after login to show the install popup (if eligible).
Future<void> maybeShowInstallPrompt(BuildContext context) async {
  if (!kIsWeb) return;
  if (PwaInstall.isStandalone) return; // already installed

  try {
    final prefs = await SharedPreferences.getInstance();
    // Don't show again if user dismissed within last 7 days
    final lastDismissed = prefs.getInt('pwaPromptDismissed') ?? 0;
    final daysSince = DateTime.now().millisecondsSinceEpoch - lastDismissed;
    if (daysSince < const Duration(days: 7).inMilliseconds) return;
  } catch (_) {}

  if (!context.mounted) return;

  // Wait a moment so it doesn't pop up instantly on login
  await Future.delayed(const Duration(seconds: 2));
  if (!context.mounted) return;

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _InstallDialog(),
  );
}

class _InstallDialog extends StatelessWidget {
  const _InstallDialog();

  Future<void> _dismiss(BuildContext context, {bool install = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pwaPromptDismissed', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
    if (context.mounted) Navigator.of(context).pop();
    if (install) await PwaInstall.promptInstall();
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = PwaInstall.isIOS;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.dark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.eco_outlined, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Add to your home screen',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.dark),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Install Remedy Handbook for quick access — works like a native app, no App Store needed.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            if (isIOS) ...[
              // iOS: manual instructions
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.lightYellow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Column(children: const [
                  _Step(icon: Icons.ios_share, text: 'Tap the Share button in Safari'),
                  SizedBox(height: 8),
                  _Step(icon: Icons.add_box_outlined, text: 'Tap "Add to Home Screen"'),
                  SizedBox(height: 8),
                  _Step(icon: Icons.check_circle_outline, text: 'Tap "Add" to confirm'),
                ]),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _dismiss(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ] else ...[
              // Android / Chrome: use browser prompt
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_to_home_screen, size: 18),
                  label: const Text('Add to Home Screen',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  onPressed: () => _dismiss(context, install: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => _dismiss(context),
              child: const Text('Not now',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Step({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.dark),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: const TextStyle(fontSize: 12, color: AppColors.dark))),
    ]);
  }
}
