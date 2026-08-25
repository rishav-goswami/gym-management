import 'dart:convert';

import 'package:fit_and_fine/data/datasources/auth_remote_data_source.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(
      fileInput: 'BASE_URL=http://localhost:3002\nX_API_KEY=test-api-key',
    );
  });

  test(
    'login sends the expected API contract and returns response data',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.toString(), 'http://localhost:3002/auth/login');
        expect(request.headers['x-api-key'], 'test-api-key');
        expect(jsonDecode(request.body), {
          'email': 'member@example.com',
          'password': 'password123',
          'role': 'MEMBER',
        });

        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'token': 'signed-token'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final result = await AuthRemoteDataSource(client: client).login(
        email: 'member@example.com',
        password: 'password123',
        role: 'MEMBER',
      );

      expect(result['token'], 'signed-token');
    },
  );

  test('login surfaces an API error message', () async {
    final client = MockClient(
      (_) async =>
          http.Response(jsonEncode({'message': 'Invalid credentials'}), 401),
    );

    expect(
      () => AuthRemoteDataSource(client: client).login(
        email: 'member@example.com',
        password: 'wrong-password',
        role: 'MEMBER',
      ),
      throwsA(isA<Exception>()),
    );
  });
}
