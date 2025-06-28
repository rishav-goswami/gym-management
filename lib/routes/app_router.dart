import 'package:fit_and_fine/data/models/user_model.dart';
import 'package:fit_and_fine/logic/auth/auth_bloc.dart';
import 'package:fit_and_fine/logic/auth/auth_state.dart';
import 'package:fit_and_fine/presentation/auth/login/login_screen.dart';
import 'package:fit_and_fine/presentation/auth/register/signup_screen.dart';
import 'package:fit_and_fine/presentation/member/member-layout/member_screen_layout.dart';
import 'package:fit_and_fine/presentation/member/profile/profile_screen.dart';
import 'package:fit_and_fine/routes/member_routes.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

        MemberRoutes.aLLMemberRoutes,
        ...MemberRoutes.detailRoutes,
        // Add other dashboard routes here...
      ],
      // --- FINAL, ROBUST REDIRECT LOGIC ---
      redirect: (BuildContext context, GoRouterState state) {
        final authState = context.read<AuthBloc>().state;
        final location = state.matchedLocation;

        final isLoggedIn = authState is AuthAuthenticated;
        final isAuthFlow =
            location.startsWith('/login') ||
            location.startsWith('/signup') ||
            location == '/select-role';

        final isSplashScreen = location == '/';

        // While the app is initializing, stay on the splash screen.
        if (authState is AuthInitial) {
          return isSplashScreen ? null : '/';
        }

        // --- Main Logic ---

        // 1. If the user is logged in...
        if (isLoggedIn) {
          // and they are on the splash or any auth screen, redirect to their dashboard.
          if (isSplashScreen || isAuthFlow) {
            final user = authState.user;
            if (user is Member) return '/member/home';
            if (user is Trainer) return '/trainer-dashboard';
            if (user is Admin) return '/admin-dashboard';
            return '/'; // Fallback
          }
        }
        // 2. If the user is NOT logged in...
        else {
          // --- THIS IS THE FIX ---
          // and the auth check is complete but they are still on the splash screen,
          // navigate them to the start of the authentication process.
          if (isSplashScreen) {
            return '/select-role';
          }

          // If they try to access a protected route, redirect them.
          if (!isAuthFlow) {
            return '/select-role';
          }
        }

        // 3. In all other cases, no redirect is needed.
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
