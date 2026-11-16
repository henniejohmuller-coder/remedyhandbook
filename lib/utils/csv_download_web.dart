// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Triggers a browser download of a CSV string. Returns null.
Future<String?> downloadCsv(String csvContent, String filename) async {
  html.AnchorElement(
    href: 'data:text/csv;charset=utf-8,${Uri.encodeComponent(csvContent)}',
  )
    ..setAttribute('download', filename)
    ..click();
  return null;
}

/// Triggers a browser download of raw bytes (e.g. an xlsx file). Returns null.
Future<String?> downloadXlsx(List<int> bytes, String filename) async {
  final blob = html.Blob(
    [bytes],
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return null;
}
