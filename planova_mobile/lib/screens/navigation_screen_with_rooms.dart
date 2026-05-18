import 'package:flutter/material.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/models/room_model.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/screens/navigation_screen.dart';

/// NavigationScreenWithRooms
///
/// This is a thin adapter — it constructs a FloorplanModel from the
/// Floor/Building data and forwards to NavigationScreen.
/// Visual styling comes from AppTheme applied in NavigationScreen itself.
class NavigationScreenWithRooms extends StatelessWidget {
  final BuildingModel building;
  final FloorModel floor;
  final RoomModel? targetRoom;

  const NavigationScreenWithRooms({
    super.key,
    required this.building,
    required this.floor,
    this.targetRoom,
  });

  @override
  Widget build(BuildContext context) {
    final floorplan = FloorplanModel(
      floorplanId: floor.id,
      buildingName: '${building.buildingName} - ${floor.floorName}',
      imageUrl: floor.imageUrl,
      floorNumber: floor.floorNumber,
      processedData: floor.processedData,
      uploadedAt: floor.uploadedAt,
      status: 'ready',
      userId: building.createdBy,
    );

    final destination = targetRoom != null
        ? GridPoint(
            row: targetRoom!.gridPoint.row,
            col: targetRoom!.gridPoint.col,
          )
        : null;

    return NavigationScreen(floorplan: floorplan, destination: destination);
  }
}
