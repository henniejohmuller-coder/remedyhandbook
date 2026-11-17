
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as xl;
import '../utils/csv_download.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';

// ── Error model ────────────────────────────────────────────────────────────
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
  List<_UploadError>        _uploadErrors  = [];   // per-row upload errors – downloadable
  bool _uploading     = false;
  bool _dbDownloading = false;
  bool _shopExporting = false;
  bool _shopImporting = false;
  bool _fmExporting   = false;
  bool _fmImporting   = false;
  bool _cancelled  = false;
  bool _parsed     = false;
  bool _uploadDone = false;
  int  _uploaded   = 0;  // successfully uploaded rows
  String? _fileName;

  // ── CSV Column Spec ────────────────────────────────────────────────────
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

  // ── Pre-upload row validation ──────────────────────────────────────────
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

    // Numeric fields – allow 0 (default/unset) so exported rows always re-import
    final tradRating = row['tradition_rating'] ?? '';
    if (tradRating.isNotEmpty && tradRating != '0') {
      final v = int.tryParse(tradRating);
      if (v == null || v < 1 || v > 5) errs.add('tradition_rating "$tradRating" must be 0–5');
    }
    final valLevel = row['validation_level'] ?? '';
    if (valLevel.isNotEmpty && valLevel != '0') {
      final v = int.tryParse(valLevel);
      if (v == null || v < 1 || v > 5) errs.add('validation_level "$valLevel" must be 0–5');
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
        errs.add('image_url format invalid – must be Wikimedia 250px thumb URL or a direct image URL');
      }
    }

    // step_1 is recommended but not a hard block (some exported remedies may lack it)
    // Warn only – do not reject the row

    return errs;
  }

  // ── RFC 4180 full-content CSV parser ───────────────────────────────────
  // Single-pass parser that correctly handles:
  //   • Quoted fields with embedded newlines (the main cause of "9 columns" errors)
  //   • Escaped double-quotes ("")
  //   • Any delimiter – comma (Excel EN), semicolon (Excel ZA/EU), tab (TSV)
  //   • UTF-8 BOM from Excel "Save as UTF-8 CSV"
  //   • Windows (\r\n) and Unix (\n) line endings
  List<List<String>> _parseAllRows(String raw) {
    // Strip UTF-8 BOM
    if (raw.startsWith('﻿')) raw = raw.substring(1);

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
            inQuotes = false; // closing quote – stay in same field
          }
        } else {
          buf.write(c); // embedded newlines, commas, etc. – all go into the field
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
          // Record separator – only triggered outside quotes
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

  // ── Parse CSV ──────────────────────────────────────────────────────────
  void _parseCsv(String content) {
    setState(() {
      _rows = []; _headers = []; _parseErrors = []; _parseWarnings = [];
      _uploadErrors = []; _parsed = false; _uploadDone = false;
      _uploaded = 0;
    });

    // _parseAllRows handles BOM stripping, delimiter detection, and
    // multi-line quoted fields in a single pass – no pre-splitting on \n.
    final allRows = _parseAllRows(content);

    if (allRows.isEmpty) {
      setState(() => _parseErrors = ['CSV file is empty']);
      return;
    }

    // Detect delimiter for the warning message (re-use same logic)
    final firstLine = content.startsWith('﻿')
        ? content.substring(1).split('\n').first
        : content.split('\n').first;
    final delimiter = _detectDelimiter(firstLine.replaceAll('\r', ''));
    if (delimiter != ',') {
      final delimName = delimiter == ';' ? 'semicolon' : 'tab';
      _parseWarnings.add('Detected $delimName-delimited file – parsed accordingly');
    }

    // First record = header
    _headers = allRows[0]
        .map((h) => h.trim().toLowerCase().replaceAll('﻿', ''))
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
        _parseWarnings.add('Row $i has ${vals.length} columns, expected ${_headers.length} – skipped');
        continue;
      }
      final row = <String, String>{};
      for (int j = 0; j < _headers.length; j++) {
        row[_headers[j]] = vals[j].trim();
      }
      if ((row['name'] ?? '').isEmpty) {
        _parseWarnings.add('Row $i has no name – skipped');
        continue;
      }
      rows.add(row);
    }

    // Pre-upload validation – collect validation errors as _UploadErrors
    // so they appear in the downloadable report if the user attempts upload.
    // We still allow proceeding to let the user decide, but we flag them.
    setState(() { _rows = rows; _parsed = true; });
  }

  // ── Pick XLSX file (remedy import) ────────────────────────────────────
  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
        withData: true,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _parseErrors = ['Could not read file']);
        return;
      }
      setState(() { _fileName = file.name; _uploadDone = false; });
      _parseCsv(_xlsxToCsv(bytes));
    } catch (e) {
      setState(() => _parseErrors = ['Error reading file: $e']);
    }
  }

  // ── Convert XLSX bytes → CSV string for _parseCsv ─────────────────────
  String _xlsxToCsv(List<int> bytes) {
    final excel = xl.Excel.decodeBytes(bytes);
    if (excel.sheets.isEmpty) return '';
    final sheetName = excel.sheets.keys.first;
    final sheet = excel.sheets[sheetName];
    if (sheet == null) return '';

    // RFC 4180 quoting
    String q(String v) {
      if (v.contains(',') || v.contains('"') || v.contains('\n')) {
        return '"${v.replaceAll('"', '""')}"';
      }
      return v;
    }

    final lines = <String>[];
    for (final row in sheet.rows) {
      final cells = row.map((cell) => q((cell?.value?.toString() ?? ''))).toList();
      lines.add(cells.join(','));
    }
    return lines.join('\n');
  }

  // ── Upload ─────────────────────────────────────────────────────────────
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

    try {
    // Check DB duplicates – batch the inFilter to avoid URL-length limits
    final db = SupabaseService.supabase;
    final names = _rows.map((r) => r['name'] ?? '').toList();
    final existingNames = <String>{};
    const batchSize = 50;
    for (int i = 0; i < names.length; i += batchSize) {
      final batch = names.sublist(i, (i + batchSize).clamp(0, names.length));
      final res = await db.from('remedies').select('name').inFilter('name', batch);
      for (final e in (res as List)) {
        existingNames.add(e['name'].toString());
      }
    }

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

      // ── Pre-upload validation ─────────────────────────────────────────
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

      // ── DB upload ──────────────────────────────────────────────────────
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
    } catch (e) {
      if (mounted) {
        setState(() { _uploading = false; _uploadDone = true; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ));
      }
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
    // (e.g. "Cancer, Diabetes") – insert each as its own atomic lookup row.
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

  // ── Build XLSX bytes from headers + rows ──────────────────────────────
  List<int> _buildXlsxBytes(
      String sheetName, List<String> headers, List<List<String>> dataRows) {
    final excel = xl.Excel.createExcel();
    // The default sheet is 'Sheet1' — rename it
    if (excel.sheets.containsKey('Sheet1')) {
      excel.rename('Sheet1', sheetName);
    }
    final sheet = excel[sheetName];

    // Header row
    sheet.appendRow(headers.map((h) => xl.TextCellValue(h)).toList());

    // Data rows
    for (final row in dataRows) {
      sheet.appendRow(row.map((v) => xl.TextCellValue(v)).toList());
    }

    return excel.encode() ?? [];
  }

  // ── Download Error Report as XLSX ─────────────────────────────────────
  Future<void> _downloadErrorReport() async {
    if (_uploadErrors.isEmpty) return;

    final reportCols = ['csv_row', 'remedy_name', 'error', ..._allCols];
    final dataRows = _uploadErrors.map((err) => [
      err.rowNumber.toString(),
      err.remedyName,
      err.errorMessage,
      ..._allCols.map((col) => err.rowData[col] ?? ''),
    ]).toList();

    final bytes = _buildXlsxBytes('Upload Errors', reportCols, dataRows);
    final ts = DateTime.now().toIso8601String().substring(0, 16).replaceAll(':', '-');
    final path = await downloadXlsx(bytes, 'upload_errors_$ts.xlsx');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(path != null ? '✅ Error report saved to $path' : '✅ Error report downloaded'),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  // ── Export full remedy database as XLSX ───────────────────────────────
  Future<void> _downloadDatabase() async {
    if (_dbDownloading) return;
    setState(() => _dbDownloading = true);

    try {
      final db = SupabaseService.supabase;

      // Fetch all remedies with pagination (no status filter – admin sees everything)
      final List<Map<String, dynamic>> allRows = [];
      int offset = 0;
      const pageSize = 1000;
      while (true) {
        final page = await db
            .from('remedies')
            .select('*, remedy_instructions(*)')
            .order('name')
            .range(offset, offset + pageSize - 1);
        final pageList = List<Map<String, dynamic>>.from(page);
        allRows.addAll(pageList);
        if (pageList.length < pageSize) break;
        offset += pageSize;
      }

      if (allRows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No remedies found in database'),
            duration: Duration(seconds: 2),
          ));
        }
        setState(() => _dbDownloading = false);
        return;
      }

      // Build data rows
      final dataRows = <List<String>>[];
      for (final row in allRows) {
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
            return steps[n] ?? '';
          }
          return (row[col] ?? '').toString();
        }).toList();
        dataRows.add(cells);
      }

      final bytes = _buildXlsxBytes('Remedy Database', _allCols, dataRows);
      final ts = DateTime.now().toIso8601String().substring(0, 10);
      final path = await downloadXlsx(bytes, 'remedy_database_$ts.xlsx');

      if (mounted) {
        setState(() => _dbDownloading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(path != null
              ? '✅ ${allRows.length} remedies exported to $path'
              : '✅ ${allRows.length} remedies exported'),
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

  // ── Export Filter Matrix as XLSX ──────────────────────────────────────
  Future<void> _exportFilterMatrix() async {
    if (_fmExporting) return;
    setState(() => _fmExporting = true);
    try {
      // Paginate to get all rows past Supabase 1000-row limit
      final List<Map<String, dynamic>> rows = [];
      int from = 0;
      const pageSize = 1000;
      while (true) {
        final page = await SupabaseService.supabase
            .from('filter_matrix')
            .select('category, subcategory, illness, symptom')
            .order('category').order('subcategory').order('illness').order('symptom')
            .range(from, from + pageSize - 1);
        final pageList = List<Map<String, dynamic>>.from(page);
        rows.addAll(pageList);
        if (pageList.length < pageSize) break;
        from += pageSize;
      }

      const headers = ['category', 'subcategory', 'illness', 'symptom'];
      final dataRows = rows
          .map((r) => headers.map((h) => (r[h] ?? '').toString()).toList())
          .toList();
      final bytes = _buildXlsxBytes('Filter Matrix', headers, dataRows);
      final ts = DateTime.now().toIso8601String().substring(0, 10);
      final path = await downloadXlsx(bytes, 'filter_matrix_$ts.xlsx');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(path != null
            ? 'Filter matrix exported (${rows.length} rows) to $path'
            : 'Filter matrix exported (${rows.length} rows)'),
        backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _fmExporting = false);
    }
  }

  // ── Import Filter Matrix from XLSX ────────────────────────────────────
  Future<void> _importFilterMatrix() async {
    if (_fmImporting) return;
    setState(() => _fmImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
      if (result == null) { setState(() => _fmImporting = false); return; }
      final bytes = result.files.first.bytes;
      if (bytes == null) { setState(() => _fmImporting = false); return; }

      // Convert xlsx → CSV string then reuse the RFC 4180 parser
      final csvContent = _xlsxToCsv(bytes);
      final allRows = _parseAllRows(csvContent);
      if (allRows.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File is empty')));
        setState(() => _fmImporting = false);
        return;
      }

      // Detect column positions from header row (supports any column order)
      final headers = allRows[0].map((h) => h.trim().toLowerCase()).toList();
      final catIdx  = headers.indexOf('category');
      final subIdx  = headers.indexOf('subcategory');
      final illIdx  = headers.indexOf('illness');
      final symIdx  = headers.indexOf('symptom');

      // Fall back to positional if no header row matches
      final useHeader = catIdx >= 0 && subIdx >= 0 && illIdx >= 0 && symIdx >= 0;
      final startRow  = useHeader ? 1 : 0;

      // Build all rows first, then batch-upsert in chunks of 500
      final batch = <Map<String, String>>[];
      for (int ri = startRow; ri < allRows.length; ri++) {
        final cols = allRows[ri].map((c) => c.trim()).toList();
        if (cols.length < 4) continue;
        final row = useHeader
            ? {
                'category':    catIdx < cols.length ? cols[catIdx] : '',
                'subcategory': subIdx < cols.length ? cols[subIdx] : '',
                'illness':     illIdx < cols.length ? cols[illIdx] : '',
                'symptom':     symIdx < cols.length ? cols[symIdx] : '',
              }
            : {
                'category': cols[0], 'subcategory': cols[1],
                'illness': cols[2],  'symptom': cols[3],
              };
        if (row.values.every((v) => v.isEmpty)) continue;
        batch.add(row);
      }
      const chunkSize = 500;
      for (int i = 0; i < batch.length; i += chunkSize) {
        final chunk = batch.sublist(i, (i + chunkSize).clamp(0, batch.length));
        await SupabaseService.supabase.from('filter_matrix').upsert(
          chunk, onConflict: 'category,subcategory,illness,symptom');
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${batch.length} rows imported!'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _fmImporting = false);
    }
  }

  // ── Export Shop Items as XLSX ──────────────────────────────────────────
  Future<void> _exportShopCsv() async {
    setState(() => _shopExporting = true);
    try {
      // Paginate to fetch all products (Supabase caps single queries at 1000)
      final allData = <Map<String, dynamic>>[];
      int offset = 0;
      const pageSize = 1000;
      while (true) {
        final page = await SupabaseService.supabase.from('products').select(
          'id, sku, name, type, description, price, cost_price, stock, delivery_cost, active, image_url, category, brand, primary_herb, main_constituent'
        ).order('name').range(offset, offset + pageSize - 1);
        final pageList = List<Map<String, dynamic>>.from(page);
        allData.addAll(pageList);
        if (pageList.length < pageSize) break;
        offset += pageSize;
      }
      const headers = ['id','sku','name','type','description','price','cost_price',
          'stock','delivery_cost','active','image_url','category','brand',
          'primary_herb','main_constituent'];
      final dataRows = allData
          .map((r) => headers.map((h) => (r[h] ?? '').toString()).toList())
          .toList();
      final bytes = _buildXlsxBytes('Shop Items', headers, dataRows);
      final ts = DateTime.now().toIso8601String().substring(0, 10);
      final path = await downloadXlsx(bytes, 'shop_items_$ts.xlsx');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(path != null
            ? 'Shop items exported (${allData.length} rows) to $path'
            : 'Shop items exported (${allData.length} rows)'),
        backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _shopExporting = false);
    }
  }

  // ── Import Shop Items from XLSX ────────────────────────────────────────
  Future<void> _importShopCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    setState(() => _shopImporting = true);
    try {
      // Convert xlsx → CSV string then reuse the RFC 4180 parser
      final csv = _xlsxToCsv(bytes);
      final allRows = _parseAllRows(csv);
      if (allRows.isEmpty) return;
      final headers = allRows[0].map((h) => h.trim()).toList();

      // Parse all data rows, separating rows-with-id (upsert) from new rows (insert)
      final upsertRows  = <Map<String, dynamic>>[];
      final insertRows  = <Map<String, dynamic>>[];
      for (int i = 1; i < allRows.length; i++) {
        final values = allRows[i].map((v) => v.trim()).toList();
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
        final hasId = row.containsKey('id') &&
            row['id'] != null &&
            row['id'].toString().isNotEmpty;
        if (hasId) {
          upsertRows.add(row);
        } else {
          row.remove('id');
          insertRows.add(row);
        }
      }

      // Batch upsert rows with id (500 per call)
      const chunkSize = 500;
      for (int i = 0; i < upsertRows.length; i += chunkSize) {
        final chunk = upsertRows.sublist(i, (i + chunkSize).clamp(0, upsertRows.length));
        await SupabaseService.supabase.from('products').upsert(chunk, onConflict: 'id');
      }
      // Batch insert new rows
      for (int i = 0; i < insertRows.length; i += chunkSize) {
        final chunk = insertRows.sublist(i, (i + chunkSize).clamp(0, insertRows.length));
        await SupabaseService.supabase.from('products').insert(chunk);
      }

      final total = upsertRows.length + insertRows.length;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $total shop items'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _shopImporting = false);
    }
  }

  // ── Download Template as XLSX ──────────────────────────────────────────
  Future<void> _downloadTemplate() async {
    final exampleRow = [
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
      "Buchu is one of nature's finest urinary herbs",
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
    ];
    final bytes = _buildXlsxBytes('Remedy Template', _allCols, [exampleRow]);
    final path = await downloadXlsx(bytes, 'remedy_template.xlsx');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(path != null ? '✅ Template saved to $path' : '✅ Template downloaded'),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasUploadErrors  = _uploadErrors.isNotEmpty;
    final successCount     = _uploaded;
    final errorCount       = _uploadErrors.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        const YellowAppBar(
          title: 'Bulk Data Upload',
          subtitle: 'Export and import data as Excel files',
          showBack: true,
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [

            // ── Remedies section ──────────────────────────────────────
            _DataSection(
              title: 'Remedies',
              description:
                  'Each row = one remedy. Required: name, component.\n'
                  'Steps go in step_1 … step_10. Lookup values auto-created.\n'
                  'prep_time in minutes. Ratings 1–5. Efficacy 0–100.',
              downloadBusy: _dbDownloading,
              uploadBusy: _uploading,
              onDownload: _dbDownloading ? null : _downloadDatabase,
              onUpload: _uploading ? null : _pickFile,
            ),
            const Divider(height: 28),

            // ── Shop Items section ────────────────────────────────────
            _DataSection(
              title: 'Shop Items',
              description:
                  'Each row = one shop item. id required for updates.\n'
                  'Columns: id, name, type, description, price, cost_price,\n'
                  'stock, delivery_cost, active, image_url',
              downloadBusy: _shopExporting,
              uploadBusy: _shopImporting,
              onDownload: _shopExporting ? null : _exportShopCsv,
              onUpload: _shopImporting ? null : _importShopCsv,
            ),
            const Divider(height: 28),

            // ── Filter Matrix section ─────────────────────────────────
            _DataSection(
              title: 'Filter Matrix',
              description:
                  'Four-tier search taxonomy.\n'
                  'Columns: category, subcategory, illness, symptom',
              downloadBusy: _fmExporting,
              uploadBusy: _fmImporting,
              onDownload: _fmExporting ? null : _exportFilterMatrix,
              onUpload: _fmImporting ? null : _importFilterMatrix,
            ),
            const SizedBox(height: 12),

            // ── Parse errors ──────────────────────────────────────────
            if (_parseErrors.isNotEmpty)
              _MessageBox(
                color: const Color(0xFFFFEBEE),
                icon: Icons.error_outline,
                iconColor: Colors.red,
                messages: _parseErrors,
                textColor: Colors.red,
              ),

            // ── Parse warnings ────────────────────────────────────────
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

            // ── Preview ───────────────────────────────────────────────
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
                        '${r['component'] ?? ''}  -  ${r['origin'] ?? ''}',
                        style: AppTextStyles.caption,
                      ),
                    );
                  },
                ),
              ),
              if (_rows.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('...and ${_rows.length - 3} more', style: AppTextStyles.caption),
                ),
            ],

            // ── Upload progress ───────────────────────────────────────
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
                'Uploading ${_uploaded + _uploadErrors.length} / ${_rows.length}...',
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

            // ── Upload results ────────────────────────────────────────
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

            // ── Action buttons ────────────────────────────────────────
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
                          ? 'Uploading...'
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

