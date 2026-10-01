import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/screens/room_mapping_screen.dart';
import 'package:planova_mobile/screens/wall_review_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:planova_mobile/theme/app_theme.dart';
import 'package:planova_mobile/widgets/skeletons.dart';
import 'package:planova_mobile/main.dart';

class FloorManagementScreen extends StatefulWidget {
  final BuildingModel building;
  const FloorManagementScreen({Key? key, required this.building})
    : super(key: key);

  @override
  State<FloorManagementScreen> createState() => _FloorManagementScreenState();
}

class _FloorManagementScreenState extends State<FloorManagementScreen> {
  final BuildingService _buildingService = BuildingService();
  final ImagePicker _imagePicker = ImagePicker();

  List<FloorModel> _floors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFloors();
  }

  Future<void> _loadFloors() async {
    setState(() => _isLoading = true);
    try {
      final floors = await _buildingService.getFloors(widget.building.id);
      setState(() {
        _floors = floors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Add floor

  Future<void> _showAddFloorSheet() async {
    final nameController = TextEditingController();
    final numberController = TextEditingController(
      text: '${_floors.length + 1}',
    );
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
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1450A8), Color(0xFF3B82F6)],
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.layers_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Add New Floor',
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
                  hintText: 'Floor name (e.g. Ground Floor, 2nd Floor)',
                  prefixIcon: Icon(Icons.layers_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: numberController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Floor number (e.g. 0, 1, 2)',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'After tapping Next, you\'ll pick a floorplan image.',
                  style: tt.bodySmall?.copyWith(color: c.onSurfaceTertiary),
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
                      'Next: Upload Floorplan',
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
      await _uploadFloorplan(
        nameController.text.trim(),
        int.tryParse(numberController.text) ?? _floors.length,
      );
    }
  }

  // Upload floorplan (logic unchanged)

  Future<void> _uploadFloorplan(String floorName, int floorNumber) async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );
    if (image == null) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No image selected')));
      return;
    }
    if (!mounted) return;

    // Upload progress dialog — themed
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: isDark ? const Color(0xFF1C2942) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: c.primary),
              const SizedBox(height: 16),
              Text(
                'Uploading floorplan...',
                style: tt.bodyMedium?.copyWith(color: c.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                'Please wait',
                style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('Not authenticated');

      final floorId = 'flr_${const Uuid().v4().substring(0, 8)}';
      final ext = image.path.split('.').last.toLowerCase();
      final storagePath =
          'floorplans/$userId/${widget.building.id}/$floorId.$ext';

      final storageRef = FirebaseStorage.instance.ref(storagePath);
      await storageRef
          .putFile(
            File(image.path),
            SettableMetadata(contentType: 'image/jpeg'),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw Exception('Upload timed out after 30 seconds'),
          );

      final imageUrl = await storageRef.getDownloadURL();

      await _buildingService.addFloor(
        buildingId: widget.building.id,
        floorId: floorId,
        floorName: floorName,
        floorNumber: floorNumber,
        imageUrl: imageUrl,
        processedData: null,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Floor "$floorName" added! Processing...'),
            backgroundColor: c.success,
          ),
        );
        _loadFloors();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.colors(context).error,
          ),
        );
      }
    }
  }

  // Delete with swipe + confirmation sheet

  Future<void> _confirmDeleteFloor(FloorModel floor) async {
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
                        'Delete Floor?',
                        style: tt.headlineSmall?.copyWith(
                          color: c.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        floor.floorName,
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
                      'This will permanently delete "${floor.floorName}" and all '
                      '${floor.totalRooms} room${floor.totalRooms == 1 ? '' : 's'} '
                      'mapped on it. This cannot be undone.',
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
                    'Yes, Delete Floor',
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

    if (confirmed == true) {
      try {
        await _buildingService.deleteFloor(widget.building.id, floor.id);
        setState(() => _floors.removeWhere((f) => f.id == floor.id));
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${floor.floorName}" deleted'),
              backgroundColor: AppTheme.colors(context).success,
            ),
          );
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting: $e'),
              backgroundColor: AppTheme.colors(context).error,
            ),
          );
        _loadFloors();
      }
    } else {
      // Snap item back by rebuilding
      setState(() {});
    }
  }

  // Build

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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: c.onBackground,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.building.buildingName,
              style: tt.titleMedium?.copyWith(
                color: c.onBackground,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Manage Floors',
              style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: c.primary),
            onPressed: _showAddFloorSheet,
            tooltip: 'Add Floor',
          ),
        ],
      ),
      body: _isLoading
          ? const FloorListSkeleton()
          : _floors.isEmpty
          ? _buildEmptyState(c, tt)
          : RefreshIndicator(
              onRefresh: _loadFloors,
              color: c.primary,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                itemCount: _floors.length,
                itemBuilder: (_, i) =>
                    _buildSwipeableFloorCard(_floors[i], c, tt, isDark),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFloorSheet,
        backgroundColor: c.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Floor'),
      ),
    );
  }

  // Swipeable floor card

  Widget _buildSwipeableFloorCard(
    FloorModel floor,
    AppColors c,
    TextTheme tt,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Dismissible(
        key: ValueKey(floor.id),
        direction: DismissDirection.endToStart,
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
        confirmDismiss: (_) async {
          await _confirmDeleteFloor(floor);
          return false;
        },
        child: _FloorCard(
          floor: floor,
          isDark: isDark,
          c: c,
          tt: tt,
          onTap: () => _openRoomMapping(floor),
          onMapRooms: () => _openRoomMapping(floor),
          onReviewWalls: () => _openWallReview(floor),
          onDeleteTap: () => _confirmDeleteFloor(floor),
        ),
      ),
    );
  }

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
              child: Icon(Icons.layers_rounded, size: 52, color: c.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'No Floors Yet',
              style: tt.headlineMedium?.copyWith(
                color: c.onBackground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first floor with a floorplan image',
              style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _showAddFloorSheet,
              child: Container(
                height: 52,
                width: 200,
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
                      'Add Floor',
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

  void _openRoomMapping(FloorModel floor) {
    Navigator.push(
      context,
      PlanovaPageRoute(
        builder: (_) =>
            RoomMappingScreen(building: widget.building, floor: floor),
      ),
    ).then((_) => _loadFloors());
  }

  void _openWallReview(FloorModel floor) {
    Navigator.push(
      context,
      PlanovaPageRoute(
        builder: (_) =>
            WallReviewScreen(building: widget.building, floor: floor),
      ),
    ).then((_) => _loadFloors());
  }
}

// Floor card widget

class _FloorCard extends StatelessWidget {
  final FloorModel floor;
  final bool isDark;
  final AppColors c;
  final TextTheme tt;
  final VoidCallback onTap;
  final VoidCallback onMapRooms;
  final VoidCallback onReviewWalls;
  final VoidCallback onDeleteTap;

  const _FloorCard({
    required this.floor,
    required this.isDark,
    required this.c,
    required this.tt,
    required this.onTap,
    required this.onMapRooms,
    required this.onReviewWalls,
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
                // Floor number badge
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
                  child: Center(
                    child: Text(
                      floor.floorNumber.toString(),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        floor.floorName,
                        style: tt.titleMedium?.copyWith(
                          color: c.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.meeting_room_rounded,
                            size: 13,
                            color: c.onSurfaceTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${floor.totalRooms} room${floor.totalRooms == 1 ? '' : 's'} mapped',
                            style: tt.bodySmall?.copyWith(
                              color: c.onSurfaceSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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

            // Map Rooms button
            GestureDetector(
              onTap: onMapRooms,
              child: Container(
                height: 44,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: heroGradient(),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  boxShadow: AppShadows.primaryGlow(c.primary),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Map Rooms',
                      style: tt.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Review Walls button
            GestureDetector(
              onTap: onReviewWalls,
              child: Container(
                height: 44,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: c.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: c.primary.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit_road_rounded, size: 16, color: c.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Review Walls',
                      style: tt.labelMedium?.copyWith(
                        color: c.primary,
                        fontWeight: FontWeight.w600,
                      ),
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
