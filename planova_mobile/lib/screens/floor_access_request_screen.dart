import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/models/access_request_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/services/access_control_service.dart';
import 'package:planova_mobile/services/auth_service.dart';
import 'package:planova_mobile/theme/app_theme.dart';

/// Lets a user request temporary access to a floor they don't already have,
/// and track the status of requests they've submitted for this building.
///
/// If [preselectedFloor] is passed (e.g. deep-linked from a locked floor tab
/// in FloorSelectionScreen), the "New Request" tab opens with that floor
/// already chosen.
class FloorAccessRequestScreen extends StatefulWidget {
  final BuildingModel building;
  final String userId;
  final FloorModel? preselectedFloor;

  const FloorAccessRequestScreen({
    Key? key,
    required this.building,
    required this.userId,
    this.preselectedFloor,
  }) : super(key: key);

  @override
  State<FloorAccessRequestScreen> createState() =>
      _FloorAccessRequestScreenState();
}

class _FloorAccessRequestScreenState extends State<FloorAccessRequestScreen>
    with SingleTickerProviderStateMixin {
  final BuildingService _buildingService = BuildingService();
  final AccessControlService _accessService = AccessControlService();
  final AuthService _authService = AuthService();
  late TabController _tabController;

  List<FloorModel> _floors = [];
  FloorModel? _selectedFloor;
  final _reasonController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedFloor = widget.preselectedFloor;
    _accessService.sweepExpired(widget.building.id);
    _loadFloors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadFloors() async {
    try {
      final floors = await _buildingService.getFloors(widget.building.id);
      if (!mounted) return;
      setState(() {
        _floors = floors;
        _selectedFloor ??= floors.isNotEmpty ? floors.first : null;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedFloor == null) return;
    setState(() => _isSubmitting = true);
    try {
      final userData = await _authService.getUserData(widget.userId);
      await _accessService.submitRequest(
        buildingId: widget.building.id,
        buildingName: widget.building.buildingName,
        floorId: _selectedFloor!.id,
        floorNumber: _selectedFloor!.floorNumber,
        floorName: _selectedFloor!.floorName,
        userId: widget.userId,
        userName: userData?['name'] ?? 'User',
        reason: _reasonController.text.trim(),
      );
      HapticFeedback.mediumImpact();
      _reasonController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Request sent to the admin'),
            backgroundColor: AppTheme.colors(context).success,
          ),
        );
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: AppTheme.colors(context).error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.onBackground,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: c.onBackground,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Floor Access',
          style: tt.titleLarge?.copyWith(
            color: c.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: c.primary,
          unselectedLabelColor: c.onSurfaceSecondary,
          indicatorColor: c.primary,
          tabs: const [
            Tab(text: 'Request Access'),
            Tab(text: 'My Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _isLoading
              ? Center(child: CircularProgressIndicator(color: c.primary))
              : _buildRequestForm(c, tt, isDark),
          _MyRequestsList(
            stream: _accessService.watchRequestsForUser(
              widget.building.id,
              widget.userId,
            ),
            c: c,
            tt: tt,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildRequestForm(AppColors c, TextTheme tt, bool isDark) {
    if (_floors.isEmpty) {
      return Center(
        child: Text(
          'No floors available for this building yet',
          style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Which floor do you need?',
            style: tt.titleSmall?.copyWith(
              color: c.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: isDark ? darkCardDecoration() : lightCardDecoration(),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: _floors.map((floor) {
                final selected = _selectedFloor?.id == floor.id;
                return RadioListTile<String>(
                  value: floor.id,
                  groupValue: _selectedFloor?.id,
                  activeColor: c.primary,
                  onChanged: (_) => setState(() => _selectedFloor = floor),
                  title: Text(
                    floor.floorName,
                    style: tt.bodyMedium?.copyWith(
                      color: c.onSurface,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  subtitle: Text(
                    'Floor ${floor.floorNumber}',
                    style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Reason for access',
            style: tt.titleSmall?.copyWith(
              color: c.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g. Meeting with the finance team at 2 PM',
              prefixIcon: Icon(Icons.edit_note_rounded, color: c.iconMuted),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: (_isSubmitting || _selectedFloor == null) ? null : _submit,
            child: AnimatedOpacity(
              opacity: (_isSubmitting || _selectedFloor == null) ? 0.6 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: heroGradient(),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.primaryGlow(c.primary),
                ),
                child: Center(
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          'Submit Request',
                          style: tt.labelLarge?.copyWith(color: Colors.white),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyRequestsList extends StatelessWidget {
  final Stream<List<AccessRequestModel>> stream;
  final AppColors c;
  final TextTheme tt;
  final bool isDark;

  const _MyRequestsList({
    required this.stream,
    required this.c,
    required this.tt,
    required this.isDark,
  });

  (IconData, Color, String) _statusInfo(AccessRequestModel r) {
    switch (r.status) {
      case AccessRequestStatus.pending:
        return (Icons.hourglass_top_rounded, c.warning, 'Pending');
      case AccessRequestStatus.approved:
        if (!r.isActiveGrant) {
          return (Icons.timer_off_outlined, c.onSurfaceTertiary, 'Expired');
        }
        return r.isPermanent
            ? (Icons.all_inclusive_rounded, c.success, 'Permanent')
            : (Icons.check_circle_rounded, c.success, 'Active');
      case AccessRequestStatus.rejected:
        return (Icons.cancel_rounded, c.error, 'Rejected');
      case AccessRequestStatus.expired:
        return (Icons.timer_off_outlined, c.onSurfaceTertiary, 'Expired');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AccessRequestModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('My requests stream error: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, color: c.error, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Couldn\'t load your requests',
                    style: tt.titleSmall?.copyWith(
                      color: c.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    snapshot.error.toString(),
                    style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: c.primary));
        }
        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return Center(
            child: Text(
              'You haven\'t requested any floor access yet',
              style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final r = requests[i];
            final (icon, color, label) = _statusInfo(r);
            return Container(
              decoration: isDark ? darkCardDecoration() : lightCardDecoration(),
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.floorName,
                          style: tt.titleSmall?.copyWith(
                            color: c.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (r.reason.isNotEmpty)
                          Text(
                            r.reason,
                            style: tt.bodySmall?.copyWith(
                              color: c.onSurfaceSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (r.isActiveGrant)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              r.isPermanent
                                  ? 'Permanent access'
                                  : 'Access until ${r.expiresAt!.hour.toString().padLeft(2, '0')}:${r.expiresAt!.minute.toString().padLeft(2, '0')}',
                              style: tt.bodySmall?.copyWith(
                                color: c.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      label,
                      style: tt.labelSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
