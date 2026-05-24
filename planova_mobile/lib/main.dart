import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planova_mobile/screens/login_screen.dart';
import 'package:planova_mobile/screens/home_screen.dart';
import 'package:planova_mobile/screens/onboarding_screen.dart';
import 'package:planova_mobile/services/auth_service.dart';
import 'package:planova_mobile/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized');
  } catch (e) {
    debugPrint('❌ Firebase init error: $e');
  }
  runApp(const PlanovaApp());
}

class PlanovaApp extends StatefulWidget {
  const PlanovaApp({Key? key}) : super(key: key);

  static _PlanovaAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_PlanovaAppState>();

  @override
  State<PlanovaApp> createState() => _PlanovaAppState();
}

class _PlanovaAppState extends State<PlanovaApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    loadTheme();
  }

  Future<void> loadTheme() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _themeMode = ThemeMode.light);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('dark_mode_${user.uid}') ?? false;
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> toggleTheme(bool isDark) async {
    final user = FirebaseAuth.instance.currentUser;
    final prefs = await SharedPreferences.getInstance();
    if (user != null) await prefs.setBool('dark_mode_${user.uid}', isDark);
    setState(() => _themeMode = isDark ? ThemeMode.dark : ThemeMode.light);
  }

  void resetToLight() => setState(() => _themeMode = ThemeMode.light);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Planova',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // ── Custom page transitions applied app-wide ──────────────────────
      // The builder wraps Navigator so every MaterialPageRoute
      // automatically uses PlanovaPageTransition.
      onGenerateRoute: PlanovaRouter.onGenerateRoute,
      home: const SplashScreen(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PLANOVA ROUTER — central route handler
// All Navigator.pushNamed calls go through here.
// For pushReplacement / push with MaterialPageRoute, use the helpers below.
// ═════════════════════════════════════════════════════════════════════════════

class PlanovaRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    // Fallback: wrap in our custom transition
    return PlanovaPageRoute(
      settings: settings,
      builder: (_) => const SplashScreen(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CUSTOM PAGE ROUTE — fade + slide up
//
// Usage (drop-in replacement for MaterialPageRoute):
//
//   Navigator.push(context, PlanovaPageRoute(builder: (_) => MyScreen()));
//   Navigator.pushReplacement(context, PlanovaPageRoute(builder: (_) => MyScreen()));
//
// For modal-style screens (bottom sheets that are full-screen):
//   Navigator.push(context, PlanovaModalRoute(builder: (_) => MyScreen()));
// ═════════════════════════════════════════════════════════════════════════════

class PlanovaPageRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;

  PlanovaPageRoute({
    required this.builder,
    RouteSettings? settings,
    bool fullscreenDialog = false,
  }) : super(settings: settings, fullscreenDialog: fullscreenDialog);

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _PlanovaTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

// ── Modal route (slides up from bottom, like a bottom sheet) ─────────────────

class PlanovaModalRoute<T> extends PageRoute<T> {
  final WidgetBuilder builder;

  PlanovaModalRoute({required this.builder, RouteSettings? settings})
    : super(settings: settings, fullscreenDialog: true);

  @override
  Color? get barrierColor => Colors.black54;

  @override
  String? get barrierLabel => null;

  @override
  bool get barrierDismissible => false;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 380);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    );
  }
}

// ── The actual transition widget ──────────────────────────────────────────────
//
// Incoming screen: fades in (0→1) + slides up slightly (16px → 0)
// Outgoing screen: fades out subtly (1→0.92) + scales down slightly (1→0.97)
// This is the same pattern used by Linear, Notion, and BrainByte.

class _PlanovaTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const _PlanovaTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // ── Incoming: fade + slide up ─────────────────────────────────────────
    final inCurve = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      ),
    );

    final slideIn = Tween<Offset>(
      begin: const Offset(0, 0.04), // 4% of screen height upward
      end: Offset.zero,
    ).animate(inCurve);

    // ── Outgoing: subtle scale + fade ─────────────────────────────────────
    final scaleOut = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut),
    );

    final fadeOut = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeInOut),
    );

    return FadeTransition(
      opacity: fadeOut,
      child: ScaleTransition(
        scale: scaleOut,
        child: FadeTransition(
          opacity: fadeIn,
          child: SlideTransition(position: slideIn, child: child),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SPLASH SCREEN
// ═════════════════════════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();

  // Logo entrance animation
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
    _checkOnboarding();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _checkOnboarding() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    final prefs = await SharedPreferences.getInstance();
    final onboardingComplete = prefs.getBool('onboarding_complete') ?? false;
    if (!mounted) return;
    if (!onboardingComplete) {
      Navigator.pushReplacement(
        context,
        PlanovaPageRoute(builder: (_) => const OnboardingScreen()),
      );
    } else {
      final user = _authService.currentUser;
      Navigator.pushReplacement(
        context,
        PlanovaPageRoute(
          builder: (_) =>
              user != null ? const HomeScreen() : const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: heroGradient()),
        child: SafeArea(
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo container
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.map,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'PLANOVA',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Indoor Navigation Made Easy',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 56),
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
