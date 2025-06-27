import 'package:equatable/equatable.dart';
import 'package:fit_and_fine/data/models/auth_model.dart';
import 'package:fit_and_fine/data/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  // It now holds the complete AuthModel
  final AuthModel authModel;

  // A convenience getter for easy access to the user object
  final User user;

  AuthAuthenticated({required this.authModel}) : user = authModel.user;

  @override
  List<Object> get props => [authModel];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
