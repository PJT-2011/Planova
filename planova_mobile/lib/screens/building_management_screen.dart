import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/screens/floor_management_screen.dart';
import 'package:planova_mobile/screens/qr_generator_screen.dart';
import 'package:planova_mobile/theme/app_theme.dart';
import 'package:planova_mobile/widgets/skeletons.dart';
import 'package:planova_mobile/main.dart';

class BuildingManagementScreen extends StatefulWidget {
  final String userId;
  const BuildingManagementScreen({Key? key, required this.userId})
    : super(key: key);

  @override
  State<BuildingManagementScreen> createState() =>
      _BuildingManagementScreenState();
}

class _BuildingManagementScreenState extends State<BuildingManagementScreen> {
  final BuildingService _buildingService = BuildingService();

  // Tracks which building IDs are mid-swipe so we can snap back on cancel
  final Set<String> _pendingDelete = {};

  List<BuildingModel> _buildings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBuildings();
  }

  Future<void> _loadBuildings() async {
    setState(() => _isLoading = true);
    try {
      final buildings = await _buildingService.getUserBuildings(widget.userId);
      setState(() {
        _buildings = buildings;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ [BuildingManagement] Error: $e');
      setState(() => _isLoading = false);
    }
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<void> _showCreateSheet() async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showModalBottomSheet<bool>(
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
              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: heroGradient(),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Create New Building',
                    style: tt.headlineSmall?.copyWith(
                      color: c.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Building name (e.g. STI Pasay Campus)',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: addressController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Address (e.g. EDSA, Pasay City)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context, true),
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
                      'Create Building',
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

    if (confirmed == true && nameController.text.trim().isNotEmpty) {
      await _createBuilding(
        nameController.text.trim(),
        addressController.text.trim(),
      );
    }
  }

  Future<void> _createBuilding(String name, String address) async {
    try {
      await _buildingService.createBuilding(
        buildingName: name,
        address: address,
        userId: widget.userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Building "$name" created!'),
            backgroundColor: AppTheme.colors(context).success,
          ),
        );
        _loadBuildings();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating building: $e'),
            backgroundColor: AppTheme.colors(context).error,
          ),
        );
    }
  }

  // ── Delete with swipe + confirmation sheet ────────────────────────────────

  /// Called when the user finishes the swipe gesture.
  /// Shows a confirmation bottom sheet; if they cancel we put the
  /// building back (via [_pendingDelete] + setState rebuild).
  Future<void> _confirmDeleteBuilding(BuildingModel building) async {
    // Haptic so the user knows the swipe registered
    HapticFeedback.mediumImpact();

    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showModalBottomSheet<bool>(
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + title
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: c.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.delete_forever_rounded,
                    color: c.error,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete Building?',
                        style: tt.headlineSmall?.copyWith(
                          color: c.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        building.buildingName,
                        style: tt.bodySmall?.copyWith(
                          color: c.onSurfaceSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.error.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: c.error.withValues(alpha: 0.20)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: c.error, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This will permanently delete all floors and rooms in '
                      '"${building.buildingName}". This cannot be undone.',
                      style: tt.bodySmall?.copyWith(
                        color: c.onSurface,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Delete button
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
                    'Yes, Delete',
                    style: tt.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel — snaps item back
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

    if (confirmed == true) {
      await _executeDelete(building);
    } else {
      // User cancelled — rebuild to restore the dismissed item
      setState(() => _pendingDelete.remove(building.id));
    }
  }

  Future<void> _executeDelete(BuildingModel building) async {
    try {
      await _buildingService.deleteBuilding(building.id);
      setState(() {
        _buildings.removeWhere((b) => b.id == building.id);
        _pendingDelete.remove(building.id);
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${building.buildingName}" deleted'),
            backgroundColor: AppTheme.colors(context).success,
          ),
        );
    } catch (e) {
      setState(() => _pendingDelete.remove(building.id));
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: $e'),
            backgroundColor: AppTheme.colors(context).error,
          ),
        );
      _loadBuildings();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.onBackground,
        title: Text(
          'My Buildings',
          style: tt.titleLarge?.copyWith(color: c.onBackground),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: c.onBackground,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: c.primary),
            onPressed: _showCreateSheet,
            tooltip: 'Create Building',
          ),
        ],
      ),
      body: _isLoading
          ? const BuildingListSkeleton()
          : _buildings.isEmpty
          ? _buildEmptyState(c, tt)
          : RefreshIndicator(
              onRefresh: _loadBuildings,
              color: c.primary,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                itemCount: _buildings.length,
                itemBuilder: (_, i) =>
                    _buildSwipeableCard(_buildings[i], c, tt, isDark),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSheet,
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create Building'),
      ),
    );
  }

  // ── Swipeable building card ───────────────────────────────────────────────

  Widget _buildSwipeableCard(
    BuildingModel building,
    AppColors c,
    TextTheme tt,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Dismissible(
        key: ValueKey(building.id),
        direction: DismissDirection.endToStart,

        // Red delete background revealed by swipe
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 28),
          decoration: BoxDecoration(
            color: c.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: c.error.withValues(alpha: 0.40)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_rounded, color: c.error, size: 28),
              const SizedBox(height: 4),
              Text(
                'Delete',
                style: tt.labelSmall?.copyWith(
                  color: c.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        // Intercept the dismiss to show confirmation first
        confirmDismiss: (_) async {
          setState(() => _pendingDelete.add(building.id));
          await _confirmDeleteBuilding(building);
          // Always return false — we manage removal ourselves
          return false;
        },

        child: _BuildingCard(
          building: building,
          isDark: isDark,
          c: c,
          tt: tt,
          onTap: () => _openFloorManagement(building),
          onManageFloors: () => _openFloorManagement(building),
          onQRCode: () => _openQRGenerator(building),
          onDeleteTap: () => _confirmDeleteBuilding(building),
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(AppColors c, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: c.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(Icons.business_rounded, size: 52, color: c.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'No Buildings Yet',
              style: tt.headlineMedium?.copyWith(
                color: c.onBackground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first building to get started',
              style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _showCreateSheet,
              child: Container(
                height: 52,
                width: 220,
                decoration: BoxDecoration(
                  gradient: heroGradient(),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.primaryGlow(c.primary),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Create Building',
                      style: tt.labelLarge?.copyWith(color: Colors.white),
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

  void _openFloorManagement(BuildingModel building) {
    Navigator.push(
      context,
      PlanovaPageRoute(
        builder: (_) => FloorManagementScreen(building: building),
      ),
    ).then((_) => _loadBuildings());
  }

  void _openQRGenerator(BuildingModel building) {
    Navigator.push(
      context,
      PlanovaPageRoute(builder: (_) => QRGeneratorScreen(building: building)),
    );
  }
}

// ── Building card widget ──────────────────────────────────────────────────────

class _BuildingCard extends StatelessWidget {
  final BuildingModel building;
  final bool isDark;
  final AppColors c;
  final TextTheme tt;
  final VoidCallback onTap;
  final VoidCallback onManageFloors;
  final VoidCallback onQRCode;
  final VoidCallback onDeleteTap;

  const _BuildingCard({
    required this.building,
    required this.isDark,
    required this.c,
    required this.tt,
    required this.onTap,
    required this.onManageFloors,
    required this.onQRCode,
    required this.onDeleteTap,
  });

  BoxDecoration get _deco => isDark
      ? BoxDecoration(
          color: const Color(0xFF1C2942),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        )
      : lightCardDecoration();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: _deco,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 50,
                  height: 50,
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
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        building.buildingName,
                        style: tt.titleMedium?.copyWith(
                          color: c.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: c.onSurfaceTertiary,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              building.address,
                              style: tt.bodySmall?.copyWith(
                                color: c.onSurfaceSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Delete icon tap (alternative to swipe)
                GestureDetector(
                  onTap: onDeleteTap,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: c.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: c.error,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Chips row
            Row(
              children: [
                _InfoChip(
                  icon: Icons.layers_rounded,
                  label:
                      '${building.totalFloors} Floor${building.totalFloors == 1 ? '' : 's'}',
                  c: c,
                  tt: tt,
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.meeting_room_rounded,
                  label:
                      '${building.totalRooms} Room${building.totalRooms == 1 ? '' : 's'}',
                  c: c,
                  tt: tt,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Swipe hint
            Row(
              children: [
                Icon(
                  Icons.swipe_left_rounded,
                  size: 13,
                  color: c.onSurfaceTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Swipe left to delete',
                  style: tt.labelSmall?.copyWith(color: c.onSurfaceTertiary),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onManageFloors,
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: c.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.layers_rounded,
                            size: 16,
                            color: c.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Manage Floors',
                            style: tt.labelSmall?.copyWith(
                              color: c.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: onQRCode,
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: heroGradient(),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.qr_code_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'QR Code',
                            style: tt.labelSmall?.copyWith(
                              color: Colors.white,
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
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppColors c;
  final TextTheme tt;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.c,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.chipFill,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c.chipText),
          const SizedBox(width: 5),
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
