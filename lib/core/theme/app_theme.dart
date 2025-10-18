import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// Custom theme provider that creates both light and dark themes
final appThemeProvider = Provider<AppTheme>((ref) => AppTheme());

class AppTheme {
  // Color palette from copilot-instructions.md
  static const Color primaryOrange = Color(0xFFF58031);
  static const Color secondaryBlue = Color(0xFF32ACE3);
  static const Color tertiaryGreen = Color(0xFF59ba32);

  // Light theme
  ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryOrange,
      brightness: Brightness.light,
    ).copyWith(primary: primaryOrange, secondary: secondaryBlue, tertiary: tertiaryGreen),
    textTheme: _textTheme,
    appBarTheme: _lightAppBarTheme,
  );

  // Dark theme
  ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryOrange,
      brightness: Brightness.dark,
    ).copyWith(primary: primaryOrange, secondary: secondaryBlue, tertiary: tertiaryGreen),
    textTheme: _textTheme,
    appBarTheme: _darkAppBarTheme,
  );

  // Shared text theme - bolder and smaller per user request
  TextTheme get _textTheme => GoogleFonts.robotoSlabTextTheme().copyWith(
    // Body text uses Roboto Slab - now bolder (w500) and smaller
    bodyLarge: GoogleFonts.robotoSlab(fontWeight: FontWeight.w500, fontSize: 14),
    bodyMedium: GoogleFonts.robotoSlab(fontWeight: FontWeight.w500, fontSize: 12),
    bodySmall: GoogleFonts.robotoSlab(fontWeight: FontWeight.w500, fontSize: 10),
    // Headings use Raleway - now bolder (w600) and smaller
    headlineLarge: GoogleFonts.raleway(fontWeight: FontWeight.w600, fontSize: 28),
    headlineMedium: GoogleFonts.raleway(fontWeight: FontWeight.w600, fontSize: 22),
    headlineSmall: GoogleFonts.raleway(fontWeight: FontWeight.w600, fontSize: 18),
    titleLarge: GoogleFonts.raleway(fontWeight: FontWeight.w600, fontSize: 18),
    titleMedium: GoogleFonts.raleway(fontWeight: FontWeight.w600, fontSize: 14),
    titleSmall: GoogleFonts.raleway(fontWeight: FontWeight.w600, fontSize: 12),
    labelLarge: GoogleFonts.robotoSlab(fontWeight: FontWeight.w600, fontSize: 12),
    labelMedium: GoogleFonts.robotoSlab(fontWeight: FontWeight.w600, fontSize: 10),
    labelSmall: GoogleFonts.robotoSlab(fontWeight: FontWeight.w600, fontSize: 8),
  );

  // Light app bar theme - smaller and bolder
  AppBarTheme get _lightAppBarTheme => AppBarTheme(
    backgroundColor: primaryOrange,
    foregroundColor: Colors.white,
    titleTextStyle: GoogleFonts.raleway(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
  );

  // Dark app bar theme - smaller and bolder
  AppBarTheme get _darkAppBarTheme => AppBarTheme(
    backgroundColor: primaryOrange,
    foregroundColor: Colors.white,
    titleTextStyle: GoogleFonts.raleway(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: Colors.white,
    ),
  );
}
