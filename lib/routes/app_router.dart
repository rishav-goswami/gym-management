import 'package:fit_and_fine/data/models/user_model.dart';
import 'package:fit_and_fine/logic/auth/auth_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fit_and_fine/logic/auth/auth_state.dart';
import 'package:fit_and_fine/presentation/auth/login/login_screen.dart';
import 'package:fit_and_fine/presentation/auth/register/signup_screen.dart';
import 'package:fit_and_fine/presentation/member/dashboard/user_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../presentation/splash/splash_screen.dart';
import '../presentation/role_selector/role_selector_screen.dart';

class AppRouter {
  static GoRouter getRouter(BuildContext context) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: GoRouterRefreshStream(context.read<AuthBloc>().stream),
      routes: [
        GoRoute(
          path: '/',
          name: 'splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/select-role',
          name: 'selectRole',
          builder: (context, state) => const RoleSelectorScreen(),
        ),
        GoRoute(
          path: '/login/:role',
          name: 'login',
          builder: (context, state) {
            final role = state.pathParameters['role']!;
            return LoginScreen(role: role);
          },
        ),
        GoRoute(
          path: '/signup/:role',
          name: 'signup',
          builder: (context, state) {
            final role = state.pathParameters['role']!;
            return SignupScreen(role: role);
          },
        ),
        GoRoute(
          path: '/member-dashboard',
          name: 'member-dashboard',
          builder: (context, state) => const MemberDashboardScreen(),
        ),
        // Add other dashboard routes here...
      ],
      // --- FINAL, ROBUST REDIRECT LOGIC ---
      redirect: (BuildContext context, GoRouterState state) {
        final authState = context.read<AuthBloc>().state;
        final location =
            state.matchedLocation; // The actual URL, e.g., '/login/member'

        // Check if the user is authenticated
        final isLoggedIn = authState is AuthAuthenticated;

        // Define which routes are part of the authentication flow (and thus public)
        final isAuthRoute =
            location == '/select-role' ||
            location.startsWith('/login') ||
            location.startsWith('/signup');

        // Define all public routes
        final isPublicRoute = location == '/' || isAuthRoute;

        // If the app is still initializing, don't redirect yet.
        if (authState is AuthInitial) {
          // Returning null allows the initial navigation to proceed.
          return null;
        }

        // --- Main Logic ---

        // 1. If the user is logged in AND is trying to access a public auth route...
        if (isLoggedIn && isPublicRoute) {
          // ...redirect them to their correct dashboard.
          final user = authState.user;
          if (user is Member) return '/member-dashboard';
          if (user is Trainer) return '/trainer-dashboard';
          if (user is Admin) return '/admin-dashboard';
          return '/'; // Fallback
        }

        // 2. If the user is NOT logged in AND is trying to access a protected route...
        if (!isLoggedIn && !isPublicRoute) {
          // ...redirect them to the start of the authentication flow.
          return '/select-role';
        }

        // 3. In all other cases (logged in and going to a protected route, OR
        //    logged out and going to a public route), no redirect is needed.
        return null;
      },
    );
  }
}

// A helper class to make GoRouter listen to a BLoC stream.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    stream.asBroadcastStream().listen((_) => notifyListeners());
  }
}
