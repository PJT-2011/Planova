import 'package:flutter/material.dart';
import 'package:planova_mobile/theme/app_theme.dart';

/// Standardized room/area indication flags an admin can attach to a
/// [RoomModel] (see RoomModel.markings, a list of `RoomMarking.name`
/// strings). These are purely informational overlays — unlike
/// [RoomModel.isOffLimits], having a marking never blocks navigation or
/// access requests on its own.
///
/// `underRenovation` is typically paired with isOffLimits/the admin-drawn
/// off-limits area — the marking explains why a room is blocked; the
/// off-limits flag is what actually blocks it. Setting the marking alone
/// blocks nothing.
enum RoomMarking {
  noFood,
  noSmoking,
  restrictedArea,
  quietArea,
  accessibility,
  underRenovation,
  authorizedOnly,
}

extension RoomMarkingX on RoomMarking {
  String get label {
    switch (this) {
      case RoomMarking.noFood:
        return 'No Food / No Eating';
      case RoomMarking.noSmoking:
        return 'No Smoking';
      case RoomMarking.restrictedArea:
        return 'Restricted Area';
      case RoomMarking.quietArea:
        return 'Quiet Area';
      case RoomMarking.accessibility:
        return 'Accessibility / PWD Access';
      case RoomMarking.underRenovation:
        return 'Under Renovation';
      case RoomMarking.authorizedOnly:
        return 'Authorized Personnel Only';
    }
  }

  /// Widely-recognized emoji/symbol for this marking — used in compact
  /// badges and the legend, matching the symbols requested for this
  /// feature.
  String get emoji {
    switch (this) {
      case RoomMarking.noFood:
        return '🚫';
      case RoomMarking.noSmoking:
        return '🚭';
      case RoomMarking.restrictedArea:
        return '⚠️';
      case RoomMarking.quietArea:
        return '🔇';
      case RoomMarking.accessibility:
        return '♿';
      case RoomMarking.underRenovation:
        return '🚧';
      case RoomMarking.authorizedOnly:
        return '🔒';
    }
  }

  IconData get icon {
    switch (this) {
      case RoomMarking.noFood:
        return Icons.no_food_rounded;
      case RoomMarking.noSmoking:
        return Icons.smoke_free_rounded;
      case RoomMarking.restrictedArea:
        return Icons.warning_amber_rounded;
      case RoomMarking.quietArea:
        return Icons.volume_off_rounded;
      case RoomMarking.accessibility:
        return Icons.accessible_rounded;
      case RoomMarking.underRenovation:
        return Icons.construction_rounded;
      case RoomMarking.authorizedOnly:
        return Icons.lock_rounded;
    }
  }

  Color colorFor(AppColors c) {
    switch (this) {
      case RoomMarking.noFood:
      case RoomMarking.noSmoking:
        return c.error;
      case RoomMarking.restrictedArea:
        return c.warning;
      case RoomMarking.quietArea:
        return c.primary;
      case RoomMarking.accessibility:
        return const Color(0xFF22C55E);
      case RoomMarking.underRenovation:
        return c.warning;
      case RoomMarking.authorizedOnly:
        return c.error;
    }
  }

  String get description {
    switch (this) {
      case RoomMarking.noFood:
        return 'Eating and drinking are not allowed in this area.';
      case RoomMarking.noSmoking:
        return 'Smoking is prohibited in this area.';
      case RoomMarking.restrictedArea:
        return 'Entry is limited — check with staff before proceeding.';
      case RoomMarking.quietArea:
        return 'Please keep noise to a minimum.';
      case RoomMarking.accessibility:
        return 'Wheelchair-accessible / PWD-friendly area.';
      case RoomMarking.underRenovation:
        return 'Temporarily inaccessible due to renovation work. Shown '
            'blurred on the map and cannot be selected for navigation or '
            'access requests.';
      case RoomMarking.authorizedOnly:
        return 'Only authorized personnel may enter.';
    }
  }
}

RoomMarking? roomMarkingFromString(String value) {
  for (final m in RoomMarking.values) {
    if (m.name == value) return m;
  }
  return null;
}

List<RoomMarking> parseRoomMarkings(List<dynamic>? raw) {
  if (raw == null) return const [];
  return raw
      .map((e) => roomMarkingFromString(e.toString()))
      .whereType<RoomMarking>()
      .toList();
}
