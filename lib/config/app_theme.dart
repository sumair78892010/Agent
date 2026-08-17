import 'package:flutter/material.dart';

/// Agent Cypher Premium Design System
/// Warm, sophisticated color palette inspired by JARVIS
class AgentCypherTheme {
  // Light Mode Colors
  static const Color lightBg = Color(0xFFF7F3EE); // Warmest cream
  static const Color lightSurface = Color(0xFFF0EBE3); // Light cream
  static const Color lightSurfaceAlt = Color(0xFFE8E1D6); // Slightly darker cream
  static const Color lightCard = Color(0xFFFFFFFF); // Pure white for cards
  static const Color lightText = Color(0xFF1C1917); // Deep warm black
  static const Color lightTextSecondary = Color(0xFF57534E); // Medium gray
  static const Color lightBorder = Color(0xFFB8B0A6); // Light taupe
  static const Color lightAccent = Color(0xFF3D3833); // Darker accent
  static const Color lightGlass = Color(0xFFD6CFC4); // Soft taupe

  // Dark Mode Colors
  static const Color darkBg = Color(0xFF1C1917); // Deep warm black
  static const Color darkSurface = Color(0xFF252220); // Slightly lighter black
  static const Color darkSurfaceAlt = Color(0xFF2E2A27); // Even lighter black
  static const Color darkCard = Color(0xFF3D3833); // Dark warm gray for cards
  static const Color darkText = Color(0xFFF0EBE3); // Light cream text
  static const Color darkTextSecondary = Color(0xFFB8B0A6); // Light taupe
  static const Color darkBorder = Color(0xFF57534E); // Medium gray border
  static const Color darkAccent = Color(0xFF8C857D); // Medium taupe accent
  static const Color darkGlass = Color(0xFFD6CFC4); // Soft taupe

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBg,
      primaryColor: lightAccent,
      colorScheme: const ColorScheme.light(
        primary: lightAccent,
        secondary: lightBorder,
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
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightAccent, width: 2),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: lightText,
          fontFamily: 'Cormorant Garamond',
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: lightText,
          fontFamily: 'DM Sans',
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: lightText,
          fontFamily: 'DM Sans',
          fontWeight: FontWeight.w400,
        ),
        labelMedium: TextStyle(
          color: lightTextSecondary,
          fontFamily: 'DM Sans',
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
        secondary: darkBorder,
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
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: darkAccent, width: 2),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: darkText,
          fontFamily: 'Cormorant Garamond',
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: darkText,
          fontFamily: 'DM Sans',
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: darkText,
          fontFamily: 'DM Sans',
          fontWeight: FontWeight.w400,
        ),
        labelMedium: TextStyle(
          color: darkTextSecondary,
          fontFamily: 'DM Sans',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
