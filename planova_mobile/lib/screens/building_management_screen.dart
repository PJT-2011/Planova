import 'package:flutter/material.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/screens/floor_management_screen.dart';
import 'package:planova_mobile/screens/qr_generator_screen.dart';

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
      print('❌ [BuildingManagement] Error loading buildings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showCreateBuildingDialog() async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Building'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Building Name',
                hintText: 'e.g., STI Pasay Campus',
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                hintText: 'e.g., EDSA, Pasay City',
              ),
              textCapitalization: TextCapitalization.words,
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
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.isNotEmpty) {
      await _createBuilding(nameController.text, addressController.text);
    }
  }

  Future<void> _createBuilding(String name, String address) async {
    try {
      await _buildingService.createBuilding(
        buildingName: name,
        address: address,
        userId: widget.userId,
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('✅ Building "$name" created!')));

      _loadBuildings();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error creating building: $e')));
    }
  }

  Future<void> _deleteBuilding(BuildingModel building) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Building?'),
        content: Text(
          'This will delete "${building.buildingName}" and all its floors and rooms. This cannot be undone.',
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
        await _buildingService.deleteBuilding(building.id);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Building deleted')));
        _loadBuildings();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error deleting: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Buildings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateBuildingDialog,
            tooltip: 'Create New Building',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildings.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadBuildings,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _buildings.length,
                itemBuilder: (context, index) {
                  final building = _buildings[index];
                  return _buildBuildingCard(building);
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateBuildingDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Building'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 24),
          Text(
            'No Buildings Yet',
            style: TextStyle(fontSize: 24, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first building to get started',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showCreateBuildingDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create Building'),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingCard(BuildingModel building) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _openFloorManagement(building),
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
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.business, color: Colors.blue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          building.buildingName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                building.address,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
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
                        _deleteBuilding(building);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.layers,
                    '${building.totalFloors} Floor${building.totalFloors == 1 ? '' : 's'}',
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    Icons.room,
                    '${building.totalRooms} Room${building.totalRooms == 1 ? '' : 's'}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openFloorManagement(building),
                      icon: const Icon(Icons.layers),
                      label: const Text('Manage Floors'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openQRGenerator(building),
                      icon: const Icon(Icons.qr_code),
                      label: const Text('QR Code'),
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

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  void _openFloorManagement(BuildingModel building) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FloorManagementScreen(building: building),
      ),
    ).then((_) => _loadBuildings()); // Refresh when coming back
  }

  void _openQRGenerator(BuildingModel building) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRGeneratorScreen(building: building),
      ),
    );
  }
}
