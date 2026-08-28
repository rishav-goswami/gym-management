import 'package:gym_management/core/services/storage_service.dart';
import 'package:gym_management/data/datasources/auth_remote_data_source.dart';
import 'package:gym_management/data/repositories/auth_repository.dart';
import 'package:gym_management/logic/auth/auth_bloc.dart';
import 'package:gym_management/logic/auth/auth_state.dart';
import 'package:gym_management/presentation/admin/dashboard/admin_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('admin logout clears the session', (tester) async {
    SharedPreferences.setMockInitialValues({
      StorageKeys.token: 'admin-token',
      StorageKeys.role: 'ADMIN',
      StorageKeys.isLoggedIn: true,
    });

    final client = MockClient((_) async => http.Response('{}', 500));
    final bloc = AuthBloc(
      AuthRepository(remote: AuthRemoteDataSource(client: client)),
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: const MaterialApp(home: AdminDashboardScreen()),
      ),
    );

    expect(find.byKey(const Key('adminLogoutButton')), findsOneWidget);
    await tester.tap(find.byKey(const Key('adminLogoutButton')));
    await tester.pumpAndSettle();

    expect(bloc.state, isA<AuthUnauthenticated>());
    expect(await StorageService.getToken(), isNull);
    expect(await StorageService.isLoggedIn(), isFalse);
  });
}
