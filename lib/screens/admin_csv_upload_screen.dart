import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import '../utils/csv_download.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';

// ── Error model ───────────────────────────────────────────────────────────────
class _UploadError {
  final int rowNumber;          // 1-based row number in original CSV
  final String remedyName;
  final String errorMessage;
  final Map<String, String> rowData; // full original row for re-download
  const _UploadError({
    required this.rowNumber,
    required this.remedyName,
    required this.errorMessage,
    required this.rowData,
  });
}

class AdminCsvUploadScreen extends StatefulWidget {
  const AdminCsvUploadScreen({super.key});

  @override
  State<AdminCsvUploadScreen> createState() => _AdminCsvUploadScreenState();
}

class _AdminCsvUploadScreenState extends State<AdminCsvUploadScreen> {
  List<Map<String, String>> _rows     = [];
  List<String>              _headers  = [];
  List<String>              _parseErrors   = [];   // pre-upload parse/validation errors
  List<String>              _parseWarnings = [];
  List<_UploadError>        _uploadErrors  = [];   // per-row upload errors → downloadable
  bool _uploading     = false;
  bool _dbDownloading = false;
  bool _shopExporting = false;
  bool _shopImporting = false;
  bool _cancelled  = false;
  bool _parsed     = false;
  bool _uploadDone = false;
  int  _uploaded   = 0;  // successfully uploaded rows
  String? _fileName;

  // ── CSV Column Spec ──────────────────────────────────────────────────────
  static const _requiredCols = ['name', 'component'];
  static const _allCols = [
    'name','component','origin','illness_name','category_name',
    'sub_category_name','symptom_name','organ_name','plant_part',
    'prep_type','difficulty','prep_time','ingredients','servings',
    'function','mechanism','constituent','cautions','clinical_study_url',
    'image_url','encouragement','tradition_rating','validation_level',
    'efficacy','efficacy_ref','step_1','step_2','step_3','step_4','step_5',
    'step_6','step_7','step_8','step_9','step_10',
  ];

  // ── Pre-upload row validation ─────────────────────────────────────────────
  // Returns a list of error strings for a row; empty = row is valid.
  List<String> _validateRow(Map<String, String> row, int rowNum) {
    final errs = <String>[];

    // Required fields
    if ((row['name'] ?? '').trim().isEmpty) {
      errs.add('name is required');
    }
    if ((row['component'] ?? '').trim().isEmpty) {
      errs.add('component is required');
    }

    // Numeric fields
    final tradRating = row['tradition_rating'] ?? '';
    if (tradRating.isNotEmpty) {
      final v = int.tryParse(tradRating);
      if (v == null || v < 1 || v > 5) errs.add('tradition_rating "$tradRating" must be 1–5');
    }
    final valLevel = row['validation_level'] ?? '';
    if (valLevel.isNotEmpty) {
      final v = int.tryParse(valLevel);
      if (v == null || v < 1 || v > 5) errs.add('validation_level "$valLevel" must be 1–5');
    }
    final efficacy = row['efficacy'] ?? '';
    if (efficacy.isNotEmpty) {
      final v = int.tryParse(efficacy);
      if (v == null || v < 0 || v > 100) errs.add('efficacy "$efficacy" must be 0–100');
    }

    // Image URL format: must be correct Wikimedia 250px thumb or empty
    final img = row['image_url'] ?? '';
    if (img.isNotEmpty) {
      final isWiki250 = img.startsWith('https://upload.wikimedia.org/wikipedia/commons/thumb/') &&
          img.contains('/250px-');
      final isOtherHttp = img.startsWith('http') && !img.contains('wikimedia');
      if (!isWiki250 && !isOtherHttp) {
        errs.add('image_url format invalid — must be Wikimedia 250px thumb URL or a direct image URL');
      }
    }

    // At least step_1 should be present
    if ((row['step_1'] ?? '').trim().isEmpty) {
      errs.add('step_1 is empty — at least one preparation step is required');
    }

    return errs;
  }

