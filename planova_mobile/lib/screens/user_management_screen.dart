import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/floor_model.dart';
import 'package:planova_mobile/models/floor_access_model.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/services/access_control_service.dart';
import 'package:planova_mobile/services/auth_service.dart';
import 'package:planova_mobile/theme/app_theme.dart';

class UserManagementScreen extends StatefulWidget {
  final BuildingModel building;
  const UserManagementScreen({Key? key, required this.building})
    : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final BuildingService _buildingService = BuildingService();
  final AccessControlService _accessService = AccessControlService();
  final AuthService _authService = AuthService();

  List<FloorModel> _floors = [];
  List<Map<String, dynamic>> _users = [];
  Map<String, UserFloorAccessModel> _accessByUser = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final floors = await _buildingService.getFloors(widget.building.id);
      final users = await _buildingService.getBuildingUsers(widget.building.id);
      final accessList = await _accessService.getAllUserAccess(widget.building.id);
      final accessMap = {for (final a in accessList) a.userId: a};

      if (!mounted) return;
      setState(() {
        _floors = floors;
        _users = users;
        _accessByUser = accessMap;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  UserFloorAccessModel _accessFor(String userId) {
    return _accessByUser[userId] ??
        UserFloorAccessModel.unrestricted(
          userId: userId,
          buildingId: widget.building.id,
        );
  }

  String _summaryFor(UserFloorAccessModel access) {
    switch (access.accessType) {
      case FloorAccessType.all:
        return 'All floors';
      case FloorAccessType.none:
        return 'No floors';
      case FloorAccessType.selected:
        if (access.floorNumbers.isEmpty) return 'No floors';
        final names = access.floorNumbers.toList()..sort();
        return 'Floor${names.length == 1 ? '' : 's'} ${names.join(", ")}';
    }
  }

  Future<void> _openEditSheet(Map<String, dynamic> user) async {
    final access = _accessFor(user['userId']);
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    FloorAccessType selectedType = access.accessType;
    final selectedFloors = Set<int>.from(access.floorNumbers);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C2942) : Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: isDark
                    ? Border.all(color: Colors.white.withValues(alpha: 0.10))
                    : null,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: heroGradient(),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: const Icon(
                            Icons.badge_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Floor Access',
                                style: tt.headlineSmall?.copyWith(
                                  color: c.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                user['name'] ?? 'Unnamed user',
                                style: tt.bodySmall?.copyWith(
                                  color: c.onSurfaceSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _AccessTypeOption(
                      c: c,
                      tt: tt,
                      label: 'All floors',
                      subtitle: 'Unrestricted access to every floor',
                      icon: Icons.public_rounded,
                      selected: selectedType == FloorAccessType.all,
                      onTap: () =>
                          setSheetState(() => selectedType = FloorAccessType.all),
                    ),
                    const SizedBox(height: 10),
                    _AccessTypeOption(
                      c: c,
                      tt: tt,
                      label: 'No floors',
                      subtitle: 'Block access until floors are granted',
                      icon: Icons.block_rounded,
                      selected: selectedType == FloorAccessType.none,
                      onTap: () => setSheetState(
                        () => selectedType = FloorAccessType.none,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _AccessTypeOption(
                      c: c,
                      tt: tt,
                      label: 'Selected floors',
                      subtitle: 'Choose exactly which floors are allowed',
                      icon: Icons.checklist_rounded,
                      selected: selectedType == FloorAccessType.selected,
                      onTap: () => setSheetState(
                        () => selectedType = FloorAccessType.selected,
                      ),
                    ),

                    if (selectedType == FloorAccessType.selected) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: c.surfaceElevated,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: c.border),
                        ),
                        child: Column(
                          children: _floors.map((floor) {
                            final checked = selectedFloors.contains(
                              floor.floorNumber,
                            );
                            return CheckboxListTile(
                              value: checked,
                              activeColor: c.primary,
                              title: Text(
                                floor.floorName,
                                style: tt.bodyMedium?.copyWith(
                                  color: c.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                'Floor ${floor.floorNumber}',
                                style: tt.bodySmall?.copyWith(
                                  color: c.onSurfaceSecondary,
                                ),
                              ),
                              onChanged: (val) {
                                setSheetState(() {
                                  if (val == true) {
                                    selectedFloors.add(floor.floorNumber);
                                  } else {
                                    selectedFloors.remove(floor.floorNumber);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () async {
                        final adminId = _authService.currentUser?.uid ?? '';
                        final adminData = await _authService.getUserData(
                          adminId,
                        );
                        await _accessService.setPermanentAccess(
                          buildingId: widget.building.id,
                          userId: user['userId'],
                          userName: user['name'] ?? 'Unnamed user',
                          accessType: selectedType,
                          floorNumbers: selectedFloors.toList(),
                          adminId: adminId,
                          adminName: adminData?['name'] ?? 'Admin',
                        );
                        HapticFeedback.mediumImpact();
                        if (mounted) Navigator.pop(context);
                        _loadData();
                      },
                      child: Container(
                        height: 54,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: heroGradient(),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: AppShadows.primaryGlow(c.primary),
                        ),
                        child: Center(
                          child: Text(
                            'Save Access',
                            style: tt.labelLarge?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Users',
              style: tt.titleLarge?.copyWith(
                color: c.onBackground,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              widget.building.buildingName,
              style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _users.isEmpty
          ? _EmptyState(c: c, tt: tt)
          : RefreshIndicator(
              onRefresh: _loadData,
              color: c.primary,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                itemCount: _users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final user = _users[i];
                  final access = _accessFor(user['userId']);
                  return _UserCard(
                    isDark: isDark,
                    c: c,
                    tt: tt,
                    name: user['name'] ?? 'Unnamed user',
                    email: user['email'] ?? '',
                    accessSummary: _summaryFor(access),
                    accessType: access.accessType,
                    onTap: () => _openEditSheet(user),
                  );
                },
              ),
            ),
    );
  }
}

class _AccessTypeOption extends StatelessWidget {
  final AppColors c;
  final TextTheme tt;
  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AccessTypeOption({
    required this.c,
    required this.tt,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? c.primaryContainer : c.surfaceElevated,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? c.primary : c.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? c.primary : c.iconMuted, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.titleSmall?.copyWith(
                      color: c.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? c.primary : c.iconMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final bool isDark;
  final AppColors c;
  final TextTheme tt;
  final String name;
  final String email;
  final String accessSummary;
  final FloorAccessType accessType;
  final VoidCallback onTap;

  const _UserCard({
    required this.isDark,
    required this.c,
    required this.tt,
    required this.name,
    required this.email,
    required this.accessSummary,
    required this.accessType,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = accessType == FloorAccessType.none
        ? c.error
        : accessType == FloorAccessType.all
        ? c.success
        : c.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: isDark ? darkCardDecoration() : lightCardDecoration(),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: c.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.person_rounded, color: c.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: tt.titleSmall?.copyWith(
                      color: c.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (email.isNotEmpty)
                    Text(
                      email,
                      style: tt.bodySmall?.copyWith(
                        color: c.onSurfaceSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text(
                accessSummary,
                style: tt.labelSmall?.copyWith(
                  color: chipColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppColors c;
  final TextTheme tt;
  const _EmptyState({required this.c, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded, size: 56, color: c.iconMuted),
            const SizedBox(height: 16),
            Text(
              'No users yet',
              style: tt.titleMedium?.copyWith(color: c.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              'Users appear here once they scan this building\'s QR code.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
