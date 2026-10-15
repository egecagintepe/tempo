import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TempoTheme {
  // Brand Color Palette
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color electricCyan = Color(0xFF06B6D4);
  static const Color emeraldActive = Color(0xFF10B981);
  static const Color amberWarning = Color(0xFFF59E0B);
  static const Color roseExhausted = Color(0xFFF43F5E);
  static const Color purpleProtected = Color(0xFF8B5CF6);

  // 1. Dark Theme (Obsidian & Charcoal)
  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF09090B),
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: electricCyan,
        surface: Color(0xFF18181B),
        surfaceContainerHighest: Color(0xFF27272A),
        error: roseExhausted,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
      cardTheme: CardThemeData(
        color: const Color(0xFF18181B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF27272A), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF09090B),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF09090B),
        indicatorColor: primaryBlue.withOpacity(0.2),
        elevation: 0,
      ),
    );
  }

  // 2. Light Theme (Warm-neutral / Soft Paper)
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFFF4F4F5),
      colorScheme: const ColorScheme.light(
        primary: primaryBlue,
        secondary: electricCyan,
        surface: Colors.white,
        surfaceContainerHighest: Color(0xFFE4E4E7),
        error: roseExhausted,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE4E4E7), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF4F4F5),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFFF4F4F5),
        indicatorColor: primaryBlue.withOpacity(0.15),
        elevation: 0,
      ),
    );
  }

  // 3. OLED Black Theme (Pure Jet Black)
  static ThemeData get oledTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.black,
      colorScheme: const ColorScheme.dark(
        primary: primaryBlue,
        secondary: electricCyan,
        surface: Color(0xFF121212),
        surfaceContainerHighest: Color(0xFF1F1F1F),
        error: roseExhausted,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
      cardTheme: CardThemeData(
        color: const Color(0xFF121212),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF222222), width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.black,
        indicatorColor: primaryBlue.withOpacity(0.25),
        elevation: 0,
      ),
    );
  }

  // Tabular Stopwatch Numbers Style
  static TextStyle get stopwatchStyle {
    return GoogleFonts.jetBrainsMono(
      fontSize: 56,
      fontWeight: FontWeight.w900,
      letterSpacing: -1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}
