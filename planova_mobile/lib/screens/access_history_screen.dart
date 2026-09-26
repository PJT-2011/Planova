import 'package:flutter/material.dart';
import 'package:planova_mobile/models/building_model.dart';
import 'package:planova_mobile/models/audit_log_model.dart';
import 'package:planova_mobile/services/access_control_service.dart';
import 'package:planova_mobile/theme/app_theme.dart';

class AccessHistoryScreen extends StatelessWidget {
  final BuildingModel building;
  final AccessControlService _accessService = AccessControlService();

  AccessHistoryScreen({Key? key, required this.building}) : super(key: key);

  (IconData, Color) _iconFor(String action, AppColors c) {
    switch (action) {
      case 'requested':
        return (Icons.mail_outline_rounded, c.primary);
      case 'approved':
        return (Icons.check_circle_outline_rounded, c.success);
      case 'rejected':
        return (Icons.cancel_outlined, c.error);
      case 'expired':
        return (Icons.timer_off_outlined, c.onSurfaceTertiary);
      case 'revoked':
        return (Icons.block_rounded, c.error);
      case 'permanent_access_updated':
        return (Icons.badge_outlined, c.warning);
      default:
        return (Icons.history_rounded, c.onSurfaceTertiary);
    }
  }

  String _labelFor(AccessAuditLogModel e) {
    switch (e.action) {
      case 'requested':
        return '${e.userName} requested access to ${e.floorName}';
      case 'approved':
        final mins = e.durationMinutes ?? 0;
        return '${e.performedByName ?? 'Admin'} approved ${e.userName} for '
            '${e.floorName} ($mins min)';
      case 'rejected':
        return '${e.performedByName ?? 'Admin'} rejected ${e.userName}\'s '
            'request for ${e.floorName}';
      case 'expired':
        return 'Temporary access to ${e.floorName} expired for ${e.userName}';
      case 'revoked':
        return '${e.performedByName ?? 'Admin'} revoked ${e.userName}\'s '
            'access to ${e.floorName}';
      case 'permanent_access_updated':
        return '${e.performedByName ?? 'Admin'} set ${e.userName}\'s access '
            'to: ${e.floorName}';
      default:
        return '${e.action} — ${e.userName}';
    }
  }

  String _formatDate(DateTime d) {
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.month}/${d.day}/${d.year} $h:$min $ampm';
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
          'Access History',
          style: tt.titleLarge?.copyWith(
            color: c.onBackground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<List<AccessAuditLogModel>>(
        stream: _accessService.watchAuditLog(building.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator(color: c.primary));
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return Center(
              child: Text(
                'No access history yet',
                style: tt.bodyMedium?.copyWith(color: c.onSurfaceSecondary),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final e = entries[i];
              final (icon, color) = _iconFor(e.action, c);
              return Container(
                decoration: isDark ? darkCardDecoration() : lightCardDecoration(),
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Icon(icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _labelFor(e),
                            style: tt.bodyMedium?.copyWith(
                              color: c.onSurface,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatDate(e.timestamp),
                            style: tt.bodySmall?.copyWith(
                              color: c.onSurfaceTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
