import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';

class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key});

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.supabase
          .from('app_content').select().order('key');
      if (!mounted) return;
      setState(() {
        _items  = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openEditor(Map<String, dynamic> item) {
    final key = item['key'] ?? '';
    final useFullEditor = key == 'terms' || key == 'home_encouragement';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => useFullEditor
          ? TermsEditor(
              item: item,
              onSaved: () { Navigator.pop(context); _load(); },
              onDeleted: () { Navigator.pop(context); _load(); },
            )
          : ContentEditor(
              item: item,
              onSaved: () { Navigator.pop(context); _load(); },
            ),
    );
  }

  String _icon(String key) {
    switch (key) {
      case 'help_support':        return '📧';
      case 'about':               return '📖';
      case 'terms':               return '⚖️';
      case 'home_encouragement':  return '💚';
      default:                    return '📄';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          const YellowAppBar(
            title: 'Edit App Content',
            subtitle: 'Help · About · Terms',
            showBack: true,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.primary,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final item    = _items[i];
                        final key     = item['key'] ?? '';
                        final title   = item['title'] ?? key;
                        final content = item['content'] ?? '';
                        final updated = item['updated_at']?.toString().substring(0, 10) ?? '';
                        final isTerms = key == 'terms' || key == 'home_encouragement';

                        return GestureDetector(
                          onTap: () => _openEditor(item),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: isTerms ? Border.all(color: AppColors.primary) : null,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
                            ),
                            child: Row(children: [
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(color: AppColors.lightYellow,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Center(child: Text(_icon(key), style: const TextStyle(fontSize: 22))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(children: [
                                  Expanded(child: Text(title, style: AppTextStyles.heading3)),
                                  if (isTerms)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(6)),
                                      child: const Text('Submit · Delete',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                                    ),
                                ]),
                                Text(content.isEmpty ? 'No content yet — tap to add' : content,
                                    style: AppTextStyles.caption,
                                    maxLines: 2, overflow: TextOverflow.ellipsis),
                                if (updated.isNotEmpty)
                                  Text('Last updated: $updated', style: AppTextStyles.caption),
                              ])),
                              const SizedBox(width: 8),
                              const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ]),
      ),
    );
  }
}

// ── Content Editor Bottom Sheet ───────────────────────────────────────────

class ContentEditor extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onSaved;
  const ContentEditor({required this.item, required this.onSaved});

  @override
  State<ContentEditor> createState() => ContentEditorState();
}

class ContentEditorState extends State<ContentEditor> {
  late TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item['content'] ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SupabaseService.supabase.from('app_content').update({
        'content':    _controller.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': SupabaseService.currentUser?.id,
      }).eq('key', widget.item['key']);
      widget.onSaved();
    } catch (e) {
      setState(() => _saving = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item['title'] ?? widget.item['key'] ?? '';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Handle
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: Text('Edit: $title', style: AppTextStyles.heading2)),
          GestureDetector(onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, size: 20, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 16),

        Expanded(
          child: TextField(
            controller: _controller,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'Enter content...',
              hintStyle: AppTextStyles.caption,
              filled: true, fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: _saving
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ]),
    );
  }
}

// ── Terms & Conditions Editor ─────────────────────────────────────────────

class TermsEditor extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onSaved;
  final VoidCallback onDeleted;
  const TermsEditor({required this.item, required this.onSaved, required this.onDeleted});

  @override
  State<TermsEditor> createState() => _TermsEditorState();
}

class _TermsEditorState extends State<TermsEditor> {
  late TextEditingController _controller;
  bool _saving   = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.item['content'] ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Terms & Conditions text'),
            backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      await SupabaseService.supabase.from('app_content').upsert({
        'key':        widget.item['key'],
        'title':      widget.item['title'] ?? widget.item['key'],
        'content':    _controller.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': SupabaseService.currentUser?.id,
      }, onConflict: 'key');
      widget.onSaved();
    } catch (e) {
      setState(() => _saving = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Terms & Conditions?', style: AppTextStyles.heading3),
        content: const Text('This will clear the T&C content from the app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _deleting = true);
    try {
      await SupabaseService.supabase.from('app_content')
          .update({'content': '', 'updated_at': DateTime.now().toIso8601String()})
          .eq('key', widget.item['key']);
      widget.onDeleted();
    } catch (e) {
      setState(() => _deleting = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text(widget.item['title'] ?? '⚖️ Content', style: AppTextStyles.heading2)),
          GestureDetector(onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, size: 20, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 4),
        const Text('Enter the full T&C text. Supports line breaks.', style: AppTextStyles.caption),
        const SizedBox(height: 12),
        Expanded(
          child: TextField(
            controller: _controller,
            maxLines: null, expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: AppTextStyles.body,
            decoration: InputDecoration(
              hintText: 'Enter Terms & Conditions...',
              hintStyle: AppTextStyles.caption,
              filled: true, fillColor: AppColors.background,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _deleting ? null : _delete,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: _deleting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
                  : const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
                  padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              icon: _saving
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                  : const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('Submit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ]),
    );
  }
}
