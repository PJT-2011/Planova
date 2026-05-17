import 'package:flutter/material.dart';
import 'package:planova_mobile/main.dart';

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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Appearance section ─────────────────────────────────────────
            _SectionHeader(title: 'Appearance'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Dark mode toggle
                  SwitchListTile(
                    secondary: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: isDark ? Colors.amber : Colors.orange,
                    ),
                    title: const Text('Dark Mode'),
                    subtitle: Text(
                      isDark ? 'Dark theme active' : 'Light theme active',
                    ),
                    value: isDark,
                    onChanged: (val) async {
                      await appState?.toggleTheme(val);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── About section ──────────────────────────────────────────────
            _SectionHeader(title: 'About'),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.blue),
                    title: const Text('Version'),
                    trailing: const Text(
                      '1.0.0',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const Icon(Icons.map, color: Colors.blue),
                    title: const Text('About Planova'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'Planova',
                      applicationVersion: '1.0.0',
                      applicationIcon: const Icon(
                        Icons.map,
                        color: Colors.blue,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey[600],
        letterSpacing: 0.5,
      ),
    );
  }
}
