import 'package:flutter/material.dart';

class AppColors {
  // Main palette
  static const Color primary = Color(0xFF0F7173); // Teal
  static const Color accent = Color(0xFFB3CBB9); // Muted Mint
  static const Color background = Color(0xFFDDD8B8); // Light Sand (light bg)
  static const Color card = Color(0xFFFFFFFF); // White card for light
  static const Color textPrimary = Color(0xFF02020B); // Deep Black for text
  static const Color textSecondary = Color(0xFF0C120C); // Dark Green-Black for secondary text
  static const Color button = Color(0xFF0F7173); // Teal
  static const Color error = Color(0xFFD00000); // Red (only for errors)
  static const Color gradientStart = Color(0xFFB3CBB9); // Muted Mint
  static const Color gradientEnd = Color(0xFF0F7173); // Teal

  // Dark theme overrides (new, less greenish, more neutral/dark)
  static const Color darkBackground = Color(0xFF181824); // Charcoal dark
  static const Color darkCard = Color(0xFF23232F); // Slightly lighter dark
  static const Color darkTextPrimary = Color(0xFFECECEC); // Soft white
  static const Color darkTextSecondary = Color(0xFFB3CBB9); // Muted Mint (for accent)
}

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: AppColors.primary,
  scaffoldBackgroundColor: AppColors.background,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    elevation: 0,
    titleTextStyle: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
      fontSize: 22,
      letterSpacing: 1.2,
    ),
  ),
  cardColor: AppColors.card,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: AppColors.textPrimary, fontFamily: 'Montserrat'),
    bodyMedium: TextStyle(color: AppColors.textSecondary, fontFamily: 'Montserrat'),
    titleLarge: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 26, fontFamily: 'Montserrat'),
  ),
  colorScheme: ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.accent,
    error: AppColors.error,
    background: AppColors.background,
    surface: AppColors.card,
    onPrimary: Colors.white,
    onSecondary: AppColors.primary,
    onSurface: AppColors.textPrimary,
    onError: Colors.white,
    onBackground: AppColors.textPrimary,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.button,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.card,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.accent, width: 2),
    ),
    labelStyle: const TextStyle(color: AppColors.primary, fontFamily: 'Montserrat'),
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: AppColors.primary,
  scaffoldBackgroundColor: AppColors.darkBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: AppColors.darkTextPrimary,
    elevation: 0,
    titleTextStyle: TextStyle(
      color: AppColors.darkTextPrimary,
      fontWeight: FontWeight.bold,
      fontSize: 22,
      letterSpacing: 1.2,
    ),
  ),
  cardColor: AppColors.darkCard,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: AppColors.darkTextPrimary, fontFamily: 'Montserrat'),
    bodyMedium: TextStyle(color: AppColors.darkTextSecondary, fontFamily: 'Montserrat'),
    titleLarge: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 26, fontFamily: 'Montserrat'),
  ),
  colorScheme: ColorScheme.dark(
    primary: AppColors.primary,
    secondary: AppColors.accent,
    error: AppColors.error,
    background: AppColors.darkBackground,
    surface: AppColors.darkCard,
    onPrimary: AppColors.darkTextPrimary,
    onSecondary: AppColors.primary,
    onSurface: AppColors.darkTextPrimary,
    onError: Colors.white,
    onBackground: AppColors.darkTextPrimary,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.button,
      foregroundColor: AppColors.darkTextPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.darkCard,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.accent, width: 2),
    ),
    labelStyle: const TextStyle(color: AppColors.accent, fontFamily: 'Montserrat'),
  ),
);
