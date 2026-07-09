import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import '../utils/csv_download.dart';

class AdminShopReportScreen extends StatefulWidget {
  const AdminShopReportScreen({super.key});
  @override
  State<AdminShopReportScreen> createState() => _AdminShopReportScreenState();
}

class _AdminShopReportScreenState extends State<AdminShopReportScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String _statusFilter = 'All';
  String _txnSearch = '';
  final _txnController = TextEditingController();
  final Set<String> _selectedIds = {};
  // Lifted supplier_paid state — persists across scroll
  final Map<String, bool> _supplierPaid = {};
  final List<String> _statuses = ['All','paid','processing','shipped','delivered','cancelled'];

  @override void initState() { super.initState(); _loadOrders(); }
  @override void dispose() { _txnController.dispose(); super.dispose(); }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.supabase
          .from('orders').select('*, order_items(*)')
          .order('transaction_number', ascending: false);
      final orders = List<Map<String,dynamic>>.from(data);
      // Seed supplier paid state from DB
      for (final o in orders) {
        final items = (o['order_items'] as List?) ?? [];
        for (final i in items) {
          final id = i['id']?.toString() ?? '';
          if (!_supplierPaid.containsKey(id)) {
            _supplierPaid[id] = i['supplier_paid'] == true;
          }
        }
      }
      setState(() { _orders = orders; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _toggleSupplierPaid(String itemId, bool current) async {
    final newVal = !current;
    setState(() => _supplierPaid[itemId] = newVal);
    try {
      await SupabaseService.supabase
          .from('order_items')
          .update({'supplier_paid': newVal})
          .eq('id', itemId);
    } catch (e) {
      // Revert on error
      setState(() => _supplierPaid[itemId] = current);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red));
    }
  }

  List<Map<String,dynamic>> get _filtered {
    var list = _statusFilter == 'All' ? _orders
        : _orders.where((o) => o['status'] == _statusFilter).toList();
    if (_txnSearch.trim().isNotEmpty) {
      final q = _txnSearch.trim().toUpperCase();
      list = list.where((o) =>
          (o['txn_ref'] ?? '').toString().toUpperCase().contains(q) ||
          (o['transaction_number'] ?? '').toString().contains(q)).toList();
    }
    return list;
  }

  double get _totalRevenue => _filtered.fold(0, (s,o) => s + ((o['total']??0) as num).toDouble());
  double get _totalCost => _filtered.fold(0, (s,o) {
    final items = (o['order_items'] as List?) ?? [];
    return s + items.fold<double>(0, (si,i) =>
        si + ((i['cost_price']??0) as num).toDouble() * ((i['quantity']??1) as num).toDouble());
  });
  double get _totalProfit => _totalRevenue - _totalCost;

  Future<void> _updateStatus(String orderId, String status) async {
    await SupabaseService.supabase.from('orders').update({'status': status}).eq('id', orderId);
    _loadOrders();
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete transactions?'),
        content: Text('Permanently delete ${_selectedIds.length} transaction(s). Cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final id in _selectedIds) {
      await SupabaseService.supabase.from('order_items').delete().eq('order_id', id);
      await SupabaseService.supabase.from('orders').delete().eq('id', id);
    }
    _selectedIds.clear();
    _loadOrders();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transactions deleted'), backgroundColor: Colors.red));
  }

  Future<void> _exportCsv() async {
    final lines = ['TXN Ref,Date,Customer,Email,Address,City,Postal,Country,Product,Qty,Cost,Total cost,Sell,Total sell,Margin,Supplier paid,Order Total,Status'];
    for (final o in _filtered) {
      final items = (o['order_items'] as List?) ?? [];
      final date = (o['created_at'] ?? '').toString().substring(0, 10);
      for (final i in items) {
        final qty  = (i['quantity'] ?? 1) as num;
        final sell = (i['unit_price'] ?? 0) as num;
        final cost = (i['cost_price'] ?? 0) as num;
        final itemId = i['id']?.toString() ?? '';
        final paid = _supplierPaid[itemId] ?? (i['supplier_paid'] == true);
        lines.add([
          o['txn_ref']??'', date, o['full_name']??'', o['email']??'',
          o['address']??'', o['city']??'', o['postal_code']??'', o['country']??'',
          i['product_name']??'', qty, cost, (cost*qty), sell, (sell*qty), ((sell-cost)*qty),
          paid ? 'Paid' : 'Pending', o['total']??0, o['status']??'',
        ].map((v) { final s=v.toString(); return s.contains(',')?'"$s"':s; }).join(','));
      }
    }
    final ts = DateTime.now().toIso8601String().substring(0, 10);
    final path = await downloadCsv(lines.join('\n'), 'shop_report_$ts.csv');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(path != null ? 'Saved: $path' : 'Report exported'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        YellowAppBar(title: 'Shop Report', subtitle: '${_filtered.length} orders', showBack: true),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _SummaryCard('Revenue', 'R${_totalRevenue.toStringAsFixed(2)}', Colors.green),
            const SizedBox(width: 8),
            _SummaryCard('Cost', 'R${_totalCost.toStringAsFixed(2)}', Colors.orange),
            const SizedBox(width: 8),
            _SummaryCard('Profit', 'R${_totalProfit.toStringAsFixed(2)}',
                _totalProfit >= 0 ? AppColors.dark : Colors.red),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(children: [
            TextField(
              controller: _txnController,
              onChanged: (v) => setState(() => _txnSearch = v),
              decoration: InputDecoration(
                labelText: 'Transaction number', hintText: 'e.g. TXN-00001', isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _txnSearch.isNotEmpty ? IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() { _txnSearch=''; _txnController.clear(); })) : null,
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                value: _statusFilter,
                decoration: const InputDecoration(labelText: 'Status', isDense: true),
                items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
              )),
              const SizedBox(width: 8),
              if (_selectedIds.isNotEmpty) ...[
                ElevatedButton.icon(
                  onPressed: _deleteSelected,
                  icon: const Icon(Icons.delete, size: 16),
                  label: Text('Delete (${_selectedIds.length})'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                ),
                const SizedBox(width: 8),
              ],
              ElevatedButton.icon(
                onPressed: _exportCsv,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('CSV'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.dark,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _filtered.isEmpty
              ? const Center(child: Text('No orders found', style: AppTextStyles.caption))
              : RefreshIndicator(
                  onRefresh: _loadOrders,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final id = _filtered[i]['id']?.toString() ?? '';
                      return _OrderCard(
                        order: _filtered[i],
                        supplierPaidMap: _supplierPaid,
                        onStatusChange: (status) => _updateStatus(id, status),
                        onSupplierPaidToggle: _toggleSupplierPaid,
                        statuses: _statuses.where((s) => s != 'All').toList(),
                        isSelected: _selectedIds.contains(id),
                        onToggleSelect: () => setState(() {
                          if (_selectedIds.contains(id)) _selectedIds.remove(id);
                          else _selectedIds.add(id);
                        }),
                      );
                    },
                  ),
                ),
        ),
      ])),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label, value; final Color color;
  const _SummaryCard(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)]),
      child: Column(children: [
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}

class _OrderCard extends StatelessWidget {
  final Map<String,dynamic> order;
  final Map<String,bool> supplierPaidMap;
  final Function(String) onStatusChange;
  final Function(String, bool) onSupplierPaidToggle;
  final List<String> statuses;
  final bool isSelected;
  final VoidCallback onToggleSelect;

  const _OrderCard({
    required this.order, required this.supplierPaidMap,
    required this.onStatusChange, required this.onSupplierPaidToggle,
    required this.statuses, required this.isSelected, required this.onToggleSelect,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'paid':       return Colors.blue;
      case 'processing': return Colors.orange;
      case 'shipped':    return Colors.purple;
      case 'delivered':  return Colors.green;
      case 'cancelled':  return Colors.red;
      default:           return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items    = (order['order_items'] as List?) ?? [];
    final date     = (order['created_at'] ?? '').toString().substring(0, 10);
    final status   = order['status'] ?? 'paid';
    final total    = ((order['total'] ?? 0) as num).toDouble();
    final shipping = ((order['shipping'] ?? 0) as num).toDouble();
    final costTotal = items.fold<double>(0, (s,i) =>
        s + ((i['cost_price']??0) as num).toDouble() * ((i['quantity']??1) as num).toDouble());
    final profit = total - shipping - costTotal;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.red.shade900 : AppColors.dark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            GestureDetector(
              onTap: onToggleSelect,
              child: Container(
                width: 22, height: 22, margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.red : Colors.transparent,
                  border: Border.all(color: isSelected ? Colors.red : AppColors.primary, width: 2),
                  borderRadius: BorderRadius.circular(4)),
                child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
            ),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(order['txn_ref'] ?? 'TXN-?',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 8),
                Text(date, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
              Text(order['full_name'] ?? 'Unknown',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              Text('R${total.toStringAsFixed(2)}',
                  style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              const Text('Customer', style: TextStyle(color: Colors.white54, fontSize: 9)),
              DropdownButton<String>(
                value: statuses.contains(status) ? status : statuses.first,
                dropdownColor: AppColors.dark,
                style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.w700, fontSize: 12),
                underline: const SizedBox.shrink(),
                icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                items: statuses.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, style: TextStyle(color: _statusColor(s), fontWeight: FontWeight.w600)),
                )).toList(),
                onChanged: (v) { if (v != null) onStatusChange(v); },
              ),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Delivery: ${order['address']??''}, ${order['city']??''}, ${order['postal_code']??''}, ${order['country']??''}',
                style: AppTextStyles.caption),
            Text('Email: ${order['email']??''}   Phone: ${order['phone']??''}',
                style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(2.2), 1: FlexColumnWidth(0.6),
                2: FlexColumnWidth(1.0), 3: FlexColumnWidth(1.2),
                4: FlexColumnWidth(1.0), 5: FlexColumnWidth(1.2),
                6: FlexColumnWidth(1.1), 7: FlexColumnWidth(0.8),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: AppColors.background),
                  children: ['Product','Qty','Cost','Tot cost','Sell','Tot sell','Margin','Supp paid']
                      .map((h) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            child: Text(h, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
                          )).toList(),
                ),
                ...items.map((item) {
                  final qty       = (item['quantity'] ?? 1) as num;
                  final sell      = (item['unit_price'] ?? 0) as num;
                  final cost      = (item['cost_price'] ?? 0) as num;
                  final totalCost = cost * qty;
                  final totalSell = sell * qty;
                  final margin    = (sell - cost) * qty;
                  final itemId    = item['id']?.toString() ?? '';
                  final paid      = supplierPaidMap[itemId] ?? (item['supplier_paid'] == true);
                  return TableRow(children: [
                    Padding(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                        child: Text(item['product_name']??'', style: AppTextStyles.body)),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                        child: Text('$qty', style: AppTextStyles.body)),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                        child: Text('R${cost.toStringAsFixed(0)}', style: AppTextStyles.body)),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                        child: Text('R${totalCost.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red))),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                        child: Text('R${sell.toStringAsFixed(0)}', style: AppTextStyles.body)),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                        child: Text('R${totalSell.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green))),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                        child: Text('R${margin.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 12,
                                color: margin >= 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w600))),
                    GestureDetector(
                      onTap: () => onSupplierPaidToggle(itemId, paid),
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: paid ? Colors.green : Colors.transparent,
                          border: Border.all(
                              color: paid ? Colors.green : Colors.grey.shade400, width: 2),
                          borderRadius: BorderRadius.circular(4)),
                        child: paid
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                  ]);
                }),
              ],
            ),
            const Divider(height: 12),
            Row(children: [
              Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('Customer status = payment received from customer',
                  style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('Supplier paid = we have paid our supplier',
                  style: TextStyle(fontSize: 9, color: AppColors.textSecondary)),
            ]),
            const Divider(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Shipping: R${shipping.toStringAsFixed(2)}', style: AppTextStyles.caption),
              Text('Cost: R${costTotal.toStringAsFixed(2)}', style: AppTextStyles.caption),
              Text('Profit: R${profit.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: profit >= 0 ? Colors.green : Colors.red)),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ]),
    );
  }
}
