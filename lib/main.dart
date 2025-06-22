// main.dart
import 'package:fit_and_fine/bloc/auth/auth_bloc.dart';
import 'package:fit_and_fine/bloc/profile/profile_bloc.dart';
import 'package:fit_and_fine/screens/edit_profile_screen.dart';
import 'package:fit_and_fine/screens/profile_screen.dart';
import 'package:fit_and_fine/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'screens/login/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme.dart';
import 'bloc/auth/auth_state.dart';
import 'bloc/profile/profile_event.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future main() async {
  await dotenv.load();
  return runApp(GymApp());
}

class GymApp extends StatelessWidget {
  const GymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc()),
        BlocProvider(create: (_) => ProfileBloc()),
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
