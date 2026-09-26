import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/access_request_model.dart';
import 'package:planova_mobile/services/access_control_service.dart';
import 'package:planova_mobile/services/auth_service.dart';
import 'package:planova_mobile/theme/app_theme.dart';

class AccessRequestsScreen extends StatefulWidget {
  final BuildingModel building;
  const AccessRequestsScreen({Key? key, required this.building})
    : super(key: key);

  @override
  State<AccessRequestsScreen> createState() => _AccessRequestsScreenState();
}

class _AccessRequestsScreenState extends State<AccessRequestsScreen>
    with SingleTickerProviderStateMixin {
  final AccessControlService _accessService = AccessControlService();
  final AuthService _authService = AuthService();
  late TabController _tabController;

  static const _durationOptions = [60, 1440, 10080]; // 1 hr, 24 hr, 7 days

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _accessService.sweepExpired(widget.building.id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _durationLabel(int? mins) {
    if (mins == null) return 'Permanent';
    if (mins < 60) return '$mins min';
    if (mins < 1440) return '${mins ~/ 60} hr';
    if (mins < 10080) {
      final days = mins ~/ 1440;
      return '$days day${days == 1 ? '' : 's'}';
    }
    final weeks = mins ~/ 10080;
    return '$weeks week${weeks == 1 ? '' : 's'}';
  }

  /// Small numeric-entry dialog for a custom minute count, used by the
  /// "Custom" chip in the approve sheet below.
  Future<int?> _promptCustomMinutes() async {
    final controller = TextEditingController();
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2942) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: isDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.10))
                : null,
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Custom Duration',
                style: tt.headlineSmall?.copyWith(
                  color: c.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter the number of minutes to grant access for',
                style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 90',
                  suffixText: 'minutes',
                  prefixIcon: Icon(Icons.timer_outlined, color: c.iconMuted),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  final value = int.tryParse(controller.text.trim());
                  Navigator.pop(context, (value != null && value > 0) ? value : null);
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
                      'Use This Duration',
                      style: tt.labelLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: c.border, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: tt.labelLarge?.copyWith(color: c.onSurfaceSecondary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _approve(AccessRequestModel request) async {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // null == Permanent. Starts on the shortest fixed option rather than
    // defaulting to Permanent, so granting permanent access is always a
    // deliberate extra tap, not the path of least resistance.
    int? selectedDuration = _durationOptions.first;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2942) : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: isDark
                ? Border.all(color: Colors.white.withValues(alpha: 0.10))
                : null,
          ),
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
                      color: c.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      color: c.success,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Approve Request',
                          style: tt.headlineSmall?.copyWith(
                            color: c.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${request.userName} · ${request.floorName}',
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
              Text(
                'Grant access for',
                style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._durationOptions.map((mins) {
                    final selected = selectedDuration == mins;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedDuration = mins),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected ? c.primary : c.surfaceElevated,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          border: Border.all(
                            color: selected ? c.primary : c.border,
                          ),
                        ),
                        child: Text(
                          _durationLabel(mins),
                          style: tt.labelMedium?.copyWith(
                            color: selected ? Colors.white : c.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }),
                  // Permanent — a deliberately distinct color so it reads
                  // as a different kind of choice, not just a longer
                  // duration on the same scale as the others.
                  GestureDetector(
                    onTap: () => setSheetState(() => selectedDuration = null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selectedDuration == null
                            ? c.warning
                            : c.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: selectedDuration == null
                              ? c.warning
                              : c.border,
                        ),
                      ),
                      child: Text(
                        'Permanent',
                        style: tt.labelMedium?.copyWith(
                          color: selectedDuration == null
                              ? Colors.white
                              : c.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Custom — anything not null and not one of the fixed
                  // options is, by definition, a custom value already in
                  // effect, so the chip highlights and shows it directly.
                  Builder(
                    builder: (_) {
                      final isCustomActive = selectedDuration != null &&
                          !_durationOptions.contains(selectedDuration);
                      return GestureDetector(
                        onTap: () async {
                          final minutes = await _promptCustomMinutes();
                          if (minutes != null) {
                            setSheetState(() => selectedDuration = minutes);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isCustomActive ? c.primary : c.surfaceElevated,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                            border: Border.all(
                              color: isCustomActive ? c.primary : c.border,
                            ),
                          ),
                          child: Text(
                            isCustomActive
                                ? 'Custom (${_durationLabel(selectedDuration)})'
                                : 'Custom',
                            style: tt.labelMedium?.copyWith(
                              color: isCustomActive ? Colors.white : c.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  height: 54,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: c.success,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: AppShadows.primaryGlow(c.success),
                  ),
                  child: Center(
                    child: Text(
                      'Approve — ${_durationLabel(selectedDuration)}',
                      style: tt.labelLarge?.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: c.border, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      'Cancel',
                      style: tt.labelLarge?.copyWith(
                        color: c.onSurfaceSecondary,
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

    if (confirmed == true) {
      final adminId = _authService.currentUser?.uid ?? '';
      final adminData = await _authService.getUserData(adminId);
      await _accessService.approveRequest(
        request: request,
        durationMinutes: selectedDuration,
        adminId: adminId,
        adminName: adminData?['name'] ?? 'Admin',
      );
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access approved for ${request.userName}'),
            backgroundColor: AppTheme.colors(context).success,
          ),
        );
      }
    }
  }

  Future<void> _reject(AccessRequestModel request) async {
    final adminId = _authService.currentUser?.uid ?? '';
    final adminData = await _authService.getUserData(adminId);
    await _accessService.rejectRequest(
      request: request,
      adminId: adminId,
      adminName: adminData?['name'] ?? 'Admin',
    );
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Request from ${request.userName} rejected'),
          backgroundColor: AppTheme.colors(context).error,
        ),
      );
    }
  }

  /// Immediately ends an active approved grant — e.g. the area was just
  /// marked off-limits, or the user should no longer have access.
  Future<void> _revoke(AccessRequestModel request) async {
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2942) : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.10))
              : null,
        ),
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
                    color: c.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.block_rounded, color: c.error, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Revoke Access?',
                        style: tt.headlineSmall?.copyWith(
                          color: c.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${request.userName} · ${request.floorName}',
                        style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Their access will stop working immediately.',
              style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary, height: 1.5),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: () => Navigator.pop(context, true),
              child: Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: c.error,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.primaryGlow(c.error),
                ),
                child: Center(
                  child: Text(
                    'Revoke Access',
                    style: tt.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context, false),
              child: Container(
                height: 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: c.border, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    'Cancel',
                    style: tt.labelLarge?.copyWith(color: c.onSurfaceSecondary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;
    final adminId = _authService.currentUser?.uid ?? '';
    final adminData = await _authService.getUserData(adminId);
    await _accessService.revokeAccess(
      request: request,
      adminId: adminId,
      adminName: adminData?['name'] ?? 'Admin',
    );
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Access revoked for ${request.userName}'),
          backgroundColor: AppTheme.colors(context).error,
        ),
      );
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
          'Access Requests',
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
            Tab(text: 'Pending'),
            Tab(text: 'All'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _RequestList(
            stream: _accessService.watchPendingRequests(widget.building.id),
            c: c,
            tt: tt,
            isDark: isDark,
            onApprove: _approve,
            onReject: _reject,
            onRevoke: _revoke,
            emptyMessage: 'No pending requests',
          ),
          _RequestList(
            stream: _accessService.watchAllRequests(widget.building.id),
            c: c,
            tt: tt,
            isDark: isDark,
            onApprove: _approve,
            onReject: _reject,
            onRevoke: _revoke,
            emptyMessage: 'No requests yet',
          ),
        ],
      ),
    );
  }
}

