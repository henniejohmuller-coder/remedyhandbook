import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'config.dart';
import 'theme/app_theme.dart';
import 'services/supabase_service.dart';
import 'widgets/shared_widgets.dart';
import 'widgets/install_banner.dart';
import 'widgets/navigation_guard.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/shop_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/order_confirmation_screen.dart';
import 'screens/submit_remedy_screen.dart';
import 'screens/my_recipes_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/recipe_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) usePathUrlStrategy();
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  if (Supabase.instance.client.auth.currentUser != null) {
    try {
      final cart = await Supabase.instance.client
          .from('cart_items').select()
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id);
      CartBadge.update((cart as List).fold<int>(0, (s, i) => s + ((i['quantity'] ?? 1) as int)));
    } catch (_) {}
  }
  runApp(const HerbalRemedyApp());
}

// ── Router ────────────────────────────────────────────────────────────────────
final _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    final isRemedyRoute = state.uri.path.startsWith('/remedy/');
    // Allow remedy routes for everyone — guests see limited view
    if (isRemedyRoute) return null;
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const _AuthGate(),
    ),
    GoRoute(
      path: '/download',
      builder: (_, __) => const _DownloadScreen(),
    ),
    GoRoute(path: '/payment-success', builder: (_, __) => const _PaymentSuccessPage()),
    GoRoute(path: '/payment-cancel', builder: (_, __) => const _PaymentCancelPage()),
    GoRoute(
      path: '/remedy/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final isLoggedIn = Supabase.instance.client.auth.currentUser != null;
        if (isLoggedIn) {
          return _LoggedInRemedyLoader(remedyId: id);
        }
        return _GuestRemedyLoader(remedyId: id);
      },
    ),
  ],
);

// ── App ───────────────────────────────────────────────────────────────────────
class HerbalRemedyApp extends StatelessWidget {
  const HerbalRemedyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Remedy Handbook',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      routerConfig: _router,
    );
  }
}

// ── Auth Gate ─────────────────────────────────────────────────────────────────
class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _loggedIn = false;
  bool _checked  = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() => _loggedIn = data.session != null);
    });
  }

  Future<void> _checkAuth() async {
    final session    = Supabase.instance.client.auth.currentSession;
    final stayIn     = await SupabaseService.shouldStayLoggedIn();
    if (!stayIn) await SupabaseService.signOut();
    if (mounted) setState(() { _loggedIn = stayIn && session != null; _checked = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (!_loggedIn) return const LoginScreen();
    return AppShell(initialIndex: 0);
  }
}

// ── App Shell ─────────────────────────────────────────────────────────────────
class AppShell extends StatefulWidget {
  final int initialIndex;
  const AppShell({super.key, required this.initialIndex});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _currentIndex;
  final List<GlobalKey<NavigatorState>> _navigatorKeys =
      List.generate(6, (_) => GlobalKey<NavigatorState>());

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkVersion());
    }
  }

  Future<void> _checkVersion() async {
    try {
      const currentVersion = '1.0.8';
      final data = await Supabase.instance.client
          .from('app_version').select().eq('id', 1).single();
      final latest     = data['version']?.toString() ?? currentVersion;
      final forceUpdate = data['force_update'] == true;
      final updateUrl  = data['update_url']?.toString() ?? 'https://remedyhandbook.com/download';
      if (!mounted) return;
      if (latest != currentVersion) {
        showDialog(
          context: context,
          barrierDismissible: !forceUpdate,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2C1A00),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Update Available',
                style: TextStyle(color: Color(0xFFF5C518), fontWeight: FontWeight.w700)),
            content: Text('Version $latest is available.\nTap Update Now to download.',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            actions: [
              if (!forceUpdate)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Later', style: TextStyle(color: Colors.white54))),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(updateUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5C518),
                    foregroundColor: const Color(0xFF2C1A00)),
                child: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
        );
      }
    } catch (_) {}
  }

  void _switchTab(int index) {
    if (index == _currentIndex) {
      _navigatorKeys[index].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _currentIndex = index);
    }
  }

  Future<bool> _onWillPop() async {
    final nav = _navigatorKeys[_currentIndex].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop();
      return false;
    }
    return true;
  }

  Widget _buildTab(Widget screen) => Navigator(
    key: _navigatorKeys[_currentIndex],
    onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => screen),
  );

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(),
      const RecipesScreen(),
      const ShopScreen(),
      const SubmitRemedyScreen(),
      const MyRecipesScreen(),
      const ProfileScreen(),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _onWillPop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: _buildTab(screens[_currentIndex]),
        bottomNavigationBar: AppBottomNavBar(
          currentIndex: _currentIndex,
          onTap: (i) async {
            final canNav = await NavigationGuard.shouldNavigate(context);
            if (canNav) _switchTab(i);
          },
        ),
      ),
    );
  }
}

