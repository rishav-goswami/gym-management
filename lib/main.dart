// main.dart
import 'package:fit_and_fine/bloc/auth/auth_bloc.dart';
import 'package:fit_and_fine/bloc/profile/profile_bloc.dart';
import 'package:fit_and_fine/screens/edit_profile_screen.dart';
import 'package:fit_and_fine/screens/profile_screen.dart';
import 'package:fit_and_fine/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme.dart';
import 'bloc/auth/auth_state.dart';
import 'bloc/profile/profile_event.dart';

final String baseUrl = 'http://10.0.2.2:3002'; // Update to your backend URL
void main() => runApp(GymApp());

class GymApp extends StatelessWidget {
  const GymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc(baseUrl: baseUrl)),
        BlocProvider(create: (_) => ProfileBloc(baseUrl: baseUrl)),
      ],
      child: Builder(
        builder: (context) {
          return BlocListener<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is AuthAuthenticated) {
                context.read<ProfileBloc>().setToken(state.token);
                context.read<ProfileBloc>().add(FetchProfile());
              } else if (state is AuthUnauthenticated) {
                context.read<ProfileBloc>().setToken(null);
              }
            },
            child: MaterialApp(
              title: 'Gym Suggestion App',
              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: ThemeMode.system,
              initialRoute: '/login',
              routes: {
                '/login': (context) => LoginScreen(),
                '/dashboard': (context) => DashboardScreen(),
                '/edit-profile': (context) => EditProfileScreen(),
                '/profile': (context) => ProfileScreen(),
                '/settings': (context) => SettingsScreen(),
              },
            ),
          );
        },
      ),
    );
  }
}
