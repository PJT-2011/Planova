import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:planova_mobile/theme/app_theme.dart';

/// Renders an off-limits/renovation area on the user-facing map using the
/// exact same visual language as OffLimitsAreaScreen (where the admin
/// draws it): a red-tinted rectangle with a solid red border. That base
/// look never changes.
///
/// [blurEnabled] adds a real backdrop blur behind that same rectangle —
/// it never replaces the rectangle or changes its color/border/position.
/// With blurEnabled false, this renders as exactly the admin screen's
/// rectangle; with it true, that rectangle sits over a blurred floorplan.
class OffLimitsBlurOverlay extends StatelessWidget {
  final Rect rect;
  final String label;
  final bool blurEnabled;
  final double blurSigma;

  const OffLimitsBlurOverlay({
    super.key,
    required this.rect,
    this.label = 'Off-Limits',
    this.blurEnabled = true,
    this.blurSigma = 6,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (blurEnabled)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: const SizedBox.expand(),
              ),
            // Same fill + border as the admin's off-limits drawing tool.
            Container(
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.18),
                border: Border.all(color: Colors.red, width: 2),
              ),
            ),
            if (rect.width > 60 && rect.height > 26)
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.pinLabel,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    boxShadow: AppShadows.card,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded, size: 11, color: Colors.red),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.pinLabelText,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
