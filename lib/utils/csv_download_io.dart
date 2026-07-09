import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:path_provider/path_provider.dart';

/// Saves [csvContent] as [filename] in the platform Downloads folder.
/// Returns the full saved path, or null if saving failed.
Future<String?> downloadCsv(String csvContent, String filename) async {
  try {
    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } catch (_) {}
    dir ??= await getApplicationDocumentsDirectory();

    final file = File('${dir.path}/$filename');
    await file.writeAsString(csvContent, encoding: utf8, flush: true);
    return file.path;
  } catch (e) {
    debugPrint('CSV save error: $e');
    return null;
  }
}
