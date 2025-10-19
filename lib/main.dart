import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rem_mm/core/config/env.dart';
import 'package:rem_mm/core/theme/app_theme.dart';
import 'package:rem_mm/features/auth/presentation/widgets/auth_wrapper.dart';
import 'package:rem_mm/features/settings/presentation/providers/settings_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);

  runApp(const ProviderScope(child: RemMmApp()));
}

class RemMmApp extends ConsumerWidget {
  const RemMmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch<ThemeMode>(themeModeProvider);
    final appTheme = ref.watch(appThemeProvider);

    return MaterialApp(
      title: 'rem_mm - Fantasy Football AI',
      debugShowCheckedModeBanner: false,
      theme: appTheme.lightTheme,
      darkTheme: appTheme.darkTheme,
      themeMode: themeMode, // Defaults to dark mode
      home: const AuthWrapper(),
    );
  }
}
