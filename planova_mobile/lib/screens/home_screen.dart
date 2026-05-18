import 'package:flutter/material.dart';
import 'package:planova_mobile/services/auth_service.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/services/recent_building_service.dart';
import 'package:planova_mobile/screens/login_screen.dart';
import 'package:planova_mobile/screens/building_management_screen.dart';
import 'package:planova_mobile/screens/floor_selection_screen.dart';
import 'package:planova_mobile/screens/qr_scanner_screen.dart';
import 'package:planova_mobile/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final RecentBuildingService _recentService = RecentBuildingService();
  final BuildingService _buildingService = BuildingService();

  Map<String, dynamic>? _userData;
  List<RecentBuildingEntry> _recentBuildings = [];
  bool _isLoading = true;
  bool _loadingRecent = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user != null) {
      final data = await _authService.getUserData(user.uid);
      setState(() {
        _userData = data;
        _isLoading = false;
      });
      _loadRecentBuildings();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRecentBuildings() async {
    final userId = _userId;
    if (userId.isEmpty) return;
    final entries = await _recentService.getRecentBuildings(userId);
    if (mounted) {
      setState(() {
        _recentBuildings = entries;
        _loadingRecent = false;
      });
    }
  }

  /// Tap on a recent building card — re-fetch from Firebase and open directly.
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
        await _recentService.removeRecentBuilding(_userId, entry.buildingId);
        _loadRecentBuildings();
        return;
      }

      // Refresh recents order
      await _recentService.saveRecentBuilding(_userId, building);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              FloorSelectionScreen(building: building, userId: _userId),
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
    await _recentService.removeRecentBuilding(_userId, entry.buildingId);
    _loadRecentBuildings();
  }

  String get _userId => _authService.currentUser?.uid ?? '';

  String get _initials {
    final name = _userData?['name'] ?? 'U';
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PLANOVA',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ).then((_) => _loadUserData()),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Theme.of(context).colorScheme.primary,
                backgroundImage: _userData?['photoUrl'] != null
                    ? NetworkImage(_userData!['photoUrl'])
                    : null,
                child: _userData?['photoUrl'] == null
                    ? Text(
                        _initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome header ───────────────────────────────────────────
              Text(
                'Welcome, ${_userData?['name'] ?? 'User'}!',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _userData?['email'] ?? '',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),

              const SizedBox(height: 32),

              const Text(
                'What would you like to do?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),

              // ── Admin card ───────────────────────────────────────────────
              _ActionCard(
                icon: Icons.business,
                iconColor: Colors.blue,
                iconBg: Colors.blue.shade50,
                title: 'Manage Buildings',
                subtitle:
                    'Create buildings, upload floorplans,\nmap rooms & generate QR codes',
                buttonLabel: 'Open Buildings',
                buttonColor: Colors.blue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BuildingManagementScreen(userId: _userId),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Visitor card ─────────────────────────────────────────────
              _ActionCard(
                icon: Icons.qr_code_scanner,
                iconColor: Colors.green,
                iconBg: Colors.green.shade50,
                title: 'Find a Room',
                subtitle:
                    'Scan a building\'s QR code to access\nfloor maps and navigate to any room',
                buttonLabel: 'Scan QR Code',
                buttonColor: Colors.green,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QRScannerScreen(userId: _userId),
                  ),
                ).then((_) => _loadRecentBuildings()),
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
                        await _recentService.clearRecentBuildings(_userId);
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
                const SizedBox(height: 32),
              ],

              // ── How it works ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
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
                          'How It Works',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _HowItWorksStep(
                      number: '1',
                      text:
                          'Admin creates a building and uploads floorplans for each floor',
                    ),
                    _HowItWorksStep(
                      number: '2',
                      text: 'Admin maps rooms by tapping on the floorplan',
                    ),
                    _HowItWorksStep(
                      number: '3',
                      text:
                          'Admin generates & prints one QR code for the building entrance',
                    ),
                    _HowItWorksStep(
                      number: '4',
                      text:
                          'Visitors scan the QR code to access all floors and navigate to any room',
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
            color: Theme.of(context).cardTheme.color ?? Colors.white,
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
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.business, color: Colors.blue, size: 22),
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

// ── Reused widgets (unchanged) ─────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final Color buttonColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.buttonColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
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
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        buttonLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorksStep extends StatelessWidget {
  final String number;
  final String text;
  final bool isLast;

  const _HowItWorksStep({
    required this.number,
    required this.text,
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
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
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
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
