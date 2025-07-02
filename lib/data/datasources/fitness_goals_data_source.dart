// --- DATA SOURCE (Simulates API) ---
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fit_and_fine/core/constants/constant.dart';

class FitnessGoalsDataSource {
  final http.Client client;
  FitnessGoalsDataSource({http.Client? client}) : client = client ?? http.Client();

  Map<String, String> _headers(String? token) => {
    'Content-Type': 'application/json',
    'x-api-key': AppConstants.xApiKey,
    if (token != null) 'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> fetchFitnessGoals(String token) async {
    try {
      final response = await client.get(
        Uri.parse('${AppConstants.baseUrl}/member/fitness-goals'),
        headers: _headers(token),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'] ?? data;
      } else {
        final errorMsg = data['message'] ?? 'Failed to fetch fitness goals';
        throw Exception('API Error (${response.statusCode}): $errorMsg');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  Future<Map<String, dynamic>> updateFitnessGoals(
    String token,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await client.put(
        Uri.parse('${AppConstants.baseUrl}/member/fitness-goals'),
        headers: _headers(token),
        body: jsonEncode(updates),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return data['data'] ?? data;
      } else {
        final errorMsg = data['message'] ?? 'Failed to update fitness goals';
        throw Exception('API Error (${response.statusCode}): $errorMsg');
      }
    } on http.ClientException catch (e) {
      throw Exception('Network error: ${e.message}');
    } on FormatException catch (e) {
      throw Exception('Invalid response format: ${e.message}');
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }
}
