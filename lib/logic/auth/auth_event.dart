import 'package:equatable/equatable.dart';
import 'package:fit_and_fine/core/constants/user_role_enum.dart';
import 'package:fit_and_fine/data/models/user_model.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  final UserRole role;

  const AuthLoginRequested({
    required this.email,
    required this.password,
    required this.role,
  });

  @override
  List<Object?> get props => [email, password, role];
}

class AuthRegisterRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;
  final String confirmPassword;
  final UserRole role;

  const AuthRegisterRequested({
    required this.name,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.role,
  });

  @override
  List<Object?> get props => [name, email, password, confirmPassword, role];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

class AuthUserUpdated extends AuthEvent {
  final User updatedUser;

  const AuthUserUpdated(this.updatedUser);

  @override
  List<Object> get props => [updatedUser];
}
