import "dart:async";
import "dart:html" as html;
import "dart:js_util" as js_util;

class PwaInstall {
  static final _controller = StreamController<bool>.broadcast();
  static dynamic _deferredPrompt;
  static bool _listenerAttached = false;

  static void _attachListener() {
    if (_listenerAttached) return;
    _listenerAttached = true;
    html.window.addEventListener("beforeinstallprompt", (event) {
      event.preventDefault();
      _deferredPrompt = event;
      _controller.add(true);
    });
    html.window.addEventListener("appinstalled", (event) {
      _deferredPrompt = null;
      _controller.add(false);
    });
  }

  static Stream<bool> get canInstallStream {
    _attachListener();
    return _controller.stream;
  }

  static bool get isIOS {
    final ua = html.window.navigator.userAgent.toLowerCase();
    return ua.contains("iphone") || ua.contains("ipad") || ua.contains("ipod");
  }

  static bool get isStandalone {
    try {
      return html.window.matchMedia("(display-mode: standalone)").matches;
    } catch (_) {
      return false;
    }
  }

  static Future<void> promptInstall() async {
    if (_deferredPrompt == null) return;
    js_util.callMethod(_deferredPrompt, "prompt", []);
    _deferredPrompt = null;
    _controller.add(false);
  }
}
