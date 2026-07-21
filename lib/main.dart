import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  // Load initial cart count if logged in
  if (Supabase.instance.client.auth.currentUser != null) {
    try {
      final cart = await Supabase.instance.client
          .from('cart_items').select().eq('user_id', Supabase.instance.client.auth.currentUser!.id);
      CartBadge.update((cart as List).fold<int>(0, (s, i) => s + ((i['quantity'] ?? 1) as int)));
    } catch (_) {}
  }

  runApp(const HerbalRemedyApp());
}

class HerbalRemedyApp extends StatelessWidget {
  const HerbalRemedyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Herbal Remedy Book',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _loggedIn  = false;
  bool _checked   = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final isLoggedIn = data.session != null;
      if (mounted && isLoggedIn != _loggedIn) {
        setState(() => _loggedIn = isLoggedIn);
      }
    });
  }

  Future<void> _checkAuth() async {
    final session    = Supabase.instance.client.auth.currentSession;
    final stayIn     = await SupabaseService.shouldStayLoggedIn();
    if (session != null && !stayIn) {
      await SupabaseService.signOut();
      if (mounted) setState(() { _loggedIn = false; _checked = true; });
    } else {
      if (mounted) setState(() { _loggedIn = session != null; _checked = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: AppColors.primary)));
    return _loggedIn ? const AppShell() : const LoginScreen();
  }
}

// ── Navigation Shell ──────────────────────────────────────────────────────

class AppShell extends StatefulWidget {
  final int initialIndex;
  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _currentIndex;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(
    6, (_) => GlobalKey<NavigatorState>(),
  );

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0: return HomeScreen(onTabSwitch: _switchTab);
      case 1: return const RecipesScreen();
      case 2: return const ShopScreen();
      case 3: return const SubmitRemedyScreen();
      case 4: return const MyRecipesScreen();
      case 5: return const ProfileScreen();
      default: return HomeScreen(onTabSwitch: _switchTab);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: List.generate(6, (i) => Offstage(
          offstage: _currentIndex != i,
          child: Navigator(
            key: _navigatorKeys[i],
            onGenerateRoute: (settings) =>
                MaterialPageRoute(builder: (_) => _buildTab(i)),
          ),
        )),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) async {
          final canNavigate = await NavigationGuard.shouldNavigate(context);
          if (!canNavigate) return;
          if (i == _currentIndex) {
            _navigatorKeys[i].currentState?.popUntil((r) => r.isFirst);
          } else {
            setState(() => _currentIndex = i);
            // Reload recipes when switching to recipes tab
            if (i == 1) {
              _navigatorKeys[1].currentState?.popUntil((r) => r.isFirst);
            }
          }
        },
      ),
    );
  }
}

