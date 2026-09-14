import 'dart:convert';
import 'package:http/http.dart' as http;

/// Searches Wikipedia for a 250px Wikimedia thumbnail URL for the given
/// plant/herb name. Returns null if nothing is found or on error.
/// Fast: single JSON API call (~2KB), no image download.
Future<String?> findWikimediaImage(String query) async {
  // Strip preparation types and parenthetical scientific names
  final clean = query
      .replaceAll(RegExp(r'\s*\(.*?\)\s*'), ' ')
      .replaceAll(
          RegExp(
              r'\b(tea|tincture|decoction|infusion|syrup|extract|oil|capsule'
              r'|powder|salve|gel|root|leaf|bark|seed|flower|bitter|purge'
              r'|wash|compress|poultice|elixir|juice|warm|cold|short|long'
              r'|daily|recovery|restorative|support|calm|stress|digestive'
              r'|immune|liver|skin|chest|winter|bronchial|fever|anti)\b',
              caseSensitive: false),
          ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  final term = clean.isEmpty ? query.trim() : clean;
  if (term.isEmpty) return null;

  try {
    // Step 1 — direct page lookup with pageimages
    final url1 = Uri.parse(
      'https://en.wikipedia.org/w/api.php?action=query'
      '&titles=${Uri.encodeComponent(term)}'
      '&prop=pageimages&format=json&pithumbsize=250',
    );
    final r1 = await http.get(url1).timeout(const Duration(seconds: 8));
    if (r1.statusCode == 200) {
      final d1 = jsonDecode(r1.body) as Map;
      final pages = (d1['query']?['pages'] as Map?) ?? {};
      final page = pages.values.isNotEmpty ? pages.values.first as Map : null;
      if (page != null && page['thumbnail'] != null) {
        return (page['thumbnail'] as Map)['source'] as String?;
      }
    }

    // Step 2 — full-text search fallback
    final url2 = Uri.parse(
      'https://en.wikipedia.org/w/api.php?action=query'
      '&list=search&srsearch=${Uri.encodeComponent(term)}'
      '&srlimit=1&format=json',
    );
    final r2 = await http.get(url2).timeout(const Duration(seconds: 8));
    if (r2.statusCode == 200) {
      final d2 = jsonDecode(r2.body) as Map;
      final results = (d2['query']?['search'] as List?) ?? [];
      if (results.isNotEmpty) {
        final title = (results.first as Map)['title'] as String;
        final url3 = Uri.parse(
          'https://en.wikipedia.org/w/api.php?action=query'
          '&titles=${Uri.encodeComponent(title)}'
          '&prop=pageimages&format=json&pithumbsize=250',
        );
        final r3 = await http.get(url3).timeout(const Duration(seconds: 8));
        if (r3.statusCode == 200) {
          final d3 = jsonDecode(r3.body) as Map;
          final pages = (d3['query']?['pages'] as Map?) ?? {};
          final page = pages.values.isNotEmpty ? pages.values.first as Map : null;
          if (page != null && page['thumbnail'] != null) {
            return (page['thumbnail'] as Map)['source'] as String?;
          }
        }
      }
    }
  } catch (_) {}
  return null;
}