// ── Logged In Remedy Loader ───────────────────────────────────────────────────
class _LoggedInRemedyLoader extends StatefulWidget {
  final String remedyId;
  const _LoggedInRemedyLoader({required this.remedyId});
  @override
  State<_LoggedInRemedyLoader> createState() => _LoggedInRemedyLoaderState();
}

class _LoggedInRemedyLoaderState extends State<_LoggedInRemedyLoader> {
  Map<String, dynamic>? _remedy;
  bool _loading  = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.supabase
          .from('remedies_full')
          .select()
          .eq('id', widget.remedyId)
          .maybeSingle();
      setState(() {
        _remedy   = data;
        _notFound = data == null;
        _loading  = false;
      });
    } catch (_) {
      setState(() { _notFound = true; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (_notFound || _remedy == null) return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text('Remedy not found', style: AppTextStyles.heading3),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dark, foregroundColor: AppColors.primary),
            child: const Text('Go to Remedy Handbook')),
        ],
      ))));
    return RecipeDetailScreenDB(remedy: _remedy!, isGuest: false);
  }
}

// ── Guest Remedy Loader ───────────────────────────────────────────────────────
class _DownloadScreen extends StatefulWidget {
  const _DownloadScreen();
  @override
  State<_DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<_DownloadScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.download_outlined, size: 56, color: AppColors.primary),
                const SizedBox(height: 16),
                const Text('Get Remedy Handbook', style: AppTextStyles.heading2, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                const InstallBanner(),
                const SizedBox(height: 16),
                TextButton(onPressed: () => context.go('/'), child: const Text('Continue to Remedy Handbook')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestRemedyLoader extends StatefulWidget {
  final String remedyId;
  const _GuestRemedyLoader({required this.remedyId});
  @override
  State<_GuestRemedyLoader> createState() => _GuestRemedyLoaderState();
}

class _GuestRemedyLoaderState extends State<_GuestRemedyLoader> {
  Map<String, dynamic>? _remedy;
  bool _loading  = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.supabase
          .from('remedies_full')
          .select()
          .eq('id', widget.remedyId)
          .maybeSingle();
      setState(() {
        _remedy   = data;
        _notFound = data == null;
        _loading  = false;
      });
    } catch (_) {
      setState(() { _notFound = true; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    if (_notFound || _remedy == null) return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text('Remedy not found', style: AppTextStyles.heading3),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dark, foregroundColor: AppColors.primary),
            child: const Text('Go to Remedy Handbook')),
        ],
      ))));
    return RecipeDetailScreenDB(remedy: _remedy!, isGuest: true);
  }
}















class _PaymentSuccessPage extends StatelessWidget {
  const _PaymentSuccessPage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 64),
          const SizedBox(height: 16),
          const Text('Payment Successful!', style: AppTextStyles.heading2),
          const SizedBox(height: 8),
          const Text('Thank you for your order.', style: AppTextStyles.caption),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dark, foregroundColor: AppColors.primary),
            child: const Text('Continue Shopping')),
        ],
      ))),
    );
  }
}

class _PaymentCancelPage extends StatelessWidget {
  const _PaymentCancelPage();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cancel_outlined, color: Colors.orange, size: 64),
          const SizedBox(height: 16),
          const Text('Payment Cancelled', style: AppTextStyles.heading2),
          const SizedBox(height: 8),
          const Text('Your order was not completed.', style: AppTextStyles.caption),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dark, foregroundColor: AppColors.primary),
            child: const Text('Return to App')),
        ],
      ))),
    );
  }
}

