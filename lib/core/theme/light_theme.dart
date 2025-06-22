part of './theme.dart';

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,

  /// Base screen background color
  scaffoldBackgroundColor: AppColors.backgroundLight,

  /// Global font for the app
  fontFamily: 'Montserrat',

  /// App bar default color (transparent to blend with scaffold)
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.textPrimaryLight,
    elevation: 0,
    centerTitle: true,
  ),

  /// Used for Card widgets, containers, and inner surfaces
  cardColor: AppColors.cardLight,

  /// Text styles for headings and paragraphs
  textTheme: const TextTheme(
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimaryLight,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      color: AppColors.textPrimaryLight,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      color: AppColors.textSecondaryLight,
    ),
  ),

  /// Used by buttons, textfields, etc.
  colorScheme: const ColorScheme.light(
    primary: AppColors.primary,
    secondary: AppColors.accent,
    background: AppColors.backgroundLight,
    surface: AppColors.cardLight,
    onPrimary: Colors.white,       // text/icons on primary (e.g. buttons)
    onSecondary: Colors.white,     // text/icons on accent
  ),
);
