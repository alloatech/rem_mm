import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/env.dart';
import 'features/fantasy_advice/presentation/pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);

  runApp(const ProviderScope(child: RemMmApp()));
}

class RemMmApp extends StatelessWidget {
  const RemMmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'rem_mm - Fantasy Football AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFFF58031), // Orange from palette
              brightness: Brightness.light,
            ).copyWith(
              secondary: const Color(0xFF32ACE3), // Blue from palette
              tertiary: const Color(0xFF59ba32), // Green from palette
            ),
        textTheme: GoogleFonts.robotoSlabTextTheme().copyWith(
          // Body text uses Roboto Slab weight 100
          bodyLarge: GoogleFonts.robotoSlab(fontWeight: FontWeight.w100),
          bodyMedium: GoogleFonts.robotoSlab(fontWeight: FontWeight.w100),
          bodySmall: GoogleFonts.robotoSlab(fontWeight: FontWeight.w100),
          // Headings use Raleway weight 400
          headlineLarge: GoogleFonts.raleway(fontWeight: FontWeight.w400),
          headlineMedium: GoogleFonts.raleway(fontWeight: FontWeight.w400),
          headlineSmall: GoogleFonts.raleway(fontWeight: FontWeight.w400),
          titleLarge: GoogleFonts.raleway(fontWeight: FontWeight.w400),
          titleMedium: GoogleFonts.raleway(fontWeight: FontWeight.w400),
          titleSmall: GoogleFonts.raleway(fontWeight: FontWeight.w400),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFF58031),
          foregroundColor: Colors.white,
          titleTextStyle: GoogleFonts.raleway(
            fontSize: 24,
            fontWeight: FontWeight.w400,
            color: Colors.white,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}
