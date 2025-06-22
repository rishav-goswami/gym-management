part of './theme.dart';

/// App-wide color palette extracted from your provided UI samples
class AppColors {
  // =========================
  // 🎨 Primary Brand Colors
  // =========================

  /// Used for app bars, highlights, and primary buttons
  static const Color primary = Color(0xFF101522);  // Deep navy

  /// Used for secondary actions like floating buttons, toggles, etc.
  static const Color accent = Color(0xFF4FADF7);   // Sky blue

  // =========================
  // 🎨 Background Colors
  // =========================

  /// Default background in light mode (screens, scaffold, etc.)
  static const Color backgroundLight = Color(0xFFFFFFFF); // Pure white

  /// Default background in dark mode
  static const Color backgroundDark = Color(0xFF0D1117); // Soft black/navy

  // =========================
  // 🎨 Text Colors
  // =========================

  /// Main text (titles, primary labels) in light theme
  static const Color textPrimaryLight = Color(0xFF1F2937); // Almost black

  /// Secondary/inactive text in light theme (subtitles, labels)
  static const Color textSecondaryLight = Color(0xFF6B7280); // Muted gray

  /// Main text in dark mode
  static const Color textPrimaryDark = Color(0xFFF4F4F6); // Soft white

  /// Secondary text in dark mode
  static const Color textSecondaryDark = Color(0xFF9CA3AF); // Muted gray

  // =========================
  // 🎨 Card and Surface Colors
  // =========================

  /// Card and container backgrounds in light mode
  static const Color cardLight = Color(0xFFF9FAFB); // Very light gray

  /// Card and container backgrounds in dark mode
  static const Color cardDark = Color(0xFF161B22); // Slightly lighter than background

  // =========================
  // 🎨 Semantic Colors
  // =========================

  /// Used for success indicators (green check icons, progress, etc.)
  static const Color success = Color(0xFF10B981); // Emerald

  /// Used for error states (error text, borders, etc.)
  static const Color error = Color(0xFFEF4444); // Bright red
}