  // ── RFC 4180 full-content CSV parser ─────────────────────────────────────
  // Single-pass parser that correctly handles:
  //   • Quoted fields with embedded newlines (the main cause of "9 columns" errors)
  //   • Escaped double-quotes ("")
  //   • Any delimiter — comma (Excel EN), semicolon (Excel ZA/EU), tab (TSV)
  //   • UTF-8 BOM from Excel "Save as UTF-8 CSV"
  //   • Windows (\r\n) and Unix (\n) line endings
  List<List<String>> _parseAllRows(String raw) {
    // Strip UTF-8 BOM
    if (raw.startsWith('\uFEFF')) raw = raw.substring(1);

    // Detect delimiter from the first line (before the first newline)
    final firstNl  = raw.indexOf('\n');
    final firstLine = (firstNl >= 0 ? raw.substring(0, firstNl) : raw)
        .replaceAll('\r', '');
    final delimiter = _detectDelimiter(firstLine);

    final records       = <List<String>>[];
    var   currentRecord = <String>[];
    final buf           = StringBuffer();
    bool  inQuotes      = false;
    final dLen          = delimiter.length;

    for (int i = 0; i < raw.length; i++) {
      final c = raw[i];

      if (inQuotes) {
        if (c == '"') {
          // Escaped quote "" → emit single "
          if (i + 1 < raw.length && raw[i + 1] == '"') {
            buf.write('"');
            i++;
          } else {
            inQuotes = false; // closing quote — stay in same field
          }
        } else {
          buf.write(c); // embedded newlines, commas, etc. — all go into the field
        }
      } else {
        if (c == '"') {
          inQuotes = true;
        } else if (i + dLen <= raw.length &&
            raw.substring(i, i + dLen) == delimiter) {
          // Field separator
          currentRecord.add(buf.toString());
          buf.clear();
          i += dLen - 1;
        } else if (c == '\r') {
          // Ignore bare \r (Windows line endings handled by \n below)
        } else if (c == '\n') {
          // Record separator — only triggered outside quotes
          currentRecord.add(buf.toString());
          buf.clear();
          if (currentRecord.any((f) => f.trim().isNotEmpty)) {
            records.add(currentRecord);
          }
          currentRecord = [];
        } else {
          buf.write(c);
        }
      }
    }

    // Flush last field / record if file has no trailing newline
    if (buf.isNotEmpty || currentRecord.isNotEmpty) {
      currentRecord.add(buf.toString());
      if (currentRecord.any((f) => f.trim().isNotEmpty)) {
        records.add(currentRecord);
      }
    }

    return records;
  }

  String _detectDelimiter(String headerLine) {
    int countChar(String line, String d) {
      int n = 0;
      bool q = false;
      for (int i = 0; i < line.length; i++) {
        if (line[i] == '"') { q = !q; continue; }
        if (!q && i + d.length <= line.length &&
            line.substring(i, i + d.length) == d) n++;
      }
      return n;
    }
    final c = countChar(headerLine, ',');
    final s = countChar(headerLine, ';');
    final t = countChar(headerLine, '\t');
    if (s > c && s > t) return ';';
    if (t > c && t > s) return '\t';
    return ',';
  }

  // ── Parse CSV ─────────────────────────────────────────────────────────────
  void _parseCsv(String content) {
    setState(() {
      _rows = []; _headers = []; _parseErrors = []; _parseWarnings = [];
      _uploadErrors = []; _parsed = false; _uploadDone = false;
      _uploaded = 0;
    });

    // _parseAllRows handles BOM stripping, delimiter detection, and
    // multi-line quoted fields in a single pass — no pre-splitting on \n.
    final allRows = _parseAllRows(content);

    if (allRows.isEmpty) {
      setState(() => _parseErrors = ['CSV file is empty']);
      return;
    }

    // Detect delimiter for the warning message (re-use same logic)
    final firstLine = content.startsWith('\uFEFF')
        ? content.substring(1).split('\n').first
        : content.split('\n').first;
    final delimiter = _detectDelimiter(firstLine.replaceAll('\r', ''));
    if (delimiter != ',') {
      final delimName = delimiter == ';' ? 'semicolon' : 'tab';
      _parseWarnings.add('Detected $delimName-delimited file — parsed accordingly');
    }

    // First record = header
    _headers = allRows[0]
        .map((h) => h.trim().toLowerCase().replaceAll('\uFEFF', ''))
        .toList();

    for (final col in _requiredCols) {
      if (!_headers.contains(col)) {
        _parseErrors.add('Missing required column: $col');
      }
    }
    for (final h in _headers) {
      if (!_allCols.contains(h)) _parseWarnings.add('Unknown column "$h" will be ignored');
    }

    if (_parseErrors.isNotEmpty) { setState(() {}); return; }

    final rows = <Map<String, String>>[];
    for (int i = 1; i < allRows.length; i++) {
      final vals = allRows[i];
      if (vals.length != _headers.length) {
        _parseWarnings.add('Row $i has ${vals.length} columns, expected ${_headers.length} — skipped');
        continue;
      }
      final row = <String, String>{};
      for (int j = 0; j < _headers.length; j++) {
        row[_headers[j]] = vals[j].trim();
      }
      if ((row['name'] ?? '').isEmpty) {
        _parseWarnings.add('Row $i has no name — skipped');
        continue;
      }
      rows.add(row);
    }

    // Pre-upload validation — collect validation errors as _UploadErrors
    // so they appear in the downloadable report if the user attempts upload.
    // We still allow proceeding to let the user decide, but we flag them.
    setState(() { _rows = rows; _parsed = true; });
  }

