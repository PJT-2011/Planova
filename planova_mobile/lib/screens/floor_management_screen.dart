import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/screens/room_mapping_screen.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';

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
      debugPrint('❌ [FloorManagement] Error loading floors: $e');

      setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddFloorDialog() async {
    final nameController = TextEditingController();

    final floorNumberController = TextEditingController(
      text: '${_floors.length + 1}',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Floor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Floor Name',
                hintText: 'e.g., Ground Floor, 2nd Floor',
              ),
              textCapitalization: TextCapitalization.words,
            ),

            const SizedBox(height: 16),

            TextField(
              controller: floorNumberController,
              decoration: const InputDecoration(
                labelText: 'Floor Number',
                hintText: 'e.g., 0, 1, 2, 3',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),

          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Next: Upload Floorplan'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      await _uploadFloorplan(
        nameController.text,
        int.tryParse(floorNumberController.text) ?? _floors.length,
      );
    }
  }

  // ── REPLACED METHOD ─────────────────────────────────────────────
  Future<void> _uploadFloorplan(String floorName, int floorNumber) async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (image == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No image selected')));
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Uploading floorplan...'),
          ],
        ),
      ),
    );

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      if (userId == null) {
        throw Exception('Not authenticated');
      }

      // ✅ Generate ONE floorId used for both
      // Storage path AND Firestore doc
      final floorId = 'flr_${DateTime.now().millisecondsSinceEpoch}';

      final ext = image.path.split('.').last.toLowerCase();

      // ✅ Path:
      // floorplans/{userId}/{buildingId}/{floorId}.ext
      final storagePath =
          'floorplans/$userId/${widget.building.id}/$floorId.$ext';

      print('🔵 userId: $userId');
      print('🔵 File path: ${image.path}');
      print('🔵 Storage path: $storagePath');

      final storageRef = FirebaseStorage.instance.ref(storagePath);

      print('🔵 Starting putFile...');

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

      print('✅ putFile done');

      final imageUrl = await storageRef.getDownloadURL();

      print('✅ Download URL: $imageUrl');

      // ✅ Pass floorId so Firestore doc
      // matches Storage path
      await _buildingService.addFloor(
        buildingId: widget.building.id,
        floorId: floorId,
        floorName: floorName,
        floorNumber: floorNumber,
        imageUrl: imageUrl,
        processedData: null,
      );

      print('✅ Floor added to Firestore');

      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Floor "$floorName" added! Processing...')),
        );
      }

      _loadFloors();
    } catch (e, stack) {
      print('❌ Upload error: $e');
      print(stack);

      if (mounted) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    }
  }

  Future<void> _deleteFloor(FloorModel floor) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Floor?'),
        content: Text(
          'This will delete "${floor.floorName}" and all its rooms. This cannot be undone.',
        ),
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
        await _buildingService.deleteFloor(widget.building.id, floor.id);

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('✅ Floor deleted')));
        }

        _loadFloors();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('❌ Error deleting: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.building.buildingName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const Text(
              'Manage Floors',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _floors.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadFloors,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _floors.length,
                itemBuilder: (context, index) {
                  final floor = _floors[index];

                  return _buildFloorCard(floor);
                },
              ),
            ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddFloorDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Floor'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers, size: 100, color: Colors.grey[300]),

          const SizedBox(height: 24),

          Text(
            'No Floors Yet',
            style: TextStyle(fontSize: 24, color: Colors.grey[600]),
          ),

          const SizedBox(height: 8),

          Text(
            'Add your first floor to get started',
            style: TextStyle(color: Colors.grey[500]),
          ),

          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: _showAddFloorDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Floor'),
          ),
        ],
      ),
    );
  }

  Widget _buildFloorCard(FloorModel floor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _openRoomMapping(floor),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        floor.floorNumber.toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          floor.floorName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          '${floor.totalRooms} room${floor.totalRooms == 1 ? '' : 's'} mapped',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteFloor(floor);
                      }
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openRoomMapping(floor),
                      icon: const Icon(Icons.location_on),
                      label: const Text('Map Rooms'),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openRoomMapping(floor),
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openRoomMapping(FloorModel floor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            RoomMappingScreen(building: widget.building, floor: floor),
      ),
    ).then((_) => _loadFloors());
  }
}
