// ============================================================
// skeletons.dart — Planova Skeleton Loaders
// Shimmer-style animated placeholders for loading states.
// Drop these in wherever a list shows a CircularProgressIndicator.
//
// Usage:
//   if (_isLoading) return const BuildingListSkeleton();
//   if (_isLoading) return const FloorListSkeleton();
//   if (_isLoading) return const RecentBuildingsSkeleton();
// ============================================================

import 'package:flutter/material.dart';
import 'package:planova_mobile/theme/app_theme.dart';

// ── Core shimmer animation ────────────────────────────────────────────────────

class _Shimmer extends StatefulWidget {
  final Widget child;
  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(
      begin: -1.5,
      end: 2.5,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark
        ? const Color(0xFF1C2942)
        : const Color(0xFFE5EDF8);
    final highlightColor = isDark
        ? const Color(0xFF243450)
        : const Color(0xFFF0F4FF);

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [baseColor, highlightColor, baseColor],
          stops: [
            (_anim.value - 0.5).clamp(0.0, 1.0),
            _anim.value.clamp(0.0, 1.0),
            (_anim.value + 0.5).clamp(0.0, 1.0),
          ],
        ).createShader(bounds),
        child: widget.child,
      ),
    );
  }
}

// ── Skeleton box primitive ────────────────────────────────────────────────────

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 8,
  });

  const _SkeletonBox.circle({required double size})
    : width = size,
      height = size,
      radius = size / 2;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2942) : const Color(0xFFE5EDF8),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// BUILDING LIST SKELETON
// Mimics the building management card layout
// ═════════════════════════════════════════════════════════════════════════════

class BuildingListSkeleton extends StatelessWidget {
  final int count;
  const BuildingListSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        itemCount: count,
        itemBuilder: (_, __) => const _BuildingCardSkeleton(),
      ),
    );
  }
}

class _BuildingCardSkeleton extends StatelessWidget {
  const _BuildingCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: isDark
          ? BoxDecoration(
              color: const Color(0xFF1C2942),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            )
          : lightCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + title row
          Row(
            children: [
              const _SkeletonBox(width: 50, height: 50, radius: 10),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _SkeletonBox(width: 160, height: 14, radius: 6),
                    SizedBox(height: 8),
                    _SkeletonBox(width: 110, height: 11, radius: 5),
                  ],
                ),
              ),
              const _SkeletonBox(width: 32, height: 32, radius: 8),
            ],
          ),
          const SizedBox(height: 14),
          // Chips
          Row(
            children: const [
              _SkeletonBox(width: 80, height: 26, radius: 13),
              SizedBox(width: 8),
              _SkeletonBox(width: 80, height: 26, radius: 13),
            ],
          ),
          const SizedBox(height: 14),
          // Swipe hint
          const _SkeletonBox(width: 100, height: 10, radius: 5),
          const SizedBox(height: 12),
          // Buttons
          Row(
            children: const [
              Expanded(
                child: _SkeletonBox(
                  width: double.infinity,
                  height: 42,
                  radius: 10,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _SkeletonBox(
                  width: double.infinity,
                  height: 42,
                  radius: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FLOOR LIST SKELETON
// Mimics the floor management card layout
// ═════════════════════════════════════════════════════════════════════════════

class FloorListSkeleton extends StatelessWidget {
  final int count;
  const FloorListSkeleton({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        itemCount: count,
        itemBuilder: (_, __) => const _FloorCardSkeleton(),
      ),
    );
  }
}

class _FloorCardSkeleton extends StatelessWidget {
  const _FloorCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: isDark
          ? BoxDecoration(
              color: const Color(0xFF1C2942),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            )
          : lightCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Floor number badge
              const _SkeletonBox(width: 50, height: 50, radius: 10),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _SkeletonBox(width: 130, height: 14, radius: 6),
                    SizedBox(height: 8),
                    _SkeletonBox(width: 90, height: 11, radius: 5),
                  ],
                ),
              ),
              const _SkeletonBox(width: 32, height: 32, radius: 8),
            ],
          ),
          const SizedBox(height: 14),
          const _SkeletonBox(width: 100, height: 10, radius: 5),
          const SizedBox(height: 12),
          const _SkeletonBox(width: double.infinity, height: 44, radius: 10),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// RECENT BUILDINGS SKELETON
// Mimics the home/guest recent buildings card layout
// ═════════════════════════════════════════════════════════════════════════════

class RecentBuildingsSkeleton extends StatelessWidget {
  final int count;
  const RecentBuildingsSkeleton({super.key, this.count = 2});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _SkeletonBox(width: 140, height: 14, radius: 6),
              _SkeletonBox(width: 60, height: 12, radius: 5),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(count, (_) => const _RecentCardSkeleton()),
        ],
      ),
    );
  }
}

class _RecentCardSkeleton extends StatelessWidget {
  const _RecentCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: isDark
          ? BoxDecoration(
              color: const Color(0xFF1C2942),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            )
          : lightCardDecoration(),
      child: Row(
        children: [
          const _SkeletonBox(width: 46, height: 46, radius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBox(width: 130, height: 13, radius: 5),
                const SizedBox(height: 6),
                const _SkeletonBox(width: 90, height: 10, radius: 4),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    _SkeletonBox(width: 70, height: 22, radius: 11),
                    SizedBox(width: 6),
                    _SkeletonBox(width: 70, height: 22, radius: 11),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              _SkeletonBox(width: 40, height: 10, radius: 4),
              SizedBox(height: 8),
              _SkeletonBox(width: 18, height: 18, radius: 9),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// FLOOR SELECTION ROOM LIST SKELETON
// Mimics the room cards in floor selection screen
// ═════════════════════════════════════════════════════════════════════════════

class RoomListSkeleton extends StatelessWidget {
  final int count;
  const RoomListSkeleton({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: count,
        itemBuilder: (_, __) => const _RoomCardSkeleton(),
      ),
    );
  }
}

class _RoomCardSkeleton extends StatelessWidget {
  const _RoomCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: isDark
          ? BoxDecoration(
              color: const Color(0xFF1C2942),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            )
          : lightCardDecoration(),
      child: Row(
        children: [
          const _SkeletonBox(width: 44, height: 44, radius: 10),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkeletonBox(width: 120, height: 13, radius: 5),
                SizedBox(height: 6),
                _SkeletonBox(width: 80, height: 10, radius: 4),
              ],
            ),
          ),
          const _SkeletonBox(width: 20, height: 20, radius: 10),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// HOME SCREEN ACTION CARDS SKELETON
// Mimics the two action cards before data loads
// ═════════════════════════════════════════════════════════════════════════════

class ActionCardsSkeleton extends StatelessWidget {
  const ActionCardsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Row(
        children: [
          Expanded(child: _ActionCardSkeleton()),
          const SizedBox(width: 12),
          Expanded(child: _ActionCardSkeleton()),
        ],
      ),
    );
  }
}

class _ActionCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: isDark
          ? BoxDecoration(
              color: const Color(0xFF1C2942),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: const Color(0x1AFFFFFF)),
            )
          : lightCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SkeletonBox(width: 48, height: 48, radius: 10),
          SizedBox(height: 12),
          _SkeletonBox(width: 100, height: 14, radius: 6),
          SizedBox(height: 8),
          _SkeletonBox(width: 80, height: 10, radius: 4),
          SizedBox(height: 14),
          _SkeletonBox(width: double.infinity, height: 40, radius: 10),
        ],
      ),
    );
  }
}
