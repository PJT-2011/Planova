import 'package:flutter/material.dart';
import 'package:planova_mobile/models/room_marking.dart';
import 'package:planova_mobile/models/safety_marker_model.dart';
import 'package:planova_mobile/theme/app_theme.dart';

/// Shows the standardized legend for everything that can appear on a
/// floor map: room/area markings (no food, no smoking, restricted, quiet,
/// accessibility, under renovation, authorized only), emergency & safety
/// equipment, and the off-limits/renovation blur treatment itself.
///
/// [onlyMarkings] restricts the "Room & Area Markings" section to the
/// symbols actually in use on the current floor — pass null (default) to
/// show every marking so the legend still explains a symbol the person
/// hasn't encountered yet.
Future<void> showMapLegendSheet(
  BuildContext context, {
  List<RoomMarking>? onlyMarkings,
}) {
  final c = AppTheme.colors(context);
  final tt = Theme.of(context).textTheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final markings = onlyMarkings ?? RoomMarking.values;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2942) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
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
            const SizedBox(height: 20),

            _SectionHeader(title: 'Off-Limits / Renovation', c: c, tt: tt),
            const SizedBox(height: 10),
            _LegendRow(
              swatch: _BlurSwatch(),
              title: 'Off-limits area',
              subtitle:
                  'Under renovation or temporarily inaccessible. Cannot be '
                  'selected for navigation or access requests. An optional '
                  'Blur toggle on the map adds a blur effect on top.',
              c: c,
              tt: tt,
            ),
            const SizedBox(height: 20),

            _SectionHeader(title: 'Room & Area Markings', c: c, tt: tt),
            const SizedBox(height: 10),
            ...markings.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LegendRow(
                  swatch: _EmojiSwatch(emoji: m.emoji, color: m.colorFor(c)),
                  title: m.label,
                  subtitle: m.description,
                  c: c,
                  tt: tt,
                ),
              ),
            ),
            const SizedBox(height: 10),

            _SectionHeader(title: 'Emergency & Safety', c: c, tt: tt),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'These always stay visible, even over blurred/off-limits areas.',
                style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
              ),
            ),
            ...SafetyMarkerType.values.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _LegendRow(
                  swatch: _IconSwatch(icon: t.icon, color: t.color),
                  title: t.label,
                  subtitle: t == SafetyMarkerType.exitDirection
                      ? 'Arrow points toward the nearest emergency exit.'
                      : 'Exact equipment/exit location on this floor.',
                  c: c,
                  tt: tt,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final AppColors c;
  final TextTheme tt;
  const _SectionHeader({required this.title, required this.c, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: tt.labelSmall?.copyWith(
        color: c.onSurfaceTertiary,
        letterSpacing: 1.0,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Widget swatch;
  final String title;
  final String subtitle;
  final AppColors c;
  final TextTheme tt;

  const _LegendRow({
    required this.swatch,
    required this.title,
    required this.subtitle,
    required this.c,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        swatch,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: tt.bodyMedium?.copyWith(
                  color: c.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: tt.bodySmall?.copyWith(
                  color: c.onSurfaceSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmojiSwatch extends StatelessWidget {
  final String emoji;
  final Color color;
  const _EmojiSwatch({required this.emoji, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 16)),
    );
  }
}

class _IconSwatch extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconSwatch({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _BlurSwatch extends StatelessWidget {
  const _BlurSwatch();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: Colors.red, width: 1.5),
      ),
      child: const Icon(Icons.lock_rounded, color: Colors.red, size: 15),
    );
  }
}

/// Small floating round button that opens the legend sheet — drop this
/// into any map Stack.
class LegendButton extends StatelessWidget {
  final List<RoomMarking>? onlyMarkings;
  const LegendButton({super.key, this.onlyMarkings});

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => showMapLegendSheet(context, onlyMarkings: onlyMarkings),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xEE1C2942) : const Color(0xF5FFFFFF),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: c.border),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_rounded, color: c.primary, size: 15),
            const SizedBox(width: 6),
            Text(
              'Legend',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: c.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
