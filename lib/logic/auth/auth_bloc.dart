import 'dart:convert';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:fit_and_fine/config/constant.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'auth_event.dart';
import 'auth_state.dart';
import '../../models/user_profile.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final String baseUrl = AppConstants.baseUrl;
  final String xApiKey = AppConstants.xApiKey;

  AuthBloc() : super(AuthInitial()) {
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
      debugPrint("xapikey:$xApiKey and baseurl: $baseUrl");

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json', "x-api-key": xApiKey},
        body: jsonEncode({'email': event.email, 'password': event.password}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['data'] != null) {
        emit(
          AuthAuthenticated(
            token: data['data']['token'],
            user: UserProfile.fromMap(data['data']['user']),
          ),
        );
      } else {
        emit(AuthError(data['message'] ?? 'Login failed'));
      }
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
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': event.name,
          'email': event.email,
          'password': event.password,
          'confirmPassword': event.confirmPassword,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['data'] != null) {
        emit(
          AuthAuthenticated(
            token: data['data']['token'] ?? '',
            user: UserProfile.fromMap(data['data']),
          ),
        );
      } else {
        emit(AuthError(data['message'] ?? 'Registration failed'));
      }
    } catch (e) {
      emit(AuthError('Registration failed: $e'));
    }
  }

  void _onLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) {
    emit(AuthUnauthenticated());
  }
}