class _RequestList extends StatelessWidget {
  final Stream<List<AccessRequestModel>> stream;
  final AppColors c;
  final TextTheme tt;
  final bool isDark;
  final void Function(AccessRequestModel) onApprove;
  final void Function(AccessRequestModel) onReject;
  final void Function(AccessRequestModel) onRevoke;
  final String emptyMessage;

  const _RequestList({
    required this.stream,
    required this.c,
    required this.tt,
    required this.isDark,
    required this.onApprove,
    required this.onReject,
    required this.onRevoke,
    required this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AccessRequestModel>>(
      stream: stream,
      builder: (context, snapshot) {
        // A Firestore compound query (this one filters by status AND
        // orders by requestedAt) needs a composite index. Without it the
        // stream errors instead of emitting data — and since hasData
        // never becomes true, leaving this unhandled means the spinner
        // below spins forever with no indication anything went wrong.
        // Firestore's own error message includes a direct link to create
        // the missing index, so it's shown in full and made selectable
        // rather than replaced with a generic "something went wrong."
        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          debugPrint('Access requests stream error: $error');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, color: c.error, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Couldn\'t load requests',
                    style: tt.titleSmall?.copyWith(
                      color: c.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    error,
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
              emptyMessage,
              style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _RequestCard(
            request: requests[i],
            c: c,
            tt: tt,
            isDark: isDark,
            onApprove: onApprove,
            onReject: onReject,
            onRevoke: onRevoke,
          ),
        );
      },
    );
  }
}

class _RequestCard extends StatelessWidget {
  final AccessRequestModel request;
  final AppColors c;
  final TextTheme tt;
  final bool isDark;
  final void Function(AccessRequestModel) onApprove;
  final void Function(AccessRequestModel) onReject;
  final void Function(AccessRequestModel) onRevoke;

