// ============================
// ✅ auth_repository.dart
// ============================

import 'package:fit_and_fine/data/datasources/auth_remote_data_source.dart';
import 'package:fit_and_fine/core/services/storage_service.dart';
import 'package:fit_and_fine/data/models/user_profile.dart';
import 'package:fit_and_fine/core/constants/auth_role_enum.dart';

class AuthRepository {
  final AuthRemoteDataSource remote;

  AuthRepository({required this.remote});

  Future<(String token, UserProfile user)> login({
    required String email,
    required String password,
    required AuthRole role,
  }) async {
    final data = await remote.login(
      email: email,
      password: password,
      role: role.name,
    );
    final token = data['token'] as String;
    final user = UserProfile.fromMap(data['user']);

    await StorageService.saveToken(token);
    await StorageService.saveUserRole(role);
    await StorageService.setLoginFlag(true);

    return (token, user);
  }

  Future<(String token, UserProfile user)> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required AuthRole role,
  }) async {
    final data = await remote.register(
      name: name,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      role: role.name,
    );

    final token = data['token'] as String;
    final user = UserProfile.fromMap(data['user']);

    await StorageService.saveToken(token);
    await StorageService.setLoginFlag(true);

    return (token, user);
  }

  Future<void> logout() async {
    await StorageService.logout();
  }
}
