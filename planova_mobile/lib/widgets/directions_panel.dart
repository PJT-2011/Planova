import 'package:flutter/material.dart';

/// Google Maps-style top turn-by-turn instruction banner.
/// Shows the CURRENT step prominently at the top, with the next step below.
class DirectionsPanel extends StatelessWidget {
  final List<String> directions;
  final int currentStepIndex;
  final VoidCallback? onClose;

  const DirectionsPanel({
    Key? key,
    required this.directions,
    this.currentStepIndex = 0,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (directions.isEmpty) return const SizedBox.shrink();

    final current = currentStepIndex < directions.length
        ? directions[currentStepIndex]
        : null;
    final next = currentStepIndex + 1 < directions.length
        ? directions[currentStepIndex + 1]
        : null;

    if (current == null) return const SizedBox.shrink();

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Primary instruction banner (Google Maps green card) ──
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A73E8), // Google Maps blue
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    // Direction icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _iconForDirection(current),
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Instruction text
                    Expanded(
                      child: Text(
                        current,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Close button
                    if (onClose != null)
                      GestureDetector(
                        onTap: onClose,
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── "Then" next-step sub-banner ──
            if (next != null) ...[
              const SizedBox(height: 4),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D47A1),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Then  ',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Icon(
                        _iconForDirection(next),
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          next,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForDirection(String direction) {
    final d = direction.toLowerCase();
    if (d.contains('left')) return Icons.turn_left;
    if (d.contains('right')) return Icons.turn_right;
    if (d.contains('straight') ||
        d.contains('continue') ||
        d.contains('head')) {
      return Icons.straight;
    }
    if (d.contains('arrive') ||
        d.contains('destination') ||
        d.contains('end')) {
      return Icons.flag;
    }
    if (d.contains('start') || d.contains('depart')) {
      return Icons.radio_button_checked;
    }
    if (d.contains('u-turn') || d.contains('uturn')) return Icons.u_turn_left;
    return Icons.navigation;
  }
}
