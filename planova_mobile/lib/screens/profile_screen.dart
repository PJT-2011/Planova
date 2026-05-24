import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:planova_mobile/services/auth_service.dart';
import 'package:planova_mobile/screens/login_screen.dart';
import 'package:planova_mobile/screens/settings_screen.dart';
import 'package:planova_mobile/main.dart';
import 'package:planova_mobile/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _picker = ImagePicker();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  bool _isSavingName = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user != null) {
      final data = await _authService.getUserData(user.uid);
      if (mounted) {
        setState(() {
          _userData =
              data ??
              {
                'name': user.displayName ?? 'User',
                'email': user.email ?? '',
                'photoUrl': user.photoURL,
                'role': 'admin',
              };
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Edit name ─────────────────────────────────────────────────────────────

  Future<void> _editName() async {
    if (!mounted) return;
    final controller = TextEditingController(text: _userData?['name'] ?? '');
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final newName = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2942) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: isDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.10))
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Name',
                style: tt.headlineSmall?.copyWith(
                  color: c.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context, controller.text.trim()),
                child: Container(
                  height: 54,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: heroGradient(),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: AppShadows.primaryGlow(c.primary),
                  ),
                  child: Center(
                    child: Text(
                      'Save',
                      style: tt.labelLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: c.border, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: tt.labelLarge?.copyWith(
                        color: c.onSurfaceSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (newName != null &&
        newName.isNotEmpty &&
        newName != _userData?['name']) {
      setState(() => _isSavingName = true);
      try {
        await _authService.updateName(_authService.currentUser!.uid, newName);
        await _loadUserData();
        if (mounted) _showSnack('Name updated!', isError: false);
      } catch (e) {
        if (mounted) _showSnack('Error: $e');
      } finally {
        if (mounted) setState(() => _isSavingName = false);
      }
    }
  }

  // ── Change photo — pick → crop → upload ───────────────────────────────────

  Future<void> _changePhoto() async {
    if (!mounted) return;
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Source picker sheet
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2942) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Update Profile Photo',
              style: tt.headlineSmall?.copyWith(
                color: c.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a source, then crop your photo',
              style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
            ),
            const SizedBox(height: 20),

            // Gallery option
            _SourceTile(
              icon: Icons.photo_library_rounded,
              iconBg: const Color(0xFF1450A8),
              title: 'Choose from Gallery',
              subtitle: 'Pick an existing photo',
              c: c,
              tt: tt,
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            Divider(height: 1, color: c.divider),

            // Camera option
            _SourceTile(
              icon: Icons.camera_alt_rounded,
              iconBg: const Color(0xFF0D8050),
              title: 'Take a Photo',
              subtitle: 'Use your camera',
              c: c,
              tt: tt,
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),

            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 50,
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: c.border, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: tt.labelLarge?.copyWith(color: c.onSurfaceSecondary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    // 2. Pick image
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 90,
    );
    if (picked == null) return;

    // 3. Crop image — square crop enforced for avatars
    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo',
          toolbarColor: const Color(0xFF1450A8),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF3B82F6),
          statusBarColor: const Color(0xFF0D3366),
          backgroundColor: isDark ? const Color(0xFF0A1628) : Colors.white,
          dimmedLayerColor: isDark ? Colors.black87 : Colors.black54,
          cropFrameColor: const Color(0xFF3B82F6),
          cropGridColor: const Color(0xFF3B82F6).withValues(alpha: 0.4),
          cropStyle: CropStyle.circle, // circle preview for avatars
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
          showCropGrid: true,
        ),
        IOSUiSettings(
          title: 'Crop Photo',
          aspectRatioLockEnabled: true,
          cropStyle: CropStyle.circle,
          minimumAspectRatio: 1.0,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (cropped == null) return; // user cancelled crop

    // 4. Upload the cropped file
    setState(() => _isUploadingPhoto = true);
    try {
      await _authService.updatePhoto(
        _authService.currentUser!.uid,
        File(cropped.path),
      );
      await _loadUserData();
      if (mounted) _showSnack('Profile photo updated!', isError: false);
    } catch (e) {
      if (mounted) _showSnack('Error uploading photo: $e');
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    if (!mounted) return;
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2942) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: c.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout_rounded, color: c.error, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign Out?',
              style: tt.headlineMedium?.copyWith(
                color: c.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You will need to sign in again to access admin features.',
              style: tt.bodyMedium?.copyWith(
                color: c.onSurfaceSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.pop(context, true),
              child: Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: c.error,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.primaryGlow(c.error),
                ),
                child: Center(
                  child: Text(
                    'Yes, Sign Out',
                    style: tt.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context, false),
              child: Container(
                height: 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: c.border, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: tt.labelLarge?.copyWith(color: c.onSurfaceSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      PlanovaApp.of(context)?.resetToLight();
      await _authService.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PlanovaPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  void _showSnack(String msg, {bool isError = true}) {
    final c = AppTheme.colors(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? c.error : c.success,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final name = _userData?['name'] ?? 'User';
    final email = _userData?['email'] ?? _authService.currentUser?.email ?? '';
    final photoUrl = _userData?['photoUrl'] as String?;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: c.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Gradient hero header ─────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: heroGradient(),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 52),
                  child: Column(
                    children: [
                      // App bar row
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_ios_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.15,
                              ),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Profile',
                            style: tt.titleLarge?.copyWith(color: Colors.white),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.push(
                              context,
                              PlanovaPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            ),
                            icon: const Icon(
                              Icons.settings_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.15,
                              ),
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Avatar with camera badge
                      Stack(
                        children: [
                          // Glow ring
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.5),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.20),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: _isUploadingPhoto
                                ? Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    ),
                                  )
                                : CircleAvatar(
                                    radius: 48,
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                    backgroundImage: photoUrl != null
                                        ? NetworkImage(photoUrl)
                                        : null,
                                    child: photoUrl == null
                                        ? Text(
                                            initials,
                                            style: tt.displaySmall?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          )
                                        : null,
                                  ),
                          ),

                          // Camera badge — tapping opens the pick+crop flow
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _isUploadingPhoto ? null : _changePhoto,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: c.primary.withValues(alpha: 0.30),
                                    width: 2,
                                  ),
                                  boxShadow: AppShadows.card,
                                ),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 15,
                                  color: c.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Name + edit
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: tt.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _isSavingName
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : GestureDetector(
                                  onTap: _editName,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.edit_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: tt.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          (_userData?['role'] ?? 'admin')
                              .toString()
                              .toUpperCase(),
                          style: tt.labelSmall?.copyWith(
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Cards ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Account info
                  _SectionCard(
                    isDark: isDark,
                    children: [
                      _InfoRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Full Name',
                        value: name,
                        c: c,
                        tt: tt,
                        trailing: GestureDetector(
                          onTap: _editName,
                          child: Icon(
                            Icons.edit_outlined,
                            size: 16,
                            color: c.iconMuted,
                          ),
                        ),
                      ),
                      Divider(height: 1, color: c.divider),
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: email,
                        c: c,
                        tt: tt,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // App settings
                  _SectionCard(
                    isDark: isDark,
                    children: [
                      _NavTile(
                        icon: Icons.settings_outlined,
                        iconColor: c.primary,
                        iconBg: c.primaryContainer,
                        label: 'Settings',
                        subtitle: 'Dark mode & preferences',
                        c: c,
                        tt: tt,
                        onTap: () => Navigator.push(
                          context,
                          PlanovaPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                      Divider(height: 1, color: c.divider),
                      _NavTile(
                        icon: Icons.info_outline_rounded,
                        iconColor: const Color(0xFF8FA3C8),
                        iconBg: const Color(0xFFE5EDF8),
                        label: 'About Planova',
                        subtitle: 'Version 1.0.0',
                        c: c,
                        tt: tt,
                        onTap: () => showAboutDialog(
                          context: context,
                          applicationName: 'Planova',
                          applicationVersion: '1.0.0',
                          applicationIcon: Icon(
                            Icons.map,
                            color: c.primary,
                            size: 40,
                          ),
                          children: const [
                            Text('Indoor navigation made easy.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Sign out
                  GestureDetector(
                    onTap: _signOut,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: c.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: c.error.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: c.error, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Sign Out',
                            style: tt.labelLarge?.copyWith(color: c.error),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _SectionCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isDark
          ? BoxDecoration(
              color: const Color(0xFF1C2942),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            )
          : lightCardDecoration(),
      clipBehavior: Clip.hardEdge,
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final AppColors c;
  final TextTheme tt;
  final Widget? trailing;
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.c,
    required this.tt,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(icon, color: c.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: tt.labelSmall?.copyWith(color: c.onSurfaceTertiary),
                ),
                const SizedBox(height: 2),
                Text(value, style: tt.titleSmall?.copyWith(color: c.onSurface)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String label, subtitle;
  final AppColors c;
  final TextTheme tt;
  final VoidCallback onTap;
  const _NavTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.c,
    required this.tt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.titleSmall?.copyWith(color: c.onSurface),
                  ),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.iconMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Source picker tile ────────────────────────────────────────────────────────

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title, subtitle;
  final AppColors c;
  final TextTheme tt;
  final VoidCallback onTap;
  const _SourceTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.c,
    required this.tt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleSmall?.copyWith(color: c.onSurface),
                  ),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.iconMuted, size: 20),
          ],
        ),
      ),
    );
  }
}
