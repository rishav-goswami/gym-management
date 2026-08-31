part of './theme.dart';

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,

  /// Base screen background color
  scaffoldBackgroundColor: AppColors.backgroundLight,

  /// App bar default color (transparent to blend with scaffold)
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    foregroundColor: AppColors.textPrimaryLight,
    elevation: 0,
    centerTitle: true,
  ),

  /// Used for Card widgets, containers, and inner surfaces
  cardColor: AppColors.cardLight,

  /// Text styles for headings and paragraphs. main.dart replaces this
  /// theme's `colorScheme` per-build with a brand-derived scheme, so every
  /// role here is pinned explicitly rather than left to fall back to a
  /// colorScheme-driven Material default.
  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimaryLight,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimaryLight,
    ),
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: AppColors.textPrimaryLight,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimaryLight,
    ),
    bodyLarge: TextStyle(fontSize: 16, color: AppColors.textPrimaryLight),
    bodyMedium: TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
    bodySmall: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
  ),
);
