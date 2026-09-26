import 'package:flutter/material.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/models/room_model.dart';
import 'package:planova_mobile/models/door_model.dart';
import 'package:planova_mobile/models/safety_marking_model.dart';
import 'package:planova_mobile/models/floorplan_model.dart';
import 'package:planova_mobile/models/grid_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/screens/navigation_screen.dart';
import 'package:planova_mobile/theme/app_theme.dart';

/// NavigationScreenWithRooms
///
/// Thin adapter that constructs a FloorplanModel from Floor/Building data
/// and forwards to NavigationScreen — but also fetches this floor's rooms
/// and doors directly from Firestore, rather than trusting whatever the
/// caller happens to have in memory. This is deliberate: NavigationScreen
/// is the single place that decides what can be navigated to, and it can
/// only enforce off-limits rooms correctly if it has current room data —
/// fetching it fresh here means that holds regardless of which screen or
/// button led here.
class NavigationScreenWithRooms extends StatefulWidget {
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
  State<NavigationScreenWithRooms> createState() =>
      _NavigationScreenWithRoomsState();
}

class _NavigationScreenWithRoomsState
    extends State<NavigationScreenWithRooms> {
  final BuildingService _buildingService = BuildingService();
  List<RoomModel>? _rooms;
  List<DoorModel> _doors = [];
  List<SafetyMarkingModel> _markings = [];
  bool _isLoading = true;
  String? _blockedMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<RoomModel> rooms = [];
    try {
      rooms = await _buildingService.getRooms(
        widget.building.id,
        widget.floor.id,
      );
    } catch (e) {
      // Room data failing to load is not allowed to silently grant access
      // to a target room we can no longer verify — but it also shouldn't
      // block navigation entirely if there's no specific target. Fall
      // back to whatever was passed in directly so a transient read error
      // degrades gracefully rather than either wrongly blocking or wrongly
      // allowing an off-limits destination.
      if (widget.targetRoom != null) rooms = [widget.targetRoom!];
    }

    List<DoorModel> doors = [];
    try {
      doors = await _buildingService.getDoors(
        widget.building.id,
        widget.floor.id,
      );
    } catch (e) {
      // Doors are purely informational on this screen — never block
      // navigation over a failure to load them.
    }

    List<SafetyMarkingModel> markings = [];
    try {
      markings = await _buildingService.getSafetyMarkings(
        widget.building.id,
        widget.floor.id,
      );
    } catch (e) {
      // Safety markings are purely informational too — never block
      // navigation over a failure to load them.
    }

    // Re-verify the target room against freshly-fetched data before ever
    // turning it into a destination.
    String? blockedMessage;
    if (widget.targetRoom != null) {
      final current = rooms.firstWhere(
        (r) => r.id == widget.targetRoom!.id,
        orElse: () => widget.targetRoom!,
      );
      if (current.isOffLimits) {
        blockedMessage =
            '"${current.name}" is off-limits and can\'t be navigated to.';
      }
    }

    if (!mounted) return;
    setState(() {
      _rooms = rooms;
      _doors = doors;
      _markings = markings;
      _blockedMessage = blockedMessage;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      final c = AppTheme.colors(context);
      return Scaffold(
        backgroundColor: c.background,
        body: Center(child: CircularProgressIndicator(color: c.primary)),
      );
    }

    final floorplan = FloorplanModel(
      floorplanId: widget.floor.id,
      buildingName:
          '${widget.building.buildingName} - ${widget.floor.floorName}',
      imageUrl: widget.floor.imageUrl,
      floorNumber: widget.floor.floorNumber,
      processedData: widget.floor.processedData,
      uploadedAt: widget.floor.uploadedAt,
      status: 'ready',
      userId: widget.building.createdBy,
    );

    final destination = (widget.targetRoom != null && _blockedMessage == null)
        ? GridPoint(
            row: widget.targetRoom!.gridPoint.row,
            col: widget.targetRoom!.gridPoint.col,
          )
        : null;

    if (_blockedMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_blockedMessage!),
            backgroundColor: AppTheme.colors(context).error,
          ),
        );
      });
    }

    return NavigationScreen(
      floorplan: floorplan,
      destination: destination,
      rooms: _rooms ?? const [],
      doors: _doors,
      markings: _markings,
    );
  }
}
