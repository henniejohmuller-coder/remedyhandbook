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
  final _nameController    = TextEditingController();
  final _phoneController   = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController    = TextEditingController();
  final _postalController  = TextEditingController();
  String _countryCode      = '+27';
  String _country          = 'South Africa';
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _postalController.dispose();
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
        if (_nameController.text.trim().isEmpty) {
          setState(() { _error = 'Please enter your full name.'; _loading = false; });
          return;
        }
        if (_phoneController.text.trim().isEmpty) {
          setState(() { _error = 'Please enter your mobile number.'; _loading = false; });
          return;
        }
        if (_addressController.text.trim().isEmpty) {
          setState(() { _error = 'Please enter your street address.'; _loading = false; });
          return;
        }
        if (_cityController.text.trim().isEmpty) {
          setState(() { _error = 'Please enter your city.'; _loading = false; });
          return;
        }

        final response = await SupabaseService.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _nameController.text.trim(),
        );
        if (mounted) {
          if (response.session != null) {
            final userId = response.session!.user.id;
            await SupabaseService.updateProfile(userId, {
              'phone':    '$_countryCode${_phoneController.text.trim()}',
              'address':  _addressController.text.trim(),
              'city':     _cityController.text.trim(),
              'country':  _country,
              'shipping_address': {
                'full_name':   _nameController.text.trim(),
                'phone':       '$_countryCode${_phoneController.text.trim()}',
                'address':     _addressController.text.trim(),
                'city':        _cityController.text.trim(),
                'postal_code': _postalController.text.trim(),
                'country':     _country,
              },
            });
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
              if (_isSignUp) ...[
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Shipping Details',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.dark)),
                ),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Required for order delivery and shipping cost calculation',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _country,
                  decoration: InputDecoration(
                    labelText: 'Country',
                    prefixIcon: const Icon(Icons.public_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Afghanistan', child: Text('Afghanistan (+93)')), 
                    DropdownMenuItem(value: 'Albania', child: Text('Albania (+355)')), 
                    DropdownMenuItem(value: 'Algeria', child: Text('Algeria (+213)')), 
                    DropdownMenuItem(value: 'Andorra', child: Text('Andorra (+376)')), 
                    DropdownMenuItem(value: 'Angola', child: Text('Angola (+244)')), 
                    DropdownMenuItem(value: 'Antigua and Barbuda', child: Text('Antigua and Barbuda (+1)')), 
                    DropdownMenuItem(value: 'Argentina', child: Text('Argentina (+54)')), 
                    DropdownMenuItem(value: 'Armenia', child: Text('Armenia (+374)')), 
                    DropdownMenuItem(value: 'Australia', child: Text('Australia (+61)')), 
                    DropdownMenuItem(value: 'Austria', child: Text('Austria (+43)')), 
                    DropdownMenuItem(value: 'Azerbaijan', child: Text('Azerbaijan (+994)')), 
                    DropdownMenuItem(value: 'Bahamas', child: Text('Bahamas (+1)')), 
                    DropdownMenuItem(value: 'Bahrain', child: Text('Bahrain (+973)')), 
                    DropdownMenuItem(value: 'Bangladesh', child: Text('Bangladesh (+880)')), 
                    DropdownMenuItem(value: 'Barbados', child: Text('Barbados (+1)')), 
                    DropdownMenuItem(value: 'Belarus', child: Text('Belarus (+375)')), 
                    DropdownMenuItem(value: 'Belgium', child: Text('Belgium (+32)')), 
                    DropdownMenuItem(value: 'Belize', child: Text('Belize (+501)')), 
                    DropdownMenuItem(value: 'Benin', child: Text('Benin (+229)')), 
                    DropdownMenuItem(value: 'Bhutan', child: Text('Bhutan (+975)')), 
                    DropdownMenuItem(value: 'Bolivia', child: Text('Bolivia (+591)')), 
                    DropdownMenuItem(value: 'Bosnia and Herzegovina', child: Text('Bosnia and Herzegovina (+387)')), 
                    DropdownMenuItem(value: 'Botswana', child: Text('Botswana (+267)')), 
                    DropdownMenuItem(value: 'Brazil', child: Text('Brazil (+55)')), 
                    DropdownMenuItem(value: 'Brunei', child: Text('Brunei (+673)')), 
                    DropdownMenuItem(value: 'Bulgaria', child: Text('Bulgaria (+359)')), 
                    DropdownMenuItem(value: 'Burkina Faso', child: Text('Burkina Faso (+226)')), 
                    DropdownMenuItem(value: 'Burundi', child: Text('Burundi (+257)')), 
                    DropdownMenuItem(value: 'Cambodia', child: Text('Cambodia (+855)')), 
                    DropdownMenuItem(value: 'Cameroon', child: Text('Cameroon (+237)')), 
                    DropdownMenuItem(value: 'Canada', child: Text('Canada (+1)')), 
                    DropdownMenuItem(value: 'Cape Verde', child: Text('Cape Verde (+238)')), 
                    DropdownMenuItem(value: 'Central African Republic', child: Text('Central African Republic (+236)')), 
                    DropdownMenuItem(value: 'Chad', child: Text('Chad (+235)')), 
                    DropdownMenuItem(value: 'Chile', child: Text('Chile (+56)')), 
                    DropdownMenuItem(value: 'China', child: Text('China (+86)')), 
                    DropdownMenuItem(value: 'Colombia', child: Text('Colombia (+57)')), 
                    DropdownMenuItem(value: 'Comoros', child: Text('Comoros (+269)')), 
                    DropdownMenuItem(value: 'Congo', child: Text('Congo (+242)')), 
                    DropdownMenuItem(value: 'Costa Rica', child: Text('Costa Rica (+506)')), 
                    DropdownMenuItem(value: 'Croatia', child: Text('Croatia (+385)')), 
                    DropdownMenuItem(value: 'Cuba', child: Text('Cuba (+53)')), 
                    DropdownMenuItem(value: 'Cyprus', child: Text('Cyprus (+357)')), 
                    DropdownMenuItem(value: 'Czech Republic', child: Text('Czech Republic (+420)')), 
                    DropdownMenuItem(value: 'Denmark', child: Text('Denmark (+45)')), 
                    DropdownMenuItem(value: 'Djibouti', child: Text('Djibouti (+253)')), 
                    DropdownMenuItem(value: 'Dominica', child: Text('Dominica (+1)')), 
                    DropdownMenuItem(value: 'Dominican Republic', child: Text('Dominican Republic (+1)')), 
                    DropdownMenuItem(value: 'Ecuador', child: Text('Ecuador (+593)')), 
                    DropdownMenuItem(value: 'Egypt', child: Text('Egypt (+20)')), 
                    DropdownMenuItem(value: 'El Salvador', child: Text('El Salvador (+503)')), 
                    DropdownMenuItem(value: 'Equatorial Guinea', child: Text('Equatorial Guinea (+240)')), 
                    DropdownMenuItem(value: 'Eritrea', child: Text('Eritrea (+291)')), 
                    DropdownMenuItem(value: 'Estonia', child: Text('Estonia (+372)')), 
                    DropdownMenuItem(value: 'Eswatini', child: Text('Eswatini (+268)')), 
                    DropdownMenuItem(value: 'Ethiopia', child: Text('Ethiopia (+251)')), 
                    DropdownMenuItem(value: 'Fiji', child: Text('Fiji (+679)')), 
                    DropdownMenuItem(value: 'Finland', child: Text('Finland (+358)')), 
                    DropdownMenuItem(value: 'France', child: Text('France (+33)')), 
                    DropdownMenuItem(value: 'Gabon', child: Text('Gabon (+241)')), 
                    DropdownMenuItem(value: 'Gambia', child: Text('Gambia (+220)')), 
                    DropdownMenuItem(value: 'Georgia', child: Text('Georgia (+995)')), 
                    DropdownMenuItem(value: 'Germany', child: Text('Germany (+49)')), 
                    DropdownMenuItem(value: 'Ghana', child: Text('Ghana (+233)')), 
                    DropdownMenuItem(value: 'Greece', child: Text('Greece (+30)')), 
                    DropdownMenuItem(value: 'Grenada', child: Text('Grenada (+1)')), 
                    DropdownMenuItem(value: 'Guatemala', child: Text('Guatemala (+502)')), 
                    DropdownMenuItem(value: 'Guinea', child: Text('Guinea (+224)')), 
                    DropdownMenuItem(value: 'Guinea-Bissau', child: Text('Guinea-Bissau (+245)')), 
                    DropdownMenuItem(value: 'Guyana', child: Text('Guyana (+592)')), 
                    DropdownMenuItem(value: 'Haiti', child: Text('Haiti (+509)')), 
                    DropdownMenuItem(value: 'Honduras', child: Text('Honduras (+504)')), 
                    DropdownMenuItem(value: 'Hungary', child: Text('Hungary (+36)')), 
                    DropdownMenuItem(value: 'Iceland', child: Text('Iceland (+354)')), 
                    DropdownMenuItem(value: 'India', child: Text('India (+91)')), 
                    DropdownMenuItem(value: 'Indonesia', child: Text('Indonesia (+62)')), 
                    DropdownMenuItem(value: 'Iran', child: Text('Iran (+98)')), 
                    DropdownMenuItem(value: 'Iraq', child: Text('Iraq (+964)')), 
                    DropdownMenuItem(value: 'Ireland', child: Text('Ireland (+353)')), 
                    DropdownMenuItem(value: 'Israel', child: Text('Israel (+972)')), 
                    DropdownMenuItem(value: 'Italy', child: Text('Italy (+39)')), 
                    DropdownMenuItem(value: 'Jamaica', child: Text('Jamaica (+1)')), 
                    DropdownMenuItem(value: 'Japan', child: Text('Japan (+81)')), 
                    DropdownMenuItem(value: 'Jordan', child: Text('Jordan (+962)')), 
                    DropdownMenuItem(value: 'Kazakhstan', child: Text('Kazakhstan (+7)')), 
                    DropdownMenuItem(value: 'Kenya', child: Text('Kenya (+254)')), 
                    DropdownMenuItem(value: 'Kiribati', child: Text('Kiribati (+686)')), 
                    DropdownMenuItem(value: 'Kuwait', child: Text('Kuwait (+965)')), 
                    DropdownMenuItem(value: 'Kyrgyzstan', child: Text('Kyrgyzstan (+996)')), 
                    DropdownMenuItem(value: 'Laos', child: Text('Laos (+856)')), 
                    DropdownMenuItem(value: 'Latvia', child: Text('Latvia (+371)')), 
                    DropdownMenuItem(value: 'Lebanon', child: Text('Lebanon (+961)')), 
                    DropdownMenuItem(value: 'Lesotho', child: Text('Lesotho (+266)')), 
                    DropdownMenuItem(value: 'Liberia', child: Text('Liberia (+231)')), 
                    DropdownMenuItem(value: 'Libya', child: Text('Libya (+218)')), 
                    DropdownMenuItem(value: 'Liechtenstein', child: Text('Liechtenstein (+423)')), 
                    DropdownMenuItem(value: 'Lithuania', child: Text('Lithuania (+370)')), 
                    DropdownMenuItem(value: 'Luxembourg', child: Text('Luxembourg (+352)')), 
                    DropdownMenuItem(value: 'Madagascar', child: Text('Madagascar (+261)')), 
                    DropdownMenuItem(value: 'Malawi', child: Text('Malawi (+265)')), 
                    DropdownMenuItem(value: 'Malaysia', child: Text('Malaysia (+60)')), 
                    DropdownMenuItem(value: 'Maldives', child: Text('Maldives (+960)')), 
                    DropdownMenuItem(value: 'Mali', child: Text('Mali (+223)')), 
                    DropdownMenuItem(value: 'Malta', child: Text('Malta (+356)')), 
                    DropdownMenuItem(value: 'Marshall Islands', child: Text('Marshall Islands (+692)')), 
                    DropdownMenuItem(value: 'Mauritania', child: Text('Mauritania (+222)')), 
                    DropdownMenuItem(value: 'Mauritius', child: Text('Mauritius (+230)')), 
                    DropdownMenuItem(value: 'Mexico', child: Text('Mexico (+52)')), 
                    DropdownMenuItem(value: 'Micronesia', child: Text('Micronesia (+691)')), 
                    DropdownMenuItem(value: 'Moldova', child: Text('Moldova (+373)')), 
                    DropdownMenuItem(value: 'Monaco', child: Text('Monaco (+377)')), 
                    DropdownMenuItem(value: 'Mongolia', child: Text('Mongolia (+976)')), 
                    DropdownMenuItem(value: 'Montenegro', child: Text('Montenegro (+382)')), 
                    DropdownMenuItem(value: 'Morocco', child: Text('Morocco (+212)')), 
                    DropdownMenuItem(value: 'Mozambique', child: Text('Mozambique (+258)')), 
                    DropdownMenuItem(value: 'Myanmar', child: Text('Myanmar (+95)')), 
                    DropdownMenuItem(value: 'Namibia', child: Text('Namibia (+264)')), 
                    DropdownMenuItem(value: 'Nauru', child: Text('Nauru (+674)')), 
                    DropdownMenuItem(value: 'Nepal', child: Text('Nepal (+977)')), 
                    DropdownMenuItem(value: 'Netherlands', child: Text('Netherlands (+31)')), 
                    DropdownMenuItem(value: 'New Zealand', child: Text('New Zealand (+64)')), 
                    DropdownMenuItem(value: 'Nicaragua', child: Text('Nicaragua (+505)')), 
                    DropdownMenuItem(value: 'Niger', child: Text('Niger (+227)')), 
                    DropdownMenuItem(value: 'Nigeria', child: Text('Nigeria (+234)')), 
                    DropdownMenuItem(value: 'North Korea', child: Text('North Korea (+850)')), 
                    DropdownMenuItem(value: 'North Macedonia', child: Text('North Macedonia (+389)')), 
                    DropdownMenuItem(value: 'Norway', child: Text('Norway (+47)')), 
                    DropdownMenuItem(value: 'Oman', child: Text('Oman (+968)')), 
                    DropdownMenuItem(value: 'Pakistan', child: Text('Pakistan (+92)')), 
                    DropdownMenuItem(value: 'Palau', child: Text('Palau (+680)')), 
                    DropdownMenuItem(value: 'Palestine', child: Text('Palestine (+970)')), 
                    DropdownMenuItem(value: 'Panama', child: Text('Panama (+507)')), 
                    DropdownMenuItem(value: 'Papua New Guinea', child: Text('Papua New Guinea (+675)')), 
                    DropdownMenuItem(value: 'Paraguay', child: Text('Paraguay (+595)')), 
                    DropdownMenuItem(value: 'Peru', child: Text('Peru (+51)')), 
                    DropdownMenuItem(value: 'Philippines', child: Text('Philippines (+63)')), 
                    DropdownMenuItem(value: 'Poland', child: Text('Poland (+48)')), 
                    DropdownMenuItem(value: 'Portugal', child: Text('Portugal (+351)')), 
                    DropdownMenuItem(value: 'Qatar', child: Text('Qatar (+974)')), 
                    DropdownMenuItem(value: 'Romania', child: Text('Romania (+40)')), 
                    DropdownMenuItem(value: 'Russia', child: Text('Russia (+7)')), 
                    DropdownMenuItem(value: 'Rwanda', child: Text('Rwanda (+250)')), 
                    DropdownMenuItem(value: 'Saint Kitts and Nevis', child: Text('Saint Kitts and Nevis (+1)')), 
                    DropdownMenuItem(value: 'Saint Lucia', child: Text('Saint Lucia (+1)')), 
                    DropdownMenuItem(value: 'Saint Vincent and the Grenadines', child: Text('Saint Vincent and the Grenadines (+1)')), 
                    DropdownMenuItem(value: 'Samoa', child: Text('Samoa (+685)')), 
                    DropdownMenuItem(value: 'San Marino', child: Text('San Marino (+378)')), 
                    DropdownMenuItem(value: 'Sao Tome and Principe', child: Text('Sao Tome and Principe (+239)')), 
                    DropdownMenuItem(value: 'Saudi Arabia', child: Text('Saudi Arabia (+966)')), 
                    DropdownMenuItem(value: 'Senegal', child: Text('Senegal (+221)')), 
                    DropdownMenuItem(value: 'Serbia', child: Text('Serbia (+381)')), 
                    DropdownMenuItem(value: 'Seychelles', child: Text('Seychelles (+248)')), 
                    DropdownMenuItem(value: 'Sierra Leone', child: Text('Sierra Leone (+232)')), 
                    DropdownMenuItem(value: 'Singapore', child: Text('Singapore (+65)')), 
                    DropdownMenuItem(value: 'Slovakia', child: Text('Slovakia (+421)')), 
                    DropdownMenuItem(value: 'Slovenia', child: Text('Slovenia (+386)')), 
                    DropdownMenuItem(value: 'Solomon Islands', child: Text('Solomon Islands (+677)')), 
                    DropdownMenuItem(value: 'Somalia', child: Text('Somalia (+252)')), 
                    DropdownMenuItem(value: 'South Africa', child: Text('South Africa (+27)')), 
                    DropdownMenuItem(value: 'South Korea', child: Text('South Korea (+82)')), 
                    DropdownMenuItem(value: 'South Sudan', child: Text('South Sudan (+211)')), 
                    DropdownMenuItem(value: 'Spain', child: Text('Spain (+34)')), 
                    DropdownMenuItem(value: 'Sri Lanka', child: Text('Sri Lanka (+94)')), 
                    DropdownMenuItem(value: 'Sudan', child: Text('Sudan (+249)')), 
                    DropdownMenuItem(value: 'Suriname', child: Text('Suriname (+597)')), 
                    DropdownMenuItem(value: 'Sweden', child: Text('Sweden (+46)')), 
                    DropdownMenuItem(value: 'Switzerland', child: Text('Switzerland (+41)')), 
                    DropdownMenuItem(value: 'Syria', child: Text('Syria (+963)')), 
                    DropdownMenuItem(value: 'Taiwan', child: Text('Taiwan (+886)')), 
                    DropdownMenuItem(value: 'Tajikistan', child: Text('Tajikistan (+992)')), 
                    DropdownMenuItem(value: 'Tanzania', child: Text('Tanzania (+255)')), 
                    DropdownMenuItem(value: 'Thailand', child: Text('Thailand (+66)')), 
                    DropdownMenuItem(value: 'Timor-Leste', child: Text('Timor-Leste (+670)')), 
                    DropdownMenuItem(value: 'Togo', child: Text('Togo (+228)')), 
                    DropdownMenuItem(value: 'Tonga', child: Text('Tonga (+676)')), 
                    DropdownMenuItem(value: 'Trinidad and Tobago', child: Text('Trinidad and Tobago (+1)')), 
                    DropdownMenuItem(value: 'Tunisia', child: Text('Tunisia (+216)')), 
                    DropdownMenuItem(value: 'Turkey', child: Text('Turkey (+90)')), 
                    DropdownMenuItem(value: 'Turkmenistan', child: Text('Turkmenistan (+993)')), 
                    DropdownMenuItem(value: 'Tuvalu', child: Text('Tuvalu (+688)')), 
                    DropdownMenuItem(value: 'Uganda', child: Text('Uganda (+256)')), 
                    DropdownMenuItem(value: 'Ukraine', child: Text('Ukraine (+380)')), 
                    DropdownMenuItem(value: 'United Arab Emirates', child: Text('United Arab Emirates (+971)')), 
                    DropdownMenuItem(value: 'United Kingdom', child: Text('United Kingdom (+44)')), 
                    DropdownMenuItem(value: 'United States', child: Text('United States (+1)')), 
                    DropdownMenuItem(value: 'Uruguay', child: Text('Uruguay (+598)')), 
                    DropdownMenuItem(value: 'Uzbekistan', child: Text('Uzbekistan (+998)')), 
                    DropdownMenuItem(value: 'Vanuatu', child: Text('Vanuatu (+678)')), 
                    DropdownMenuItem(value: 'Vatican City', child: Text('Vatican City (+39)')), 
                    DropdownMenuItem(value: 'Venezuela', child: Text('Venezuela (+58)')), 
                    DropdownMenuItem(value: 'Vietnam', child: Text('Vietnam (+84)')), 
                    DropdownMenuItem(value: 'Yemen', child: Text('Yemen (+967)')), 
                    DropdownMenuItem(value: 'Zambia', child: Text('Zambia (+260)')), 
                    DropdownMenuItem(value: 'Zimbabwe', child: Text('Zimbabwe (+263)')), 
                  ],
                  onChanged: (v) => setState(() {
                    _country = v ?? 'South Africa';
                    _countryCode = {
                      'Afghanistan': '+93',
                      'Albania': '+355',
                      'Algeria': '+213',
                      'Andorra': '+376',
                      'Angola': '+244',
                      'Antigua and Barbuda': '+1',
                      'Argentina': '+54',
                      'Armenia': '+374',
                      'Australia': '+61',
                      'Austria': '+43',
                      'Azerbaijan': '+994',
                      'Bahamas': '+1',
                      'Bahrain': '+973',
                      'Bangladesh': '+880',
                      'Barbados': '+1',
                      'Belarus': '+375',
                      'Belgium': '+32',
                      'Belize': '+501',
                      'Benin': '+229',
                      'Bhutan': '+975',
                      'Bolivia': '+591',
                      'Bosnia and Herzegovina': '+387',
                      'Botswana': '+267',
                      'Brazil': '+55',
                      'Brunei': '+673',
                      'Bulgaria': '+359',
                      'Burkina Faso': '+226',
                      'Burundi': '+257',
                      'Cambodia': '+855',
                      'Cameroon': '+237',
                      'Canada': '+1',
                      'Cape Verde': '+238',
                      'Central African Republic': '+236',
                      'Chad': '+235',
                      'Chile': '+56',
                      'China': '+86',
                      'Colombia': '+57',
                      'Comoros': '+269',
                      'Congo': '+242',
                      'Costa Rica': '+506',
                      'Croatia': '+385',
                      'Cuba': '+53',
                      'Cyprus': '+357',
                      'Czech Republic': '+420',
                      'Denmark': '+45',
                      'Djibouti': '+253',
                      'Dominica': '+1',
                      'Dominican Republic': '+1',
                      'Ecuador': '+593',
                      'Egypt': '+20',
                      'El Salvador': '+503',
                      'Equatorial Guinea': '+240',
                      'Eritrea': '+291',
                      'Estonia': '+372',
                      'Eswatini': '+268',
                      'Ethiopia': '+251',
                      'Fiji': '+679',
                      'Finland': '+358',
                      'France': '+33',
                      'Gabon': '+241',
                      'Gambia': '+220',
                      'Georgia': '+995',
                      'Germany': '+49',
                      'Ghana': '+233',
                      'Greece': '+30',
                      'Grenada': '+1',
                      'Guatemala': '+502',
                      'Guinea': '+224',
                      'Guinea-Bissau': '+245',
                      'Guyana': '+592',
                      'Haiti': '+509',
                      'Honduras': '+504',
                      'Hungary': '+36',
                      'Iceland': '+354',
                      'India': '+91',
                      'Indonesia': '+62',
                      'Iran': '+98',
                      'Iraq': '+964',
                      'Ireland': '+353',
                      'Israel': '+972',
                      'Italy': '+39',
                      'Jamaica': '+1',
                      'Japan': '+81',
                      'Jordan': '+962',
                      'Kazakhstan': '+7',
                      'Kenya': '+254',
                      'Kiribati': '+686',
                      'Kuwait': '+965',
                      'Kyrgyzstan': '+996',
                      'Laos': '+856',
                      'Latvia': '+371',
                      'Lebanon': '+961',
                      'Lesotho': '+266',
                      'Liberia': '+231',
                      'Libya': '+218',
                      'Liechtenstein': '+423',
                      'Lithuania': '+370',
                      'Luxembourg': '+352',
                      'Madagascar': '+261',
                      'Malawi': '+265',
                      'Malaysia': '+60',
                      'Maldives': '+960',
                      'Mali': '+223',
                      'Malta': '+356',
                      'Marshall Islands': '+692',
                      'Mauritania': '+222',
                      'Mauritius': '+230',
                      'Mexico': '+52',
                      'Micronesia': '+691',
                      'Moldova': '+373',
                      'Monaco': '+377',
                      'Mongolia': '+976',
                      'Montenegro': '+382',
                      'Morocco': '+212',
                      'Mozambique': '+258',
                      'Myanmar': '+95',
                      'Namibia': '+264',
                      'Nauru': '+674',
                      'Nepal': '+977',
                      'Netherlands': '+31',
                      'New Zealand': '+64',
                      'Nicaragua': '+505',
                      'Niger': '+227',
                      'Nigeria': '+234',
                      'North Korea': '+850',
                      'North Macedonia': '+389',
                      'Norway': '+47',
                      'Oman': '+968',
                      'Pakistan': '+92',
                      'Palau': '+680',
                      'Palestine': '+970',
                      'Panama': '+507',
                      'Papua New Guinea': '+675',
                      'Paraguay': '+595',
                      'Peru': '+51',
                      'Philippines': '+63',
                      'Poland': '+48',
                      'Portugal': '+351',
                      'Qatar': '+974',
                      'Romania': '+40',
                      'Russia': '+7',
                      'Rwanda': '+250',
                      'Saint Kitts and Nevis': '+1',
                      'Saint Lucia': '+1',
                      'Saint Vincent and the Grenadines': '+1',
                      'Samoa': '+685',
                      'San Marino': '+378',
                      'Sao Tome and Principe': '+239',
                      'Saudi Arabia': '+966',
                      'Senegal': '+221',
                      'Serbia': '+381',
                      'Seychelles': '+248',
                      'Sierra Leone': '+232',
                      'Singapore': '+65',
                      'Slovakia': '+421',
                      'Slovenia': '+386',
                      'Solomon Islands': '+677',
                      'Somalia': '+252',
                      'South Africa': '+27',
                      'South Korea': '+82',
                      'South Sudan': '+211',
                      'Spain': '+34',
                      'Sri Lanka': '+94',
                      'Sudan': '+249',
                      'Suriname': '+597',
                      'Sweden': '+46',
                      'Switzerland': '+41',
                      'Syria': '+963',
                      'Taiwan': '+886',
                      'Tajikistan': '+992',
                      'Tanzania': '+255',
                      'Thailand': '+66',
                      'Timor-Leste': '+670',
                      'Togo': '+228',
                      'Tonga': '+676',
                      'Trinidad and Tobago': '+1',
                      'Tunisia': '+216',
                      'Turkey': '+90',
                      'Turkmenistan': '+993',
                      'Tuvalu': '+688',
                      'Uganda': '+256',
                      'Ukraine': '+380',
                      'United Arab Emirates': '+971',
                      'United Kingdom': '+44',
                      'United States': '+1',
                      'Uruguay': '+598',
                      'Uzbekistan': '+998',
                      'Vanuatu': '+678',
                      'Vatican City': '+39',
                      'Venezuela': '+58',
                      'Vietnam': '+84',
                      'Yemen': '+967',
                      'Zambia': '+260',
                      'Zimbabwe': '+263',
                    }[v] ?? '+27';
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey.shade50,
                      ),
                      child: Text(_countryCode,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.dark)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Mobile number',
                          hintText: 'e.g. 821234567',
                          prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    labelText: 'Street address',
                    hintText: 'e.g. 12 Main Street, Apartment 3',
                    prefixIcon: const Icon(Icons.home_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _cityController,
                        decoration: InputDecoration(
                          labelText: 'City / Town',
                          hintText: 'e.g. Cape Town',
                          prefixIcon: const Icon(Icons.location_city_outlined, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _postalController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Postal code',
                          hintText: 'e.g. 8001',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
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
