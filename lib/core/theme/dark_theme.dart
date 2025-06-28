part of 'theme.dart';
final darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.backgroundDark,
  fontFamily: 'Montserrat',
  primaryColor: AppColors.primary,
  cardColor: AppColors.cardDark,

  /// Fix: Override default text color globally
  textTheme: const TextTheme(
    displayLarge: TextStyle(color: AppColors.textPrimaryDark),
    titleLarge: TextStyle(
      color: AppColors.textPrimaryDark,
      fontWeight: FontWeight.bold,
      fontSize: 22,
    ),
    bodyLarge: TextStyle(color: AppColors.textPrimaryDark, fontSize: 16),
    bodyMedium: TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
    bodySmall: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
  ),

  /// Fix: Make sure all color roles are set for contrast
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    secondary: AppColors.primary,
    surface: AppColors.cardDark,

    onPrimary: AppColors.textPrimaryDark, // Text on buttons using primary background
    onSecondary: AppColors.textSecondaryDark,
    onSurface: AppColors.textPrimaryDark,
    onError: Colors.white,
    error: AppColors.error,
  ),

  /// Fix: Make button theme override safe
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent, // default background
      foregroundColor: Colors.white, // default text/icon color
      textStyle: const TextStyle(
        fontWeight: FontWeight.bold,
        fontFamily: 'Montserrat',
        color: AppColors.textPrimaryDark
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    ),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.textPrimaryDark,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      color: AppColors.textPrimaryDark,
      fontWeight: FontWeight.bold,
      fontSize: 22,
    ),
  ),
);
