import 'package:flutter/material.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/services/floorplan_service.dart';
import 'package:planova_mobile/screens/navigation_screen.dart';
import 'package:planova_mobile/theme/app_theme.dart';
import 'package:planova_mobile/main.dart';

class FloorplanProcessingScreen extends StatefulWidget {
  final FloorplanModel floorplan;
  const FloorplanProcessingScreen({Key? key, required this.floorplan})
    : super(key: key);

  @override
  State<FloorplanProcessingScreen> createState() =>
      _FloorplanProcessingScreenState();
}

class _FloorplanProcessingScreenState extends State<FloorplanProcessingScreen>
    with SingleTickerProviderStateMixin {
  final FloorplanService _service = FloorplanService();
  late AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

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
        automaticallyImplyLeading: false,
        title: Text(
          widget.floorplan.buildingName,
          style: tt.titleLarge?.copyWith(color: c.onBackground),
        ),
      ),
      body: StreamBuilder<FloorplanModel?>(
        stream: _service.watchFloorplan(widget.floorplan.floorplanId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildError(
              'Connection error: ${snapshot.error}',
              c,
              tt,
              isDark,
            );
          }
          final floorplan = snapshot.data ?? widget.floorplan;

          switch (floorplan.status) {
            case 'uploaded':
              return _buildStep(
                status: 'uploaded',
                progress: 0.1,
                c: c,
                tt: tt,
                isDark: isDark,
              );
            case 'processing':
              return _buildStep(
                status: 'processing',
                progress: 0.6,
                c: c,
                tt: tt,
                isDark: isDark,
              );
            case 'ready':
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted)
                  Navigator.pushReplacement(
                    context,
                    PlanovaModalRoute(
                      builder: (_) => NavigationScreen(floorplan: floorplan),
                    ),
                  );
              });
              return _buildStep(
                status: 'ready',
                progress: 1.0,
                c: c,
                tt: tt,
                isDark: isDark,
              );
            case 'failed':
              return _buildError(
                floorplan.errorMessage ??
                    'Processing failed. Please try uploading again.',
                c,
                tt,
                isDark,
              );
            default:
              return _buildStep(
                status: 'waiting',
                progress: 0.05,
                c: c,
                tt: tt,
                isDark: isDark,
              );
          }
        },
      ),
    );
  }

  Widget _buildStep({
    required String status,
    required double progress,
    required AppColors c,
    required TextTheme tt,
    required bool isDark,
  }) {
    final isProcessing = status == 'processing';
    final isReady = status == 'ready';

    final steps = [
      _StepData('Upload to cloud', 0.10, Icons.cloud_upload_rounded),
      _StepData('AI wall detection (Gemini)', 0.60, Icons.auto_awesome_rounded),
      _StepData('Build navigation grid', 0.85, Icons.grid_on_rounded),
      _StepData('Ready to navigate', 1.00, Icons.check_circle_rounded),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // ── Animated icon area ──────────────────────────────────────────
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer ring
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        (isReady
                                ? const Color(0xFF22C55E)
                                : isProcessing
                                ? c.primary
                                : c.primary)
                            .withValues(alpha: 0.08),
                  ),
                ),
                // Spinning arc (processing only)
                if (isProcessing)
                  RotationTransition(
                    turns: _spinController,
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        color: c.primary.withValues(alpha: 0.4),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),
                // Inner circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isReady
                        ? const LinearGradient(
                            colors: [Color(0xFF0D8050), Color(0xFF22C55E)],
                          )
                        : heroGradient(),
                    boxShadow: [
                      BoxShadow(
                        color: (isReady ? const Color(0xFF22C55E) : c.primary)
                            .withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    isReady
                        ? Icons.check_rounded
                        : isProcessing
                        ? Icons.auto_awesome_rounded
                        : Icons.cloud_upload_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // ── Title & subtitle ────────────────────────────────────────────
          Text(
            isReady
                ? 'Ready!'
                : isProcessing
                ? 'AI Processing'
                : 'Uploaded',
            style: tt.displaySmall?.copyWith(
              color: c.onBackground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isReady
                ? 'Opening navigation...'
                : isProcessing
                ? 'Gemini is analysing your floorplan.\nThis takes 20–60 seconds.'
                : 'Waiting for processing to begin...',
            style: tt.bodyLarge?.copyWith(
              color: c.onSurfaceSecondary,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // ── Progress bar ────────────────────────────────────────────────
          Container(
            decoration: isDark
                ? BoxDecoration(
                    color: const Color(0xFF1C2942),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  )
                : lightCardDecoration(),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: tt.titleSmall?.copyWith(color: c.onSurface),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: tt.titleSmall?.copyWith(
                        color: isReady ? const Color(0xFF22C55E) : c.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: c.border,
                    valueColor: AlwaysStoppedAnimation(
                      isReady ? const Color(0xFF22C55E) : c.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Steps list
                ...steps.map((step) {
                  final done = progress >= step.threshold;
                  final active = !done && progress >= step.threshold - 0.35;
                  final color = done
                      ? const Color(0xFF22C55E)
                      : active
                      ? c.primary
                      : c.onSurfaceTertiary;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: done
                                ? const Color(
                                    0xFF22C55E,
                                  ).withValues(alpha: 0.12)
                                : active
                                ? c.primary.withValues(alpha: 0.10)
                                : c.border.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Icon(
                            done ? Icons.check_rounded : step.icon,
                            size: 16,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          step.label,
                          style: tt.bodyMedium?.copyWith(
                            color: done ? c.onSurface : c.onSurfaceSecondary,
                            fontWeight: done
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message, AppColors c, TextTheme tt, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: c.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 52,
                color: c.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Processing Failed',
              style: tt.headlineLarge?.copyWith(
                color: c.onBackground,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: c.onSurfaceSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => Navigator.pop(context),
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
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Go Back',
                      style: tt.labelLarge?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepData {
  final String label;
  final double threshold;
  final IconData icon;
  const _StepData(this.label, this.threshold, this.icon);
}
