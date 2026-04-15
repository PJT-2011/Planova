import 'dart:io';
import 'package:flutter/material.dart';
import 'package:planova_mobile/services/auth_service.dart';
import 'package:planova_mobile/services/floorplan_service.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/screens/login_screen.dart';
import 'package:planova_mobile/screens/upload_floorplan_screen.dart';
import 'package:planova_mobile/screens/floorplan_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FloorplanService _floorplanService = FloorplanService();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

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
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  void _navigateToUpload() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UploadFloorplanScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PLANOVA'),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome message
                    Text(
                      'Welcome, ${_userData?['name'] ?? 'User'}!',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _userData?['email'] ?? '',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),

                    // Storage mode indicator
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _floorplanService.USE_MOCK_STORAGE
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _floorplanService.USE_MOCK_STORAGE
                              ? Colors.orange
                              : Colors.blue,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _floorplanService.USE_MOCK_STORAGE
                                ? Icons.phone_android
                                : Icons.cloud,
                            color: _floorplanService.USE_MOCK_STORAGE
                                ? Colors.orange
                                : Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _floorplanService.USE_MOCK_STORAGE
                                  ? 'Demo Mode: Using local storage'
                                  : 'Production Mode: Using Firebase Storage',
                              style: TextStyle(
                                color: _floorplanService.USE_MOCK_STORAGE
                                    ? Colors.orange[900]
                                    : Colors.blue[900],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Upload floorplan card
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        onTap: _navigateToUpload,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: const [
                              Icon(
                                Icons.upload_file,
                                size: 64,
                                color: Colors.blue,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Upload Floorplan',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Tap to upload a building floorplan',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Your floorplans section
                    const Text(
                      'Your Floorplans',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Floorplans list
                    StreamBuilder<List<FloorplanModel>>(
                      stream: _floorplanService.getUserFloorplans(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        final floorplans = snapshot.data ?? [];

                        if (floorplans.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: Text(
                                'No floorplans yet.\nUpload one to get started!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: floorplans.length,
                          itemBuilder: (context, index) {
                            final floorplan = floorplans[index];
                            return _buildFloorplanCard(floorplan);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFloorplanCard(FloorplanModel floorplan) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FloorplanDetailScreen(floorplan: floorplan),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildThumbnail(floorplan.imageUrl),
              ),
              const SizedBox(width: 16),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      floorplan.buildingName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Floor ${floorplan.floorNumber}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatusChip(floorplan.status),
                        const SizedBox(width: 8),
                        if (MockStorageService.isMockUrl(floorplan.imageUrl))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Local',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow icon
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String imageUrl) {
    if (MockStorageService.isMockUrl(imageUrl)) {
      // Load from local file
      final mockStorage = MockStorageService();
      final localFile = mockStorage.getLocalFile(imageUrl);

      return Image.file(
        localFile,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 80,
            height: 80,
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          );
        },
      );
    } else {
      // Load from network
      return Image.network(
        imageUrl,
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 80,
            height: 80,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 80,
            height: 80,
            color: Colors.grey[300],
            child: const Icon(Icons.error),
          );
        },
      );
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;

    switch (status) {
      case 'ready':
        color = Colors.green;
        text = 'Ready';
        break;
      case 'processing':
        color = Colors.orange;
        text = 'Processing';
        break;
      case 'failed':
        color = Colors.red;
        text = 'Failed';
        break;
      default:
        color = Colors.blue;
        text = 'Uploaded';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
