import 'package:flutter/material.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/access_request_model.dart';
import 'package:planova_mobile/services/access_control_service.dart';
import 'package:planova_mobile/services/building_service.dart';
import 'package:planova_mobile/theme/app_theme.dart';

/// Shows everyone who currently has *active* access to this building —
/// whether they got in via a QR scan or a manual per-floor request, and
/// whether that access is permanent or time-boxed. This screen is
/// read-only: approving, rejecting, or revoking a request all happen in
/// AccessRequestsScreen, which is the single place a request is reviewed
/// regardless of how it originated.
class UserManagementScreen extends StatefulWidget {
  final BuildingModel building;
  const UserManagementScreen({Key? key, required this.building})
    : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final AccessControlService _accessService = AccessControlService();
  final BuildingService _buildingService = BuildingService();

  // One-time fetch of pre-migration approvals — nothing new is ever
  // written to that collection, so a stream would be overkill; a single
  // load on open is enough to keep showing people approved under the old
  // system alongside everyone approved under the current one.
  List<Map<String, dynamic>> _legacyUsers = [];
  bool _legacyLoaded = false;

  @override
  void initState() {
    super.initState();
    _accessService.sweepExpired(widget.building.id);
    _loadLegacyUsers();
  }

  Future<void> _loadLegacyUsers() async {
    try {
      final users = await _buildingService.getLegacyApprovedUsers(
        widget.building.id,
      );
      if (mounted) setState(() {
        _legacyUsers = users;
        _legacyLoaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _legacyLoaded = true);
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
          'Users',
          style: tt.titleLarge?.copyWith(
            color: c.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<List<AccessRequestModel>>(
        stream: _accessService.watchActiveGrants(widget.building.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, color: c.error, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Couldn\'t load users',
                      style: tt.titleSmall?.copyWith(
                        color: c.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
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
          if (!snapshot.hasData || !_legacyLoaded) {
            return Center(child: CircularProgressIndicator(color: c.primary));
          }

          final grants = List<AccessRequestModel>.from(snapshot.data!)
            ..sort((a, b) {
              final at = a.respondedAt ?? a.requestedAt;
              final bt = b.respondedAt ?? b.requestedAt;
              return bt.compareTo(at);
            });
          final grantedUserIds = grants.map((g) => g.userId).toSet();
          final legacyOnly = _legacyUsers
              .where((u) => !grantedUserIds.contains(u['userId']))
              .toList();

          if (grants.isEmpty && legacyOnly.isEmpty) {
            return _EmptyState(c: c, tt: tt);
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            itemCount: grants.length + legacyOnly.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              if (i < grants.length) {
                return _GrantCard(grant: grants[i], isDark: isDark, c: c, tt: tt);
              }
              final legacy = legacyOnly[i - grants.length];
              return _LegacyUserCard(
                name: legacy['name'] ?? 'Unnamed user',
                isDark: isDark,
                c: c,
                tt: tt,
              );
            },
          );
        },
      ),
    );
  }
}

class _GrantCard extends StatelessWidget {
  final AccessRequestModel grant;
  final bool isDark;
  final AppColors c;
  final TextTheme tt;

  const _GrantCard({
    required this.grant,
    required this.isDark,
    required this.c,
    required this.tt,
  });

  String _formatDate(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.month}/${d.day} $h:$min $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final chipColor = grant.isPermanent ? c.success : c.primary;
    final chipLabel = grant.isPermanent
        ? 'Permanent'
        : 'Expires ${_formatDate(grant.expiresAt!)}';

    return Container(
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
                  grant.userName,
                  style: tt.titleSmall?.copyWith(
                    color: c.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  grant.floorName,
                  style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
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
              chipLabel,
              style: tt.labelSmall?.copyWith(
                color: chipColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegacyUserCard extends StatelessWidget {
  final String name;
  final bool isDark;
  final AppColors c;
  final TextTheme tt;

  const _LegacyUserCard({
    required this.name,
    required this.isDark,
    required this.c,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Text(
              name,
              style: tt.titleSmall?.copyWith(
                color: c.onSurface,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: c.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              'Permanent',
              style: tt.labelSmall?.copyWith(
                color: c.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, size: 48, color: c.onSurfaceTertiary),
            const SizedBox(height: 12),
            Text(
              'No one currently has active access',
              style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