  // ── Pick file ─────────────────────────────────────────────────────────────
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _parseErrors = ['Could not read file — try re-saving the CSV in UTF-8 encoding']);
        return;
      }
      setState(() { _fileName = file.name; _uploadDone = false; });
      _parseCsv(utf8.decode(bytes, allowMalformed: true));
    } catch (e) {
      setState(() => _parseErrors = ['Error reading file: $e']);
    }
  }

  // ── Upload ────────────────────────────────────────────────────────────────
  Future<void> _upload() async {
    if (_rows.isEmpty) return;

    // Reset upload state
    setState(() {
      _uploadErrors = [];
      _uploading = true;
      _uploaded = 0;
      _cancelled = false;
      _uploadDone = false;
    });

    // Check DB duplicates
    final db = SupabaseService.supabase;
    final names = _rows.map((r) => r['name'] ?? '').toList();
    final existing = await db.from('remedies').select('name').inFilter('name', names);
    final existingNames = (existing as List).map((e) => e['name'].toString()).toSet();

    Set<String> skipNames = {};
    if (existingNames.isNotEmpty && mounted) {
      final selected = await showDialog<Set<String>>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _DuplicateDialog(existingNames: existingNames),
      );
      if (selected == null) { setState(() => _uploading = false); return; }
      skipNames = selected;
    }

    final rowsToUpload = _rows.where((r) => !skipNames.contains(r['name'] ?? '')).toList();
    if (rowsToUpload.isEmpty) { setState(() => _uploading = false); return; }

    for (int i = 0; i < rowsToUpload.length; i++) {
      if (_cancelled) {
        setState(() { _uploading = false; _uploadDone = true; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('⛔ Upload cancelled'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ));
        }
        return;
      }

      final row = rowsToUpload[i];
      final rowNum = _rows.indexOf(row) + 2; // +2 = 1-based + header row

      // ── Pre-upload validation ─────────────────────────────────────
      final validationErrs = _validateRow(row, rowNum);
      if (validationErrs.isNotEmpty) {
        setState(() {
          _uploadErrors.add(_UploadError(
            rowNumber: rowNum,
            remedyName: row['name'] ?? 'Row $rowNum',
            errorMessage: validationErrs.join('; '),
            rowData: Map.from(row),
          ));
        });
        continue; // skip DB upload for invalid row
      }

      // ── DB upload ─────────────────────────────────────────────────
      try {
        await _uploadRow(row);
        setState(() => _uploaded++);
      } catch (e) {
        final msg = e.toString()
            .replaceAll('PostgrestException(', '')
            .replaceAll(')', '')
            .trim();
        setState(() {
          _uploadErrors.add(_UploadError(
            rowNumber: rowNum,
            remedyName: row['name'] ?? 'Row $rowNum',
            errorMessage: msg,
            rowData: Map.from(row),
          ));
        });
      }
    }

    setState(() { _uploading = false; _uploadDone = true; });

    if (mounted && _uploadErrors.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ $_uploaded remedies uploaded successfully!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  Future<void> _uploadRow(Map<String, String> row) async {
    final db = SupabaseService.supabase;

    await _upsertLookup(db, 'illnesses',      'name',        row['illness_name']);
    await _upsertLookup(db, 'categories',     'name',        row['category_name']);
    await _upsertLookup(db, 'sub_categories', 'name',        row['sub_category_name']);
    await _upsertLookup(db, 'symptoms',       'name',        row['symptom_name']);
    await _upsertLookup(db, 'organs',         'name',        row['organ_name']);
    await _upsertLookup(db, 'countries',      'name',        row['origin']);
    await _upsertLookup(db, 'components',     'common_name', row['component']);

    final remedy = await db.from('remedies').upsert({
      'name':              row['name'],
      'component':         row['component'],
      'origin':            _val(row['origin']),
      'illness_name':      _val(row['illness_name']),
      'category_name':     _val(row['category_name']),
      'sub_category_name': _val(row['sub_category_name']),
      'symptom_name':      _val(row['symptom_name']),
      'organ_name':        _val(row['organ_name']),
      'plant_part':        _val(row['plant_part']),
      'prep_type':         _val(row['prep_type']),
      'difficulty':        _val(row['difficulty']),
      'prep_time':         int.tryParse((row['prep_time'] ?? '').replaceAll('.0', '').trim()),
      'ingredients':       _val(row['ingredients']),
      'servings':          _val(row['servings']),
      'function':          _val(row['function']),
      'mechanism':         _val(row['mechanism']),
      'constituent':       _val(row['constituent']),
      'cautions':          _val(row['cautions']),
      'clinical_study_url':_normaliseUrls(row['clinical_study_url'] ?? ''),
      'image_url':         _val(row['image_url']),
      'encouragement':     _val(row['encouragement']),
      'tradition_rating':  int.tryParse(row['tradition_rating'] ?? '') ?? 0,
      'validation_level':  int.tryParse(row['validation_level'] ?? '') ?? 1,
      'efficacy':          int.tryParse(row['efficacy'] ?? '') ?? 0,
      'efficacy_ref':      _val(row['efficacy_ref']),
      'status':            'pending',
      'submitted_by':      SupabaseService.currentUser?.id,
    }, onConflict: 'name').select('id').single();

    final remedyId = remedy['id'];
    final steps = <Map<String, dynamic>>[];
    for (int s = 1; s <= 10; s++) {
      final text = _val(row['step_$s']);
      if (text != null && text.isNotEmpty) {
        steps.add({'step_number': s, 'instruction': text});
      }
    }
    if (steps.isNotEmpty) {
      await db.rpc('replace_remedy_instructions', params: {
        'p_remedy_id': remedyId,
        'p_steps':     steps,
      });
    }
  }

  Future<void> _upsertLookup(dynamic db, String table, String col, String? val) async {
    if (val == null || val.isEmpty) return;
    // A single cell may contain multiple comma/semicolon-separated values
    // (e.g. "Cancer, Diabetes") — insert each as its own atomic lookup row.
    final items = val
        .split(RegExp(r'[,;]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    for (final item in items) {
      try { await db.from(table).upsert({col: item, 'active': true}, onConflict: col); }
      catch (_) {}
    }
  }

  // Accepts URLs separated by commas, semicolons, or newlines → one per line.
  String _normaliseUrls(String raw) {
    if (raw.trim().isEmpty) return '';
    return raw
        .split(RegExp(r'[,;\n]+'))
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty)
        .join('\n');
  }

  String? _val(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

  // ── Download Error Report CSV ────────────────────────────────────────────
  Future<void> _downloadErrorReport() async {
    if (_uploadErrors.isEmpty) return;

    // Columns: error metadata + all original CSV columns
    final reportCols = ['csv_row', 'remedy_name', 'error', ..._allCols];

    // Quote a cell value for CSV safety
    String q(String v) {
      if (v.contains(',') || v.contains('"') || v.contains('\n')) {
        return '"${v.replaceAll('"', '""')}"';
      }
      return v;
    }

    final lines = <String>[reportCols.join(',')];
    for (final err in _uploadErrors) {
      final cells = <String>[
        q(err.rowNumber.toString()),
        q(err.remedyName),
        q(err.errorMessage),
        ..._allCols.map((col) => q(err.rowData[col] ?? '')),
      ];
      lines.add(cells.join(','));
    }

    final csv = lines.join('\n');
    final ts = DateTime.now().toIso8601String().substring(0, 16).replaceAll(':', '-');
    final path = await downloadCsv(csv, 'upload_errors_${ts}.csv');
    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Error report saved to $path'),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  // ── Download full database as CSV ────────────────────────────────────────
  // Fetches all remedies from Supabase and exports as a CSV matching _allCols
  Future<void> _downloadDatabase() async {
    if (_dbDownloading) return;
    setState(() => _dbDownloading = true);

    try {
      final db = SupabaseService.supabase;

      // Fetch all remedies (no status filter — admin sees everything)
      final List rows = await db
          .from('remedies')
          .select('*, remedy_instructions(*)')
          .order('name');

      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No remedies found in database'),
            duration: Duration(seconds: 2),
          ));
        }
        setState(() => _dbDownloading = false);
        return;
      }

      // Quote a value for CSV safety
      String q(dynamic v) {
        final s = (v ?? '').toString();
        if (s.contains(',') || s.contains('"') || s.contains('\n')) {
          return '"${s.replaceAll('"', '""')}"';
        }
        return s;
      }

      final lines = <String>[_allCols.join(',')];

      for (final row in rows) {
        // Flatten remedy_instructions into step_1..step_10
        final steps = <int, String>{};
        final instructions = row['remedy_instructions'] as List? ?? [];
        for (final inst in instructions) {
          final num = inst['step_number'] as int? ?? 0;
          if (num >= 1 && num <= 10) {
            steps[num] = inst['instruction']?.toString() ?? '';
          }
        }

        final cells = _allCols.map((col) {
          if (col.startsWith('step_')) {
            final n = int.tryParse(col.split('_')[1]) ?? 0;
            return q(steps[n] ?? '');
          }
          return q(row[col]);
        }).toList();

        lines.add(cells.join(','));
      }

      final csv = lines.join('\n');
      final ts  = DateTime.now().toIso8601String().substring(0, 10);
      final path = await downloadCsv(csv, 'remedy_database_$ts.csv');

      if (mounted) {
        setState(() => _dbDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(path != null
              ? '✅ Database exported: ${rows.length} remedies — saved to $path'
              : '✅ Database exported: ${rows.length} remedies'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _dbDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ));
      }
    }
  }
  Future<void> _exportShopCsv() async {
    setState(() => _shopExporting = true);
    try {
      final data = await SupabaseService.supabase.from('products').select(
        'id, name, type, description, price, cost_price, stock, delivery_cost, active, image_url, category, brand, primary_herb, main_constituent'
      ).order('name');
      final rows = data as List;
      final headers = ['id','name','type','description','price','cost_price','stock','delivery_cost','active','image_url','category','brand','primary_herb','main_constituent'];
      final csvLines = [headers.join(',')];
      for (final r in rows) {
        final row = headers.map((h) {
          final val = (r[h] ?? '').toString().replaceAll('"', "'");
          return '"' + val + '"';
        }).toList();
        csvLines.add(row.join(','));
      }
      final csv = csvLines.join('\n');
      await downloadCsv(csv, 'shop_items_' + DateTime.now().millisecondsSinceEpoch.toString() + '.csv');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop items exported!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: ' + e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _shopExporting = false);
    }
  }

  Future<void> _importShopCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['csv'], withData: true);
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    setState(() => _shopImporting = true);
    try {
      final csv = utf8.decode(bytes);
      final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) return;
      final headers = lines.first.split(',').map((h) => h.trim().replaceAll('"', '')).toList();
      int updated = 0;
      for (int i = 1; i < lines.length; i++) {
        final values = lines[i].split(',').map((v) => v.trim().replaceAll('"', '')).toList();
        if (values.length < 2) continue;
        final row = <String, dynamic>{};
        for (int j = 0; j < headers.length; j++) {
          final h = headers[j];
          final v = j < values.length ? values[j] : '';
          if (h == 'price' || h == 'cost_price' || h == 'delivery_cost') {
            row[h] = double.tryParse(v) ?? 0;
          } else if (h == 'stock') {
            row[h] = int.tryParse(v) ?? 0;
          } else if (h == 'active') {
            row[h] = v.toLowerCase() == 'true';
          } else {
            if (v.isNotEmpty) row[h] = v;
          }
        }
        if (row.containsKey('id') && row['id'] != null && row['id'].toString().isNotEmpty) {
          await SupabaseService.supabase.from('products').upsert(row);
          updated++;
        } else {
          row.remove('id');
          await SupabaseService.supabase.from('products').insert(row);
          updated++;
        }
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ' + updated.toString() + ' shop items'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: ' + e.toString()), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _shopImporting = false);
    }
  }

  // ── Download Template ────────────────────────────────────────────────────
  Future<void> _downloadTemplate() async {
    final header = _allCols.join(',');
    final example = [
      'Buchu Tea',
      'Agathosma betulina (Buchu)',
      'South Africa',
      'Urinary tract infection',
      'Urinary health',
      'Bladder infections',
      'Burning urination, urinary tract infection, cystitis, fluid retention',
      'Kidney',
      'Leaf',
      'Infusion',
      'Easy',
      '10',
      '2 tsp dried buchu leaves + 250ml boiling water',
      '1 cup',
      'Natural diuretic and antiseptic for the urinary tract',
      'Diosphenol acts on kidney tubules increasing urine flow',
      'Diosphenol',
      'Avoid in pregnancy and kidney disease',
      '',
      'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9f/Agathosma_betulina.jpg/250px-Agathosma_betulina.jpg',
      'Buchu is one of nature\'s finest urinary herbs',
      '5',
      '4',
      '80',
      '',
      'Boil water and remove from heat',
      'Add 2 tsp dried buchu leaves to a cup',
      'Pour boiling water over the leaves',
      'Cover and steep for 10 minutes',
      'Strain and drink while warm',
      '',
      '',
      '',
      '',
      '',
    ].join(',');
    final csv = '$header\n$example';
    final path = await downloadCsv(csv, 'remedy_template.csv');
    if (path != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Template saved to $path'),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasUploadErrors  = _uploadErrors.isNotEmpty;
    final successCount     = _uploaded;
    final errorCount       = _uploadErrors.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        const YellowAppBar(
          title: 'Bulk CSV Upload',
          subtitle: 'Upload multiple remedies at once',
          showBack: true,
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [

            // ── Info / template card ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightYellow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('CSV Format - Remedies', style: AppTextStyles.heading3),
                const SizedBox(height: 6),
                const Text(
                  'Each row = one remedy. Required: name, component.\n'
                  'Preparation steps go in step_1 … step_10.\n'
                  'Lookup values (illness, category etc.) are auto-created.\n'
                  'prep_time is in minutes (numbers only). Values > 100 will show "see instructions" in the app. Ratings 1–5. Efficacy 0–100.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _SmallButton(
                    icon: _dbDownloading ? Icons.hourglass_top : Icons.download_outlined,
                    label: _dbDownloading ? 'Exporting...' : 'Export Remedy CSV',
                    onTap: _dbDownloading ? () {} : _downloadDatabase,
                  ),
                  _SmallButton(
                    icon: _uploading ? Icons.hourglass_top : Icons.upload_outlined,
                    label: _uploading ? 'Importing...' : 'Import Remedy CSV',
                    onTap: _uploading ? () {} : _pickFile,
                    bgColor: AppColors.lightGreen,
                  ),
                ]),
              ]),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightYellow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('CSV Format - Shop Items', style: AppTextStyles.heading3),
                const SizedBox(height: 6),
                const Text(
                  'Each row = one shop item. id required for updates.\nColumns: id, name, type, description, price, cost_price, stock, delivery_cost, active, image_url',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _SmallButton(
                    icon: _shopExporting ? Icons.hourglass_top : Icons.download_outlined,
                    label: _shopExporting ? 'Exporting...' : 'Export Shop CSV',
                    onTap: _shopExporting ? () {} : _exportShopCsv,
                  ),
                  _SmallButton(
                    icon: _shopImporting ? Icons.hourglass_top : Icons.upload_outlined,
                    label: _shopImporting ? 'Importing...' : 'Import Shop CSV',
                    onTap: _shopImporting ? () {} : _importShopCsv,
                    bgColor: AppColors.lightGreen,
                  ),
                ]),
              ]),
            ),
            const SizedBox(height: 12),

            // ── Parse errors ──────────────────────────────────────────────
            if (_parseErrors.isNotEmpty)
              _MessageBox(
                color: const Color(0xFFFFEBEE),
                icon: Icons.error_outline,
                iconColor: Colors.red,
                messages: _parseErrors,
                textColor: Colors.red,
              ),

            // ── Parse warnings ────────────────────────────────────────────
            if (_parseWarnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              _MessageBox(
                color: const Color(0xFFFFF8E1),
                icon: Icons.warning_amber,
                iconColor: Colors.orange,
                messages: _parseWarnings,
                textColor: Colors.orange,
              ),
            ],

            // ── Preview ───────────────────────────────────────────────────
            if (_parsed && _rows.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Preview (first 3 rows)', style: AppTextStyles.heading3),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _rows.length.clamp(0, 3),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = _rows[i];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.lightGreen,
                        child: Text('${i + 1}',
                            style: const TextStyle(fontSize: 11, color: AppColors.dark)),
                      ),
                      title: Text(r['name'] ?? '', style: AppTextStyles.heading3),
                      subtitle: Text(
                        '${r['component'] ?? ''} · ${r['origin'] ?? ''}',
                        style: AppTextStyles.caption,
                      ),
                    );
                  },
                ),
              ),
              if (_rows.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('…and ${_rows.length - 3} more', style: AppTextStyles.caption),
                ),
            ],

            // ── Upload progress ───────────────────────────────────────────
            if (_uploading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(
                value: _rows.isEmpty ? 0 : (_uploaded + _uploadErrors.length) / _rows.length,
                color: AppColors.primary,
                backgroundColor: Colors.grey.shade200,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 6),
              Text(
                'Uploading ${_uploaded + _uploadErrors.length} / ${_rows.length}…',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
              if (_uploadErrors.isNotEmpty)
                Text(
                  '${_uploadErrors.length} error${_uploadErrors.length == 1 ? '' : 's'} so far',
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
            ],

            // ── Upload results ─────────────────────────────────────────────
            if (_uploadDone) ...[
              const SizedBox(height: 20),
              _UploadResultCard(
                successCount: successCount,
                errorCount: errorCount,
                errors: _uploadErrors,
                allCols: _allCols,
                onDownload: hasUploadErrors ? _downloadErrorReport : null,
              ),
            ],

            const SizedBox(height: 24),

            // ── Action buttons ────────────────────────────────────────────
            if (_parsed && _rows.isNotEmpty && _parseErrors.isEmpty)
              Row(children: [
                if (_uploading) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _cancelled = true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Cancel',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _uploading ? null : _upload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.dark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    icon: _uploading
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.dark))
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      _uploading
                          ? 'Uploading…'
                          : 'Upload ${_rows.length} remedies',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
              ]),
          ]),
        )),
      ])),
    );
  }
}

