import 'package:flutter/material.dart';
import 'package:planova_mobile/screens/login_screen.dart';
import 'package:planova_mobile/screens/qr_scanner_screen.dart';
import 'package:planova_mobile/screens/floor_selection_screen.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/services/recent_building_service.dart';

class GuestHomeScreen extends StatefulWidget {
  final String userId;

  const GuestHomeScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  final RecentBuildingService _recentService = RecentBuildingService();
  final BuildingService _buildingService = BuildingService();

  List<RecentBuildingEntry> _recentBuildings = [];
  bool _loadingRecent = true;

  // Use the anonymous Firebase Auth uid passed from LoginScreen

  @override
  void initState() {
    super.initState();
    _loadRecentBuildings();
  }

  Future<void> _loadRecentBuildings() async {
    final entries = await _recentService.getRecentBuildings(widget.userId);
    if (mounted) {
      setState(() {
        _recentBuildings = entries;
        _loadingRecent = false;
      });
    }
  }

  /// Tap on a recent building — re-fetch from Firebase and open directly.
  Future<void> _openRecentBuilding(RecentBuildingEntry entry) async {
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final building = await _buildingService.getBuilding(entry.buildingId);

      if (!mounted) return;
      Navigator.pop(context); // dismiss loader

      if (building == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Building no longer available.'),
            backgroundColor: Colors.red,
          ),
        );
        // Remove stale entry
        await _recentService.removeRecentBuilding(
          widget.userId,
          entry.buildingId,
        );
        _loadRecentBuildings();
        return;
      }

      // Grant/refresh access and save as most-recent
      await _buildingService.grantAccess(building.id, widget.userId);
      await _recentService.saveRecentBuilding(widget.userId, building);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              FloorSelectionScreen(building: building, userId: widget.userId),
        ),
      ).then((_) => _loadRecentBuildings());
    } catch (e) {
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to open building: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeRecentBuilding(RecentBuildingEntry entry) async {
    await _recentService.removeRecentBuilding(widget.userId, entry.buildingId);
    _loadRecentBuildings();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'PLANOVA',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Login'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRecentBuildings,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome header ───────────────────────────────────────────
              const Text(
                'Welcome, Guest!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'You can scan QR codes to navigate buildings.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),

              const SizedBox(height: 32),

              // ── Recent Buildings ─────────────────────────────────────────
              if (!_loadingRecent && _recentBuildings.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Buildings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _recentService.clearRecentBuildings(
                          widget.userId,
                        );
                        _loadRecentBuildings();
                      },
                      child: const Text(
                        'Clear all',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentBuildings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final entry = _recentBuildings[index];
                    return _RecentBuildingCard(
                      entry: entry,
                      timeAgo: _timeAgo(entry.accessedAt),
                      onTap: () => _openRecentBuilding(entry),
                      onDismiss: () => _removeRecentBuilding(entry),
                    );
                  },
                ),
                const SizedBox(height: 28),
              ],

              // ── Scan QR card ─────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          color: Colors.green,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Find a Room',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Scan a building\'s QR code to access\nfloor maps and navigate to any room',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        QRScannerScreen(userId: widget.userId),
                                  ),
                                ).then((_) => _loadRecentBuildings()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Scan QR Code',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Admin prompt ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Are you a building admin?',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Login or create an account to upload floorplans, map rooms and generate QR codes.',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: const Text('Login / Sign Up'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── How to Navigate ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'How to Navigate',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _step('1', 'Find the QR code at the building entrance'),
                    _step(
                      '2',
                      'Tap "Scan QR Code" and point your camera at it',
                    ),
                    _step(
                      '3',
                      'Browse the floor map and select your destination',
                    ),
                    _step('4', 'Follow the route to your room', isLast: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(String number, String text, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent Building Card ───────────────────────────────────────────────────────

class _RecentBuildingCard extends StatelessWidget {
  final RecentBuildingEntry entry;
  final String timeAgo;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _RecentBuildingCard({
    required this.entry,
    required this.timeAgo,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(entry.buildingId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 26),
      ),
      onDismissed: (_) => onDismiss(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.business,
                  color: Colors.green,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.buildingName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.address,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _pill(
                          Icons.layers,
                          '${entry.totalFloors} floor${entry.totalFloors == 1 ? '' : 's'}',
                        ),
                        const SizedBox(width: 8),
                        _pill(
                          Icons.meeting_room,
                          '${entry.totalRooms} room${entry.totalRooms == 1 ? '' : 's'}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Time + chevron
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeAgo,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 11, color: Colors.grey),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
