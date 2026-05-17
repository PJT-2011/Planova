import 'package:flutter/material.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/models/room_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';

class RoomMappingScreen extends StatefulWidget {
  final BuildingModel building;
  final FloorModel floor;

  const RoomMappingScreen({
    Key? key,
    required this.building,
    required this.floor,
  }) : super(key: key);

  @override
  State<RoomMappingScreen> createState() => _RoomMappingScreenState();
}

class _RoomMappingScreenState extends State<RoomMappingScreen> {
  final BuildingService _buildingService = BuildingService();
  final GlobalKey _imageKey = GlobalKey();

  GridModel? _gridModel;
  List<RoomModel> _rooms = [];
  bool _isLoading = true;

  // Image display info for coordinate transformation
  Size? _imageDisplaySize;
  Offset? _imageDisplayOffset;
  Size? _imageOriginalSize;
  bool _boundsCalculated = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load grid model from floor's processed data
      if (widget.floor.processedData != null) {
        _gridModel = GridModel.fromJson(widget.floor.processedData!);
      }

      // Load existing rooms
      final rooms = await _buildingService.getRooms(
        widget.building.id,
        widget.floor.id,
      );

      setState(() {
        _rooms = rooms;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateImageBounds();
      });
    } catch (e) {
      debugPrint('❌ [RoomMapping] Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  void _calculateImageBounds() {
    if (_boundsCalculated || _gridModel == null) return;

    final RenderBox? renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;

    if (renderBox == null) return;

    final containerSize = renderBox.size;
    final imageWidth = _gridModel!.metadata.imageWidth.toDouble();
    final imageHeight = _gridModel!.metadata.imageHeight.toDouble();

    if (containerSize.width == 0 || containerSize.height == 0) return;

    final containerAspect = containerSize.width / containerSize.height;
    final imageAspect = imageWidth / imageHeight;

    double displayWidth;
    double displayHeight;
    double offsetX;
    double offsetY;

    if (containerAspect > imageAspect) {
      displayHeight = containerSize.height;
      displayWidth = displayHeight * imageAspect;
      offsetX = (containerSize.width - displayWidth) / 2;
      offsetY = 0;
    } else {
      displayWidth = containerSize.width;
      displayHeight = displayWidth / imageAspect;
      offsetX = 0;
      offsetY = (containerSize.height - displayHeight) / 2;
    }

    setState(() {
      _imageDisplaySize = Size(displayWidth, displayHeight);
      _imageDisplayOffset = Offset(offsetX, offsetY);
      _imageOriginalSize = Size(imageWidth, imageHeight);
      _boundsCalculated = true;
    });

    debugPrint('✅ [RoomMapping] Image bounds calculated');
  }

  Future<void> _handleTapToAddRoom(TapDownDetails details) async {
    if (_gridModel == null || _imageDisplaySize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for floorplan to load')),
      );
      return;
    }

    // Convert tap to grid coordinates (same logic as navigation)
    final tapX = details.localPosition.dx;
    final tapY = details.localPosition.dy;

    final adjustedX = tapX - _imageDisplayOffset!.dx;
    final adjustedY = tapY - _imageDisplayOffset!.dy;

    if (adjustedX < 0 ||
        adjustedX > _imageDisplaySize!.width ||
        adjustedY < 0 ||
        adjustedY > _imageDisplaySize!.height) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please tap inside the floorplan')),
      );
      return;
    }

    final scaleX = _imageOriginalSize!.width / _imageDisplaySize!.width;
    final scaleY = _imageOriginalSize!.height / _imageDisplaySize!.height;

    final imageX = adjustedX * scaleX;
    final imageY = adjustedY * scaleY;

    final cellSize = _gridModel!.cellSize.toDouble();

    final col = ((imageX - cellSize / 2) / cellSize).floor();
    final row = ((imageY - cellSize / 2) / cellSize).floor();

    if (row < 0 ||
        row >= _gridModel!.height ||
        col < 0 ||
        col >= _gridModel!.width) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please tap inside the floorplan area')),
      );
      return;
    }

    // Check if it's a wall
    final isWall = _gridModel!.grid[row][col] == 1;
    if (isWall) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot place room on a wall. Tap on an open area.'),
        ),
      );
      return;
    }

    // Show dialog to enter room name
    await _showAddRoomDialog(row, col);
  }

  Future<void> _showAddRoomDialog(int row, int col) async {
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Room Name',
                hintText: 'e.g., Conference Room A',
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Location: Row $row, Col $col',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _addRoom(result, row, col);
    }
  }

  Future<void> _addRoom(String name, int row, int col) async {
    try {
      await _buildingService.addRoom(
        buildingId: widget.building.id,
        floorId: widget.floor.id,
        roomName: name,
        row: row,
        col: col,
        floorNumber: widget.floor.floorNumber,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('✅ Room "$name" added!')));
      }

      _loadData(); // Reload rooms
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error adding room: $e')));
      }
    }
  }

  Future<void> _deleteRoom(RoomModel room) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room?'),
        content: Text('Delete "${room.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _buildingService.deleteRoom(
          widget.building.id,
          widget.floor.id,
          room.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('✅ Room deleted')));
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('❌ Error deleting room: $e')));
        }
      }
    }
  }

  double _getScreenX(int col) {
    if (_imageDisplaySize == null || _gridModel == null) return 0;

    final cellSize = _gridModel!.cellSize.toDouble();
    final imageX = (col + 0.5) * cellSize;

    final scaleX = _imageDisplaySize!.width / _imageOriginalSize!.width;
    final screenX = (imageX * scaleX) + _imageDisplayOffset!.dx;

    return screenX;
  }

  double _getScreenY(int row) {
    if (_imageDisplaySize == null || _gridModel == null) return 0;

    final cellSize = _gridModel!.cellSize.toDouble();
    final imageY = (row + 0.5) * cellSize;

    final scaleY = _imageDisplaySize!.height / _imageOriginalSize!.height;
    final screenY = (imageY * scaleY) + _imageDisplayOffset!.dy;

    return screenY;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FIX: AppBar does not support `subtitle`. Use `title` with a Column instead.
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.floor.floorName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_rooms.length} rooms mapped',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('How to Map Rooms'),
                  content: const Text(
                    '1. Tap anywhere on the floorplan\n'
                    '2. Enter the room name\n'
                    '3. Room marker will appear\n'
                    '4. Repeat for all important rooms\n\n'
                    'Tip: Map key locations like elevators, entrances, restrooms, and major rooms.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Instructions banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue.shade50,
                  child: const Row(
                    children: [
                      Icon(Icons.touch_app, color: Colors.blue),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tap anywhere on the floorplan to add a room',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),

                // Floorplan with room markers
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        onTapDown: _handleTapToAddRoom,
                        child: Container(
                          key: _imageKey,
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[850]
                              : Colors.grey[200],
                          child: Stack(
                            children: [
                              // Floorplan image
                              if (_imageDisplaySize != null &&
                                  _imageDisplayOffset != null)
                                Positioned(
                                  left: _imageDisplayOffset!.dx,
                                  top: _imageDisplayOffset!.dy,
                                  width: _imageDisplaySize!.width,
                                  height: _imageDisplaySize!.height,
                                  child: _buildFloorplanImage(),
                                ),

                              // Room markers
                              if (_gridModel != null)
                                ..._rooms.map((room) => _buildRoomMarker(room)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Room list at bottom
                if (_rooms.isNotEmpty)
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(12),
                      itemCount: _rooms.length,
                      itemBuilder: (context, index) {
                        final room = _rooms[index];
                        return _buildRoomChip(room);
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildFloorplanImage() {
    final imageUrl = widget.floor.imageUrl;

    if (MockStorageService.isMockUrl(imageUrl)) {
      final mockStorage = MockStorageService();
      final localFile = mockStorage.getLocalFile(imageUrl);

      return Image.file(
        localFile,
        fit: BoxFit.contain,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame != null && !_boundsCalculated) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _calculateImageBounds(),
            );
          }
          return child;
        },
      );
    } else {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame != null && !_boundsCalculated) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _calculateImageBounds(),
            );
          }
          return child;
        },
      );
    }
  }

  Widget _buildRoomMarker(RoomModel room) {
    final x = _getScreenX(room.gridPoint.col);
    final y = _getScreenY(room.gridPoint.row);

    return Positioned(
      left: x - 20,
      top: y - 40,
      child: GestureDetector(
        onTap: () => _showRoomOptions(room),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                room.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.location_on, color: Colors.blue, size: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomChip(RoomModel room) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Chip(
        avatar: const Icon(Icons.room, size: 18),
        label: Text(room.name),
        deleteIcon: const Icon(Icons.close, size: 18),
        onDeleted: () => _deleteRoom(room),
      ),
    );
  }

  void _showRoomOptions(RoomModel room) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              room.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Row: ${room.gridPoint.row}, Col: ${room.gridPoint.col}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Room'),
              onTap: () {
                Navigator.pop(context);
                _deleteRoom(room);
              },
            ),
          ],
        ),
      ),
    );
  }
}