// ── Upload result card ────────────────────────────────────────────────────────
class _UploadResultCard extends StatefulWidget {
  final int successCount;
  final int errorCount;
  final List<_UploadError> errors;
  final List<String> allCols;
  final VoidCallback? onDownload;

  const _UploadResultCard({
    required this.successCount,
    required this.errorCount,
    required this.errors,
    required this.allCols,
    this.onDownload,
  });

  @override
  State<_UploadResultCard> createState() => _UploadResultCardState();
}

class _UploadResultCardState extends State<_UploadResultCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final hasErrors = widget.errorCount > 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

      // ── Summary strip ────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: hasErrors ? const Color(0xFFFFF3E0) : AppColors.lightGreen,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasErrors ? Colors.orange : Colors.green),
        ),
        child: Row(children: [
          Icon(
            hasErrors ? Icons.warning_amber : Icons.check_circle,
            color: hasErrors ? Colors.orange : Colors.green,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              hasErrors
                  ? '${widget.successCount} uploaded · ${widget.errorCount} failed'
                  : '${widget.successCount} remedies uploaded successfully',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: hasErrors ? Colors.orange.shade800 : Colors.green.shade800,
              ),
            ),
            if (hasErrors)
              const Text(
                'Download the error report, fix the rows, and re-upload.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
          ])),
        ]),
      ),

      // ── Error list + download ─────────────────────────────────────────────
      if (hasErrors) ...[
        const SizedBox(height: 10),

        // Download button
        _SmallButton(
          icon: Icons.download,
          label: kIsWeb
              ? 'Download error report (${widget.errorCount} rows)'
              : 'Save error report (${widget.errorCount} rows)',
          onTap: widget.onDownload ?? () {},
          color: Colors.red.shade600,
          bgColor: const Color(0xFFFFEBEE),
        ),

        const SizedBox(height: 10),

        // Collapsible error list
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(children: [
              const Icon(Icons.list_alt, size: 16, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${widget.errorCount} row${widget.errorCount == 1 ? '' : 's'} with errors',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 18, color: AppColors.textSecondary,
              ),
            ]),
          ),
        ),

        if (_expanded) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.errors.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 48),
              itemBuilder: (_, i) {
                final err = widget.errors[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Row badge
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'R${err.rowNumber}',
                        style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w700, color: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(err.remedyName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(err.errorMessage,
                          style: const TextStyle(fontSize: 12, color: Colors.red)),
                    ])),
                  ]),
                );
              },
            ),
          ),
        ],
      ],
    ]);
  }
}

