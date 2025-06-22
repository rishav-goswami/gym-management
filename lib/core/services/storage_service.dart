// lib/core/services/storage_service.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../constants/auth_role_enum.dart';

/// Shared Preferences keys
class StorageKeys {
  static const String role = 'user_role'; // "ADMIN", "TRAINER", "USER"
  static const String isLoggedIn = 'logged_in'; // true/false
}

/// Service for storing simple app data

class StorageService {
  static Future<void> saveUserRole(AuthRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.role, role.name);
    // await prefs.setBool(StorageKeys.isLoggedIn, true);
  }

  static Future<AuthRole?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final roleStr = prefs.getString(StorageKeys.role);
    return AuthRole.fromString(roleStr);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(StorageKeys.isLoggedIn) ?? false;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.role);
    await prefs.setBool(StorageKeys.isLoggedIn, false);
  }
}
