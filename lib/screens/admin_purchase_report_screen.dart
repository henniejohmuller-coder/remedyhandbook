import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import '../utils/csv_download.dart';

class AdminPurchaseReportScreen extends StatefulWidget {
  const AdminPurchaseReportScreen({super.key});
  @override
  State<AdminPurchaseReportScreen> createState() => _AdminPurchaseReportScreenState();
}

class _AdminPurchaseReportScreenState extends State<AdminPurchaseReportScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String _statusFilter = 'All';
  String _txnSearch = '';
  final _txnController = TextEditingController();
  final List<String> _statuses = ['All','paid','processing','shipped','delivered','cancelled'];

  @override void initState() { super.initState(); _loadOrders(); }
  @override void dispose() { _txnController.dispose(); super.dispose(); }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final data = await SupabaseService.supabase
          .from('orders').select('*, order_items(*)')
          .order('transaction_number', ascending: false);
      setState(() { _orders = List<Map<String,dynamic>>.from(data); _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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

  double get _totalCost => _filtered.fold(0, (s, o) {
    final items = (o['order_items'] as List?) ?? [];
    return s + items.fold<double>(0, (si, i) =>
        si + ((i['cost_price']??0) as num).toDouble() * ((i['quantity']??1) as num).toDouble());
  });

  Future<void> _exportCsv() async {
    final lines = ['TXN Ref,Date,Customer,Email,Phone,Address,City,Postal,Country,Product,Qty,Cost,Total cost,Supplier paid'];
    for (final o in _filtered) {
      final items = (o['order_items'] as List?) ?? [];
      final date = (o['created_at'] ?? '').toString().substring(0, 10);
      for (final i in items) {
        final qty  = (i['quantity'] ?? 1) as num;
        final cost = (i['cost_price'] ?? 0) as num;
        final supplierPaid = i['supplier_paid'] == true ? 'Paid' : 'Pending';
        lines.add([
          o['txn_ref']??'', date, o['full_name']??'', o['email']??'', o['phone']??'',
          o['address']??'', o['city']??'', o['postal_code']??'', o['country']??'',
          i['product_name']??'', qty, cost, (cost*qty), supplierPaid,
        ].map((v) { final s=v.toString(); return s.contains(',')?'"$s"':s; }).join(','));
      }
    }
    final ts = DateTime.now().toIso8601String().substring(0, 10);
    final path = await downloadCsv(lines.join('\n'), 'purchase_report_$ts.csv');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(path != null ? 'Saved: $path' : 'Report exported'), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        YellowAppBar(title: 'Purchase Report', subtitle: '${_filtered.length} orders', showBack: true),
        // Summary
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _SummaryCard('Orders', '${_filtered.length}', AppColors.dark),
            const SizedBox(width: 8),
            _SummaryCard('Items',
                '${_filtered.fold<int>(0, (s,o) => s + ((o['order_items'] as List?)?.length ?? 0))}',
                Colors.orange),
            const SizedBox(width: 8),
            _SummaryCard('Total cost', 'R${_totalCost.toStringAsFixed(2)}', Colors.red),
          ]),
        ),
        // Filters
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
              ElevatedButton.icon(
                onPressed: _exportCsv,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Export CSV'),
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
                    itemBuilder: (_, i) => _PurchaseOrderCard(order: _filtered[i]),
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

class _PurchaseOrderCard extends StatelessWidget {
  final Map<String,dynamic> order;
  const _PurchaseOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final items    = (order['order_items'] as List?) ?? [];
    final date     = (order['created_at'] ?? '').toString().substring(0, 10);
    final status   = order['status'] ?? 'paid';
    final costTotal = items.fold<double>(0, (s,i) =>
        s + ((i['cost_price']??0) as num).toDouble() * ((i['quantity']??1) as num).toDouble());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: AppColors.dark,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(order['txn_ref'] ?? 'TXN-?',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(width: 8),
                Text(date, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
              Text(order['full_name'] ?? 'Unknown',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6)),
              child: Text(status,
                  style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('📦 ${order['address']}, ${order['city']}, ${order['postal_code']}, ${order['country']}',
                style: AppTextStyles.caption),
            Text('📧 ${order['email']??''}  📞 ${order['phone']??''}', style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(3), 1: FlexColumnWidth(0.8),
                2: FlexColumnWidth(1.3), 3: FlexColumnWidth(1.5), 4: FlexColumnWidth(1.3),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: AppColors.background),
                  children: ['Product','Qty','Cost','Total cost','Supplier paid']
                      .map((h) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                            child: Text(h, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                          )).toList(),
                ),
                ...items.map((item) {
                  final qty  = (item['quantity'] ?? 1) as num;
                  final cost = (item['cost_price'] ?? 0) as num;
                  final paid = item['supplier_paid'] == true;
                  return TableRow(children: [
                    Padding(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                        child: Text(item['product_name']??'', style: AppTextStyles.body)),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                        child: Text('$qty', style: AppTextStyles.body)),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                        child: Text('R${cost.toStringAsFixed(0)}', style: AppTextStyles.body)),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                        child: Text('R${(cost*qty).toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red))),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: paid ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6)),
                          child: Text(paid ? '✓ Paid' : 'Pending',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                                  color: paid ? Colors.green : Colors.orange)),
                        )),
                  ]);
                }),
              ],
            ),
            const Divider(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              const Text('Total cost to purchase: ', style: AppTextStyles.caption),
              Text('R${costTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.red)),
            ]),
            const SizedBox(height: 8),
          ]),
        ),
      ]),
    );
  }
}
