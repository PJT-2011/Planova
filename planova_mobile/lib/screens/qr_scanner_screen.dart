import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/access_request_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/services/access_control_service.dart';
import 'package:planova_mobile/services/recent_building_service.dart';
import 'package:planova_mobile/services/auth_service.dart';
import 'package:planova_mobile/screens/floor_selection_screen.dart';
import 'package:planova_mobile/theme/app_theme.dart';
import 'package:planova_mobile/main.dart';

class QRScannerScreen extends StatefulWidget {
  final String userId;
  const QRScannerScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final BuildingService _buildingService = BuildingService();
  final AccessControlService _accessService = AccessControlService();
  final RecentBuildingService _recentService = RecentBuildingService();
  final AuthService _authService = AuthService();
  final MobileScannerController _controller = MobileScannerController();

  bool _isProcessing = false;
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // QR logic

  Future<void> _processQRCode(String? qrCode) async {
    if (qrCode == null || qrCode.isEmpty) return;
    if (_isProcessing || _hasScanned) return;
    setState(() {
      _isProcessing = true;
      _hasScanned = true;
    });
    await _controller.stop();
    try {
      final building = await _buildingService.getBuildingByQRCode(qrCode);
      if (building == null) {
        _showErrorSheet(
          'Building Not Found',
          'This QR code is not registered in Planova. Please contact the building administrator.',
        );
        return;
      }

      // Scanning no longer grants access on the spot — it files (or
      // re-reads) an approval request in the same accessRequests
      // collection/admin queue as manual per-floor requests, so it shows
      // up in the admin's Pending tab like anything else does. The admin
      // has to sign off before this user can actually open the building.
      final userData = await _authService.getUserData(widget.userId);
      final request = await _accessService.submitBuildingAccessRequest(
        buildingId: building.id,
        buildingName: building.buildingName,
        userId: widget.userId,
        userName: userData?['name'] ?? 'User',
      );
      await _recentService.saveRecentBuilding(widget.userId, building);
      HapticFeedback.heavyImpact();

      switch (request.status) {
        case AccessRequestStatus.approved:
          if (request.isActiveGrant) {
            _showSuccessSheet(building);
          } else {
            // Approved once, but the grant has since lapsed or was
            // revoked (status stays 'approved' with an elapsed expiresAt
            // until the next lazy-expiry sweep flips it) — treat the same
            // as an explicit rejection for the scanning user.
            _showRejectedSheet(building);
          }
          break;
        case AccessRequestStatus.rejected:
        case AccessRequestStatus.expired:
          // 'expired' here means an admin explicitly revoked a grant
          // (see AccessControlService.revokeAccess) rather than a
          // duration simply running out before ever being checked again.
          _showRejectedSheet(building);
          break;
        case AccessRequestStatus.pending:
          _showPendingSheet(building);
          break;
      }
    } catch (e) {
      _showErrorSheet('Error', 'Failed to access building. Please try again.');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  // Success bottom sheet — already-approved user

  void _showSuccessSheet(BuildingModel building) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2942) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF22C55E),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'Building Found!',
                  style: tt.headlineSmall?.copyWith(
                    color: c.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Building name + address
            Text(
              building.buildingName,
              style: tt.titleLarge?.copyWith(
                color: c.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.location_on_rounded,
                  size: 14,
                  color: c.onSurfaceTertiary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    building.address,
                    style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats card — fully themed
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF243450) // elevated dark card
                    : const Color(0xFFEFF6FF), // light blue tint
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFF1A6ADB).withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatCol(
                    icon: Icons.layers_rounded,
                    value: '${building.totalFloors}',
                    label: 'Floor${building.totalFloors == 1 ? '' : 's'}',
                    c: c,
                    tt: tt,
                  ),
                  Container(
                    width: 1,
                    height: 44,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : const Color(0xFF1A6ADB).withValues(alpha: 0.20),
                  ),
                  _StatCol(
                    icon: Icons.meeting_room_rounded,
                    value: '${building.totalRooms}',
                    label: 'Room${building.totalRooms == 1 ? '' : 's'}',
                    c: c,
                    tt: tt,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Open Building button
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _openBuilding(building);
              },
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
                    'Open Building',
                    style: tt.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel button
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
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
  }

  // Pending bottom sheet — request filed, waiting on the admin

