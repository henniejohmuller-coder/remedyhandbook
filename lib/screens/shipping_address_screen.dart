import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';

class ShippingAddressScreen extends StatefulWidget {
  const ShippingAddressScreen({super.key});

  @override
  State<ShippingAddressScreen> createState() => _ShippingAddressScreenState();
}

class _ShippingAddressScreenState extends State<ShippingAddressScreen> {
  bool _loading = true;
  bool _saving  = false;

  final _nameController     = TextEditingController();
  final _phoneController    = TextEditingController();
  final _address1Controller = TextEditingController();
  final _address2Controller = TextEditingController();
  final _cityController     = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalController   = TextEditingController();
  final _countryController  = TextEditingController();
  final _specialController  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalController.dispose();
    _countryController.dispose();
    _specialController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) { setState(() => _loading = false); return; }
      final profile = await SupabaseService.getProfile(userId);
      final addr = profile?['shipping_address'] as Map? ?? {};
      setState(() {
        _nameController.text     = addr['full_name']    ?? profile?['full_name'] ?? '';
        _phoneController.text    = addr['phone']        ?? profile?['phone'] ?? '';
        _address1Controller.text = addr['address1']     ?? profile?['address'] ?? '';
        _address2Controller.text = addr['address2']     ?? '';
        _cityController.text     = addr['city']         ?? profile?['city'] ?? '';
        _provinceController.text = addr['province']     ?? '';
        _postalController.text   = addr['postal_code']  ?? '';
        _countryController.text  = addr['country']      ?? profile?['country'] ?? 'South Africa';
        _specialController.text  = addr['special_instructions'] ?? '';
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_address1Controller.text.isEmpty || _cityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address and city are required'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;
      await SupabaseService.updateProfile(userId, {
        'shipping_address': {
          'full_name':            _nameController.text.trim(),
          'phone':                _phoneController.text.trim(),
          'address1':             _address1Controller.text.trim(),
          'address2':             _address2Controller.text.trim(),
          'city':                 _cityController.text.trim(),
          'province':             _provinceController.text.trim(),
          'postal_code':          _postalController.text.trim(),
          'country':              _countryController.text.trim(),
          'special_instructions': _specialController.text.trim(),
        },
        // Also update the flat fields
        'full_name': _nameController.text.trim(),
        'phone':     _phoneController.text.trim(),
        'address':   _address1Controller.text.trim(),
        'city':      _cityController.text.trim(),
        'country':   _countryController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      setState(() => _saving = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Shipping address saved!'),
              backgroundColor: Colors.green, duration: Duration(seconds: 2)));
        Navigator.pop(context);
      }
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          YellowAppBar(
            title: 'Default shipping address',
            subtitle: 'Pre-filled at checkout',
            showBack: true,
            actions: [
              GestureDetector(
                onTap: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                    : const Icon(Icons.check_circle, color: AppColors.dark, size: 22),
              ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                      // Info
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.lightYellow, borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: const Row(children: [
                          Icon(Icons.info_outline, size: 16, color: AppColors.dark),
                          SizedBox(width: 8),
                          Expanded(child: Text(
                            'This address will be automatically filled in at checkout.',
                            style: TextStyle(fontSize: 12, color: AppColors.dark),
                          )),
                        ]),
                      ),
                      const SizedBox(height: 20),

                      const SectionLabel('CONTACT'),
                      _field('Full name *', 'e.g. Maria Smit', _nameController),
                      const SizedBox(height: 10),
                      _field('Phone number *', 'e.g. +27 82 123 4567', _phoneController,
                          type: TextInputType.phone),

                      const SectionLabel('ADDRESS'),
                      _field('Address line 1 *', 'e.g. 12 Rose Street', _address1Controller),
                      const SizedBox(height: 10),
                      _field('Address line 2', 'Apartment, suite, unit (optional)', _address2Controller),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _field('City *', 'e.g. Cape Town', _cityController)),
                        const SizedBox(width: 10),
                        Expanded(child: _field('Province / State', 'e.g. Western Cape', _provinceController)),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(child: _field('Postal code', 'e.g. 8001', _postalController,
                            type: TextInputType.number)),
                        const SizedBox(width: 10),
                        Expanded(child: _field('Country', 'South Africa', _countryController)),
                      ]),

                      const SectionLabel('DELIVERY NOTES'),
                      _field('Special instructions', 'e.g. Leave at gate, call on arrival',
                          _specialController, maxLines: 3),

                      const SizedBox(height: 24),
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
                              : const Text('Save address',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ]),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, String hint, TextEditingController controller,
      {TextInputType type = TextInputType.text, int maxLines = 1}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTextStyles.label),
      const SizedBox(height: 4),
      TextField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: hint, hintStyle: AppTextStyles.caption,
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        ),
      ),
    ]);
  }
}
