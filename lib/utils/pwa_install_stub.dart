class PwaInstall {
  static Stream<bool> get canInstallStream => const Stream.empty();
  static bool get isIOS => false;
  static bool get isStandalone => false;
  static Future<void> promptInstall() async {}
}