  void _showPendingSheet(BuildingModel building) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2942) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hourglass_top_rounded,
                    color: c.warning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Waiting for Approval',
                    style: tt.headlineSmall?.copyWith(
                      color: c.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              building.buildingName,
              style: tt.titleMedium?.copyWith(
                color: c.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Your request to access this building has been sent to the '
              'admin. You\'ll be notified as soon as it\'s approved.',
              style: tt.bodyMedium?.copyWith(
                color: c.onSurfaceSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
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
                    'Got it',
                    style: tt.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Rejected bottom sheet

  void _showRejectedSheet(BuildingModel building) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2942) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.block_rounded,
                    color: c.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Access Rejected',
                    style: tt.headlineSmall?.copyWith(
                      color: c.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              building.buildingName,
              style: tt.titleMedium?.copyWith(
                color: c.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'The admin denied your request to access this building. '
              'Contact them directly if you think this is a mistake.',
              style: tt.bodyMedium?.copyWith(
                color: c.onSurfaceSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: c.border, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    'Close',
                    style: tt.labelLarge?.copyWith(color: c.onSurfaceSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Error bottom sheet

  void _showErrorSheet(String title, String message) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2942) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.error_rounded, color: c.error, size: 26),
                ),
                const SizedBox(width: 14),
                Text(
                  title,
                  style: tt.headlineSmall?.copyWith(
                    color: c.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: tt.bodyMedium?.copyWith(
                color: c.onSurfaceSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Try Again
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                setState(() => _hasScanned = false);
                _controller.start();
              },
              child: Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: heroGradient(),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    'Try Again',
                    style: tt.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
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
  }

  // Manual entry

  void _showManualEntryDialog() {
    final codeController = TextEditingController();
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;

    showModalBottomSheet(
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
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1C2942)
                : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Theme.of(context).brightness == Brightness.dark
                ? Border.all(color: Colors.white.withValues(alpha: 0.10))
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter QR Code',
                style: tt.headlineSmall?.copyWith(
                  color: c.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Type the code printed below the QR at the entrance',
                style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: codeController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'QR_BUILDING_NAME_12345',
                  prefixIcon: Icon(Icons.qr_code_rounded, color: c.iconMuted),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  final code = codeController.text.trim();
                  Navigator.pop(context);
                  if (code.isNotEmpty) _processQRCode(code);
                },
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
                      'Submit',
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
  }

  void _openBuilding(BuildingModel building) {
    Navigator.pushReplacement(
      context,
      PlanovaPageRoute(
        builder: (_) =>
            FloorSelectionScreen(building: building, userId: widget.userId),
      ),
    );
  }

  // Build

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.55),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan Building QR Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
            onPressed: () => _controller.toggleTorch(),
            tooltip: 'Toggle Flash',
          ),
          IconButton(
            icon: const Icon(
              Icons.flip_camera_ios_rounded,
              color: Colors.white,
            ),
            onPressed: () => _controller.switchCamera(),
            tooltip: 'Flip Camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Live camera feed
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcode = capture.barcodes.firstOrNull;
              if (barcode != null) _processQRCode(barcode.rawValue);
            },
          ),

          // Dark vignette top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Dark vignette bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Instruction text below app bar
          Positioned(
            top: kToolbarHeight + MediaQuery.of(context).padding.top + 12,
            left: 0,
            right: 0,
            child: const Column(
              children: [
                Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 44,
                  color: Colors.white,
                ),
                SizedBox(height: 10),
                Text(
                  'Point camera at QR code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6),
                Text(
                  'The QR code should be at the building entrance',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Scan frame
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                    ),
                    // Corners
                    ..._buildCorners(c.primary),
                  ],
                ),
              ],
            ),
          ),

          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.75),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2942),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: c.primary,
                        strokeWidth: 3,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Loading building...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Enter Code Manually button (bottom)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 24,
            right: 24,
            child: GestureDetector(
              onTap: _showManualEntryDialog,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.30),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.keyboard_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Enter Code Manually',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Animated corner markers for scan frame

  List<Widget> _buildCorners(Color color) {
    const s = 28.0; // corner arm length
    const t = 3.5; // thickness
    const r = 20.0; // frame radius

    Widget corner(AlignmentGeometry alignment, double rotZ) => Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Transform.rotate(
          angle: rotZ,
          child: SizedBox(
            width: s + t,
            height: s + t,
            child: CustomPaint(
              painter: _CornerPainter(color: color, size: s, thickness: t),
            ),
          ),
        ),
      ),
    );

    return [
      corner(Alignment.topLeft, 0),
      corner(Alignment.topRight, 1.5708),
      corner(Alignment.bottomRight, 3.1416),
      corner(Alignment.bottomLeft, 4.7124),
    ];
  }
}

// Stat column

class _StatCol extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final AppColors c;
  final TextTheme tt;
  const _StatCol({
    required this.icon,
    required this.value,
    required this.label,
    required this.c,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: c.primary, size: 22),
        const SizedBox(height: 8),
        Text(
          value,
          style: tt.headlineMedium?.copyWith(
            color: c.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary)),
      ],
    );
  }
}

// Corner marker painter

class _CornerPainter extends CustomPainter {
  final Color color;
  final double size, thickness;
  const _CornerPainter({
    required this.color,
    required this.size,
    required this.thickness,
  });

  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    // Horizontal arm
    canvas.drawLine(
      Offset(0, thickness / 2),
      Offset(size, thickness / 2),
      paint,
    );
    // Vertical arm
    canvas.drawLine(
      Offset(thickness / 2, 0),
      Offset(thickness / 2, size),
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}
