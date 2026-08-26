import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../firebase/logic/session_cubit.dart';
import '../firebase/presentation/auth/firebase_login_screen.dart';
import '../firebase/presentation/auth/firebase_register_screen.dart';
import '../firebase/presentation/context/gym_context_screen.dart';
import '../firebase/presentation/platform/platform_admin_screen.dart';
import '../firebase/presentation/workspace/gym_workspace_screen.dart';

GoRouter createFirebaseRouter(SessionCubit session) => GoRouter(
  initialLocation: '/',
  refreshListenable: RouterRefreshStream(session.stream),
  routes: [
    GoRoute(path: '/', builder: (_, _) => const _SessionLoadingScreen()),
    GoRoute(path: '/login', builder: (_, _) => const FirebaseLoginScreen()),
    GoRoute(
      path: '/register',
      builder: (_, _) => const FirebaseRegisterScreen(),
    ),
    GoRoute(path: '/contexts', builder: (_, _) => const GymContextScreen()),
    GoRoute(path: '/workspace', builder: (_, _) => const GymWorkspaceScreen()),
    GoRoute(path: '/platform', builder: (_, _) => const PlatformAdminScreen()),
  ],
  redirect: (_, routerState) {
    final state = session.state;
    final location = routerState.matchedLocation;
    final authRoute = location == '/login' || location == '/register';
    return switch (state.status) {
      SessionStatus.initializing => location == '/' ? null : '/',
      SessionStatus.signedOut => authRoute ? null : '/login',
      SessionStatus.failure => authRoute ? null : '/login',
      SessionStatus.selectingContext =>
        location == '/contexts' ? null : '/contexts',
      SessionStatus.ready => _readyRedirect(state, location),
    };
  },
);

String? _readyRedirect(SessionState state, String location) {
  if (location == '/contexts') return null;
  if (state.activeMembership != null) {
    return location == '/workspace' ? null : '/workspace';
  }
  if (state.isPlatformAdmin) {
    return location == '/platform' ? null : '/platform';
  }
  return '/contexts';
}

class RouterRefreshStream extends ChangeNotifier {
  RouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