// ── Shared small button ───────────────────────────────────────────────────────
class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final Color bgColor;

  const _SmallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppColors.dark,
    this.bgColor = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            fontWeight: FontWeight.w700, fontSize: 13, color: color,
          )),
        ]),
      ),
    );
  }
}

// ── Message box (errors / warnings) ──────────────────────────────────────────
class _MessageBox extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Color iconColor;
  final List<String> messages;
  final Color textColor;

  const _MessageBox({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.messages,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: messages.map((m) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Expanded(child: Text(m,
                style: TextStyle(fontSize: 12, color: textColor))),
          ]),
        )).toList(),
      ),
    );
  }
}

// ── Duplicate dialog ──────────────────────────────────────────────────────────
class _DuplicateDialog extends StatefulWidget {
  final Set<String> existingNames;
  const _DuplicateDialog({required this.existingNames});

  @override
  State<_DuplicateDialog> createState() => _DuplicateDialogState();
}

class _DuplicateDialogState extends State<_DuplicateDialog> {
  late Set<String> _checkedToUpdate;

  @override
  void initState() {
    super.initState();
    _checkedToUpdate = Set.from(widget.existingNames);
  }

  @override
  Widget build(BuildContext context) {
    final updateCount = _checkedToUpdate.length;
    final skipCount   = widget.existingNames.length - updateCount;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        const Icon(Icons.warning_amber, color: Colors.orange, size: 22),
        const SizedBox(width: 8),
        Text('${widget.existingNames.length} duplicates found',
            style: AppTextStyles.heading3),
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const Text('Tick to UPDATE existing · Untick to SKIP',
              style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Row(children: [
            TextButton(
              onPressed: () => setState(() =>
                  _checkedToUpdate = Set.from(widget.existingNames)),
              child: const Text('Select all',
                  style: TextStyle(fontSize: 12, color: AppColors.primary)),
            ),
            TextButton(
              onPressed: () => setState(() => _checkedToUpdate.clear()),
              child: const Text('Deselect all',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
          ]),
          const Divider(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: SingleChildScrollView(
              child: Column(
                children: widget.existingNames.map((name) {
                  final checked = _checkedToUpdate.contains(name);
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(name, style: AppTextStyles.body),
                    subtitle: Text(
                      checked ? 'Will be updated' : 'Will be skipped',
                      style: TextStyle(
                        fontSize: 11,
                        color: checked ? Colors.orange : AppColors.textSecondary,
                      ),
                    ),
                    value: checked,
                    activeColor: AppColors.primary,
                    checkboxShape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (v) => setState(() {
                      if (v == true) _checkedToUpdate.add(name);
                      else _checkedToUpdate.remove(name);
                    }),
                  );
                }).toList(),
              ),
            ),
          ),
          const Divider(height: 12),
          Text(
            '$updateCount will be updated · $skipCount will be skipped',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel upload',
              style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(
          onPressed: () {
            final skipNames = widget.existingNames.difference(_checkedToUpdate);
            Navigator.pop(context, skipNames);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.dark,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Continue upload'),
        ),
      ],
    );
  }
}







