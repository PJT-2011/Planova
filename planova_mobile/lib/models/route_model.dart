import 'package:planova_mobile/models/grid_model.dart';

class RouteModel {
  final List<GridPoint> path;
  final List<String> directions;
  final double distance;
  final int estimatedTime;

  RouteModel({
    required this.path,
    required this.directions,
    required this.distance,
    required this.estimatedTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'path': path.map((p) => p.toJson()).toList(),
      'directions': directions,
      'distance': distance,
      'estimatedTime': estimatedTime,
    };
  }

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      path: (json['path'] as List)
          .map((p) => GridPoint.fromJson(p as Map<String, dynamic>))
          .toList(),
      directions: List<String>.from(json['directions'] as List),
      distance: (json['distance'] as num).toDouble(),
      estimatedTime: json['estimatedTime'] as int,
    );
  }
}
