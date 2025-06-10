import 'package:flutter/material.dart';

class AppColors {
  // Gym-inspired palette
  static const Color primary = Color(0xFF232946); // Deep navy blue (strength, focus)
  static const Color accent = Color(0xFFFF8906); // Vibrant orange (energy, action)
  static const Color background = Color(0xFFF4F4F6); // Light gray (clean, modern)
  static const Color card = Color(0xFFFFFFFF); // White card for light
  static const Color textPrimary = Color(0xFF121629); // Almost black (readability)
  static const Color textSecondary = Color(0xFF6B7280); // Muted gray (secondary info)
  static const Color button = Color(0xFFFF8906); // Orange (call to action)
  static const Color error = Color(0xFFDF2935); // Strong red (error/alert)
  static const Color gradientStart = Color(0xFF232946); // Deep navy
  static const Color gradientEnd = Color(0xFFFF8906); // Orange

  // Dark theme overrides (gym, bold/modern)
  static const Color darkBackground = Color(0xFF121629); // Deep navy/black
  static const Color darkCard = Color(0xFF232946); // Slightly lighter navy
  static const Color darkTextPrimary = Color(0xFFF4F4F6); // Light gray
  static const Color darkTextSecondary = Color(0xFFFF8906); // Orange accent
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
