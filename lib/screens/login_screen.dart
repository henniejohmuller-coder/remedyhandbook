import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../services/supabase_service.dart';
import '../main.dart';
import 'policy_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading      = false;
  bool _isSignUp     = false;
  bool _stayLoggedIn = true; // default true — most users want this
  final _nameController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _emailController.text);
    bool sending = false;
    bool sent    = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reset password', style: AppTextStyles.heading3),
          content: sent
              ? Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.mark_email_read_outlined, size: 48, color: Colors.green),
                  const SizedBox(height: 12),
                  Text('A reset link has been sent to:\n${resetEmailController.text}',
                      textAlign: TextAlign.center, style: AppTextStyles.body),
                  const SizedBox(height: 8),
                  const Text('Check your inbox and follow the link to set a new password.',
                      textAlign: TextAlign.center, style: AppTextStyles.caption),
                ])
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Enter your email address and we\'ll send you a link to reset your password.',
                      style: AppTextStyles.caption),
                  const SizedBox(height: 16),
                  TextField(
                    controller: resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email address',
                      hintText: 'e.g. you@email.com',
                      labelStyle: AppTextStyles.caption,
                      prefixIcon: const Icon(Icons.email_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    ),
                  ),
                ]),
          actions: sent
              ? [ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.dark, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Done'),
                )]
              : [
                  TextButton(onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
                  ElevatedButton(
                    onPressed: sending ? null : () async {
                      if (resetEmailController.text.isEmpty) return;
                      setDialogState(() => sending = true);
                      await supabase.auth.resetPasswordForEmail(
                        resetEmailController.text.trim(),
                        redirectTo: 'com.myherb.remedy_handbook://login-callback',
                      );
                      setDialogState(() { sending = false; sent = true; });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary, foregroundColor: AppColors.dark,
                      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: sending
                        ? const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                        : const Text('Send reset link'),
                  ),
                ],
        ),
      ),
    );
  }



  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_isSignUp) {
        final response = await SupabaseService.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _nameController.text.trim(),
        );
        if (mounted) {
          if (response.session != null) {
            // Signed in immediately — AuthGate handles navigation
            await SupabaseService.setSessionPersistence(_stayLoggedIn);
          } else if (response.user != null) {
            // Try signing in immediately (confirmation off scenario)
            try {
              await SupabaseService.signIn(
                _emailController.text.trim(),
                _passwordController.text.trim(),
              );
              await SupabaseService.setSessionPersistence(_stayLoggedIn);
            } catch (_) {
              // Email confirmation required — show dialog
              setState(() => _loading = false);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Check your email', style: AppTextStyles.heading3),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.mark_email_read_outlined, size: 48, color: Colors.green),
                    const SizedBox(height: 12),
                    Text('We sent a confirmation link to:\n${_emailController.text.trim()}',
                        textAlign: TextAlign.center, style: AppTextStyles.body),
                    const SizedBox(height: 8),
                    const Text('Click the link in the email to activate your account.',
                        textAlign: TextAlign.center, style: AppTextStyles.caption),
                  ]),
                  actions: [
                    ElevatedButton(
                      onPressed: () { Navigator.pop(ctx); setState(() => _isSignUp = false); },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.dark, elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: const Text('Go to login'),
                    ),
                  ],
                ),
              );
              return;
            }
          }
        }
      } else {
        await SupabaseService.signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        await SupabaseService.setSessionPersistence(_stayLoggedIn);
        // AuthGate listens to onAuthStateChange and will navigate automatically
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: AppColors.dark,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withOpacity(0.5), blurRadius: 20, spreadRadius: 4),
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.eco, size: 60, color: AppColors.primary),
              ),
              const SizedBox(height: 16),
              const Text('Remedy Handbook', style: AppTextStyles.heading1),
              const SizedBox(height: 8),
              Text(
                _isSignUp ? 'Create your account' : 'Welcome back',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.dark),
              ),
              const SizedBox(height: 4),
              Text(
                _isSignUp ? 'Join our community' : 'Sign in to your account',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 36),
              // Error message
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              // Name field (sign up only)
              if (_isSignUp) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 12),
              ],
              // Email
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(hintText: 'Email address'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              // Password
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(hintText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              // Stay logged in — only show on sign in, not sign up
              if (!_isSignUp)
                GestureDetector(
                  onTap: () => setState(() => _stayLoggedIn = !_stayLoggedIn),
                  child: Row(children: [
                    SizedBox(
                      width: 24, height: 24,
                      child: Checkbox(
                        value: _stayLoggedIn,
                        onChanged: (v) => setState(() => _stayLoggedIn = v ?? true),
                        activeColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Stay logged in', style: TextStyle(
                        fontSize: 13, color: AppColors.dark, fontWeight: FontWeight.w500)),
                  ]),
                ),
              const SizedBox(height: 16),
              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.dark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dark))
                      : Text(_isSignUp ? 'Create account' : 'Sign in',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 12),
              // Toggle sign in / sign up
              TextButton(
                onPressed: () => setState(() { _isSignUp = !_isSignUp; _error = null; }),
                child: Text(
                  _isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up",
                  style: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.w600),
                ),
              ),
              if (!_isSignUp) ...[
                TextButton(
                  onPressed: () => _showForgotPasswordDialog(),
                  child: const Text('Forgot password?',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
              ],
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PolicyScreen())),
                child: const Text(
                  'Terms & Conditions · Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.dark,
                      decoration: TextDecoration.underline, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
