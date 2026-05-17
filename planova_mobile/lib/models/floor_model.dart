import 'package:cloud_firestore/cloud_firestore.dart';

class FloorModel {
  final String id;
  final String buildingId;
  final String floorName;
  final int floorNumber;
  final String imageUrl;
  final Map<String, dynamic>? processedData; // Grid data from wall detection
  final int totalRooms;
  final DateTime uploadedAt;

  FloorModel({
    required this.id,
    required this.buildingId,
    required this.floorName,
    required this.floorNumber,
    required this.imageUrl,
    this.processedData,
    this.totalRooms = 0,
    required this.uploadedAt,
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'buildingId': buildingId,
      'floorName': floorName,
      'floorNumber': floorNumber,
      'imageUrl': imageUrl,
      'processedData': processedData,
      'totalRooms': totalRooms,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
    };
  }

  // Create from Firestore document
  factory FloorModel.fromJson(String id, Map<String, dynamic> json) {
    return FloorModel(
      id: id,
      buildingId: json['buildingId'] ?? '',
      floorName: json['floorName'] ?? '',
      floorNumber: json['floorNumber'] ?? 0,
      imageUrl: json['imageUrl'] ?? '',
      processedData: json['processedData'] as Map<String, dynamic>?,
      totalRooms: json['totalRooms'] ?? 0,
      uploadedAt:
          (json['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Copy with updated fields
  FloorModel copyWith({
    String? id,
    String? buildingId,
    String? floorName,
    int? floorNumber,
    String? imageUrl,
    Map<String, dynamic>? processedData,
    int? totalRooms,
    DateTime? uploadedAt,
  }) {
    return FloorModel(
      id: id ?? this.id,
      buildingId: buildingId ?? this.buildingId,
      floorName: floorName ?? this.floorName,
      floorNumber: floorNumber ?? this.floorNumber,
      imageUrl: imageUrl ?? this.imageUrl,
      processedData: processedData ?? this.processedData,
      totalRooms: totalRooms ?? this.totalRooms,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }
}
