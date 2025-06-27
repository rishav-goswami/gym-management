// ============================
// ✅ auth_bloc.dart (Refactored)
// ============================

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fit_and_fine/data/repositories/auth_repository.dart';
import 'package:fit_and_fine/logic/auth/auth_event.dart';
import 'package:fit_and_fine/logic/auth/auth_state.dart';
import 'package:fit_and_fine/data/models/auth_model.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repository;

  AuthBloc(this.repository) : super(AuthInitial()) {
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
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
      // 2. Emit the state with the complete model.
      emit(AuthAuthenticated(authModel: authModel));
      // --- END OF CHANGE ---
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
      // --- CHANGE IS HERE ---
      // 1. The repository now returns a single AuthModel.
      final authModel = await repository.register(
        name: event.name,
        email: event.email,
        password: event.password,
        confirmPassword: event.confirmPassword,
        role: event.role,
      );
      // 2. Emit the state with the complete model.
      emit(AuthAuthenticated(authModel: authModel));
      // --- END OF CHANGE ---
    } catch (e) {
      emit(AuthError('Registration failed: $e'));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // This part was already correct and needs no changes.
    await repository.logout();
    emit(AuthUnauthenticated());
  }
}
