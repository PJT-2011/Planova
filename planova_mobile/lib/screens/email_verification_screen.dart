import 'dart:async';
import 'package:flutter/material.dart';
import 'package:planova_mobile/services/auth_service.dart';
import 'package:planova_mobile/screens/home_screen.dart';
import 'package:planova_mobile/screens/login_screen.dart';
import 'package:planova_mobile/main.dart';
import 'package:planova_mobile/theme/app_theme.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({Key? key, required this.email})
    : super(key: key);

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  Timer? _verifyTimer;
  Timer? _countdownTimer;
  bool _isResending = false;
  bool _canResend = false;
  int _countdown = 60;

  // Pulse animation for the email icon
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _startVerificationCheck();
    _startCountdown();
  }

  @override
  void dispose() {
    _verifyTimer?.cancel();
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startVerificationCheck() {
    _verifyTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final verified = await _authService.isEmailVerified();
      if (verified && mounted) {
        _verifyTimer?.cancel();
        await PlanovaApp.of(context)?.loadTheme();
        Navigator.pushReplacement(
          context,
          PlanovaPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    });
  }

  void _startCountdown() {
    setState(() {
      _canResend = false;
      _countdown = 60;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _canResend = true;
          t.cancel();
        }
      });
    });
  }

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      await _authService.sendEmailVerification();
      if (mounted) {
        _showSnack('Verification email resent!', isError: false);
        _startCountdown();
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _checkManually() async {
    final verified = await _authService.isEmailVerified();
    if (verified && mounted) {
      _verifyTimer?.cancel();
      await PlanovaApp.of(context)?.loadTheme();
      Navigator.pushReplacement(
        context,
        PlanovaPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (mounted) {
      _showSnack(
        'Not verified yet — check your inbox.',
        isError: false,
        color: const Color(0xFFF59E0B),
      );
    }
  }

  Future<void> _cancelAndSignOut() async {
    _verifyTimer?.cancel();
    await _authService.signOut();
    if (mounted)
      Navigator.pushReplacement(
        context,
        PlanovaPageRoute(builder: (_) => const LoginScreen()),
      );
  }

  void _showSnack(String msg, {bool isError = true, Color? color}) {
    final c = AppTheme.colors(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? (isError ? c.error : c.success),
      ),
    );
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
            // ── Gradient header ─────────────────────────────────────────────
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
                      // Cancel button
                      Align(
                        alignment: Alignment.topRight,
                        child: GestureDetector(
                          onTap: _cancelAndSignOut,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppRadius.full,
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: tt.labelMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Pulsing icon
                      ScaleTransition(
                        scale: _pulseAnim,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.30),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_outlined,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Verify Your\nEmail',
                        style: tt.displayMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This page updates automatically when verified',
                        style: tt.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Card body ───────────────────────────────────────────────────
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Check your inbox',
                      style: tt.headlineMedium?.copyWith(
                        color: c.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'We sent a verification link to:',
                      style: tt.bodyMedium?.copyWith(
                        color: c.onSurfaceSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Email pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: c.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: c.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            color: c.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.email,
                              style: tt.titleSmall?.copyWith(
                                color: c.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Click the link in the email to verify your account.',
                      style: tt.bodyMedium?.copyWith(
                        color: c.onSurfaceSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Spam note
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.30),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFF59E0B),
                            size: 16,
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
                    const SizedBox(height: 28),

                    // "I've verified" button
                    GestureDetector(
                      onTap: _checkManually,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: heroGradient(),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: AppShadows.primaryGlow(c.primary),
                        ),
                        child: Center(
                          child: Text(
                            "I've Verified My Email",
                            style: tt.labelLarge?.copyWith(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Resend button
                    GestureDetector(
                      onTap: (_canResend && !_isResending)
                          ? _resendEmail
                          : null,
                      child: AnimatedOpacity(
                        opacity: (_canResend && !_isResending) ? 1.0 : 0.5,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: c.border, width: 1.5),
                          ),
                          child: Center(
                            child: _isResending
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: c.primary,
                                    ),
                                  )
                                : Text(
                                    _canResend
                                        ? 'Resend Email'
                                        : 'Resend in ${_countdown}s',
                                    style: tt.labelLarge?.copyWith(
                                      color: _canResend
                                          ? c.primary
                                          : c.onSurfaceTertiary,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
