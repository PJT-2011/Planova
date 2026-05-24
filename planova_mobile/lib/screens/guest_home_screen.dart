import 'package:flutter/material.dart';
import 'package:planova_mobile/screens/login_screen.dart';
import 'package:planova_mobile/screens/qr_scanner_screen.dart';
import 'package:planova_mobile/screens/floor_selection_screen.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/services/recent_building_service.dart';
import 'package:planova_mobile/theme/app_theme.dart';
import 'package:planova_mobile/widgets/skeletons.dart';
import 'package:planova_mobile/main.dart';

class GuestHomeScreen extends StatefulWidget {
  final String userId;
  const GuestHomeScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  final _recentService = RecentBuildingService();
  final _buildingService = BuildingService();

  List<RecentBuildingEntry> _recentBuildings = [];
  bool _loadingRecent = true;

  @override
  void initState() {
    super.initState();
    _loadRecentBuildings();
  }

  Future<void> _loadRecentBuildings() async {
    final entries = await _recentService.getRecentBuildings(widget.userId);
    if (mounted)
      setState(() {
        _recentBuildings = entries;
        _loadingRecent = false;
      });
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
        await _recentService.removeRecentBuilding(
          widget.userId,
          entry.buildingId,
        );
        _loadRecentBuildings();
        return;
      }
      await _buildingService.grantAccess(building.id, widget.userId);
      await _recentService.saveRecentBuilding(widget.userId, building);
      Navigator.push(
        context,
        PlanovaPageRoute(
          builder: (_) =>
              FloorSelectionScreen(building: building, userId: widget.userId),
        ),
      ).then((_) => _loadRecentBuildings());
    } catch (e) {
      if (mounted) Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to open building: $e')),
      );
    }
  }

  Future<void> _removeRecentBuilding(RecentBuildingEntry entry) async {
    await _recentService.removeRecentBuilding(widget.userId, entry.buildingId);
    _loadRecentBuildings();
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

    return Scaffold(
      backgroundColor: c.background,
      body: RefreshIndicator(
        onRefresh: _loadRecentBuildings,
        color: c.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. Gradient header ───────────────────────────────────────
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top bar: brand + login button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
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
                                    color: Colors.white.withValues(alpha: 0.85),
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () => Navigator.pushReplacement(
                                context,
                                PlanovaPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              ),
                              icon: const Icon(
                                Icons.login_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                'Login',
                                style: tt.labelMedium?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.15,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.full,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Hello, Welcome 👋',
                          style: tt.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Guest',
                          style: tt.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Scan a building QR to access floorplans & navigate',
                          style: tt.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.60),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── 2. Scan card ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: _ScanCard(
                  userId: widget.userId,
                  isDark: isDark,
                  c: c,
                  tt: tt,
                  onScanned: _loadRecentBuildings,
                ),
              ),

              // ── 3. Rest of content ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recent buildings
                    if (_loadingRecent) ...[
                      RecentBuildingsSkeleton(),
                      const SizedBox(height: 16),
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
                                widget.userId,
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
                          child: _RecentCard(
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
                      const SizedBox(height: 16),
                    ],

                    // Admin prompt
                    _AdminPromptCard(
                      isDark: isDark,
                      c: c,
                      tt: tt,
                      onLogin: () => Navigator.pushReplacement(
                        context,
                        PlanovaPageRoute(builder: (_) => const LoginScreen()),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // How to navigate
                    _HowToCard(isDark: isDark, c: c, tt: tt),
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

// ── Card decoration helpers (consistent dark elevation) ───────────────────────

BoxDecoration _darkCard({double radius = 20}) => BoxDecoration(
  color: const Color(0xFF1C2942),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: Colors.white.withValues(alpha: 0.10), width: 1),
);

// ── Scan QR card ──────────────────────────────────────────────────────────────

class _ScanCard extends StatelessWidget {
  final String userId;
  final bool isDark;
  final AppColors c;
  final TextTheme tt;
  final VoidCallback onScanned;

  const _ScanCard({
    required this.userId,
    required this.isDark,
    required this.c,
    required this.tt,
    required this.onScanned,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isDark ? _darkCard() : lightCardDecoration(),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D8050), Color(0xFF22C55E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF22C55E).withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Find a Room',
                  style: tt.titleMedium?.copyWith(
                    color: c.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Scan a building\'s QR code to access floor maps and navigate to any room',
                  style: tt.bodySmall?.copyWith(
                    color: c.onSurfaceSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    PlanovaModalRoute(
                      builder: (_) => QRScannerScreen(userId: userId),
                    ),
                  ).then((_) => onScanned()),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D8050), Color(0xFF22C55E)],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Center(
                      child: Text(
                        'Scan QR Code',
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
          ),
        ],
      ),
    );
  }
}

// ── Recent card ───────────────────────────────────────────────────────────────

class _RecentCard extends StatelessWidget {
  final RecentBuildingEntry entry;
  final String timeAgo;
  final VoidCallback onTap, onDismiss;
  final bool isDark;
  final AppColors c;
  final TextTheme tt;

  const _RecentCard({
    required this.entry,
    required this.timeAgo,
    required this.onTap,
    required this.onDismiss,
    required this.isDark,
    required this.c,
    required this.tt,
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
          decoration: isDark ? _darkCard() : lightCardDecoration(),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1450A8), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: Colors.white,
                  size: 20,
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
                        _Pill(
                          icon: Icons.layers_rounded,
                          label:
                              '${entry.totalFloors} floor${entry.totalFloors == 1 ? '' : 's'}',
                          c: c,
                          tt: tt,
                        ),
                        const SizedBox(width: 6),
                        _Pill(
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

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppColors c;
  final TextTheme tt;
  const _Pill({
    required this.icon,
    required this.label,
    required this.c,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.chipFill,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: c.chipText),
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

// ── Admin prompt ──────────────────────────────────────────────────────────────

class _AdminPromptCard extends StatelessWidget {
  final bool isDark;
  final AppColors c;
  final TextTheme tt;
  final VoidCallback onLogin;
  const _AdminPromptCard({
    required this.isDark,
    required this.c,
    required this.tt,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: isDark
          ? _darkCard()
          : BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: const Color(0xFF1A6ADB).withValues(alpha: 0.20),
              ),
            ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: c.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(
              Icons.admin_panel_settings_rounded,
              color: c.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you a building admin?',
                  style: tt.titleSmall?.copyWith(
                    color: c.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Login to upload floorplans, map rooms, and generate QR codes.',
                  style: tt.bodySmall?.copyWith(
                    color: c.onSurfaceSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onLogin,
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: heroGradient(),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Center(
                      child: Text(
                        'Login / Sign Up',
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
          ),
        ],
      ),
    );
  }
}

// ── How to navigate ───────────────────────────────────────────────────────────

class _HowToCard extends StatelessWidget {
  final bool isDark;
  final AppColors c;
  final TextTheme tt;
  const _HowToCard({required this.isDark, required this.c, required this.tt});

  @override
  Widget build(BuildContext context) {
    final steps = [
      'Find the QR code at the building entrance',
      'Tap "Scan QR Code" and point your camera at it',
      'Browse the floor map and select your destination',
      'Follow the route to your room',
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: isDark ? _darkCard() : lightCardDecoration(),
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
                'How to Navigate',
                style: tt.titleSmall?.copyWith(
                  color: c.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
                        width: 28,
                        height: 28,
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
                          height: 16,
                          margin: const EdgeInsets.symmetric(vertical: 3),
                          color: c.borderSubtle,
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
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
