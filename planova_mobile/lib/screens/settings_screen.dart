import 'package:flutter/material.dart';
import 'package:planova_mobile/main.dart';
import 'package:planova_mobile/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = PlanovaApp.of(context);
    final isDark = appState?.isDarkMode ?? false;
    final c = AppTheme.colors(context);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: c.onBackground,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: tt.titleLarge?.copyWith(color: c.onBackground),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Appearance ───────────────────────────────────────────────
            _SectionLabel(label: 'Appearance', c: c, tt: tt),
            const SizedBox(height: 10),
            _SettingsCard(
              isDark: isDark,
              children: [
                _ThemeToggleTile(
                  isDark: isDark,
                  c: c,
                  tt: tt,
                  onChanged: (val) async {
                    await appState?.toggleTheme(val);
                    setState(() {});
                  },
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── About ────────────────────────────────────────────────────
            _SectionLabel(label: 'About', c: c, tt: tt),
            const SizedBox(height: 10),
            _SettingsCard(
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.info_outline_rounded,
                  iconColor: c.primary,
                  iconBg: c.primaryContainer,
                  title: 'Version',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.chipFill,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Text(
                      '1.0.0',
                      style: tt.labelSmall?.copyWith(color: c.chipText),
                    ),
                  ),
                  c: c,
                  tt: tt,
                ),
                Divider(height: 1, color: c.divider),
                _SettingsTile(
                  icon: Icons.navigation_rounded,
                  iconColor: c.primary,
                  iconBg: c.primaryContainer,
                  title: 'About Planova',
                  subtitle: 'Indoor navigation made easy',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: c.iconMuted,
                    size: 20,
                  ),
                  c: c,
                  tt: tt,
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: 'Planova',
                    applicationVersion: '1.0.0',
                    applicationIcon: Icon(
                      Icons.navigation_rounded,
                      color: c.primary,
                      size: 40,
                    ),
                    children: const [
                      Text('Indoor navigation made easy.'),
                      SizedBox(height: 8),
                      Text(
                        'Upload floorplans, map rooms, and navigate with ease.',
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Support ──────────────────────────────────────────────────
            _SectionLabel(label: 'Support', c: c, tt: tt),
            const SizedBox(height: 10),
            _SettingsCard(
              isDark: isDark,
              children: [
                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  iconColor: const Color(0xFF22C55E),
                  iconBg: const Color(0xFFDCFCE7),
                  title: 'Help & FAQ',
                  subtitle: 'Get answers to common questions',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: c.iconMuted,
                    size: 20,
                  ),
                  c: c,
                  tt: tt,
                  onTap: () {},
                ),
                Divider(height: 1, color: c.divider),
                _SettingsTile(
                  icon: Icons.feedback_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  iconBg: const Color(0xFFFEF3C7),
                  title: 'Send Feedback',
                  subtitle: 'Help us improve Planova',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: c.iconMuted,
                    size: 20,
                  ),
                  c: c,
                  tt: tt,
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Themed dark mode toggle ───────────────────────────────────────────────────

class _ThemeToggleTile extends StatelessWidget {
  final bool isDark;
  final AppColors c;
  final TextTheme tt;
  final ValueChanged<bool> onChanged;

  const _ThemeToggleTile({
    required this.isDark,
    required this.c,
    required this.tt,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C2942) : const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dark Mode',
                  style: tt.titleSmall?.copyWith(color: c.onSurface),
                ),
                Text(
                  isDark ? 'Dark theme active' : 'Light theme active',
                  style: tt.bodySmall?.copyWith(color: c.onSurfaceSecondary),
                ),
              ],
            ),
          ),

          // Switch
          Switch(value: isDark, onChanged: onChanged, activeColor: c.primary),
        ],
      ),
    );
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final AppColors c;
  final TextTheme tt;
  const _SectionLabel({required this.label, required this.c, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: tt.labelSmall?.copyWith(
        color: c.onSurfaceTertiary,
        letterSpacing: 1.0,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;
  const _SettingsCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: isDark ? darkCardDecoration() : lightCardDecoration(),
      clipBehavior: Clip.hardEdge,
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final AppColors c;
  final TextTheme tt;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.c,
    required this.tt,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleSmall?.copyWith(color: c.onSurface),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: tt.bodySmall?.copyWith(
                        color: c.onSurfaceSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
