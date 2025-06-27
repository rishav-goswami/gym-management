// lib/core/services/storage_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../constants/auth_role_enum.dart';

/// Shared Preferences keys
class StorageKeys {
  static const String role = 'user_role'; // "ADMIN", "TRAINER", "MEMBER"
  static const String isLoggedIn = 'logged_in'; // true/false
  static const String token = 'auth_token'; // bearer token
}

/// Service for storing user/session-related data
class StorageService {
  /// Save role
  static Future<void> saveUserRole(AuthRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.role, role.name);
  }

  /// Get saved role
  static Future<AuthRole?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString(StorageKeys.role);
    return AuthRole.fromString(roleStr);
  }

  /// Save login status
  static Future<void> setLoginFlag(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(StorageKeys.isLoggedIn, value);
  }

  /// Is user logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.isLoggedIn) ?? false;
  }

  /// Save token
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.token, token);
  }

  /// Get token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.token);
  }

  /// Clear all on logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.role);
    await prefs.remove(StorageKeys.token);
    await prefs.setBool(StorageKeys.isLoggedIn, false);
  }
}
