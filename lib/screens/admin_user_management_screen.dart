import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import '../utils/csv_download.dart';

class AdminUserManagementScreen extends StatefulWidget {
  const AdminUserManagementScreen({super.key});
  @override
  State<AdminUserManagementScreen> createState() => _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String _search = '';
  String _roleFilter = 'All';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profileData = await SupabaseService.supabase
          .from('profiles')
          .select('id, full_name, phone, email, role, city, country, joined_at')
          .order('full_name', ascending: true);
      final profiles = List<Map<String, dynamic>>.from(profileData);

      final orderData = await SupabaseService.supabase
          .from('orders')
          .select('user_id, status, created_at');
      final orders = List<Map<String, dynamic>>.from(orderData);

      final Map<String, Map<String, dynamic>> stats = {};
      for (final o in orders) {
        final uid = o['user_id']?.toString() ?? '';
        if (uid.isEmpty) continue;
        stats.putIfAbsent(uid, () => {'total': 0, 'pending': 0, 'last_order': ''});
        stats[uid]!['total'] = (stats[uid]!['total'] as int) + 1;
        if ((o['status'] ?? '').toString().toLowerCase() == 'pending') {
          stats[uid]!['pending'] = (stats[uid]!['pending'] as int) + 1;
        }
        final d = (o['created_at'] ?? '').toString().split('T').first;
        if (d.isNotEmpty && d.compareTo(stats[uid]!['last_order'] as String) > 0) {
          stats[uid]!['last_order'] = d;
        }
      }

      final merged = profiles.map((p) {
        final uid = p['id']?.toString() ?? '';
        return {...p, ...(stats[uid] ?? {'total': 0, 'pending': 0, 'last_order': ''})};
      }).toList();

      if (!mounted) return;
      setState(() { _users = merged; _applyFilter(); _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _applyFilter() {
    var list = _users;
    if (_roleFilter != 'All') {
      list = list.where((u) =>
          (u['role'] ?? 'user').toString().toLowerCase() == _roleFilter.toLowerCase()).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list.where((u) =>
          (u['full_name'] ?? '').toString().toLowerCase().contains(q) ||
          (u['email']     ?? '').toString().toLowerCase().contains(q) ||
          (u['phone']     ?? '').toString().toLowerCase().contains(q) ||
          (u['city']      ?? '').toString().toLowerCase().contains(q) ||
          (u['country']   ?? '').toString().toLowerCase().contains(q)).toList();
    }
    _filtered = list;
  }

  Future<void> _updateRole(Map<String, dynamic> user, String newRole) async {
    try {
      await SupabaseService.updateProfile(user['id'], {'role': newRole});
      setState(() {
        final idx = _users.indexWhere((u) => u['id'] == user['id']);
        if (idx >= 0) _users[idx] = {..._users[idx], 'role': newRole};
        _applyFilter();
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user['full_name']} updated to $newRole'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update failed'), backgroundColor: Colors.red));
    }
  }

