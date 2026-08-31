part of 'theme.dart';

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.backgroundDark,
  primaryColor: AppColors.primary,
  cardColor: AppColors.cardDark,

  /// main.dart replaces this theme's `colorScheme` per-build with a
  /// brand-derived scheme, so every text role here is pinned explicitly
  /// rather than left to fall back to a colorScheme-driven Material default.
  textTheme: const TextTheme(
    displayLarge: TextStyle(color: AppColors.textPrimaryDark),
    headlineMedium: TextStyle(
      color: AppColors.textPrimaryDark,
      fontWeight: FontWeight.bold,
      fontSize: 28,
    ),
    headlineSmall: TextStyle(
      color: AppColors.textPrimaryDark,
      fontWeight: FontWeight.bold,
      fontSize: 24,
    ),
    titleLarge: TextStyle(
      color: AppColors.textPrimaryDark,
      fontWeight: FontWeight.bold,
      fontSize: 22,
    ),
    bodyLarge: TextStyle(color: AppColors.textPrimaryDark, fontSize: 16),
    bodyMedium: TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
    bodySmall: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
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
