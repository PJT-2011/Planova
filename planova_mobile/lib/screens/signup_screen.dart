import 'package:flutter/material.dart';
import 'package:planova_mobile/services/auth_service.dart';
import 'package:planova_mobile/screens/email_verification_screen.dart';
import 'package:planova_mobile/theme/app_theme.dart';
import 'package:planova_mobile/main.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Password strength: 0-4
  int _passwordStrength = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email';
    final rx = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    if (!rx.hasMatch(value.trim()))
      return 'Please enter a valid email (e.g. name@example.com)';
    return null;
  }

  void _updatePasswordStrength(String password) {
    int strength = 0;
    if (password.length >= 6) strength++;
    if (password.length >= 10) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#\$&*~%^()_+\-=]'))) strength++;
    setState(() => _passwordStrength = strength.clamp(0, 4));
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.signUpWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        role: 'admin',
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PlanovaPageRoute(
            builder: (_) =>
                EmailVerificationScreen(email: _emailController.text.trim()),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.colors(context).error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: c.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Gradient header ───────────────────────────────────────────
            Container(
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
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 52),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Logo pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.map,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'PLANOVA',
                              style: tt.labelSmall?.copyWith(
                                color: Colors.white,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Create\nAccount',
                        style: tt.displayMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign up to manage your buildings',
                        style: tt.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Form card ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Container(
                decoration: isDark
                    ? BoxDecoration(
                        color: const Color(0xFF1C2942),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      )
                    : lightCardDecoration(radius: AppRadius.xl),
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Your details',
                        style: tt.headlineMedium?.copyWith(
                          color: c.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fill in your information below',
                        style: tt.bodyMedium?.copyWith(
                          color: c.onSurfaceSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Full name
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          hintText: 'Full name',
                          prefixIcon: Icon(
                            Icons.person_outline_rounded,
                            color: c.iconMuted,
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Please enter your name'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      // Email
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
                      const SizedBox(height: 14),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        onChanged: _updatePasswordStrength,
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
                            return 'Please enter a password';
                          if (v.length < 6)
                            return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),

                      // Password strength bar
                      if (_passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _PasswordStrengthBar(
                          strength: _passwordStrength,
                          c: c,
                          tt: tt,
                        ),
                      ],
                      const SizedBox(height: 14),

                      // Confirm password
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          hintText: 'Confirm password',
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: c.iconMuted,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: c.iconMuted,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Please confirm your password';
                          if (v != _passwordController.text)
                            return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      // Sign up button
                      GestureDetector(
                        onTap: _isLoading ? null : _signUp,
                        child: AnimatedOpacity(
                          opacity: _isLoading ? 0.7 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: heroGradient(),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              boxShadow: AppShadows.primaryGlow(c.primary),
                            ),
                            child: Center(
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 22,
                                      width: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      'Create Account',
                                      style: tt.labelLarge?.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Login link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: tt.bodyMedium?.copyWith(
                              color: c.onSurfaceSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              'Sign In',
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
          ],
        ),
      ),
    );
  }
}

// ── Password strength bar ─────────────────────────────────────────────────────

class _PasswordStrengthBar extends StatelessWidget {
  final int strength; // 0–4
  final AppColors c;
  final TextTheme tt;
  const _PasswordStrengthBar({
    required this.strength,
    required this.c,
    required this.tt,
  });

  Color get _color {
    if (strength <= 1) return const Color(0xFFEF4444);
    if (strength == 2) return const Color(0xFFF59E0B);
    if (strength == 3) return const Color(0xFF3B82F6);
    return const Color(0xFF22C55E);
  }

  String get _label {
    if (strength <= 1) return 'Weak';
    if (strength == 2) return 'Fair';
    if (strength == 3) return 'Good';
    return 'Strong';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            final filled = i < strength;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: filled ? _color : c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              'Password strength: $_label',
              style: tt.labelSmall?.copyWith(color: _color),
            ),
            const Spacer(),
            Text(
              'Use letters, numbers & symbols',
              style: tt.labelSmall?.copyWith(color: c.onSurfaceTertiary),
            ),
          ],
        ),
      ],
    );
  }
}
