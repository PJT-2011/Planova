import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planova_mobile/models/floor_access_model.dart';

class BuildingModel {
  final String id;
  final String buildingName;
  final String address;
  final String createdBy;
  final String qrCode;
  final String? qrCodeImageUrl;
  final DateTime createdAt;
  final int totalFloors;
  final int totalRooms;

  // Which floors scanning this building's QR code grants access to.
  // Defaults to "all" so buildings created before this feature keep
  // behaving exactly as before until an admin explicitly restricts them.
  final FloorAccessType qrFloorAccessType;
  final List<int> qrFloorNumbers; // used when qrFloorAccessType == selected

  BuildingModel({
    required this.id,
    required this.buildingName,
    required this.address,
    required this.createdBy,
    required this.qrCode,
    this.qrCodeImageUrl,
    required this.createdAt,
    this.totalFloors = 0,
    this.totalRooms = 0,
    this.qrFloorAccessType = FloorAccessType.all,
    this.qrFloorNumbers = const [],
  });

  // Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'buildingName': buildingName,
      'address': address,
      'createdBy': createdBy,
      'qrCode': qrCode,
      'qrCodeImageUrl': qrCodeImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'totalFloors': totalFloors,
      'totalRooms': totalRooms,
      'qrFloorAccessType': qrFloorAccessType.name,
      'qrFloorNumbers': qrFloorNumbers,
    };
  }

  // Create from Firestore document
  factory BuildingModel.fromJson(String id, Map<String, dynamic> json) {
    return BuildingModel(
      id: id,
      buildingName: json['buildingName'] ?? '',
      address: json['address'] ?? '',
      createdBy: json['createdBy'] ?? '',
      qrCode: json['qrCode'] ?? '',
      qrCodeImageUrl: json['qrCodeImageUrl'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalFloors: json['totalFloors'] ?? 0,
      totalRooms: json['totalRooms'] ?? 0,
      qrFloorAccessType: json['qrFloorAccessType'] == 'selected'
          ? FloorAccessType.selected
          : FloorAccessType.all,
      qrFloorNumbers: List<int>.from(json['qrFloorNumbers'] ?? const []),
    );
  }

  // Copy with updated fields
  BuildingModel copyWith({
    String? id,
    String? buildingName,
    String? address,
    String? createdBy,
    String? qrCode,
    String? qrCodeImageUrl,
    DateTime? createdAt,
    int? totalFloors,
    int? totalRooms,
    FloorAccessType? qrFloorAccessType,
    List<int>? qrFloorNumbers,
  }) {
    return BuildingModel(
      id: id ?? this.id,
      buildingName: buildingName ?? this.buildingName,
      address: address ?? this.address,
      createdBy: createdBy ?? this.createdBy,
      qrCode: qrCode ?? this.qrCode,
      qrCodeImageUrl: qrCodeImageUrl ?? this.qrCodeImageUrl,
      createdAt: createdAt ?? this.createdAt,
      totalFloors: totalFloors ?? this.totalFloors,
      totalRooms: totalRooms ?? this.totalRooms,
      qrFloorAccessType: qrFloorAccessType ?? this.qrFloorAccessType,
      qrFloorNumbers: qrFloorNumbers ?? this.qrFloorNumbers,
    );
  }
}