// ── Upload result card ─────────────────────────────────────────────────────
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

      // ── Summary strip ───────────────────────────────────────────────
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
                  ? '${widget.successCount} uploaded  -  ${widget.errorCount} failed'
                  : '${widget.successCount} remedies uploaded successfully',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: hasErrors ? Colors.orange.shade800 : Colors.green.shade800,
              ),
            ),
            if (hasErrors)
              Text(
                'Tap "Download Error Report" to get an Excel file of failed rows',
                style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
              ),
          ])),
          if (hasErrors)
            IconButton(
              icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              color: Colors.orange,
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
        ]),
      ),

      // ── Error list ──────────────────────────────────────────────────
      if (hasErrors && _expanded) ...[
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.errors.length.clamp(0, 10),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final err = widget.errors[i];
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.red.shade50,
                  child: Text('${err.rowNumber}',
                      style: const TextStyle(fontSize: 11, color: Colors.red)),
                ),
                title: Text(err.remedyName,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(err.errorMessage,
                    style: const TextStyle(fontSize: 12, color: Colors.red)),
              );
            },
          ),
        ),
        if (widget.errors.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('...and ${widget.errors.length - 10} more errors',
                style: const TextStyle(fontSize: 12, color: Colors.red),
                textAlign: TextAlign.center),
          ),
        if (widget.onDownload != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: widget.onDownload,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Download Error Report'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ],
      ],
    ]);
  }
}

