import 'package:flutter/material.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/models/room_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/screens/navigation_screen_with_rooms.dart';
import 'package:planova_mobile/theme/app_theme.dart';
import 'package:planova_mobile/widgets/skeletons.dart';
import 'package:planova_mobile/main.dart';

class FloorSelectionScreen extends StatefulWidget {
  final BuildingModel building;
  final String userId;

  const FloorSelectionScreen({
    Key? key,
    required this.building,
    required this.userId,
  }) : super(key: key);

  @override
  State<FloorSelectionScreen> createState() => _FloorSelectionScreenState();
}

class _FloorSelectionScreenState extends State<FloorSelectionScreen>
    with SingleTickerProviderStateMixin {
  final BuildingService _buildingService = BuildingService();

  List<FloorModel> _floors = [];
  Map<String, List<RoomModel>> _roomsByFloor = {};
  bool _isLoading = true;
  TabController? _tabController;
  int _currentFloorIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBuildingData();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadBuildingData() async {
    setState(() => _isLoading = true);
    try {
      final floors = await _buildingService.getFloors(widget.building.id);
      final Map<String, List<RoomModel>> roomsByFloor = {};
      for (final floor in floors) {
        roomsByFloor[floor.id] = await _buildingService.getRooms(
          widget.building.id,
          floor.id,
        );
      }
      if (!mounted) return;
      setState(() {
        _floors = floors;
        _roomsByFloor = roomsByFloor;
        _isLoading = false;
        if (floors.isNotEmpty) {
          _tabController?.dispose();
          _tabController = TabController(length: floors.length, vsync: this);
          _tabController!.addListener(() {
            if (!_tabController!.indexIsChanging) {
              setState(() => _currentFloorIndex = _tabController!.index);
            }
          });
        }
      });
    } catch (e) {
      debugPrint('❌ [FloorSelection] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  FloorModel get _currentFloor => _floors[_currentFloorIndex];
  List<RoomModel> get _currentRooms => _roomsByFloor[_currentFloor.id] ?? [];

  void _openNavigation(FloorModel floor, {RoomModel? targetRoom}) {
    Navigator.push(
      context,
      PlanovaModalRoute(
        builder: (_) => NavigationScreenWithRooms(
          building: widget.building,
          floor: floor,
          targetRoom: targetRoom,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          title: Text(widget.building.buildingName),
          backgroundColor: c.background,
          foregroundColor: c.onBackground,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_floors.isEmpty) {
      return Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          title: Text(widget.building.buildingName),
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
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.layers_clear, size: 80, color: c.onSurfaceTertiary),
              const SizedBox(height: 20),
              Text(
                'No Floors Available',
                style: tt.headlineSmall?.copyWith(color: c.onBackground),
              ),
              const SizedBox(height: 8),
              Text(
                'This building hasn\'t been set up yet',
                style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.onBackground,
        elevation: 0,
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
              style: tt.titleLarge?.copyWith(color: c.onBackground),
            ),
            Text(
              widget.building.address,
              style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c.divider, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: _floors.length > 3,
              labelColor: c.primary,
              unselectedLabelColor: c.onSurfaceTertiary,
              indicatorColor: c.primary,
              indicatorWeight: 2.5,
              dividerColor: Colors.transparent,
              labelStyle: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              unselectedLabelStyle: tt.titleSmall,
              tabs: _floors
                  .map(
                    (floor) => Tab(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            floor.floorNumber.toString(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${_roomsByFloor[floor.id]?.length ?? 0} rooms',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _floors.map((floor) {
          final rooms = _roomsByFloor[floor.id] ?? [];
          return _buildFloorView(floor, rooms, c, tt, isDark);
        }).toList(),
      ),
    );
  }

  Widget _buildFloorView(
    FloorModel floor,
    List<RoomModel> rooms,
    AppColors c,
    TextTheme tt,
    bool isDark,
  ) {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          color: c.background,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search rooms on ${floor.floorName}...',
              prefixIcon: Icon(Icons.search_rounded, color: c.iconMuted),
            ),
            onSubmitted: _searchRooms,
          ),
        ),

        // Info banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: c.primary.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: c.primary, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Viewing: ${floor.floorName} · ${rooms.length} room${rooms.length == 1 ? '' : 's'} available',
                  style: tt.bodySmall?.copyWith(color: c.onPrimaryContainer),
                ),
              ),
              GestureDetector(
                onTap: _showAllFloorsSearch,
                child: Text(
                  'Search All Floors',
                  style: tt.labelSmall?.copyWith(
                    color: c.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Room list or empty state
        Expanded(
          child: rooms.isEmpty
              ? _buildEmptyRoomState(floor, c, tt)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: rooms.length,
                  itemBuilder: (_, i) =>
                      _buildRoomCard(floor, rooms[i], c, tt, isDark),
                ),
        ),

        // Bottom bar
        Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2942) : c.surface,
            border: Border(top: BorderSide(color: c.divider, width: 1)),
            boxShadow: isDark ? [] : AppShadows.modal,
          ),
          child: GestureDetector(
            onTap: () => _openNavigation(floor),
            child: Container(
              height: 54,
              decoration: BoxDecoration(
                gradient: heroGradient(),
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadows.primaryGlow(c.primary),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'View Floor Map',
                    style: tt.labelLarge?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyRoomState(FloorModel floor, AppColors c, TextTheme tt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: c.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(
                Icons.location_off_rounded,
                size: 40,
                color: c.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Rooms Mapped Yet',
              style: tt.headlineSmall?.copyWith(color: c.onBackground),
            ),
            const SizedBox(height: 8),
            Text(
              'This floor hasn\'t been set up',
              style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => _openNavigation(floor),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  gradient: heroGradient(),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Center(
                  child: Text(
                    'View Map Anyway',
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

  Widget _buildRoomCard(
    FloorModel floor,
    RoomModel room,
    AppColors c,
    TextTheme tt,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: isDark
          ? BoxDecoration(
              color: const Color(0xFF1C2942),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            )
          : lightCardDecoration(),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => _navigateToRoom(floor, room),
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.meeting_room_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.name,
                      style: tt.titleSmall?.copyWith(
                        color: c.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${floor.floorName} · Row ${room.gridPoint.row}, Col ${room.gridPoint.col}',
                      style: tt.bodySmall?.copyWith(
                        color: c.onSurfaceSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.iconMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToRoom(FloorModel floor, RoomModel room) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C2942) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1450A8), Color(0xFF3B82F6)],
                ),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.meeting_room_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              room.name,
              style: tt.headlineMedium?.copyWith(
                color: c.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              floor.floorName,
              style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _openNavigation(floor, targetRoom: room);
              },
              child: Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: heroGradient(),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.primaryGlow(c.primary),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.navigation_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Navigate to This Room',
                      style: tt.labelLarge?.copyWith(color: Colors.white),
                    ),
                  ],
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

  void _searchRooms(String query) {
    if (query.isEmpty) return;
    final results = _currentRooms.where((r) => r.matchesSearch(query)).toList();
    _showSearchResults(results, query, singleFloor: true);
  }

  void _showAllFloorsSearch() {
    final controller = TextEditingController();
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Search All Floors', style: tt.headlineSmall),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g., Conference Room',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final q = controller.text;
              Navigator.pop(context);
              _searchAllFloors(q);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchAllFloors(String query) async {
    if (query.isEmpty) return;
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final results = await _buildingService.searchRooms(
        widget.building.id,
        query,
      );
      if (!mounted) return;
      Navigator.pop(context);
      _showSearchResults(results, query, singleFloor: false);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error searching: $e')));
    }
  }

  void _showSearchResults(
    List<RoomModel> results,
    String query, {
    required bool singleFloor,
  }) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1C2942) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Search Results',
                style: tt.headlineSmall?.copyWith(color: c.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                '${results.length} result${results.length == 1 ? '' : 's'} for "$query"'
                '${singleFloor ? ' on ${_currentFloor.floorName}' : ' across all floors'}',
                style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 56,
                              color: c.onSurfaceTertiary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No rooms found',
                              style: tt.bodyMedium?.copyWith(
                                color: c.onSurfaceSecondary,
                              ),
                            ),
                            if (singleFloor) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showAllFloorsSearch();
                                },
                                child: const Text('Search all floors instead'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: results.length,
                        itemBuilder: (_, i) {
                          final room = results[i];
                          final floorMatch = _floors.where(
                            (f) => f.id == room.floorId,
                          );
                          if (floorMatch.isEmpty)
                            return const SizedBox.shrink();
                          final floor = floorMatch.first;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: isDark
                                ? BoxDecoration(
                                    color: const Color(0xFF243450),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.md,
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.07,
                                      ),
                                    ),
                                  )
                                : lightCardDecoration(radius: 14),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1450A8),
                                      Color(0xFF3B82F6),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.meeting_room_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                room.name,
                                style: tt.titleSmall?.copyWith(
                                  color: c.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                floor.floorName,
                                style: tt.bodySmall?.copyWith(
                                  color: c.onSurfaceSecondary,
                                ),
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: c.iconMuted,
                                size: 18,
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                final idx = _floors.indexOf(floor);
                                _tabController?.animateTo(idx);
                                Future.delayed(
                                  const Duration(milliseconds: 300),
                                  () {
                                    if (mounted) _navigateToRoom(floor, room);
                                  },
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
