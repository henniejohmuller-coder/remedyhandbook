// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;

class PwaInstall {
  static html.Event? _deferredPrompt;
  static final _controller = StreamController<bool>.broadcast();

  static Stream<bool> get canInstallStream => _controller.stream;

  static bool get isStandalone {
    try {
      return html.window.matchMedia('(display-mode: standalone)').matches ||
          (html.window.navigator as dynamic).standalone == true;
    } catch (_) { return false; }
  }

  static bool get isIOS {
    final ua = html.window.navigator.userAgent.toLowerCase();
    return (ua.contains('iphone') || ua.contains('ipad') || ua.contains('ipod'))
        && !ua.contains('crios');
  }

  static bool get canInstall => _deferredPrompt != null;

  static void init() {
    html.window.addEventListener('beforeinstallprompt', (event) {
      event.preventDefault();
      _deferredPrompt = event;
      _controller.add(true);
    });
    html.window.addEventListener('appinstalled', (_) {
      _deferredPrompt = null;
      _controller.add(false);
    });
  }

  static Future<bool> promptInstall() async {
    final prompt = _deferredPrompt;
    if (prompt == null) return false;
    try {
      (prompt as dynamic).prompt();
      final outcome = await (prompt as dynamic).userChoice;
      _deferredPrompt = null;
      _controller.add(false);
      return (outcome as dynamic).outcome == 'accepted';
    } catch (_) { return false; }
  }
}
