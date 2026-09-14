// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Triggers a browser download. Returns null — the browser handles feedback.
Future<String?> downloadCsv(String csvContent, String filename) async {
  html.AnchorElement(
    href: 'data:text/csv;charset=utf-8,${Uri.encodeComponent(csvContent)}',
  )
    ..setAttribute('download', filename)
    ..click();
  return null;
}
