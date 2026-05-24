import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planova_mobile/screens/login_screen.dart';
import 'package:planova_mobile/theme/app_theme.dart';
import 'package:planova_mobile/main.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  static const _pages = [
    _OnboardingData(
      title: 'Navigate Indoors\nwith Ease',
      description:
          'Find any room, office, or facility instantly. No more getting lost in unfamiliar buildings.',
      icon: Icons.navigation_rounded,
      gradientEnd: Color(0xFF3B82F6),
    ),
    _OnboardingData(
      title: 'Upload Your\nFloorplans',
      description:
          'Simply upload a photo of any building floorplan and Planova takes care of the rest.',
      icon: Icons.upload_file_rounded,
      gradientEnd: Color(0xFF2563EB),
    ),
    _OnboardingData(
      title: 'AI-Powered\nProcessing',
      description:
          'Our AI automatically detects walls, doorways, and navigable spaces to build the perfect map.',
      icon: Icons.auto_awesome_rounded,
      gradientEnd: Color(0xFF1D4ED8),
    ),
    _OnboardingData(
      title: 'Scan & Go\nin Seconds',
      description:
          'Scan a building\'s QR code at the entrance, pick your destination and follow the route.',
      icon: Icons.qr_code_scanner_rounded,
      gradientEnd: Color(0xFF1450A8),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PlanovaPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _complete();
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _fadeController.reset();
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final page = _pages[_currentPage];

    return Scaffold(
      body: Stack(
        children: [
          // ── Full-screen gradient background (animates per slide) ─────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF0D3366), page.gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Decorative circles ───────────────────────────────────────────
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -80,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),

          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16, top: 8),
                    child: TextButton(
                      onPressed: _complete,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.7),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        'Skip',
                        style: tt.labelLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ),

                // Page content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    itemBuilder: (context, i) =>
                        _PageContent(data: _pages[i], tt: tt),
                  ),
                ),

                // ── Bottom controls ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
                  child: Column(
                    children: [
                      // Pill dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _pages.length,
                          (i) => _Dot(active: i == _currentPage),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Next / Get Started button
                      GestureDetector(
                        onTap: _next,
                        child: Container(
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              _currentPage == _pages.length - 1
                                  ? 'Get Started'
                                  : 'Next',
                              style: tt.labelLarge?.copyWith(
                                color: const Color(0xFF1A6ADB),
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (_currentPage < _pages.length - 1) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _complete,
                          child: Text(
                            'Already have an account? Sign in',
                            style: tt.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Page Content ──────────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  final _OnboardingData data;
  final TextTheme tt;
  const _PageContent({required this.data, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon container (BrainByte-style frosted card)
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.20),
                width: 1.5,
              ),
            ),
            child: Icon(data.icon, size: 80, color: Colors.white),
          ),
          const SizedBox(height: 52),
          Text(
            data.title,
            style: tt.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.18,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Text(
            data.description,
            style: tt.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Animated pill dot ─────────────────────────────────────────────────────────

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 28 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
    );
  }
}

// ── Data model ────────────────────────────────────────────────────────────────

class _OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  final Color gradientEnd;

  const _OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
    required this.gradientEnd,
  });
}

// Keep public alias for external reference compatibility
class OnboardingPage extends _OnboardingData {
  const OnboardingPage({
    required super.title,
    required super.description,
    required super.icon,
    required super.gradientEnd,
  });
}