// ── Duplicate Dialog ───────────────────────────────────────────────────────
class _DuplicateDialog extends StatefulWidget {
  final Set<String> existingNames;
  const _DuplicateDialog({required this.existingNames});

  @override
  State<_DuplicateDialog> createState() => _DuplicateDialogState();
}

class _DuplicateDialogState extends State<_DuplicateDialog> {
  late Set<String> _skip;

  @override
  void initState() {
    super.initState();
    _skip = {}; // default: overwrite all duplicates
  }

  @override
  Widget build(BuildContext context) {
    final allSkipped = _skip.length == widget.existingNames.length;
    return AlertDialog(
      title: const Text('Duplicate Remedies Found'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${widget.existingNames.length} remedy name(s) already exist. '
              'Checked = skip (keep existing). Unchecked = overwrite.'),
          const SizedBox(height: 6),
          Row(children: [
            TextButton(
              onPressed: () => setState(() => _skip = Set.from(widget.existingNames)),
              child: const Text('Skip All'),
            ),
            TextButton(
              onPressed: () => setState(() => _skip = {}),
              child: const Text('Overwrite All'),
            ),
            Expanded(child: Text(
              allSkipped
                  ? 'All duplicates will be skipped'
                  : _skip.isEmpty
                      ? 'All duplicates will be overwritten'
                      : '${_skip.length} skipped, ${widget.existingNames.length - _skip.length} overwritten',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.right,
            )),
          ]),
          const SizedBox(height: 4),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: widget.existingNames.map((name) => CheckboxListTile(
                dense: true,
                title: Text(name, style: const TextStyle(fontSize: 13)),
                value: _skip.contains(name),
                onChanged: (v) => setState(() {
                  if (v == true) _skip.add(name); else _skip.remove(name);
                }),
              )).toList(),
            ),
          ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _skip),
          child: Text(allSkipped ? 'Skip All & Close' : 'Continue Upload'),
        ),
      ],
    );
  }
}

