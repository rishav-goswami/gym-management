import 'package:fit_and_fine/data/models/auth_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fit_and_fine/data/repositories/auth_repository.dart';
import 'package:fit_and_fine/logic/auth/auth_event.dart';
import 'package:fit_and_fine/logic/auth/auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repository;

  AuthBloc(this.repository) : super(AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthUserUpdated>(_onAuthUserUpdated);
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final authModel = await repository.login(
        email: event.email,
        password: event.password,
        role: event.role,
      );

      emit(AuthAuthenticated(authModel: authModel));
    } catch (e) {
      emit(AuthError('Login failed: $e'));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final authModel = await repository.register(
        name: event.name,
        email: event.email,
        password: event.password,
        confirmPassword: event.confirmPassword,
        role: event.role,
      );

      emit(AuthAuthenticated(authModel: authModel));
    } catch (e) {
      emit(AuthError('Registration failed: $e'));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await repository.logout();
    emit(AuthUnauthenticated());
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final authModel = await repository.tryAutoLogin();
    print("AuthModel: $authModel");
    if (authModel != null) {
      emit(AuthAuthenticated(authModel: authModel));
    } else {
      emit(AuthUnauthenticated());
    }
  }

  void _onAuthUserUpdated(AuthUserUpdated event, Emitter<AuthState> emit) {
    // Check if the user is currently authenticated
    final currentState = state;
    if (currentState is AuthAuthenticated) {
      // Create a new AuthModel with the existing token but the NEW user data
      final newAuthModel = AuthModel(
        accessToken: currentState.authModel.accessToken,
        user: event.updatedUser,
      );
      // Emit a new AuthAuthenticated state with the updated model
      emit(AuthAuthenticated(authModel: newAuthModel));
    }
  }
}
