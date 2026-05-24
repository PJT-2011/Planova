import 'package:flutter/material.dart';
import 'package:planova_mobile/services/auth_service.dart';
import 'package:planova_mobile/theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Please enter your email';
    final rx = RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
    if (!rx.hasMatch(value.trim()))
      return 'Please enter a valid email (e.g. name@example.com)';
    return null;
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _authService.sendPasswordResetEmail(_emailController.text.trim());
      if (mounted) setState(() => _emailSent = true);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppTheme.colors(context).error,
          ),
        );
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
                      // Animated icon — lock to email
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Container(
                          key: ValueKey(_emailSent),
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Icon(
                            _emailSent
                                ? Icons.mark_email_read_outlined
                                : Icons.lock_reset_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _emailSent ? 'Check Your\nEmail' : 'Reset\nPassword',
                          key: ValueKey(_emailSent),
                          style: tt.displayMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _emailSent
                            ? 'We sent a reset link to your inbox'
                            : 'Enter your email and we\'ll send a reset link',
                        style: tt.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Card body ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: _emailSent
                    ? _SuccessCard(
                        key: const ValueKey('success'),
                        email: _emailController.text.trim(),
                        isDark: isDark,
                        c: c,
                        tt: tt,
                        onBack: () => Navigator.pop(context),
                        onTryDifferent: () =>
                            setState(() => _emailSent = false),
                      )
                    : _FormCard(
                        key: const ValueKey('form'),
                        emailController: _emailController,
                        formKey: _formKey,
                        isLoading: _isLoading,
                        validateEmail: _validateEmail,
                        onSubmit: _sendResetEmail,
                        isDark: isDark,
                        c: c,
                        tt: tt,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Form card ─────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final TextEditingController emailController;
  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final String? Function(String?) validateEmail;
  final VoidCallback onSubmit;
  final bool isDark;
  final AppColors c;
  final TextTheme tt;

  const _FormCard({
    super.key,
    required this.emailController,
    required this.formKey,
    required this.isLoading,
    required this.validateEmail,
    required this.onSubmit,
    required this.isDark,
    required this.c,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isDark
          ? BoxDecoration(
              color: const Color(0xFF1C2942),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            )
          : lightCardDecoration(radius: AppRadius.xl),
      padding: const EdgeInsets.all(28),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter your email',
              style: tt.headlineMedium?.copyWith(
                color: c.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'We\'ll send a password reset link',
              style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined, color: c.iconMuted),
              ),
              validator: validateEmail,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: isLoading ? null : onSubmit,
              child: AnimatedOpacity(
                opacity: isLoading ? 0.7 : 1.0,
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
                            'Send Reset Link',
                            style: tt.labelLarge?.copyWith(color: Colors.white),
                          ),
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

// ── Success card ──────────────────────────────────────────────────────────────

class _SuccessCard extends StatelessWidget {
  final String email;
  final bool isDark;
  final AppColors c;
  final TextTheme tt;
  final VoidCallback onBack;
  final VoidCallback onTryDifferent;

  const _SuccessCard({
    super.key,
    required this.email,
    required this.isDark,
    required this.c,
    required this.tt,
    required this.onBack,
    required this.onTryDifferent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isDark
          ? BoxDecoration(
              color: const Color(0xFF1C2942),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            )
          : lightCardDecoration(radius: AppRadius.xl),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Green check circle
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF22C55E),
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Email sent!',
            style: tt.headlineMedium?.copyWith(
              color: c.onSurface,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'We sent the reset link to:',
            style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            email,
            style: tt.titleSmall?.copyWith(
              color: c.primary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Spam note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.30),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFF59E0B),
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Can\'t find it? Check your spam or junk folder.',
                    style: tt.bodySmall?.copyWith(
                      color: c.onSurface,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          GestureDetector(
            onTap: onBack,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: heroGradient(),
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadows.primaryGlow(c.primary),
              ),
              child: Center(
                child: Text(
                  'Back to Login',
                  style: tt.labelLarge?.copyWith(color: Colors.white),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onTryDifferent,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: c.border, width: 1.5),
              ),
              child: Center(
                child: Text(
                  'Try a different email',
                  style: tt.labelLarge?.copyWith(color: c.onSurfaceSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
