import 'package:flutter_dotenv/flutter_dotenv.dart';

/// App-wide constant values
class AppConstants {
  static const String appName = 'Fit & Fine';
  static const double defaultPadding = 16.0;
  static const double defaultRadius = 12.0;
  static const Duration animationDuration = Duration(milliseconds: 300);

  // API Endpoints
  static final String xApiKey = dotenv.env['X_API_KEY']!;
  static final String baseUrl = "http://192.168.169.249:3002"; //dotenv.env['BASE_URL']!;

  // Asset paths
  static const String logoAsset = 'assets/images/logo.png';
}
