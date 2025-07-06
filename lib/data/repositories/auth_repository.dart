import 'package:fit_and_fine/data/datasources/auth_remote_data_source.dart';
import 'package:fit_and_fine/core/services/storage_service.dart';
import 'package:fit_and_fine/core/constants/user_role_enum.dart';
// import 'package:fit_and_fine/data/datasources/testing_remote_auth_source.dart';
import 'package:fit_and_fine/data/models/auth_model.dart';

class AuthRepository {
  final AuthRemoteDataSource remote;

  AuthRepository({required this.remote});

  // The login method now returns a single, clean AuthModel object.
  Future<AuthModel> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final data = await remote.login(
      email: email,
      password: password,
      role: role.name,
    );

    // The AuthModel factory now handles all the parsing logic.
    // It reads the 'token' and dynamically creates the correct User object.
    final authModel = AuthModel.fromJson(data);

    // Save token and role from the new model
    await StorageService.saveToken(authModel.accessToken);
    await StorageService.saveUserRole(
      authModel.user.role,
    ); // Role comes from the user object
    await StorageService.setLoginFlag(true);

    return authModel;
  }

  // The register method is also updated to return AuthModel.
  Future<AuthModel> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required UserRole role,
  }) async {
    final data = await remote.register(
      name: name,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      role: role.name,
    );

    // Same logic as login: let the AuthModel do the heavy lifting.
    final authModel = AuthModel.fromJson(data);

    await StorageService.saveToken(authModel.accessToken);
    await StorageService.saveUserRole(authModel.user.role);
    await StorageService.setLoginFlag(true);

    return authModel;
  }

  Future<void> logout() async {
    await StorageService.logout();
  }

  /// Checks for a saved session and attempts to auto-login.
  /// Returns AuthModel on success, null on failure.
  Future<AuthModel?> tryAutoLogin() async {
    try {
      // 1. Check for a token in storage
      final token = await StorageService.getToken();
      if (token == null) {
        return null; // No session exists
      }

      // 2. Token exists, now validate it with the backend
      final userJson = await remote.getMe(token); // uncomment original live

      // final TestingRemoteDataSource testingRemoteDataSource =
      //     TestingRemoteDataSource(); // just for mocking
      // final userJson = await testingRemoteDataSource.getMe(
      //   token,
      // ); // just for mocking wihtout backend

      print("userJson: $userJson");
      // 3. If validation is successful, construct the AuthModel
      // We pass the existing token and the fresh user data from the API
      return AuthModel.fromJson({'token': token, 'user': userJson});
    } catch (e) {
      // If any error occurs (e.g., 401 from API), the session is invalid.
      // Clean up the invalid stored data.
      await StorageService.logout();
      return null;
    }
  }
}
