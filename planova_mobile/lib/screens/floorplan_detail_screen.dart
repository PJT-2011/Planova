import 'package:flutter/material.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/services/floorplan_service.dart';

class FloorplanDetailScreen extends StatefulWidget {
  final FloorplanModel floorplan;

  const FloorplanDetailScreen({Key? key, required this.floorplan})
    : super(key: key);

  @override
  State<FloorplanDetailScreen> createState() => _FloorplanDetailScreenState();
}

class _FloorplanDetailScreenState extends State<FloorplanDetailScreen> {
  final FloorplanService _floorplanService = FloorplanService();
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _deleteFloorplan() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Floorplan'),
        content: const Text('Are you sure you want to delete this floorplan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _floorplanService.deleteFloorplan(
          widget.floorplan.floorplanId,
          widget.floorplan.imageUrl,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Floorplan deleted'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.floorplan.buildingName),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteFloorplan,
          ),
        ],
      ),
      body: Column(
        children: [
          // Floorplan image (zoomable)
          Expanded(
            child: Container(
              color: Colors.grey[200],
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.network(
                    widget.floorplan.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 64, color: Colors.red),
                            SizedBox(height: 16),
                            Text('Failed to load image'),
                          ],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Details panel
          Container(
            padding: const EdgeInsets.all(24),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.floorplan.buildingName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Floor ${widget.floorplan.floorNumber}',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Status
                Row(
                  children: [
                    const Text('Status: '),
                    _buildStatusChip(widget.floorplan.status),
                  ],
                ),
                const SizedBox(height: 8),

                // Upload date
                Text(
                  'Uploaded: ${_formatDate(widget.floorplan.uploadedAt)}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),

                // Navigate button (disabled if not ready)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: widget.floorplan.status == 'ready'
                        ? () {
                            // TODO: Navigate to navigation screen
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Navigation coming soon!'),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.navigation),
                    label: Text(
                      widget.floorplan.status == 'ready'
                          ? 'Start Navigation'
                          : widget.floorplan.status == 'processing'
                          ? 'Processing...'
                          : 'Not Ready',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
