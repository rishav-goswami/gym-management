// ============================
// ✅ auth_remote_data_source.dart
// ============================

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fit_and_fine/core/constants/constant.dart';

class AuthRemoteDataSource {
  final http.Client client;

  AuthRemoteDataSource({required this.client});

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    required String role,
  }) async {
    final response = await client.post(
      Uri.parse('${AppConstants.baseUrl}/auth/login'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': AppConstants.xApiKey,
      },
      body: jsonEncode({'email': email, 'password': password, 'role': role}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['data'] != null) {
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Login failed');
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required String role,
  }) async {
    final response = await client.post(
      Uri.parse('${AppConstants.baseUrl}/auth/register'),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': AppConstants.xApiKey,
      },
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'confirmPassword': confirmPassword,
        "role": role,
      }),
    );

    final data = jsonDecode(response.body);
    debugPrint("Response On Register: $data");
    if (response.statusCode == 201 && data['data'] != null) {
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Registration failed');
    }
  }
}
