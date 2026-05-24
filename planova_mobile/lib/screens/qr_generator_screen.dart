import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'dart:io';
import 'package:planova_mobile/theme/app_theme.dart';

class QRGeneratorScreen extends StatefulWidget {
  final BuildingModel building;
  const QRGeneratorScreen({Key? key, required this.building}) : super(key: key);

  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  final GlobalKey _qrKey = GlobalKey();

  Future<File> _captureQR() async {
    final boundary =
        _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final pngBytes = byteData!.buffer.asUint8List();
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/planova_qr_${widget.building.buildingName.replaceAll(' ', '_')}.png',
    );
    await file.writeAsBytes(pngBytes);
    return file;
  }

  Future<void> _shareQRCode() async {
    try {
      final file = await _captureQR();
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Scan this QR code to access ${widget.building.buildingName} in Planova',
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sharing QR code: $e')));
    }
  }

  Future<void> _downloadQRCode() async {
    try {
      final file = await _captureQR();
      await Gal.putImage(file.path, album: 'Planova');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('QR code saved to Gallery!'),
            backgroundColor: AppTheme.colors(context).success,
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving QR code: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Stats & instructions card decoration — theme-aware
    final infoCardDeco = isDark
        ? BoxDecoration(
            color: const Color(0xFF1C2942),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          )
        : BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: const Color(0xFF1A6ADB).withValues(alpha: 0.15),
            ),
          );

    final codeCardDeco = isDark
        ? BoxDecoration(
            color: const Color(0xFF162039),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          )
        : BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: const Color(0xFFCDD8EE)),
          );

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(
          'Building QR Code',
          style: tt.titleLarge?.copyWith(color: c.onBackground),
        ),
        backgroundColor: c.background,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: c.onBackground,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Building name ─────────────────────────────────────────────
            Text(
              widget.building.buildingName,
              style: tt.headlineMedium?.copyWith(
                color: c.onBackground,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              widget.building.address,
              style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // ── QR code card — ALWAYS white (needed for scanning) ─────────
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white, // intentionally always white
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.4 : 0.10,
                      ),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: widget.building.qrCode,
                      version: QrVersions.auto,
                      size: 240,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF0C1A30),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF0C1A30),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Scan to Access',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0C1A30),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.building.buildingName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4A6080),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Stats card ────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: infoCardDeco,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatColumn(
                    icon: Icons.layers_rounded,
                    value: '${widget.building.totalFloors}',
                    label:
                        'Floor${widget.building.totalFloors == 1 ? '' : 's'}',
                    c: c,
                    tt: tt,
                  ),
                  Container(
                    width: 1,
                    height: 44,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFF1A6ADB).withValues(alpha: 0.20),
                  ),
                  _StatColumn(
                    icon: Icons.meeting_room_rounded,
                    value: '${widget.building.totalRooms}',
                    label: 'Room${widget.building.totalRooms == 1 ? '' : 's'}',
                    c: c,
                    tt: tt,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Share button ──────────────────────────────────────────────
            GestureDetector(
              onTap: _shareQRCode,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: heroGradient(),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.primaryGlow(c.primary),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.share_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Share QR Code',
                      style: tt.labelLarge?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Download button ───────────────────────────────────────────
            GestureDetector(
              onTap: _downloadQRCode,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: c.primary, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.download_rounded, color: c.primary, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Download QR Code',
                      style: tt.labelLarge?.copyWith(color: c.primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // ── Instructions ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(18),
              decoration: isDark ? darkCardDecoration() : lightCardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: c.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: c.primary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Instructions',
                        style: tt.titleSmall?.copyWith(
                          color: c.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Instruction(
                    number: '1',
                    c: c,
                    tt: tt,
                    text: 'Print or display this QR code at building entrance',
                  ),
                  _Instruction(
                    number: '2',
                    c: c,
                    tt: tt,
                    text: 'Visitors open Planova app and tap "Scan QR Code"',
                  ),
                  _Instruction(
                    number: '3',
                    c: c,
                    tt: tt,
                    text: 'They scan this code to access all floors and rooms',
                  ),
                  _Instruction(
                    number: '4',
                    c: c,
                    tt: tt,
                    text: 'Visitors can search rooms and navigate instantly',
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── QR code value ─────────────────────────────────────────────
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.building.qrCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text('QR code value copied!'),
                      ],
                    ),
                    backgroundColor: AppTheme.colors(context).success,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: codeCardDeco,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'QR Code Value',
                          style: tt.labelSmall?.copyWith(
                            color: c.onSurfaceTertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: c.onSurfaceTertiary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.building.qrCode,
                      style: tt.bodySmall?.copyWith(
                        color: c.onSurfaceSecondary,
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
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

// ── Stat column ───────────────────────────────────────────────────────────────

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final String value, label;
  final AppColors c;
  final TextTheme tt;
  const _StatColumn({
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
        Icon(icon, color: c.primary, size: 24),
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

// ── Instruction row ───────────────────────────────────────────────────────────

class _Instruction extends StatelessWidget {
  final String number, text;
  final bool isLast;
  final AppColors c;
  final TextTheme tt;
  const _Instruction({
    required this.number,
    required this.text,
    required this.c,
    required this.tt,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: heroGradient(),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Center(
              child: Text(
                number,
                style: tt.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: tt.bodyMedium?.copyWith(
                  color: c.onSurface,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
