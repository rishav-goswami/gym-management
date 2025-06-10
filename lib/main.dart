// main.dart
import 'package:fit_and_fine/screens/edit_profile_screen.dart';
import 'package:fit_and_fine/screens/profile_screen.dart';
import 'package:fit_and_fine/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'theme.dart';
import 'bloc/auth/auth_wrapper.dart';

void main() => runApp(GymApp());

class GymApp extends StatelessWidget {
  const GymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthWrapper(
      baseUrl: 'http://10.0.2.2:3002', // Update to your backend URL
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
  }
}
