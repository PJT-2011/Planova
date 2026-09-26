import 'package:flutter/material.dart';
import 'package:planova_mobile/services/auth_service.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/services/recent_building_service.dart';
import 'package:planova_mobile/screens/building_management_screen.dart';
import 'package:planova_mobile/screens/floor_selection_screen.dart';
import 'package:planova_mobile/screens/qr_scanner_screen.dart';
import 'package:planova_mobile/screens/profile_screen.dart';
import 'package:planova_mobile/theme/app_theme.dart';
import 'package:planova_mobile/widgets/skeletons.dart';
import 'package:planova_mobile/main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _recentService = RecentBuildingService();
  final _buildingService = BuildingService();

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
    if (_userId.isEmpty) return;
    final entries = await _recentService.getRecentBuildings(_userId);
    if (mounted) {
      setState(() {
        _recentBuildings = entries;
        _loadingRecent = false;
      });
    }
  }

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
      Navigator.pop(context);
      if (building == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Building no longer available.')),
        );
        await _recentService.removeRecentBuilding(_userId, entry.buildingId);
        _loadRecentBuildings();
        return;
      }
      await _recentService.saveRecentBuilding(_userId, building);
      if (!mounted) return;

      // Re-check current approval status rather than assuming access — a
      // previously-pending request may since have been approved or
      // rejected by the admin. Buildings this user owns/manages have no
      // access doc at all, so a null status is treated as approved.
      final status =
          await _buildingService.getAccessStatus(building.id, _userId) ??
          'approved';
      if (status == 'pending') {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Still waiting for admin approval for ${building.buildingName}.',
            ),
          ),
        );
        return;
      }
      if (status == 'rejected') {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Your access to ${building.buildingName} was rejected by the admin.',
            ),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        PlanovaPageRoute(
          builder: (_) =>
              FloorSelectionScreen(building: building, userId: _userId),
        ),
      ).then((_) => _loadRecentBuildings());
    } catch (e) {
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(SnackBar(content: Text('Failed to open: $e')));
    }
  }

  Future<void> _removeRecentBuilding(RecentBuildingEntry entry) async {
    await _recentService.removeRecentBuilding(_userId, entry.buildingId);
    _loadRecentBuildings();
  }

  String get _userId => _authService.currentUser?.uid ?? '';
  String get _firstName {
    final name = _userData?['name'] ?? 'User';
    return name.toString().split(' ').first;
  }

  String get _initials {
    final name = _userData?['name'] ?? 'U';
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays == 1) return 'Yesterday';
    return '${d.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: c.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        color: c.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Gradient header (NO overlap tricks)
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
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Brand row
                              Row(
                                children: [
                                  const Icon(
                                    Icons.map,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'PLANOVA',
                                    style: tt.labelMedium?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Hello, Welcome ',
                                style: tt.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _firstName,
                                style: tt.displaySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if ((_userData?['email'] ?? '')
                                  .toString()
                                  .isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _userData?['email'] ?? '',
                                  style: tt.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.55),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Avatar
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            PlanovaPageRoute(
                              builder: (_) => const ProfileScreen(),
                            ),
                          ).then((_) => _loadUserData()),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                                width: 2.5,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.2,
                              ),
                              backgroundImage:
                                  (_userData?['photoUrl'] as String?) != null
                                  ? NetworkImage(
                                      _userData!['photoUrl'] as String,
                                    )
                                  : null,
                              child: (_userData?['photoUrl'] as String?) == null
                                  ? Text(
                                      _initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Action cards — normal flow, 16px below header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _QuickActionsRow(
                  c: c,
                  tt: tt,
                  isDark: isDark,
                  onManage: () => Navigator.push(
                    context,
                    PlanovaPageRoute(
                      builder: (_) => BuildingManagementScreen(userId: _userId),
                    ),
                  ),
                  onScan: () => Navigator.push(
                    context,
                    PlanovaModalRoute(
                      builder: (_) => QRScannerScreen(userId: _userId),
                    ),
                  ).then((_) => _loadRecentBuildings()),
                ),
              ),

              // 3. Rest of content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_loadingRecent) ...[
                      RecentBuildingsSkeleton(),
                      const SizedBox(height: 20),
                    ] else if (!_loadingRecent &&
                        _recentBuildings.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Buildings',
                            style: tt.titleLarge?.copyWith(
                              color: c.onBackground,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await _recentService.clearRecentBuildings(
                                _userId,
                              );
                              _loadRecentBuildings();
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                            child: Text(
                              'Clear all',
                              style: tt.labelMedium?.copyWith(
                                color: c.onSurfaceTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(_recentBuildings.length, (i) {
                        final entry = _recentBuildings[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RecentBuildingCard(
                            entry: entry,
                            timeAgo: _timeAgo(entry.accessedAt),
                            onTap: () => _openRecentBuilding(entry),
                            onDismiss: () => _removeRecentBuilding(entry),
                            isDark: isDark,
                            c: c,
                            tt: tt,
                          ),
                        );
                      }),
                      const SizedBox(height: 20),
                    ],
                    _HowItWorksCard(c: c, tt: tt, isDark: isDark),
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

// Quick Actions

class _QuickActionsRow extends StatelessWidget {
  final AppColors c;
  final TextTheme tt;
  final bool isDark;
  final VoidCallback onManage;
  final VoidCallback onScan;

  const _QuickActionsRow({
    required this.c,
    required this.tt,
    required this.isDark,
    required this.onManage,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.business_rounded,
            label: 'Manage\nBuildings',
            description: 'Floors, rooms & QR codes',
            buttonLabel: 'Open',
            onTap: onManage,
            gradientColors: const [Color(0xFF1450A8), Color(0xFF3B82F6)],
            isDark: isDark,
            c: c,
            tt: tt,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionCard(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Find a\nRoom',
            description: 'Scan building QR code',
            buttonLabel: 'Scan',
            onTap: onScan,
            gradientColors: const [Color(0xFF0D8050), Color(0xFF22C55E)],
            isDark: isDark,
            c: c,
            tt: tt,
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label, description, buttonLabel;
  final VoidCallback onTap;
  final List<Color> gradientColors;
  final bool isDark;
  final AppColors c;
  final TextTheme tt;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.buttonLabel,
    required this.onTap,
    required this.gradientColors,
    required this.isDark,
    required this.c,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    // Dark card uses a lighter shade so it pops off the dark scaffold
    final cardDecoration = isDark
        ? BoxDecoration(
            color: const Color(0xFF1C2942), // noticeably lighter than #080E1A
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.10),
              width: 1,
            ),
          )
        : lightCardDecoration();

    return Container(
      decoration: cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.last.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: tt.titleMedium?.copyWith(
              color: c.onSurface,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: onTap,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Center(
                child: Text(
                  buttonLabel,
                  style: tt.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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

// Recent Building Card

class _RecentBuildingCard extends StatelessWidget {
  final RecentBuildingEntry entry;
  final String timeAgo;
  final VoidCallback onTap, onDismiss;
  final bool isDark;
  final AppColors c;
  final TextTheme tt;

  const _RecentBuildingCard({
    required this.entry,
    required this.timeAgo,
    required this.onTap,
    required this.onDismiss,
    required this.isDark,
    required this.c,
    required this.tt,
  });

  BoxDecoration _cardDeco() => isDark
      ? BoxDecoration(
          color: const Color(0xFF162039),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        )
      : lightCardDecoration();

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(entry.buildingId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: c.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: c.error.withValues(alpha: 0.3)),
        ),
        child: Icon(Icons.delete_outline_rounded, color: c.error),
      ),
      onDismissed: (_) => onDismiss(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDeco(),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1450A8), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.buildingName,
                      style: tt.titleSmall?.copyWith(
                        color: c.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.address,
                      style: tt.bodySmall?.copyWith(
                        color: c.onSurfaceSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        _Chip(
                          icon: Icons.layers_rounded,
                          label:
                              '${entry.totalFloors} floor${entry.totalFloors == 1 ? '' : 's'}',
                          c: c,
                          tt: tt,
                        ),
                        const SizedBox(width: 6),
                        _Chip(
                          icon: Icons.meeting_room_rounded,
                          label:
                              '${entry.totalRooms} room${entry.totalRooms == 1 ? '' : 's'}',
                          c: c,
                          tt: tt,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeAgo,
                    style: tt.labelSmall?.copyWith(color: c.onSurfaceTertiary),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: c.iconMuted,
                    size: 18,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppColors c;
  final TextTheme tt;
  const _Chip({
    required this.icon,
    required this.label,
    required this.c,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.chipFill,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: c.chipText),
          const SizedBox(width: 3),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: c.chipText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// How It Works

class _HowItWorksCard extends StatelessWidget {
  final AppColors c;
  final TextTheme tt;
  final bool isDark;
  const _HowItWorksCard({
    required this.c,
    required this.tt,
    required this.isDark,
  });

  BoxDecoration _deco() => isDark
      ? BoxDecoration(
          color: const Color(0xFF111D30),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        )
      : lightCardDecoration();

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Admin creates a building and uploads floorplans for each floor',
      'Admin maps rooms by tapping on the floorplan',
      'Admin generates and prints one QR code for the entrance',
      'Visitors scan the QR to access all floors and navigate to any room',
    ];

    return Container(
      decoration: _deco(),
      padding: const EdgeInsets.all(20),
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
                'How It Works',
                style: tt.titleSmall?.copyWith(
                  color: c.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(steps.length, (i) {
            final isLast = i == steps.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: heroGradient(),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: tt.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 1.5,
                          height: 18,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          color: c.borderSubtle,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        steps[i],
                        style: tt.bodyMedium?.copyWith(
                          color: c.onSurfaceSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
