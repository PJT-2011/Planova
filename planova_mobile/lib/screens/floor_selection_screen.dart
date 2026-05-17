import 'package:flutter/material.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/models/room_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/screens/navigation_screen_with_rooms.dart';

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
      // Load all floors
      final floors = await _buildingService.getFloors(widget.building.id);

      // Load rooms for each floor
      final Map<String, List<RoomModel>> roomsByFloor = {};
      for (final floor in floors) {
        final rooms = await _buildingService.getRooms(
          widget.building.id,
          floor.id,
        );
        roomsByFloor[floor.id] = rooms;
      }

      if (!mounted) return;

      setState(() {
        _floors = floors;
        _roomsByFloor = roomsByFloor;
        _isLoading = false;

        // Create tab controller
        if (floors.isNotEmpty) {
          _tabController?.dispose();
          _tabController = TabController(length: floors.length, vsync: this);
          _tabController!.addListener(() {
            if (!_tabController!.indexIsChanging) {
              setState(() {
                _currentFloorIndex = _tabController!.index;
              });
            }
          });
        }
      });
    } catch (e) {
      debugPrint('❌ [FloorSelection] Error loading data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  FloorModel get _currentFloor => _floors[_currentFloorIndex];
  List<RoomModel> get _currentRooms => _roomsByFloor[_currentFloor.id] ?? [];

  void _openNavigation(FloorModel floor, {RoomModel? targetRoom}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NavigationScreenWithRooms(
          building: widget.building,
          floor: floor,
          targetRoom: targetRoom,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.building.buildingName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_floors.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.building.buildingName)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.layers_clear, size: 100, color: Colors.grey[300]),
              const SizedBox(height: 24),
              const Text(
                'No Floors Available',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This building hasn\'t been set up yet',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.building.buildingName),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: _floors.length > 4,
          tabs: _floors.map((floor) {
            return Tab(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(floor.floorName),
                  Text(
                    '${_roomsByFloor[floor.id]?.length ?? 0} rooms',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _floors.map((floor) {
          final rooms = _roomsByFloor[floor.id] ?? [];
          return _buildFloorView(floor, rooms);
        }).toList(),
      ),
    );
  }

  Widget _buildFloorView(FloorModel floor, List<RoomModel> rooms) {
    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search rooms on ${floor.floorName}...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (query) => _searchRooms(query),
          ),
        ),

        // Floor info banner
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Viewing: ${floor.floorName} • ${rooms.length} room${rooms.length == 1 ? '' : 's'} available',
                  style: const TextStyle(color: Colors.blue),
                ),
              ),
              TextButton(
                onPressed: () => _showAllFloorsSearch(),
                child: const Text('Search All Floors'),
              ),
            ],
          ),
        ),

        // Room list
        Expanded(
          child: rooms.isEmpty
              ? _buildEmptyRoomState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return _buildRoomCard(floor, room);
                  },
                ),
        ),

        // Quick actions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openNavigation(floor),
              icon: const Icon(Icons.map),
              label: const Text('View Floor Map'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyRoomState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.room_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No Rooms Mapped Yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'This floor hasn\'t been set up',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _openNavigation(_currentFloor),
            child: const Text('View Map Anyway'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(FloorModel floor, RoomModel room) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.room, color: Colors.blue),
        ),
        title: Text(
          room.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${floor.floorName} • Row ${room.gridPoint.row}, Col ${room.gridPoint.col}',
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _navigateToRoom(floor, room),
      ),
    );
  }

  void _navigateToRoom(FloorModel floor, RoomModel room) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              room.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              floor.floorName,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _openNavigation(floor, targetRoom: room);
                },
                icon: const Icon(Icons.navigation),
                label: const Text('Navigate to This Room'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
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

    final results = _currentRooms
        .where((room) => room.matchesSearch(query))
        .toList();

    _showSearchResults(results, query, singleFloor: true);
  }

  void _showAllFloorsSearch() {
    final queryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search All Floors'),
        content: TextField(
          controller: queryController,
          decoration: const InputDecoration(
            labelText: 'Room name',
            hintText: 'e.g., Conference Room',
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
              final query = queryController.text;
              Navigator.pop(context);
              _searchAllFloors(query);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _searchAllFloors(String query) async {
    if (query.isEmpty) return;

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final results = await _buildingService.searchRooms(
        widget.building.id,
        query,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      _showSearchResults(results, query, singleFloor: false);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Search Results',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '${results.length} result${results.length == 1 ? '' : 's'} for "$query"'
                '${singleFloor ? ' on ${_currentFloor.floorName}' : ' across all floors'}',
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No rooms found',
                              style: TextStyle(color: Colors.grey),
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
                        itemBuilder: (context, index) {
                          final room = results[index];
                          // Find the floor safely
                          final floorMatches = _floors.where(
                            (f) => f.id == room.floorId,
                          );
                          if (floorMatches.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final floor = floorMatches.first;

                          return ListTile(
                            leading: const Icon(Icons.room, color: Colors.blue),
                            title: Text(room.name),
                            subtitle: Text(floor.floorName),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              // Switch to correct floor tab
                              final floorIndex = _floors.indexOf(floor);
                              _tabController?.animateTo(floorIndex);
                              // Navigate to room after tab switch
                              Future.delayed(
                                const Duration(milliseconds: 300),
                                () {
                                  if (mounted) {
                                    _navigateToRoom(floor, room);
                                  }
                                },
                              );
                            },
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
