import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/features/settings/presentation/providers/settings_providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeToggle = ref.watch<bool>(themeToggleProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'settings',
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Theme Section
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'appearance',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Theme Toggle
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      themeToggle ? Icons.light_mode : Icons.dark_mode,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      'theme mode',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      themeToggle ? 'light mode' : 'dark mode',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Switch(
                      value: themeToggle,
                      onChanged: (value) {
                        ref.read(themeToggleNotifierProvider.notifier).toggle();
                      },
                      activeColor: theme.colorScheme.primary,
                    ),
                  ),

                  const Divider(),

                  // Theme Selection Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ref.read(themeToggleNotifierProvider.notifier).setDark();
                          },
                          icon: const Icon(Icons.dark_mode),
                          label: const Text('dark'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: !themeToggle
                                ? theme.colorScheme.primaryContainer
                                : null,
                            foregroundColor: !themeToggle
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ref.read(themeToggleNotifierProvider.notifier).setLight();
                          },
                          icon: const Icon(Icons.light_mode),
                          label: const Text('light'),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: themeToggle
                                ? theme.colorScheme.primaryContainer
                                : null,
                            foregroundColor: themeToggle
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Color Palette Preview
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'color palette',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Color swatches
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ColorSwatch(
                        color: const Color(0xFFF58031),
                        label: 'primary orange',
                        theme: theme,
                      ),
                      _ColorSwatch(
                        color: const Color(0xFF32ACE3),
                        label: 'secondary blue',
                        theme: theme,
                      ),
                      _ColorSwatch(
                        color: const Color(0xFF59ba32),
                        label: 'tertiary green',
                        theme: theme,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // App Info
          Text(
            'rem_mm - fantasy football assistant',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final String label;
  final ThemeData theme;

  const _ColorSwatch({required this.color, required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
