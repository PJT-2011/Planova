import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/models/floor_access_model.dart';
import 'package:planova_mobile/services/building_service.dart';
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
  final BuildingService _buildingService = BuildingService();

  late BuildingModel _building = widget.building;
  List<FloorModel> _floors = [];
  bool _isLoadingFloors = true;
  bool _isSaving = false;

  // Editable draft — only written to Firestore when the admin taps Save,
  // so browsing the floor list doesn't change access until confirmed.
  late FloorAccessType _draftAccessType = _building.qrFloorAccessType;
  late Set<int> _draftFloorNumbers = _building.qrFloorNumbers.toSet();

  @override
  void initState() {
    super.initState();
    _loadFloors();
  }

  Future<void> _loadFloors() async {
    try {
      final floors = await _buildingService.getFloors(_building.id);
      if (mounted) setState(() {
        _floors = floors;
        _isLoadingFloors = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingFloors = false);
    }
  }

  bool get _hasUnsavedChanges =>
      _draftAccessType != _building.qrFloorAccessType ||
      !_setEquals(_draftFloorNumbers, _building.qrFloorNumbers.toSet());

  bool _setEquals(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);

  Future<void> _saveFloorAccess() async {
    if (_draftAccessType == FloorAccessType.selected &&
        _draftFloorNumbers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Select at least one floor, or choose "All Floors"'),
          backgroundColor: AppTheme.colors(context).error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _buildingService.updateQRFloorAccess(
        buildingId: _building.id,
        accessType: _draftAccessType,
        floorNumbers: _draftFloorNumbers.toList(),
      );
      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() {
          _building = _building.copyWith(
            qrFloorAccessType: _draftAccessType,
            qrFloorNumbers: _draftFloorNumbers.toList(),
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Floor access saved for this QR code'),
            backgroundColor: AppTheme.colors(context).success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppTheme.colors(context).error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _confirmReapplyToExistingVisitors() async {
    final c = AppTheme.colors(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update existing visitors too?'),
        content: const Text(
          'This will overwrite floor access for everyone who has already '
          'scanned this QR code, matching what\'s currently saved above. '
          'Any manual per-user changes made in User Management will be '
          'replaced.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: c.error),
            child: const Text('Update Everyone'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _buildingService.reapplyQrAccessToAllVisitors(_building.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Existing visitors updated'),
            backgroundColor: c.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update visitors: $e'),
            backgroundColor: c.error,
          ),
        );
      }
    }
  }

  String get _accessSummary {
    if (_building.qrFloorAccessType == FloorAccessType.all) return 'All floors';
    if (_building.qrFloorNumbers.isEmpty) return 'No floors';
    final sorted = _building.qrFloorNumbers.toList()..sort();
    return 'Floor${sorted.length == 1 ? '' : 's'} ${sorted.join(", ")}';
  }

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
            // Building name
            Text(
              _building.buildingName,
              style: tt.headlineMedium?.copyWith(
                color: c.onBackground,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              _building.address,
              style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Floor Access card — controls what this QR code actually grants
            Container(
              width: double.infinity,
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
                          Icons.layers_rounded,
                          color: c.primary,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Floor Access',
                          style: tt.titleSmall?.copyWith(
                            color: c.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: c.chipFill,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          _accessSummary,
                          style: tt.labelSmall?.copyWith(color: c.chipText),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: Text(
                      'Choose which floors people get when they scan this code.',
                      style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_isLoadingFloors)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(color: c.primary),
                      ),
                    )
                  else if (_floors.isEmpty)
                    Text(
                      'Add floors to this building to configure QR access.',
                      style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _QrAccessOption(
                            label: 'All Floors',
                            icon: Icons.public_rounded,
                            selected: _draftAccessType == FloorAccessType.all,
                            c: c,
                            tt: tt,
                            onTap: () => setState(
                              () => _draftAccessType = FloorAccessType.all,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QrAccessOption(
                            label: 'Selected Floors',
                            icon: Icons.checklist_rounded,
                            selected:
                                _draftAccessType == FloorAccessType.selected,
                            c: c,
                            tt: tt,
                            onTap: () => setState(
                              () =>
                                  _draftAccessType = FloorAccessType.selected,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_draftAccessType == FloorAccessType.selected) ...[
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: c.surfaceElevated,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: c.border),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          children: _floors.map((floor) {
                            final checked = _draftFloorNumbers.contains(
                              floor.floorNumber,
                            );
                            return CheckboxListTile(
                              dense: true,
                              value: checked,
                              activeColor: c.primary,
                              title: Text(
                                floor.floorName,
                                style: tt.bodyMedium?.copyWith(
                                  color: c.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                'Floor ${floor.floorNumber}',
                                style: tt.bodySmall?.copyWith(
                                  color: c.onSurfaceSecondary,
                                ),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _draftFloorNumbers.add(floor.floorNumber);
                                  } else {
                                    _draftFloorNumbers.remove(
                                      floor.floorNumber,
                                    );
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: (_isSaving || !_hasUnsavedChanges)
                                ? null
                                : _saveFloorAccess,
                            child: AnimatedOpacity(
                              opacity: (_isSaving || !_hasUnsavedChanges)
                                  ? 0.5
                                  : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: heroGradient(),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
                                child: Center(
                                  child: _isSaving
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          'Save Floor Access',
                                          style: tt.labelMedium?.copyWith(
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _confirmReapplyToExistingVisitors,
                      child: Text(
                        'Also update people who already scanned this code',
                        textAlign: TextAlign.center,
                        style: tt.labelSmall?.copyWith(
                          color: c.onSurfaceSecondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // QR code card — ALWAYS white (needed for scanning)
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
                      _building.buildingName,
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

            // Stats card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: infoCardDeco,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatColumn(
                    icon: Icons.layers_rounded,
                    value: '${_building.totalFloors}',
                    label:
                        'Floor${_building.totalFloors == 1 ? '' : 's'}',
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
                    value: '${_building.totalRooms}',
                    label: 'Room${_building.totalRooms == 1 ? '' : 's'}',
                    c: c,
                    tt: tt,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Share button
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

            // Download button
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

            // Instructions
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
                    text: _building.qrFloorAccessType == FloorAccessType.all
                        ? 'They scan this code to access all floors and rooms'
                        : 'They scan this code to access $_accessSummary only',
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

            // QR code value
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

// QR floor-access option chip

class _QrAccessOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final AppColors c;
  final TextTheme tt;
  final VoidCallback onTap;

  const _QrAccessOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.c,
    required this.tt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? c.primaryContainer : c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: selected ? c.primary : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? c.primary : c.iconMuted),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: tt.labelMedium?.copyWith(
                  color: selected ? c.primary : c.onSurfaceSecondary,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Stat column

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

// Instruction row

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
