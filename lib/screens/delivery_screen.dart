import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../models/delivery_models.dart';
import '../services/courierguy_service.dart';
import '../services/supabase_service.dart';
import 'checkout_screen.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  // ── State ────────────────────────────────────────────────────────────────
  DeliveryType _method = DeliveryType.door2door;

  // D2D form controllers
  final _streetCtrl   = TextEditingController();
  final _suburbCtrl   = TextEditingController();
  final _cityCtrl     = TextEditingController();
  final _postalCtrl   = TextEditingController();
  String _province    = 'Gauteng';

  // PUDO state
  final _searchCtrl       = TextEditingController();
  String _pudoType        = 'locker'; // 'locker' | 'counter' | 'all'
  List<PickupPoint> _points = [];
  PickupPoint? _selectedPoint;
  bool _searchingPoints   = false;
  String? _searchError;

  // Quote state
  List<DeliveryQuote> _quotes = [];
  DeliveryQuote? _selectedQuote;
  bool _loadingQuote  = false;
  String? _quoteError;

  int _itemCount = 1;

  @override
  void initState() {
    super.initState();
    _loadItemCount();
    _prefillAddress();
  }

  Future<void> _prefillAddress() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;
      final profile = await SupabaseService.getProfile(userId);
      if (profile == null) return;

      // Try structured shipping_address first, fall back to flat fields
      final addr = profile['shipping_address'] as Map? ?? {};

      // street: combine address1 + address2 if present
      final street = addr['address1']?.toString() ?? profile['address']?.toString() ?? '';
      final suburb = addr['suburb']?.toString() ?? profile['suburb']?.toString() ?? '';
      final city   = addr['city']?.toString() ?? profile['city']?.toString() ?? '';
      final postal = addr['postal_code']?.toString() ?? profile['postal_code']?.toString() ?? '';
      final prov   = addr['province']?.toString() ?? profile['province']?.toString() ?? '';

      if (mounted) {
        setState(() {
          if (street.isNotEmpty) _streetCtrl.text = street;
          if (suburb.isNotEmpty) _suburbCtrl.text = suburb;
          if (city.isNotEmpty)   _cityCtrl.text   = city;
          if (postal.isNotEmpty) _postalCtrl.text  = postal;
          if (prov.isNotEmpty && _provinces.contains(prov)) _province = prov;
        });
      }
    } catch (_) {}
  }

  static const _provinces = [
    'Gauteng', 'Western Cape', 'KwaZulu-Natal', 'Eastern Cape',
    'Limpopo', 'Mpumalanga', 'North West', 'Free State', 'Northern Cape',
  ];

  @override
  void dispose() {
    _streetCtrl.dispose();
    _suburbCtrl.dispose();
    _cityCtrl.dispose();
    _postalCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadItemCount() async {
    try {
      final items = await SupabaseService.getCart();
      final count = items.fold<int>(0, (s, i) => s + ((i['quantity'] ?? 1) as int));
      if (mounted) setState(() => _itemCount = count.clamp(1, 99));
    } catch (_) {}
  }

  // ── API calls ─────────────────────────────────────────────────────────────
  Future<void> _searchPoints() async {
    final q = _searchCtrl.text.trim();
    if (q.length < 3) return;
    setState(() { _searchingPoints = true; _searchError = null; _points = []; _selectedPoint = null; _quotes = []; _selectedQuote = null; });
    try {
      final type = _pudoType == 'all' ? 'locker' : _pudoType;
      final pts  = await CourierGuyService.getPickupPoints(search: q, type: type);
      setState(() { _points = pts; _searchingPoints = false; });
    } catch (_) {
      setState(() {
        _searchError = 'PUDO lookup not available yet. Please use "To my door" delivery for now.';
        _searchingPoints = false;
      });
    }
  }

  /// Flat-rate fallback shown when the CourierGuy API is not yet configured.
  static final _fallbackQuote = DeliveryQuote(
    serviceCode:  'FLAT',
    serviceName:  'Standard Delivery',
    price:        130,
    deliveryDays: '3–5 business days',
  );

  Future<void> _getD2DQuote() async {
    final street = _streetCtrl.text.trim();
    final suburb = _suburbCtrl.text.trim();
    final city   = _cityCtrl.text.trim();
    final postal = _postalCtrl.text.trim();

    if (street.isEmpty || city.isEmpty || postal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in street address, city and postal code'), backgroundColor: Colors.red));
      return;
    }

    setState(() { _loadingQuote = true; _quoteError = null; _quotes = []; _selectedQuote = null; });
    try {
      final quotes = await CourierGuyService.getD2DQuote(
        street: street, suburb: suburb, city: city,
        province: _province, postalCode: postal,
        itemCount: _itemCount,
      );
      if (quotes.isEmpty) {
        setState(() { _quotes = [_fallbackQuote]; _selectedQuote = _fallbackQuote; _loadingQuote = false; });
      } else {
        setState(() { _quotes = quotes; _selectedQuote = quotes.first; _loadingQuote = false; });
      }
    } catch (_) {
      // API not yet configured — show flat-rate fallback so checkout still works
      setState(() { _quotes = [_fallbackQuote]; _selectedQuote = _fallbackQuote; _loadingQuote = false; });
    }
  }

  Future<void> _getPudoQuote(PickupPoint point) async {
    setState(() { _selectedPoint = point; _loadingQuote = true; _quoteError = null; _quotes = []; _selectedQuote = null; });
    try {
      final quotes = await CourierGuyService.getPudoQuote(pudoPointId: point.id, itemCount: _itemCount);
      if (quotes.isEmpty) {
        setState(() { _quotes = [_fallbackQuote]; _selectedQuote = _fallbackQuote; _loadingQuote = false; });
      } else {
        setState(() { _quotes = quotes; _selectedQuote = quotes.first; _loadingQuote = false; });
      }
    } catch (_) {
      setState(() { _quotes = [_fallbackQuote]; _selectedQuote = _fallbackQuote; _loadingQuote = false; });
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  void _confirm() {
    if (_selectedQuote == null) return;

    final selection = _method == DeliveryType.door2door
        ? DeliverySelection(
            type: DeliveryType.door2door,
            quote: _selectedQuote!,
            street:     _streetCtrl.text.trim(),
            suburb:     _suburbCtrl.text.trim(),
            city:       _cityCtrl.text.trim(),
            province:   _province,
            postalCode: _postalCtrl.text.trim(),
          )
        : DeliverySelection(
            type: DeliveryType.pudo,
            quote: _selectedQuote!,
            pudoPoint: _selectedPoint,
          );

    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CheckoutScreen(deliverySelection: selection),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          const YellowAppBar(title: 'Delivery', subtitle: 'Choose how to receive your order', showBack: true),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Method selector ──────────────────────────────────────
                _MethodCard(
                  icon: Icons.home_outlined,
                  label: 'To my door',
                  sub: 'Standard delivery',
                  selected: _method == DeliveryType.door2door,
                  onTap: () => setState(() {
                    _method = DeliveryType.door2door;
                    _quotes = []; _selectedQuote = null; _quoteError = null;
                  }),
                ),
                const SizedBox(height: 10),
                _MethodCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'PUDO Point',
                  sub: 'Locker or kiosk',
                  selected: _method == DeliveryType.pudo,
                  onTap: () => setState(() {
                    _method = DeliveryType.pudo;
                    _quotes = []; _selectedQuote = null; _quoteError = null;
                  }),
                ),

                const SizedBox(height: 20),

                // ── Method content ───────────────────────────────────────
                if (_method == DeliveryType.door2door) ...[
                  _sectionLabel('Delivery address'),
                  const SizedBox(height: 10),
                  _field('Street address', _streetCtrl, hint: '12 Main Street'),
                  const SizedBox(height: 10),
                  _field('Suburb', _suburbCtrl, hint: 'Sandton'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _field('City', _cityCtrl, hint: 'Johannesburg')),
                    const SizedBox(width: 10),
                    Expanded(child: _field('Postal code', _postalCtrl, hint: '2196', keyboard: TextInputType.number)),
                  ]),
                  const SizedBox(height: 10),
                  _ProvinceDropdown(
                    value: _province,
                    onChanged: (v) => setState(() { _province = v!; _quotes = []; _selectedQuote = null; }),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _loadingQuote
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                          : const Icon(Icons.local_shipping_outlined, size: 18),
                      label: Text(_loadingQuote ? 'Getting quote…' : 'Get delivery quote',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      onPressed: _loadingQuote ? null : _getD2DQuote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
                        minimumSize: const Size(double.infinity, 44),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ] else ...[
                  // ── PUDO search ──────────────────────────────────────
                  _sectionLabel('Find a nearby PUDO point'),
                  const SizedBox(height: 10),

                  // Type filter
                  Row(children: [
                    _TypeChip(label: 'Locker',  value: 'locker',  group: _pudoType, onTap: (v) => setState(() => _pudoType = v)),
                    const SizedBox(width: 8),
                    _TypeChip(label: 'Kiosk',   value: 'counter', group: _pudoType, onTap: (v) => setState(() => _pudoType = v)),
                    const SizedBox(width: 8),
                    _TypeChip(label: 'All',     value: 'all',     group: _pudoType, onTap: (v) => setState(() => _pudoType = v)),
                  ]),
                  const SizedBox(height: 10),

                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: _inputDecoration('Search by area, suburb or city', prefixIcon: Icons.search),
                        onSubmitted: (_) => _searchPoints(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _searchingPoints ? null : _searchPoints,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
                        minimumSize: const Size(60, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: _searchingPoints
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                          : const Icon(Icons.search),
                    ),
                  ]),

                  if (_searchError != null) ...[
                    const SizedBox(height: 10),
                    _ErrorBanner(_searchError!),
                  ],

                  if (_points.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _sectionLabel('${_points.length} point${_points.length == 1 ? '' : 's'} found'),
                    const SizedBox(height: 8),
                    ..._points.map((pt) => _PointTile(
                      point: pt,
                      selected: _selectedPoint?.id == pt.id,
                      loading: _loadingQuote && _selectedPoint?.id == pt.id,
                      onTap: () => _getPudoQuote(pt),
                    )),
                  ],
                ],

                // ── Quote section ─────────────────────────────────────────
                if (_quoteError != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(_quoteError!),
                ],

                if (_quotes.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _sectionLabel('Delivery options'),
                  const SizedBox(height: 10),
                  ..._quotes.map((q) => _QuoteTile(
                    quote: q,
                    selected: _selectedQuote?.serviceCode == q.serviceCode,
                    onTap: () => setState(() => _selectedQuote = q),
                  )),
                ],

                const SizedBox(height: 24),
              ]),
            ),
          ),

          // ── Bottom bar ───────────────────────────────────────────────────
          if (_selectedQuote != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_selectedQuote!.serviceName, style: AppTextStyles.heading3),
                    if (_selectedQuote!.deliveryDays != null)
                      Text(_selectedQuote!.deliveryDays!, style: AppTextStyles.caption),
                  ]),
                  Text('R${_selectedQuote!.price.toStringAsFixed(2)}',
                      style: AppTextStyles.heading2),
                ]),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Confirm & Continue to Checkout',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(text, style: AppTextStyles.heading3);

  Widget _field(String label, TextEditingController ctrl, {String? hint, TextInputType keyboard = TextInputType.text}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark)),
      const SizedBox(height: 4),
      TextField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: _inputDecoration(hint ?? label),
      ),
    ]);
  }

  InputDecoration _inputDecoration(String hint, {IconData? prefixIcon}) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7), fontSize: 13),
    prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: AppColors.textSecondary) : null,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
  );
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;
  const _MethodCard({required this.icon, required this.label, required this.sub, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade300, width: selected ? 1.5 : 1),
          boxShadow: selected ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4)],
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.dark),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$label  ·  $sub',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.dark)),
          ),
          if (selected) const Icon(Icons.check_circle_outline, size: 18, color: AppColors.dark),
        ]),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label, value, group;
  final ValueChanged<String> onTap;
  const _TypeChip({required this.label, required this.value, required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sel = value == group;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? AppColors.primary : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: sel ? AppColors.dark : AppColors.textSecondary)),
      ),
    );
  }
}

