import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Settings providers for user preferences

/// Notifier for theme mode that can be changed
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;

  void setLightMode() => state = ThemeMode.light;
  void setDarkMode() => state = ThemeMode.dark;
  void toggleTheme() =>
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
}

/// Notifier for theme toggle that can be changed
class ThemeToggleNotifier extends Notifier<bool> {
  @override
  bool build() => false; // false = dark mode, true = light mode

  void toggle() {
    state = !state;
    // Update theme mode accordingly
    ref.read(themeModeNotifierProvider.notifier).state = state
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  void setLight() {
    state = true;
    ref.read(themeModeNotifierProvider.notifier).setLightMode();
  }

  void setDark() {
    state = false;
    ref.read(themeModeNotifierProvider.notifier).setDarkMode();
  }
}

/// Provider for theme mode
final themeModeNotifierProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Backwards compatibility provider
final themeModeProvider = Provider<ThemeMode>(
  (ref) => ref.watch(themeModeNotifierProvider),
);

/// Provider for theme toggle functionality
final themeToggleNotifierProvider = NotifierProvider<ThemeToggleNotifier, bool>(
  ThemeToggleNotifier.new,
);

/// Backwards compatibility provider
final themeToggleProvider = Provider<bool>(
  (ref) => ref.watch(themeToggleNotifierProvider),
);
