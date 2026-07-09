// Selects the correct implementation at compile time:
//   Web              → csv_download_web.dart  (dart:html AnchorElement)
//   Windows/Android  → csv_download_io.dart   (path_provider file save)
export 'csv_download_web.dart'
    if (dart.library.io) 'csv_download_io.dart';
