import 'dart:convert';
import 'package:fit_and_fine/core/constants/constant.dart';
import 'package:http/http.dart' as http;
import 'package:fit_and_fine/data/models/fitness_goals_model.dart'; // Make sure this is updated
import 'package:flutter/foundation.dart';

class FitnessGoalsDataSource {
  final String _baseUrl =
      '${AppConstants.baseUrl}/member'; // !!! IMPORTANT: Replace with your actual base URL

  Future<FitnessGoals> getFitnessGoals(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/fitness-goals'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'x-api-key': AppConstants.xApiKey,
      },
    );

    if (response.statusCode == 200) {
      return FitnessGoals.fromJson(json.decode(response.body)['data']);
    } else {
      throw Exception('Failed to load fitness goals: ${response.body}');
    }
  }

  Future<FitnessGoals> updateFitnessGoals(
    String token,
    Map<String, dynamic> updates,
  ) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/fitness-goals'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'x-api-key': AppConstants.xApiKey,
      },
      body: json.encode(updates),
    );

    if (response.statusCode == 200) {
      return FitnessGoals.fromJson(json.decode(response.body)['data']);
    } else {
      throw Exception('Failed to update fitness goals: ${response.body}');
    }
  }

  // NEW: Fetch all health goal options
  Future<List<OptionItem>> fetchHealthGoalsOptions(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/options/health-goals'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'x-api-key': AppConstants.xApiKey,
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body)['data'];
      return jsonList.map((json) => OptionItem.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load health goals options: ${response.body}');
    }
  }

  // NEW: Fetch all workout frequency options
  Future<List<OptionItem>> fetchWorkoutFrequencyOptions(String token) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/options/workout-frequencies'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'x-api-key': AppConstants.xApiKey,
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body)['data'];
      return jsonList.map((json) => OptionItem.fromJson(json)).toList();
    } else {
      throw Exception(
        'Failed to load workout frequency options: ${response.body}',
      );
    }
  }

  // NEW: Search workouts
  Future<List<OptionItem>> searchWorkouts(String token, String query) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/options/workouts?search=$query'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'x-api-key': AppConstants.xApiKey,
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body)['data'];
      return jsonList.map((json) => OptionItem.fromJson(json)).toList();
    } else {
      throw Exception('Failed to search workouts: ${response.body}');
    }
  }
}
