import 'package:flutter/material.dart';
import 'package:planova_mobile/models/safety_marking_model.dart';
import 'package:planova_mobile/theme/app_theme.dart';

/// Icon + color for one [SafetyMarkingType]. Kept as a single lookup table
/// (below) rather than duplicated per-screen switch statements, so the
/// admin's palette icon, the marker drawn on the map, and the Map Legend
/// entry can never fall out of sync with each other.
class SafetyMarkingStyle {
  final IconData icon;
  final Color color;
  const SafetyMarkingStyle(this.icon, this.color);
}

const Map<SafetyMarkingType, SafetyMarkingStyle> kSafetyMarkingStyles = {
  SafetyMarkingType.emergencyExit: SafetyMarkingStyle(
    Icons.directions_run_rounded,
    Color(0xFF22C55E),
  ),
  SafetyMarkingType.fireExtinguisher: SafetyMarkingStyle(
    Icons.fire_extinguisher_rounded,
    Color(0xFFEF4444),
  ),
  SafetyMarkingType.noFoodAllowed: SafetyMarkingStyle(
    Icons.no_food_rounded,
    Color(0xFFF59E0B),
  ),
  SafetyMarkingType.noEntry: SafetyMarkingStyle(
    Icons.do_not_disturb_on_rounded,
    Color(0xFFEF4444),
  ),
  SafetyMarkingType.restroom: SafetyMarkingStyle(
    Icons.wc_rounded,
    Color(0xFF1A6ADB),
  ),
  SafetyMarkingType.firstAidStation: SafetyMarkingStyle(
    Icons.medical_services_rounded,
    Color(0xFF22C55E),
  ),
  SafetyMarkingType.fireAlarm: SafetyMarkingStyle(
    Icons.notifications_active_rounded,
    Color(0xFFEF4444),
  ),
  SafetyMarkingType.other: SafetyMarkingStyle(
    Icons.info_rounded,
    Color(0xFF8FA3C8),
  ),
};

SafetyMarkingStyle styleForMarking(SafetyMarkingType type) =>
    kSafetyMarkingStyles[type] ?? kSafetyMarkingStyles[SafetyMarkingType.other]!;

/// Map Legend bottom sheet — every safety/facility marking type plus the
/// two other map indicators (off-limits areas, access-controlled doors),
/// each with its icon and meaning. Opened identically from Room Mapping
/// (admin) and Navigation (user) so both sides always see the same key.
void showSafetyMarkingLegend(BuildContext context) {
  final c = AppTheme.colors(context);
  final tt = Theme.of(context).textTheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2942) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 32,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Icon(Icons.map_rounded, color: c.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Map Legend',
                  style: tt.headlineSmall?.copyWith(
                    color: c.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  ...SafetyMarkingType.values.map((type) {
                    final style = styleForMarking(type);
                    return _LegendRow(
                      icon: style.icon,
                      color: style.color,
                      label: type.defaultLabel,
                      c: c,
                      tt: tt,
                    );
                  }),
                  Divider(height: 28, color: c.divider),
                  _LegendRow(
                    icon: Icons.lock_rounded,
                    color: Colors.red.shade600,
                    label: 'Off-Limits Area',
                    c: c,
                    tt: tt,
                  ),
                  _LegendRow(
                    icon: Icons.sensor_door_rounded,
                    color: const Color(0xFFF59E0B),
                    label: 'Access-Controlled Door',
                    c: c,
                    tt: tt,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LegendRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final AppColors c;
  final TextTheme tt;

  const _LegendRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.c,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(
                color: c.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
