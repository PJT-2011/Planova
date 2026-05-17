import 'package:flutter/material.dart';
import 'package:planova_mobile/models/room_model.dart';
import 'package:planova_mobile/services/building_service.dart';

/// Reusable room search widget with autocomplete
/// Can search current floor only OR all floors
class RoomSearchWidget extends StatefulWidget {
  final String buildingId;
  final String? floorId; // If null, searches all floors
  final Function(RoomModel) onRoomSelected;
  final String hintText;

  const RoomSearchWidget({
    Key? key,
    required this.buildingId,
    this.floorId,
    required this.onRoomSelected,
    this.hintText = 'Search rooms...',
  }) : super(key: key);

  @override
  State<RoomSearchWidget> createState() => _RoomSearchWidgetState();
}

class _RoomSearchWidgetState extends State<RoomSearchWidget> {
  final BuildingService _buildingService = BuildingService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<RoomModel> _searchResults = [];
  bool _isSearching = false;
  bool _showResults = false;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showResults = true;
    });

    try {
      List<RoomModel> results;

      if (widget.floorId != null) {
        // Search only current floor
        results = await _buildingService.searchRoomsInFloor(
          widget.buildingId,
          widget.floorId!,
          query,
        );
      } else {
        // Search all floors
        results = await _buildingService.searchRooms(widget.buildingId, query);
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      print('❌ [RoomSearch] Error searching: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _selectRoom(RoomModel room) {
    _searchController.clear();
    setState(() {
      _showResults = false;
      _searchResults = [];
    });
    _focusNode.unfocus();
    widget.onRoomSelected(room);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search text field
        TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
          ),
          onChanged: _performSearch,
          onTap: () {
            if (_searchController.text.isNotEmpty) {
              setState(() => _showResults = true);
            }
          },
        ),

        // Search results dropdown
        if (_showResults)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 300),
            child: _isSearching
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _searchResults.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No rooms found for "${_searchController.text}"',
                          style: const TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        if (widget.floorId != null) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Try searching all floors',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: _searchResults.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final room = _searchResults[index];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.room, color: Colors.blue),
                        ),
                        title: Text(
                          room.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: widget.floorId == null
                            ? Text('Floor ${room.floorNumber}')
                            : Text(
                                'Row ${room.gridPoint.row}, Col ${room.gridPoint.col}',
                              ),
                        trailing: const Icon(
                          Icons.arrow_forward,
                          color: Colors.blue,
                        ),
                        onTap: () => _selectRoom(room),
                      );
                    },
                  ),
          ),
      ],
    );
  }
}

/// Simpler variant - just a search field with callback
class SimpleRoomSearch extends StatefulWidget {
  final String hintText;
  final Function(String) onSearch;

  const SimpleRoomSearch({
    Key? key,
    required this.onSearch,
    this.hintText = 'Search rooms...',
  }) : super(key: key);

  @override
  State<SimpleRoomSearch> createState() => _SimpleRoomSearchState();
}

class _SimpleRoomSearchState extends State<SimpleRoomSearch> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _controller.clear();
                  widget.onSearch('');
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: widget.onSearch,
      onSubmitted: widget.onSearch,
    );
  }
}
