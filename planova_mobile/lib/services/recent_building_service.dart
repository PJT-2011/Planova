import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planova_mobile/models/building_model.dart';

/// Stores a lightweight snapshot of a building the user recently accessed.
/// Persisted locally via shared_preferences — works for both guests and
/// logged-in users without requiring a Firebase round-trip.
class RecentBuildingEntry {
  final String buildingId;
  final String buildingName;
  final String address;
  final int totalFloors;
  final int totalRooms;
  final DateTime accessedAt;

  RecentBuildingEntry({
    required this.buildingId,
    required this.buildingName,
    required this.address,
    required this.totalFloors,
    required this.totalRooms,
    required this.accessedAt,
  });

  factory RecentBuildingEntry.fromBuilding(BuildingModel building) {
    return RecentBuildingEntry(
      buildingId: building.id,
      buildingName: building.buildingName,
      address: building.address,
      totalFloors: building.totalFloors,
      totalRooms: building.totalRooms,
      accessedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'buildingId': buildingId,
    'buildingName': buildingName,
    'address': address,
    'totalFloors': totalFloors,
    'totalRooms': totalRooms,
    'accessedAt': accessedAt.toIso8601String(),
  };

  factory RecentBuildingEntry.fromJson(Map<String, dynamic> json) {
    return RecentBuildingEntry(
      buildingId: json['buildingId'] ?? '',
      buildingName: json['buildingName'] ?? '',
      address: json['address'] ?? '',
      totalFloors: json['totalFloors'] ?? 0,
      totalRooms: json['totalRooms'] ?? 0,
      accessedAt: DateTime.tryParse(json['accessedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class RecentBuildingService {
  // Use a per-user key so admins and guests don't share history.
  // Pass 'guest' for unauthenticated users.
  static String _key(String userId) => 'recent_buildings_$userId';

  static const int _maxEntries = 5;

  /// Save a building to the recent list (most-recent first, no duplicates).
  Future<void> saveRecentBuilding(String userId, BuildingModel building) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = await getRecentBuildings(userId);

      // Remove existing entry for this building (we'll re-insert at the top)
      entries.removeWhere((e) => e.buildingId == building.id);

      // Insert at the front
      entries.insert(0, RecentBuildingEntry.fromBuilding(building));

      // Keep only the most recent N entries
      final trimmed = entries.take(_maxEntries).toList();

      final encoded = jsonEncode(trimmed.map((e) => e.toJson()).toList());
      await prefs.setString(_key(userId), encoded);

      debugPrint(
        '✅ [RecentBuildingService] Saved "${building.buildingName}" for user $userId',
      );
    } catch (e) {
      debugPrint('❌ [RecentBuildingService] Failed to save: $e');
    }
  }

  /// Load the recent buildings list for a user.
  Future<List<RecentBuildingEntry>> getRecentBuildings(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null) return [];

      final List<dynamic> decoded = jsonDecode(raw);
      return decoded
          .map((e) => RecentBuildingEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ [RecentBuildingService] Failed to load: $e');
      return [];
    }
  }

  /// Remove a single entry (e.g. user explicitly dismisses it).
  Future<void> removeRecentBuilding(String userId, String buildingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = await getRecentBuildings(userId);
      entries.removeWhere((e) => e.buildingId == buildingId);
      final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
      await prefs.setString(_key(userId), encoded);
    } catch (e) {
      debugPrint('❌ [RecentBuildingService] Failed to remove: $e');
    }
  }

  /// Clear all recent buildings for a user.
  Future<void> clearRecentBuildings(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(userId));
    } catch (e) {
      debugPrint('❌ [RecentBuildingService] Failed to clear: $e');
    }
  }
}
