import 'package:flutter/material.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/services/floorplan_service.dart';
import 'package:planova_mobile/screens/navigation_screen.dart';

/// Shows real-time processing status while the Cloud Function
/// (Gemini + grid processor) runs in the background.
///
/// Automatically navigates to NavigationScreen when status = 'ready'.
/// Shows error message if status = 'failed'.
class FloorplanProcessingScreen extends StatefulWidget {
  final FloorplanModel floorplan;

  const FloorplanProcessingScreen({Key? key, required this.floorplan})
    : super(key: key);

  @override
  State<FloorplanProcessingScreen> createState() =>
      _FloorplanProcessingScreenState();
}

class _FloorplanProcessingScreenState extends State<FloorplanProcessingScreen> {
  final FloorplanService _service = FloorplanService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.floorplan.buildingName),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<FloorplanModel?>(
        stream: _service.watchFloorplan(widget.floorplan.floorplanId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildError('Connection error: ${snapshot.error}');
          }

          final floorplan = snapshot.data ?? widget.floorplan;

          switch (floorplan.status) {
            case 'uploaded':
              return _buildStep(
                icon: Icons.cloud_upload,
                color: Colors.blue,
                title: 'Uploaded',
                subtitle: 'Waiting for processing to begin...',
                progress: 0.1,
              );

            case 'processing':
              return _buildStep(
                icon: Icons.auto_awesome,
                color: Colors.orange,
                title: 'AI Processing',
                subtitle:
                    'Gemini is cleaning your floorplan.\nThis takes 20–60 seconds.',
                progress: 0.6,
                showSpinner: true,
              );

            case 'ready':
              // Auto-navigate when ready
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NavigationScreen(floorplan: floorplan),
                    ),
                  );
                }
              });
              return _buildStep(
                icon: Icons.check_circle,
                color: Colors.green,
                title: 'Ready!',
                subtitle: 'Opening navigation...',
                progress: 1.0,
              );

            case 'failed':
              return _buildError(
                floorplan.errorMessage ??
                    'Processing failed. Please try uploading again.',
              );

            default:
              return _buildStep(
                icon: Icons.hourglass_empty,
                color: Colors.grey,
                title: 'Waiting...',
                subtitle: 'Status: ${floorplan.status}',
                progress: 0.05,
              );
          }
        },
      ),
    );
  }

  Widget _buildStep({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required double progress,
    bool showSpinner = false,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon or spinner
            if (showSpinner)
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(strokeWidth: 6, color: color),
              )
            else
              Icon(icon, size: 80, color: color),

            const SizedBox(height: 24),

            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),

            const SizedBox(height: 32),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                color: color,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),

            const SizedBox(height: 48),

            // Processing steps indicator
            _buildStepsList(progress),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsList(double progress) {
    final steps = [
      ('Upload to cloud', 0.1),
      ('AI wall detection (Gemini)', 0.6),
      ('Build navigation grid', 0.85),
      ('Ready to navigate', 1.0),
    ];

    return Column(
      children: steps.map((step) {
        final done = progress >= step.$2;
        final active = !done && progress >= step.$2 - 0.3;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                done ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18,
                color: done
                    ? Colors.green
                    : active
                    ? Colors.orange
                    : Colors.grey[300],
              ),
              const SizedBox(width: 8),
              Text(
                step.$1,
                style: TextStyle(
                  color: done ? Colors.black87 : Colors.grey,
                  fontWeight: done ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 24),
            const Text(
              'Processing Failed',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