class _PointTile extends StatelessWidget {
  final PickupPoint point;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;
  const _PointTile({required this.point, required this.selected, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.lightGreen : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? Colors.green.shade300 : Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4)],
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: selected ? Colors.green.shade100 : AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              point.type == 'counter' ? Icons.storefront_outlined : Icons.inventory_2_outlined,
              size: 20, color: selected ? Colors.green.shade700 : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(point.name, style: AppTextStyles.heading3, overflow: TextOverflow.ellipsis),
            if (point.displayAddress.isNotEmpty)
              Text(point.displayAddress, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis),
          ])),
          if (loading)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
          else if (selected)
            const Icon(Icons.check_circle, color: Colors.green, size: 22)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
              child: Text(point.typeLabel, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            ),
        ]),
      ),
    );
  }
}

class _QuoteTile extends StatelessWidget {
  final DeliveryQuote quote;
  final bool selected;
  final VoidCallback onTap;
  const _QuoteTile({required this.quote, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.lightYellow : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? AppColors.primary : Colors.grey.shade200, width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(quote.serviceName, style: AppTextStyles.heading3),
            if (quote.deliveryDays != null)
              Text(quote.deliveryDays!, style: AppTextStyles.caption),
          ])),
          Text('R${quote.price.toStringAsFixed(2)}', style: AppTextStyles.heading3),
          const SizedBox(width: 8),
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? AppColors.dark : AppColors.textSecondary, size: 20),
        ]),
      ),
    );
  }
}

class _ProvinceDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  const _ProvinceDropdown({required this.value, required this.onChanged});

  static const _provinces = [
    'Gauteng', 'Western Cape', 'KwaZulu-Natal', 'Eastern Cape',
    'Limpopo', 'Mpumalanga', 'North West', 'Free State', 'Northern Cape',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Province', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.dark)),
      const SizedBox(height: 4),
      DropdownButtonFormField<String>(
        value: value,
        onChanged: onChanged,
        decoration: InputDecoration(
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        ),
        items: _provinces.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
      ),
    ]);
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(fontSize: 12, color: Colors.red))),
      ]),
    );
  }
}
