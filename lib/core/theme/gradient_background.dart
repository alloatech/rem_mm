import 'package:flutter/material.dart';

/// Custom gradient background for the app
/// Uses a subtle gradient from black to very dark gray
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          // diagonal gradient from top-left to bottom-right
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF3B3B3B), // edge: lighter gray
                  const Color(0xFF2E2E2E), // edge -> inner transition
                  const Color(0xFF181818), // center: darker to increase contrast
                  const Color(0xFF2E2E2E), // mirror
                  const Color(0xFF3B3B3B), // edge: lighter gray
                ]
              : [
                  theme.colorScheme.surface,
                  theme.colorScheme.surfaceVariant,
                  theme.colorScheme.surface, // simpler for light mode
                ],
          stops: isDark ? const [0.0, 0.25, 0.5, 0.75, 1.0] : const [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}
