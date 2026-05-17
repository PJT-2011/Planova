import 'package:cloud_firestore/cloud_firestore.dart';

class FloorplanModel {
  final String floorplanId;
  final String userId;
  final String buildingName;
  final int floorNumber;
  final String imageUrl;
  final String? imagePath;
  final String? thumbnailUrl;
  final DateTime uploadedAt;
  final DateTime? processedAt;
  final String status; // 'uploaded', 'processing', 'ready', 'failed'
  final Map<String, dynamic>? processedData;
  final bool isPublic;
  final List<String> tags;
  final String? errorMessage;

  FloorplanModel({
    required this.floorplanId,
    required this.userId,
    required this.buildingName,
    required this.floorNumber,
    required this.imageUrl,
    this.imagePath,
    this.thumbnailUrl,
    required this.uploadedAt,
    this.processedAt,
    required this.status,
    this.processedData,
    this.isPublic = false,
    this.tags = const [],
    this.errorMessage,
  });

  // ── fromFirestore — for DocumentSnapshot (keeps doc.id as floorplanId) ──────
  factory FloorplanModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FloorplanModel.fromJson(data, docId: doc.id);
  }

  // ── fromJson — single source of truth ────────────────────────────────────────
  // [docId] is optional: if omitted, falls back to data['floorplanId'] ?? ''
  // floorplan_service can call fromJson(snap.data()!) with 1 arg, OR
  // fromJson(snap.data()!, docId: snap.id) with 2 — both compile fine.
  factory FloorplanModel.fromJson(Map<String, dynamic> data, {String? docId}) {
    DateTime toDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    }

    return FloorplanModel(
      floorplanId: docId ?? data['floorplanId'] ?? '',
      userId: data['userId'] ?? '',
      buildingName: data['buildingName'] ?? '',
      floorNumber: data['floorNumber'] ?? 0,
      imageUrl: data['imageUrl'] ?? '',
      imagePath: data['imagePath'],
      thumbnailUrl: data['thumbnailUrl'],
      uploadedAt: toDate(data['uploadedAt']),
      processedAt: data['processedAt'] != null
          ? toDate(data['processedAt'])
          : null,
      status: data['status'] ?? 'uploaded',
      processedData: data['processedData'],
      isPublic: data['isPublic'] ?? false,
      tags: List<String>.from(data['tags'] ?? []),
      errorMessage: data['errorMessage'],
    );
  }

  // ── toMap — alias kept for any existing Firestore writes ─────────────────────
  Map<String, dynamic> toMap() => toJson();

  // ── toJson ───────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() {
    return {
      'floorplanId': floorplanId,
      'userId': userId,
      'buildingName': buildingName,
      'floorNumber': floorNumber,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'thumbnailUrl': thumbnailUrl,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'processedAt': processedAt != null
          ? Timestamp.fromDate(processedAt!)
          : null,
      'status': status,
      'processedData': processedData,
      'isPublic': isPublic,
      'tags': tags,
      'errorMessage': errorMessage,
    };
  }

  // ── copyWith ─────────────────────────────────────────────────────────────────
  FloorplanModel copyWith({
    String? floorplanId,
    String? userId,
    String? buildingName,
    int? floorNumber,
    String? imageUrl,
    String? imagePath,
    String? thumbnailUrl,
    DateTime? uploadedAt,
    DateTime? processedAt,
    String? status,
    Map<String, dynamic>? processedData,
    bool? isPublic,
    List<String>? tags,
    String? errorMessage,
  }) {
    return FloorplanModel(
      floorplanId: floorplanId ?? this.floorplanId,
      userId: userId ?? this.userId,
      buildingName: buildingName ?? this.buildingName,
      floorNumber: floorNumber ?? this.floorNumber,
      imageUrl: imageUrl ?? this.imageUrl,
      imagePath: imagePath ?? this.imagePath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      processedAt: processedAt ?? this.processedAt,
      status: status ?? this.status,
      processedData: processedData ?? this.processedData,
      isPublic: isPublic ?? this.isPublic,
      tags: tags ?? this.tags,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
