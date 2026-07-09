import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _newController     = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving       = false;
  bool _showNew      = false;
  bool _showConfirm  = false;

  String? _validate() {
    if (_newController.text.length < 8)
      return 'Password must be at least 8 characters';
    if (_newController.text != _confirmController.text)
      return 'Passwords do not match';
    if (!RegExp(r'[A-Z]').hasMatch(_newController.text))
      return 'Include at least one uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(_newController.text))
      return 'Include at least one number';
    return null;
  }

  Future<void> _changePassword() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red));
      return;
    }
    setState(() => _saving = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newController.text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Password changed successfully!'),
              backgroundColor: Colors.green));
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
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          const YellowAppBar(title: 'Change password', subtitle: 'Choose a strong password', showBack: true),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 16),

                // Info box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.lightYellow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Password requirements:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    SizedBox(height: 6),
                    _Req(text: 'At least 8 characters'),
                    _Req(text: 'At least one uppercase letter'),
                    _Req(text: 'At least one number'),
                  ]),
                ),
                const SizedBox(height: 24),

                // New password
                const Text('New password', style: AppTextStyles.label),
                const SizedBox(height: 6),
                TextField(
                  controller: _newController,
                  obscureText: !_showNew,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _showNew = !_showNew),
                      child: Icon(_showNew ? Icons.visibility_off : Icons.visibility,
                          size: 20, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Strength indicator
                if (_newController.text.isNotEmpty) ...[
                  _StrengthBar(password: _newController.text),
                  const SizedBox(height: 16),
                ],

                // Confirm password
                const Text('Confirm new password', style: AppTextStyles.label),
                const SizedBox(height: 6),
                TextField(
                  controller: _confirmController,
                  obscureText: !_showConfirm,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    suffixIcon: GestureDetector(
                      onTap: () => setState(() => _showConfirm = !_showConfirm),
                      child: Icon(_showConfirm ? Icons.visibility_off : Icons.visibility,
                          size: 20, color: AppColors.textSecondary),
                    ),
                    // Show match indicator
                    suffixIconConstraints: const BoxConstraints(minWidth: 40),
                  ),
                ),
                if (_confirmController.text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(
                      _newController.text == _confirmController.text
                          ? Icons.check_circle : Icons.cancel,
                      size: 16,
                      color: _newController.text == _confirmController.text
                          ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _newController.text == _confirmController.text
                          ? 'Passwords match' : 'Passwords do not match',
                      style: TextStyle(fontSize: 12,
                        color: _newController.text == _confirmController.text
                            ? Colors.green : Colors.red),
                    ),
                  ]),
                ],
                const SizedBox(height: 32),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                        : const Text('Change password',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Req extends StatelessWidget {
  final String text;
  const _Req({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(children: [
        const Icon(Icons.check, size: 14, color: AppColors.herbGreen),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  final String password;
  const _StrengthBar({required this.password});

  int get _strength {
    int score = 0;
    if (password.length >= 8)  score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*]').hasMatch(password)) score++;
    return score;
  }

  String get _label {
    switch (_strength) {
      case 1: case 2: return 'Weak';
      case 3:         return 'Fair';
      case 4:         return 'Strong';
      default:        return 'Very strong';
    }
  }

  Color get _color {
    switch (_strength) {
      case 1: case 2: return Colors.red;
      case 3:         return Colors.orange;
      case 4:         return Colors.green;
      default:        return Colors.green.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: List.generate(5, (i) => Expanded(
        child: Container(
          height: 4, margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: i < _strength ? _color : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ))),
      const SizedBox(height: 4),
      Text(_label, style: TextStyle(fontSize: 11, color: _color, fontWeight: FontWeight.w600)),
    ]);
  }
}
