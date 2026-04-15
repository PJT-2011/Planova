import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

class InteractiveFloorplanCanvas extends StatefulWidget {
  final String imageUrl;
  final bool isMockUrl;
  final Function(Offset)? onTap;
  final List<Offset>? markers;

  const InteractiveFloorplanCanvas({
    Key? key,
    required this.imageUrl,
    this.isMockUrl = false,
    this.onTap,
    this.markers,
  }) : super(key: key);

  @override
  State<InteractiveFloorplanCanvas> createState() =>
      _InteractiveFloorplanCanvasState();
}

class _InteractiveFloorplanCanvasState
    extends State<InteractiveFloorplanCanvas> {
  final TransformationController _transformationController =
      TransformationController();

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails details) {
    if (widget.onTap == null) return;

    // Get the current transformation matrix
    final Matrix4 transform = _transformationController.value;
    final Matrix4 invertedTransform = Matrix4.inverted(transform);

    // Convert screen coordinates to image coordinates
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final Offset localPosition = details.localPosition;

    // Apply inverse transformation to get position in image space
    final Vector3 position = invertedTransform.transform3(
      Vector3(localPosition.dx, localPosition.dy, 0),
    );

    final Offset imagePosition = Offset(position.x, position.y);

    print('🔵 Tap detected:');
    print('🔵 Screen position: $localPosition');
    print('🔵 Image position: $imagePosition');

    widget.onTap!(imagePosition);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTap,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 0.5,
        maxScale: 4.0,
        boundaryMargin: const EdgeInsets.all(double.infinity),
        child: Stack(
          children: [
            // Floorplan image
            _buildFloorplanImage(),

            // Markers overlay
            if (widget.markers != null && widget.markers!.isNotEmpty)
              ..._buildMarkers(),
          ],
        ),
      ),
    );
  }

  Widget _buildFloorplanImage() {
    if (widget.isMockUrl) {
      // Mock storage - load from file
      // This will be handled by the parent widget
      return Container(
        color: Colors.grey[200],
        child: const Center(child: Text('Image loaded from local storage')),
      );
    } else {
      // Firebase storage - load from network
      return Image.network(
        widget.imageUrl,
        fit: BoxFit.contain,
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
      );
    }
  }

  List<Widget> _buildMarkers() {
    return widget.markers!.asMap().entries.map((entry) {
      final int index = entry.key;
      final Offset position = entry.value;

      return Positioned(
        left: position.dx - 20,
        top: position.dy - 20,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: index == 0 ? Colors.green : Colors.red,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              index == 0 ? 'S' : 'E',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }
}