  Future<void> _editUser(Map<String, dynamic> user) async {
    final nameCtrl    = TextEditingController(text: user['full_name'] ?? '');
    final phoneCtrl   = TextEditingController(text: user['phone']     ?? '');
    final emailCtrl   = TextEditingController(text: user['email']     ?? '');
    final cityCtrl    = TextEditingController(text: user['city']      ?? '');
    final countryCtrl = TextEditingController(text: user['country']   ?? '');
    String role       = (user['role'] ?? 'user').toString();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Edit User', style: AppTextStyles.heading3),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field('Full name',  nameCtrl,    Icons.person_outline),
                const SizedBox(height: 10),
                _field('Phone',      phoneCtrl,   Icons.phone_outlined),
                const SizedBox(height: 10),
                _field('Email',      emailCtrl,   Icons.email_outlined),
                const SizedBox(height: 10),
                _field('City',       cityCtrl,    Icons.location_city_outlined),
                const SizedBox(height: 10),
                _field('Country',    countryCtrl, Icons.public_outlined),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    prefixIcon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                  items: ['user', 'admin', 'moderator']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setDlg(() => role = v ?? 'user'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: AppColors.dark, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    try {
      final updates = {
        'full_name': nameCtrl.text.trim(),
        'phone':     phoneCtrl.text.trim(),
        'email':     emailCtrl.text.trim(),
        'city':      cityCtrl.text.trim(),
        'country':   countryCtrl.text.trim(),
        'role':      role,
      };
      await SupabaseService.updateProfile(user['id'], updates);
      setState(() {
        final idx = _users.indexWhere((u) => u['id'] == user['id']);
        if (idx >= 0) _users[idx] = {..._users[idx], ...updates};
        _applyFilter();
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${nameCtrl.text.trim()} saved'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Save failed'), backgroundColor: Colors.red));
    }
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon) => TextField(
    controller: ctrl,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      isDense: true,
    ),
  );

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final name = user['full_name'] ?? 'this user';
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete user?', style: AppTextStyles.heading3),
        content: Text('Delete "$name"?\n\nThis removes their profile. Orders remain but will be unlinked.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.supabase.from('profiles').delete().eq('id', user['id']);
      setState(() { _users.removeWhere((u) => u['id'] == user['id']); _applyFilter(); });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name deleted'), backgroundColor: Colors.red.shade700));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete failed'), backgroundColor: Colors.red));
    }
  }

  void _exportCsv() {
    final rows = <List<String>>[
      ['Name', 'Phone', 'Email', 'City', 'Country', 'Role', 'Total Orders', 'Pending Orders', 'Last Order', 'Joined'],
      ..._filtered.map((u) => [
        u['full_name']   ?? '',
        u['phone']       ?? '',
        u['email']       ?? '',
        u['city']        ?? '',
        u['country']     ?? '',
        u['role']        ?? 'user',
        (u['total']      ?? 0).toString(),
        (u['pending']    ?? 0).toString(),
        (u['last_order'] ?? '').toString(),
        (u['joined_at']  ?? '').toString().split('T').first,
      ]),
    ];
    final csv = rows.map((r) => r.map((c) => '"${c.replaceAll('"', '""')}"').join(',')).join('\n');
    downloadCsv(csv, 'users_${DateTime.now().millisecondsSinceEpoch}.csv');
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    final csvString = String.fromCharCodes(bytes);
    final rows = csvString.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (rows.length < 2) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV has no data rows'), backgroundColor: Colors.red));
      return;
    }

    final headers = rows.first.split(',')
        .map((h) => h.trim().replaceAll('"', '').toLowerCase()).toList();
    final nameIdx    = headers.indexOf('name');
    final phoneIdx   = headers.indexOf('phone');
    final emailIdx   = headers.indexOf('email');
    final cityIdx    = headers.indexOf('city');
    final countryIdx = headers.indexOf('country');
    final roleIdx    = headers.indexOf('role');

    int updated = 0;
    int skipped = 0;

    for (final row in rows.skip(1)) {
      final cols = row.split(',').map((c) => c.trim().replaceAll('"', '')).toList();
      if (cols.length < 2) { skipped++; continue; }
      final email = emailIdx >= 0 && emailIdx < cols.length ? cols[emailIdx] : '';
      if (email.isEmpty) { skipped++; continue; }

      final matches = _users.where((u) =>
          (u['email'] ?? '').toString().toLowerCase() == email.toLowerCase()).toList();
      if (matches.isEmpty) { skipped++; continue; }

      final uid = matches.first['id'];
      final updates = <String, dynamic>{};
      if (nameIdx    >= 0 && nameIdx    < cols.length && cols[nameIdx].isNotEmpty)    updates['full_name'] = cols[nameIdx];
      if (phoneIdx   >= 0 && phoneIdx   < cols.length && cols[phoneIdx].isNotEmpty)   updates['phone']     = cols[phoneIdx];
      if (cityIdx    >= 0 && cityIdx    < cols.length && cols[cityIdx].isNotEmpty)    updates['city']      = cols[cityIdx];
      if (countryIdx >= 0 && countryIdx < cols.length && cols[countryIdx].isNotEmpty) updates['country']   = cols[countryIdx];
      if (roleIdx    >= 0 && roleIdx    < cols.length && cols[roleIdx].isNotEmpty)    updates['role']      = cols[roleIdx];
      if (updates.isEmpty) { skipped++; continue; }

      try {
        await SupabaseService.updateProfile(uid, updates);
        updated++;
      } catch (_) { skipped++; }
    }

    await _load();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Import done: $updated updated, $skipped skipped'),
          backgroundColor: updated > 0 ? Colors.green : Colors.orange));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            YellowAppBar(
              title: 'User Management',
              subtitle: '${_filtered.length} of ${_users.length} users',
              showBack: true,
            ),
            // Search + filter + export/import row
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() { _search = v; _applyFilter(); }),
                        decoration: InputDecoration(
                          hintText: 'Search name, email, phone...',
                          hintStyle: AppTextStyles.caption,
                          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textSecondary),
                          suffixIcon: _search.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () => setState(() { _search = ''; _searchController.clear(); _applyFilter(); }))
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _roleFilter,
                        isDense: true,
                        items: ['All', 'user', 'admin', 'moderator']
                            .map((r) => DropdownMenuItem(value: r, child: Text(r, style: AppTextStyles.caption)))
                            .toList(),
                        onChanged: (v) => setState(() { _roleFilter = v ?? 'All'; _applyFilter(); }),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Download CSV
                  GestureDetector(
                    onTap: _exportCsv,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.download_outlined, size: 20, color: AppColors.dark),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Upload CSV
                  GestureDetector(
                    onTap: _importCsv,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.dark,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.upload_outlined, size: 20, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            // Table header
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: const [
                  Expanded(flex: 3, child: Text('Name',    style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700))),
                  Expanded(flex: 3, child: Text('Phone',   style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700))),
                  Expanded(flex: 3, child: Text('Email',   style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700))),
                  SizedBox(width: 40, child: Text('Ord',   style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700))),
                  SizedBox(width: 40, child: Text('Pend',  style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700))),
                  SizedBox(width: 60, child: Text('Role',  style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700))),
                  SizedBox(width: 56, child: Text('',      style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filtered.isEmpty
                      ? const Center(child: Text('No users found', style: AppTextStyles.caption))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) {
                            final u         = _filtered[i];
                            final name      = u['full_name']   ?? '—';
                            final phone     = u['phone']       ?? '—';
                            final email     = u['email']       ?? '—';
                            final role      = (u['role']       ?? 'user').toString();
                            final total     = (u['total']      ?? 0) as int;
                            final pending   = (u['pending']    ?? 0) as int;
                            final lastOrder = (u['last_order'] ?? '').toString();
                            final isAdmin   = role == 'admin' || role == 'moderator';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: isAdmin ? AppColors.primary.withOpacity(0.4) : Colors.grey.shade100),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(flex: 3, child: Text(name,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark),
                                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      Expanded(flex: 3, child: Text(phone,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      Expanded(flex: 3, child: Text(email,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      SizedBox(
                                        width: 40,
                                        child: Text('$total',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                                color: total > 0 ? AppColors.dark : AppColors.textSecondary),
                                            textAlign: TextAlign.center),
                                      ),
                                      SizedBox(
                                        width: 40,
                                        child: pending > 0
                                            ? Container(
                                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                                decoration: BoxDecoration(
                                                    color: Colors.orange.shade100,
                                                    borderRadius: BorderRadius.circular(6)),
                                                child: Text('$pending',
                                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                                        color: Colors.orange.shade800),
                                                    textAlign: TextAlign.center))
                                            : const Text('—',
                                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                                textAlign: TextAlign.center),
                                      ),
                                      SizedBox(
                                        width: 60,
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: role,
                                            isDense: true,
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                                color: isAdmin ? AppColors.dark : AppColors.textSecondary),
                                            items: ['user', 'admin', 'moderator']
                                                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                                                .toList(),
                                            onChanged: (v) {
                                              if (v != null && v != role) _updateRole(u, v);
                                            },
                                          ),
                                        ),
                                      ),
                                      // Edit + Delete buttons
                                      SizedBox(
                                        width: 56,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            GestureDetector(
                                              onTap: () => _editUser(u),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                    color: AppColors.primary.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(6)),
                                                child: const Icon(Icons.edit_outlined, size: 14, color: AppColors.dark),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            GestureDetector(
                                              onTap: () => _deleteUser(u),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                    color: Colors.red.shade50,
                                                    borderRadius: BorderRadius.circular(6)),
                                                child: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (lastOrder.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text('Last order: $lastOrder',
                                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
