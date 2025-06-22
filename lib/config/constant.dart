import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App-wide constant values
class AppConstants {
  static const String appName = 'Fit & Fine';
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 12.0;
  static const Duration animationDuration = Duration(milliseconds: 300);

  // API Endpoints
  static final String xApiKey = dotenv.env['X_API_KEY']!;
  static final String baseUrl = dotenv.env['BASE_URL']!;

  // Asset paths
  static const String logoAsset = 'assets/images/logo.png';
}

/// Commonly used colors
class AppColors {
  static const Color primary = Color(0xFF4CAF50);
  static const Color accent = Color(0xFFFFC107);
  static const Color background = Color(0xFFF5F5F5);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
}