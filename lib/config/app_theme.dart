import 'package:flutter/material.dart';

/// Agent Cypher mobile-first design system.
///
/// The palette intentionally stays neutral so conversation content remains the
/// visual focus. Accent color is reserved for actions and important states.
class AgentCypherTheme {
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF7F7F8);
  static const Color lightSurfaceAlt = Color(0xFFF0F0F0);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightText = Color(0xFF202123);
  static const Color lightTextSecondary = Color(0xFF6E6E80);
  static const Color lightBorder = Color(0xFFE5E5E5);
  static const Color lightAccent = Color(0xFF10A37F);

  static const Color darkBg = Color(0xFF212121);
  static const Color darkSurface = Color(0xFF2F2F2F);
  static const Color darkSurfaceAlt = Color(0xFF3A3A3A);
  static const Color darkCard = Color(0xFF2F2F2F);
  static const Color darkText = Color(0xFFECECEC);
  static const Color darkTextSecondary = Color(0xFFB4B4B4);
  static const Color darkBorder = Color(0xFF4A4A4A);
  static const Color darkAccent = Color(0xFF19C37D);

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: lightAccent,
      colorScheme: const ColorScheme.light(
        primary: lightAccent,
        secondary: lightAccent,
        surface: lightSurface,
        onSurface: lightText,
        surfaceContainer: lightSurfaceAlt,
        error: Colors.redAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBg,
        foregroundColor: lightText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightAccent, width: 1.2),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: lightText, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: lightText, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: lightText, fontWeight: FontWeight.w400),
        labelMedium: TextStyle(
          color: lightTextSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBg,
      primaryColor: darkAccent,
      colorScheme: const ColorScheme.dark(
        primary: darkAccent,
        secondary: darkAccent,
        surface: darkSurface,
        onSurface: darkText,
        surfaceContainer: darkSurfaceAlt,
        error: Colors.redAccent,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBg,
        foregroundColor: darkText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkAccent, width: 1.2),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(color: darkText, fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(color: darkText, fontWeight: FontWeight.w400),
        labelMedium: TextStyle(
          color: darkTextSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
