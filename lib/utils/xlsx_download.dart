// Selects the correct implementation at compile time:
//   Web              → xlsx_download_web.dart  (dart:html Blob download)
//   Windows/Android  → xlsx_download_io.dart   (path_provider file save)
export 'xlsx_download_web.dart'
    if (dart.library.io) 'xlsx_download_io.dart';