// ── Data Section row (title + description left, buttons right) ────────────
class _DataSection extends StatelessWidget {
  final String title;
  final String description;
  final bool downloadBusy;
  final bool uploadBusy;
  final VoidCallback? onDownload;
  final VoidCallback? onUpload;

  const _DataSection({
    required this.title,
    required this.description,
    required this.downloadBusy,
    required this.uploadBusy,
    this.onDownload,
    this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: title + description
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark)),
              const SizedBox(height: 4),
              Text(description,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.5)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Right: download + upload buttons stacked
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _IconBtn(
              icon: downloadBusy ? Icons.hourglass_top : Icons.download_outlined,
              label: downloadBusy ? 'Exporting…' : 'Download',
              onTap: onDownload ?? () {},
              busy: downloadBusy,
            ),
            const SizedBox(height: 6),
            _IconBtn(
              icon: uploadBusy ? Icons.hourglass_top : Icons.upload_outlined,
              label: uploadBusy ? 'Importing…' : 'Upload',
              onTap: onUpload ?? () {},
              busy: uploadBusy,
              isUpload: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool busy;
  final bool isUpload;

  const _IconBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.isUpload = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isUpload ? const Color(0xFFE8F5E9) : const Color(0xFFFFF9E6);
    final fg = isUpload ? Colors.green.shade700 : AppColors.dark;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: busy ? Colors.grey.shade100 : bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: busy ? Colors.grey.shade300
                  : (isUpload ? Colors.green.shade200 : AppColors.primary)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: busy ? Colors.grey : fg),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: busy ? Colors.grey : fg)),
          ],
        ),
      ),
    );
  }
}

// ── Small Button ───────────────────────────────────────────────────────────
class _SmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? bgColor;

  const _SmallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgColor ?? AppColors.lightYellow,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: AppColors.dark),
            const SizedBox(width: 6),
            Text(label, style: AppTextStyles.caption),
          ]),
        ),
      ),
    );
  }
}

// ── Message Box ────────────────────────────────────────────────────────────
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
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: messages
                .map((m) => Text(m,
                    style: TextStyle(fontSize: 13, color: textColor)))
                .toList(),
          ),
        ),
      ]),
    );
  }
}
