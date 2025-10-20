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

  // Light theme - more elevated and compact like phlux
  ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryOrange,
      brightness: Brightness.light,
    ).copyWith(primary: primaryOrange, secondary: secondaryBlue, tertiary: tertiaryGreen),
    textTheme: _textTheme,
    appBarTheme: _lightAppBarTheme,
    cardTheme: CardThemeData(
      elevation: 6,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x293A3A3A), width: 1),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF242424),
      elevation: 6,
      selectedItemColor: primaryOrange,
      unselectedItemColor: const Color(0xFFB0B0B0),
      selectedLabelStyle: _textTheme.labelMedium,
      unselectedLabelStyle: _textTheme.labelMedium,
      type: BottomNavigationBarType.fixed,
    ),
    // allow gradient background to show through
    scaffoldBackgroundColor: Colors.transparent,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 2,
        shadowColor: primaryOrange.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
  );

  // Dark theme with elevated, less dark styling (like phlux)
  ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: primaryOrange,
          brightness: Brightness.dark,
        ).copyWith(
          primary: primaryOrange,
          secondary: secondaryBlue,
          tertiary: tertiaryGreen,
          surface: const Color(0xFF121212), // Dark gray background
          background: const Color(0xFF121212), // Dark gray background
          surfaceVariant: const Color(
            0xFF2D2D2D,
          ), // Lighter surface for cards - increased contrast
          onSurfaceVariant: const Color(0xFFE0E0E0), // Light gray for secondary text
          outline: const Color(
            0xFF555555,
          ), // Lighter gray for borders - better visibility
        ),
    // Make scaffold transparent so the global gradient background is visible
    scaffoldBackgroundColor: Colors.transparent,
    // Cards remain lighter than the scaffold to pop off the background
    cardColor: const Color(0xFF222222), // Darker card color for clearer separation
    textTheme: _textTheme,
    appBarTheme: _darkAppBarTheme,
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        elevation: 2, // Reduced from 8
        shadowColor: primaryOrange.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E1E1E), // Darker cards for improved contrast with gradient
      elevation: 6, // match AppBar elevation
      shadowColor: Colors.black54,
      surfaceTintColor: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x293A3A3A), width: 1),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: const Color(0xFF242424),
      elevation: 6,
      selectedItemColor: primaryOrange,
      unselectedItemColor: const Color(0xFF9E9E9E),
      selectedLabelStyle: _textTheme.labelMedium,
      unselectedLabelStyle: _textTheme.labelMedium,
      type: BottomNavigationBarType.fixed,
    ),
    // Enhanced container decorations for headers and panels
    listTileTheme: ListTileThemeData(
      tileColor: const Color(0xFF2D2D2D), // Lighter tile color for better contrast
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  // Shared text theme
  // Headers: use Roboto Slab (slab-serif) with controlled sizes/weights so headers match app bar
  // Body/content: use a serif font (Merriweather) for readable, classic content typography
  TextTheme get _textTheme => TextTheme(
    // Headlines / titles (Roboto Slab)
    headlineLarge: GoogleFonts.robotoSlab(fontWeight: FontWeight.w600, fontSize: 26),
    headlineMedium: GoogleFonts.robotoSlab(fontWeight: FontWeight.w600, fontSize: 20),
    headlineSmall: GoogleFonts.robotoSlab(fontWeight: FontWeight.w600, fontSize: 16),
    titleLarge: GoogleFonts.robotoSlab(fontWeight: FontWeight.w600, fontSize: 18),
    titleMedium: GoogleFonts.robotoSlab(fontWeight: FontWeight.w600, fontSize: 14),
    titleSmall: GoogleFonts.robotoSlab(fontWeight: FontWeight.w600, fontSize: 12),

    // Body (Merriweather - serif)
    bodyLarge: GoogleFonts.merriweather(fontWeight: FontWeight.w500, fontSize: 14),
    bodyMedium: GoogleFonts.merriweather(fontWeight: FontWeight.w500, fontSize: 12),
    bodySmall: GoogleFonts.merriweather(fontWeight: FontWeight.w500, fontSize: 10),

    // Labels (use Roboto Slab small labels for consistency)
    labelLarge: GoogleFonts.robotoSlab(fontWeight: FontWeight.w600, fontSize: 12),
    labelMedium: GoogleFonts.robotoSlab(fontWeight: FontWeight.w600, fontSize: 10),
    labelSmall: GoogleFonts.robotoSlab(fontWeight: FontWeight.w600, fontSize: 9),
  );

  // Light app bar theme - smaller and bolder
  AppBarTheme get _lightAppBarTheme => AppBarTheme(
    // Use the dark-gray + orange look even in light mode for consistency
    backgroundColor: const Color(0xFF242424),
    foregroundColor: primaryOrange,
    elevation: 6,
    // Use Roboto Slab for app bar title to align with headers; slightly lighter weight than bold
    titleTextStyle: GoogleFonts.robotoSlab(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: primaryOrange,
    ),
    // Add a thin bottom divider to emphasize separation on flat platforms
    shape: _BottomDividerShape(
      BorderSide(color: const Color(0xFF2A2A2A).withOpacity(0.18), width: 1),
    ),
  );

  // Dark app bar theme with stronger contrast against the scaffold background
  AppBarTheme get _darkAppBarTheme => AppBarTheme(
    backgroundColor: const Color(0xFF242424), // noticeably lighter than scaffold
    foregroundColor: primaryOrange,
    elevation: 6, // a little more elevation to create separation
    titleTextStyle: GoogleFonts.robotoSlab(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: primaryOrange,
    ),
    iconTheme: const IconThemeData(color: Color(0xFFF58031)),
    surfaceTintColor: const Color(0xFF2A2A2A),
    shape: _BottomDividerShape(
      BorderSide(color: const Color(0xFF2A2A2A).withOpacity(0.18), width: 1),
    ),
  );
}

// Draws a single-pixel bottom divider for app bars
class _BottomDividerShape extends ShapeBorder {
  final BorderSide side;

  _BottomDividerShape(this.side);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(bottom: side.width);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()..addRect(rect.deflate(side.width));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final paint = Paint()
      ..color = side.color
      ..strokeWidth = side.width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final y = rect.bottom - (side.width / 2);
    canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
  }

  @override
  ShapeBorder scale(double t) =>
      _BottomDividerShape(BorderSide(color: side.color, width: side.width * t));
}