  const _RequestCard({
    required this.request,
    required this.c,
    required this.tt,
    required this.isDark,
    required this.onApprove,
    required this.onReject,
    required this.onRevoke,
  });

  Color get _statusColor {
    switch (request.status) {
      case AccessRequestStatus.pending:
        return c.warning;
      case AccessRequestStatus.approved:
        return request.isActiveGrant ? c.success : c.onSurfaceTertiary;
      case AccessRequestStatus.rejected:
        return c.error;
      case AccessRequestStatus.expired:
        return c.onSurfaceTertiary;
    }
  }

  String get _statusLabel {
    switch (request.status) {
      case AccessRequestStatus.pending:
        return 'Pending';
      case AccessRequestStatus.approved:
        if (!request.isActiveGrant) return 'Expired';
        return request.isPermanent ? 'Permanent' : 'Active';
      case AccessRequestStatus.rejected:
        return 'Rejected';
      case AccessRequestStatus.expired:
        return 'Expired';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isDark ? darkCardDecoration() : lightCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.userName,
                      style: tt.titleSmall?.copyWith(
                        color: c.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      request.floorName,
                      style: tt.bodySmall?.copyWith(
                        color: c.onSurfaceSecondary,
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
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  _statusLabel,
                  style: tt.labelSmall?.copyWith(
                    color: _statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (request.reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.surfaceElevated,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                request.reason,
                style: tt.bodySmall?.copyWith(color: c.onSurface, height: 1.4),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 13, color: c.onSurfaceTertiary),
              const SizedBox(width: 4),
              Text(
                _formatDate(request.requestedAt),
                style: tt.bodySmall?.copyWith(color: c.onSurfaceTertiary),
              ),
              if (request.isActiveGrant) ...[
                const SizedBox(width: 12),
                Icon(
                  request.isPermanent ? Icons.all_inclusive_rounded : Icons.timer_outlined,
                  size: 13,
                  color: c.success,
                ),
                const SizedBox(width: 4),
                Text(
                  request.isPermanent
                      ? 'Permanent access'
                      : 'Expires ${_formatDate(request.expiresAt!)}',
                  style: tt.bodySmall?.copyWith(color: c.success),
                ),
              ],
            ],
          ),
          if (request.isActiveGrant) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => onRevoke(request),
              child: Container(
                height: 44,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: c.error.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.block_rounded, size: 16, color: c.error),
                    const SizedBox(width: 8),
                    Text(
                      'Revoke Access',
                      style: tt.labelMedium?.copyWith(color: c.error),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (request.status == AccessRequestStatus.pending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => onReject(request),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: c.error.withValues(alpha: 0.4)),
                      ),
                      child: Center(
                        child: Text(
                          'Reject',
                          style: tt.labelMedium?.copyWith(color: c.error),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => onApprove(request),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: c.success,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Center(
                        child: Text(
                          'Approve',
                          style: tt.labelMedium?.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.month}/${d.day} $h:$min $ampm';
  }
}
