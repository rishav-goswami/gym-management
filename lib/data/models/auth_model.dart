// lib/data/auth_model.dart
import 'package:fit_and_fine/core/constants/user_role_enum.dart';

import 'user_model.dart';

class AuthModel {
  final String accessToken;
  final User user; // Holds an instance of Member, Trainer, or Admin

  AuthModel({required this.accessToken, required this.user});

  factory AuthModel.fromJson(Map<String, dynamic> json) {
    // 1. Read the role from the user object in the JSON
    final userJson = json['user'] as Map<String, dynamic>;
    final role = UserRole.fromString(userJson['role'])!;

    // 2. Based on the role, create the correct concrete User object
    User user;
    switch (role) {
      case UserRole.member:
        user = Member.fromJson(userJson);
        break;
      case UserRole.trainer:
        user = Trainer.fromJson(userJson);
        break;
      case UserRole.admin:
        user = Admin.fromJson(userJson);
        break;
    }

    // 3. Return the complete AuthModel
    return AuthModel(accessToken: json['token'], user: user);
  }
}
