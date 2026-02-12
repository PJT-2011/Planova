import 'package:cloud_firestore/cloud_firestore.dart';

class FloorplanModel {
  final String floorplanId;
  final String userId;
  final String buildingName;
  final int floorNumber;
  final String imageUrl;
  final String? thumbnailUrl;
  final DateTime uploadedAt;
  final DateTime? processedAt;
  final String status; // 'uploaded', 'processing', 'ready', 'failed'
  final Map<String, dynamic>? processedData;
  final bool isPublic;
  final List<String> tags;

  FloorplanModel({
    required this.floorplanId,
    required this.userId,
    required this.buildingName,
    required this.floorNumber,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.uploadedAt,
    this.processedAt,
    required this.status,
    this.processedData,
    this.isPublic = false,
    this.tags = const [],
  });

  // Create from Firestore document
  factory FloorplanModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return FloorplanModel(
      floorplanId: doc.id,
      userId: data['userId'] ?? '',
      buildingName: data['buildingName'] ?? '',
      floorNumber: data['floorNumber'] ?? 0,
      imageUrl: data['imageUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      processedAt: data['processedAt'] != null
          ? (data['processedAt'] as Timestamp).toDate()
          : null,
      status: data['status'] ?? 'uploaded',
      processedData: data['processedData'],
      isPublic: data['isPublic'] ?? false,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'buildingName': buildingName,
      'floorNumber': floorNumber,
      'imageUrl': imageUrl,
      'thumbnailUrl': thumbnailUrl,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'processedAt': processedAt != null
          ? Timestamp.fromDate(processedAt!)
          : null,
      'status': status,
      'processedData': processedData,
      'isPublic': isPublic,
      'tags': tags,
    };
  }

  // Copy with (for updating)
  FloorplanModel copyWith({
    String? floorplanId,
    String? userId,
    String? buildingName,
    int? floorNumber,
    String? imageUrl,
    String? thumbnailUrl,
    DateTime? uploadedAt,
    DateTime? processedAt,
    String? status,
    Map<String, dynamic>? processedData,
    bool? isPublic,
    List<String>? tags,
  }) {
    return FloorplanModel(
      floorplanId: floorplanId ?? this.floorplanId,
      userId: userId ?? this.userId,
      buildingName: buildingName ?? this.buildingName,
      floorNumber: floorNumber ?? this.floorNumber,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      processedAt: processedAt ?? this.processedAt,
      status: status ?? this.status,
      processedData: processedData ?? this.processedData,
      isPublic: isPublic ?? this.isPublic,
      tags: tags ?? this.tags,
    );
  }
}
