import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fit_and_fine/core/constants/constant.dart';

class WorkoutDataSource {
  final http.Client client;
  WorkoutDataSource({http.Client? client}) : client = client ?? http.Client();

  // Reusable private method for headers, just like in your reference.
  Map<String, String> _headers(String token) => {
    'Content-Type': 'application/json',
    'x-api-key': AppConstants.xApiKey,
    'Authorization': 'Bearer $token',
  };

  /// Fetches the user's assigned weekly workout plan from the backend.
  /// Corresponds to: GET /api/users/me/workout-plan
  Future<Map<String, dynamic>?> fetchWorkoutPlan(String token) async {
    try {
      final response = await client.get(
        Uri.parse('${AppConstants.baseUrl}/member/me/workout-plan'),
        headers: _headers(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'];
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch workout plan');
      }
    } catch (e) {
      // Re-throwing with a more specific message can be helpful for debugging.
      throw Exception('Error in fetchWorkoutPlan: $e');
    }
  }

  /// Fetches the list of all exercises from the library.
  /// Corresponds to: GET /api/users/exercises
  Future<List<dynamic>> fetchExerciseLibrary(String token) async {
    try {
      final response = await client.get(
        Uri.parse('${AppConstants.baseUrl}/member/exercises'),
        headers: _headers(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'] as List<dynamic>;
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch exercise library');
      }
    } catch (e) {
      throw Exception('Error in fetchExerciseLibrary: $e');
    }
  }
}
