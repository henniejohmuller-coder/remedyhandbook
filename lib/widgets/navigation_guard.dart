import 'package:flutter/material.dart';

/// Global navigation guard.
/// Any screen can register a callback to intercept navigation attempts.
/// The AppShell bottom nav and YellowAppBar cart icon check this before navigating.
class NavigationGuard {
  static Future<bool> Function(BuildContext context)? _guard;

  static void register(Future<bool> Function(BuildContext context) guard) {
    _guard = guard;
  }

  static void clear() {
    _guard = null;
  }

  /// Returns true if navigation should proceed, false if blocked.
  static Future<bool> shouldNavigate(BuildContext context) async {
    if (_guard == null) return true;
    return await _guard!(context);
  }
}
