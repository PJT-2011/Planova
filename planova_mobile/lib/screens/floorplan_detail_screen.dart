import 'dart:io';
import 'package:flutter/material.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/services/floorplan_service.dart';
import 'package:planova_mobile/services/mock_storage_service.dart';
import 'package:planova_mobile/screens/navigation_screen.dart';
import 'package:planova_mobile/theme/app_theme.dart';
import 'package:planova_mobile/main.dart';

class FloorplanDetailScreen extends StatefulWidget {
  final FloorplanModel floorplan;
  const FloorplanDetailScreen({Key? key, required this.floorplan})
    : super(key: key);

  @override
  State<FloorplanDetailScreen> createState() => _FloorplanDetailScreenState();
}

class _FloorplanDetailScreenState extends State<FloorplanDetailScreen> {
  final FloorplanService _floorplanService = FloorplanService();
  final TransformationController _transformController =
      TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  // ── Delete with confirmation sheet ────────────────────────────────────────

  Future<void> _deleteFloorplan() async {
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
              color: Colors.black.withValues(alpha: 0.20),
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
                        'Delete Floorplan?',
                        style: tt.headlineSmall?.copyWith(
                          color: c.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.floorplan.buildingName,
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
                      'This will permanently delete this floorplan and cannot be undone.',
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
                    'Yes, Delete',
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
        await _floorplanService.deleteFloorplan(
          widget.floorplan.floorplanId,
          widget.floorplan.imageUrl,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Floorplan deleted'),
              backgroundColor: AppTheme.colors(context).success,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Delete failed: $e'),
              backgroundColor: AppTheme.colors(context).error,
            ),
          );
      }
    }
  }

  Future<void> _startNavigation() async {
    if (widget.floorplan.status != 'ready') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please wait for floorplan processing to complete',
          ),
          backgroundColor: AppTheme.colors(context).warning,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      PlanovaModalRoute(
        builder: (_) => NavigationScreen(floorplan: widget.floorplan),
      ),
    );
  }

  Widget _buildFloorplanImage() {
    final url = widget.floorplan.imageUrl;
    if (MockStorageService.isMockUrl(url)) {
      return Image.file(
        MockStorageService().getLocalFile(url),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _imageError(),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.contain,
      loadingBuilder: (_, child, prog) {
        if (prog == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: prog.expectedTotalBytes != null
                ? prog.cumulativeBytesLoaded / prog.expectedTotalBytes!
                : null,
            color: AppTheme.colors(context).primary,
          ),
        );
      },
      errorBuilder: (_, __, ___) => _imageError(),
    );
  }

  Widget _imageError() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.broken_image_rounded,
          size: 56,
          color: AppTheme.colors(context).onSurfaceTertiary,
        ),
        const SizedBox(height: 12),
        Text(
          'Failed to load image',
          style: TextStyle(color: AppTheme.colors(context).onSurfaceSecondary),
        ),
      ],
    ),
  );

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
        title: Text(
          widget.floorplan.buildingName,
          style: tt.titleLarge?.copyWith(color: c.onBackground),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.fit_screen_rounded,
              color: c.onBackground,
              size: 22,
            ),
            onPressed: _resetZoom,
            tooltip: 'Reset zoom',
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: c.error, size: 22),
            onPressed: _deleteFloorplan,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Floorplan image viewer ──────────────────────────────────────
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF111D30) : const Color(0xFFE8EDF5),
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.5,
                maxScale: 5.0,
                child: Center(child: _buildFloorplanImage()),
              ),
            ),
          ),

          // ── Detail panel ────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).padding.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C2942) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: AppShadows.modal,
              border: Border(top: BorderSide(color: c.border, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
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

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.floorplan.buildingName,
                            style: tt.titleLarge?.copyWith(
                              color: c.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Floor ${widget.floorplan.floorNumber}',
                            style: tt.bodyMedium?.copyWith(
                              color: c.onSurfaceSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(status: widget.floorplan.status, c: c, tt: tt),
                  ],
                ),
                const SizedBox(height: 14),

                // Meta row
                Row(
                  children: [
                    _MetaChip(
                      icon:
                          MockStorageService.isMockUrl(
                            widget.floorplan.imageUrl,
                          )
                          ? Icons.storage_rounded
                          : Icons.cloud_done_rounded,
                      label:
                          MockStorageService.isMockUrl(
                            widget.floorplan.imageUrl,
                          )
                          ? 'Local (Demo)'
                          : 'Firebase Cloud',
                      c: c,
                      tt: tt,
                    ),
                    const SizedBox(width: 8),
                    _MetaChip(
                      icon: Icons.calendar_today_rounded,
                      label: _formatDate(widget.floorplan.uploadedAt),
                      c: c,
                      tt: tt,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Navigate button
                GestureDetector(
                  onTap: widget.floorplan.status == 'ready'
                      ? _startNavigation
                      : null,
                  child: AnimatedOpacity(
                    opacity: widget.floorplan.status == 'ready' ? 1.0 : 0.5,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      height: 54,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: heroGradient(),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        boxShadow: widget.floorplan.status == 'ready'
                            ? AppShadows.primaryGlow(c.primary)
                            : [],
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
                            widget.floorplan.status == 'ready'
                                ? 'Start Navigation'
                                : widget.floorplan.status == 'processing'
                                ? 'Processing...'
                                : 'Not Ready',
                            style: tt.labelLarge?.copyWith(color: Colors.white),
                          ),
                        ],
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

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

// ── Status chip ───────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  final AppColors c;
  final TextTheme tt;
  const _StatusChip({required this.status, required this.c, required this.tt});

  @override
  Widget build(BuildContext context) {
    late Color color;
    late IconData icon;
    late String label;

    switch (status) {
      case 'ready':
        color = const Color(0xFF22C55E);
        icon = Icons.check_circle_rounded;
        label = 'Ready';
        break;
      case 'processing':
        color = const Color(0xFFF59E0B);
        icon = Icons.hourglass_top_rounded;
        label = 'Processing';
        break;
      case 'failed':
        color = c.error;
        icon = Icons.error_rounded;
        label = 'Failed';
        break;
      default:
        color = c.primary;
        icon = Icons.cloud_upload_rounded;
        label = 'Uploaded';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meta chip ─────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppColors c;
  final TextTheme tt;
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.c,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.chipFill,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c.chipText),
          const SizedBox(width: 5),
          Text(label, style: tt.labelSmall?.copyWith(color: c.chipText)),
        ],
      ),
    );
  }
}
