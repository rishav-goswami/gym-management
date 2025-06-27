import 'package:fit_and_fine/presentation/auth/login/login_screen.dart';
import 'package:fit_and_fine/presentation/auth/register/signup_screen.dart';
import 'package:fit_and_fine/presentation/member/dashboard/user_dashboard_screen.dart';
import 'package:go_router/go_router.dart';
import '../presentation/splash/splash_screen.dart';
import '../presentation/role_selector/role_selector_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
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
        builder: (context, state) => const MemberDashboardScreen(),
      ),
      // GoRoute(
      //   path: '/trainer-dashboard',
      //   builder: (context, state) => const TrainerDashboardScreen(),
      // ),
      // GoRoute(
      //   path: '/admin-dashboard',
      //   builder: (context, state) => const AdminDashboardScreen(),
      // ),
    ],
  );
}
