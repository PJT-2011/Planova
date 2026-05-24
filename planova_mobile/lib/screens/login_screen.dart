import 'package:flutter/material.dart';
import 'package:planova_mobile/services/auth_service.dart';
import 'package:planova_mobile/screens/signup_screen.dart';
import 'package:planova_mobile/screens/home_screen.dart';
import 'package:planova_mobile/screens/guest_home_screen.dart';
import 'package:planova_mobile/screens/forgot_password_screen.dart';
import 'package:planova_mobile/screens/email_verification_screen.dart';
import 'package:planova_mobile/theme/app_theme.dart';
import 'package:planova_mobile/main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _isGuestLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email';
    final rx = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    if (!rx.hasMatch(value.trim()))
      return 'Enter a valid email (e.g. name@example.com)';
    return null;
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      final verified = await _authService.isEmailVerified();
      if (!verified) {
        await _authService.sendEmailVerification();
        Navigator.pushReplacement(
          context,
          PlanovaPageRoute(
            builder: (_) =>
                EmailVerificationScreen(email: _emailController.text.trim()),
          ),
        );
        return;
      }
      await PlanovaApp.of(context)?.loadTheme();
      Navigator.pushReplacement(
        context,
        PlanovaPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final result = await _authService.signInWithGoogle();
      if (result == null) return;
      if (!mounted) return;
      await PlanovaApp.of(context)?.loadTheme();
      Navigator.pushReplacement(
        context,
        PlanovaPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() => _isGuestLoading = true);
    try {
      final credential = await _authService.signInAnonymously();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PlanovaPageRoute(
          builder: (_) => GuestHomeScreen(userId: credential.user!.uid),
        ),
      );
    } catch (e) {
      if (mounted) _showError('Failed to continue as guest: $e');
    } finally {
      if (mounted) setState(() => _isGuestLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.colors(context).error,
      ),
    );
  }

  bool get _anyLoading => _isLoading || _isGoogleLoading || _isGuestLoading;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          // ── Gradient hero header ──────────────────────────────────────────
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: heroGradient(),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(36),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.map,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'PLANOVA',
                              style: tt.labelMedium?.copyWith(
                                color: Colors.white,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Navigate\nIndoors',
                        style: tt.displayMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Smart floorplans. Instant directions.',
                        style: tt.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Form card ─────────────────────────────────────────────────────
          Expanded(
            flex: 7,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Container(
                decoration: isDark
                    ? BoxDecoration(
                        color: const Color(0xFF1C2942),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                          width: 1,
                        ),
                      )
                    : lightCardDecoration(radius: AppRadius.xl),
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section heading
                      Text(
                        'Welcome back',
                        style: tt.headlineMedium?.copyWith(
                          color: c.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to continue',
                        style: tt.bodyMedium?.copyWith(
                          color: c.onSurfaceSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Email field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Email address',
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: c.iconMuted,
                          ),
                        ),
                        validator: _validateEmail,
                      ),
                      const SizedBox(height: 12),

                      // Password field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: c.iconMuted,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: c.iconMuted,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Please enter your password';
                          if (v.length < 6)
                            return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            PlanovaPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 6,
                            ),
                          ),
                          child: Text(
                            'Forgot Password?',
                            style: tt.labelMedium?.copyWith(color: c.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),

                      // Sign in button
                      _GradientButton(
                        label: 'Sign In',
                        isLoading: _isLoading,
                        onTap: _anyLoading ? null : _signIn,
                        c: c,
                        tt: tt,
                      ),
                      const SizedBox(height: 16),

                      // OR divider
                      _OrDivider(c: c, tt: tt),
                      const SizedBox(height: 14),

                      // Google
                      _SocialButton(
                        icon: const _GoogleIcon(),
                        label: 'Continue with Google',
                        isLoading: _isGoogleLoading,
                        onTap: _anyLoading ? null : _signInWithGoogle,
                        c: c,
                        tt: tt,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 10),

                      // Guest
                      _SocialButton(
                        icon: Icon(
                          Icons.person_outline_rounded,
                          size: 20,
                          color: c.onSurfaceSecondary,
                        ),
                        label: 'Continue as Guest',
                        isLoading: _isGuestLoading,
                        onTap: _anyLoading ? null : _continueAsGuest,
                        c: c,
                        tt: tt,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Guests can scan QR codes and navigate buildings.\nAdmin login required to manage floorplans.',
                        textAlign: TextAlign.center,
                        style: tt.bodySmall?.copyWith(
                          color: c.onSurfaceTertiary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Sign up link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: tt.bodyMedium?.copyWith(
                              color: c.onSurfaceSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: _anyLoading
                                ? null
                                : () => Navigator.push(
                                    context,
                                    PlanovaPageRoute(
                                      builder: (_) => const SignUpScreen(),
                                    ),
                                  ),
                            child: Text(
                              'Sign Up',
                              style: tt.bodyMedium?.copyWith(
                                color: c.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Gradient CTA button ───────────────────────────────────────────────────────

class _GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;
  final AppColors c;
  final TextTheme tt;

  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.onTap,
    required this.c,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.55 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: heroGradient(),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.primaryGlow(c.primary),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: tt.labelLarge?.copyWith(color: Colors.white),
                  ),
          ),
        ),
      ),
    );
  }
}

// ── OR divider ────────────────────────────────────────────────────────────────

class _OrDivider extends StatelessWidget {
  final AppColors c;
  final TextTheme tt;
  const _OrDivider({required this.c, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: c.border, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: tt.bodySmall?.copyWith(color: c.onSurfaceTertiary),
          ),
        ),
        Expanded(child: Divider(color: c.border, thickness: 1)),
      ],
    );
  }
}

// ── Social button ─────────────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;
  final AppColors c;
  final TextTheme tt;
  final bool isDark;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.isLoading,
    required this.onTap,
    required this.c,
    required this.tt,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.55 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF243450) : c.inputFill,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: c.border, width: 1),
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.primary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon,
                      const SizedBox(width: 10),
                      Text(
                        label,
                        style: tt.labelLarge?.copyWith(color: c.onSurface),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ── Google "G" icon ───────────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleIconPainter()),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final center = rect.center;
    final radius = size.width / 2;
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.5, 1.6, true, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.14, 1.1, true, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 4.25, 0.9, true, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 2.2, 0.9, true, paint);
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.55, paint);
    paint.color = const Color(0xFF4285F4);
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - radius * 0.18,
        radius * 0.95,
        radius * 0.36,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
