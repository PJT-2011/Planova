import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/services/recent_building_service.dart';
import 'package:planova_mobile/screens/floor_selection_screen.dart';

class QRScannerScreen extends StatefulWidget {
  final String userId;

  const QRScannerScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final BuildingService _buildingService = BuildingService();
  final RecentBuildingService _recentService = RecentBuildingService();
  final MobileScannerController _controller = MobileScannerController();

  bool _isProcessing = false;
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
        _showErrorDialog(
          'Building Not Found',
          'This QR code is not registered in Planova. Please contact the building administrator.',
        );
        return;
      }

      await _buildingService.grantAccess(building.id, widget.userId);

      // ✅ Save to recent buildings history
      await _recentService.saveRecentBuilding(widget.userId, building);

      _showSuccessDialog(building);
    } catch (e) {
      debugPrint('❌ [QRScanner] Error processing QR code: $e');
      _showErrorDialog('Error', 'Failed to access building. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showSuccessDialog(BuildingModel building) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Building Found!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              building.buildingName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(building.address, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn(
                    Icons.layers,
                    '${building.totalFloors}',
                    'Floor${building.totalFloors == 1 ? '' : 's'}',
                  ),
                  _buildStatColumn(
                    Icons.room,
                    '${building.totalRooms}',
                    'Room${building.totalRooms == 1 ? '' : 's'}',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openBuilding(building);
            },
            child: const Text('Open Building'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red, size: 32),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _hasScanned = false);
              _controller.start();
            },
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _openBuilding(BuildingModel building) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FloorSelectionScreen(building: building, userId: widget.userId),
      ),
    );
  }

  void _showManualEntryDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter QR Code'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'QR Code',
            hintText: 'QR_BUILDING_NAME_12345',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (codeController.text.isNotEmpty) {
                _processQRCode(codeController.text);
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Building QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
            tooltip: 'Toggle Flash',
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () => _controller.switchCamera(),
            tooltip: 'Flip Camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Scanner ──────────────────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcode = capture.barcodes.firstOrNull;
              if (barcode != null) {
                _processQRCode(barcode.rawValue);
              }
            },
          ),

          // ── Scan-frame overlay ───────────────────────────────────
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          // ── Top instructions ─────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.qr_code_scanner, size: 48, color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Point camera at QR code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'The QR code should be at the building entrance',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // ── Processing indicator ─────────────────────────────────
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Loading building...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // ── Manual entry button ──────────────────────────────────
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton.icon(
                onPressed: _showManualEntryDialog,
                icon: const Icon(Icons.keyboard),
                label: const Text('Enter Code Manually'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
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
