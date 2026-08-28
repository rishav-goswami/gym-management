import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/invitations/gym_invitation_link.dart';
import '../firebase/logic/session_cubit.dart';
import '../firebase/presentation/auth/firebase_login_screen.dart';
import '../firebase/presentation/auth/firebase_register_screen.dart';
import '../firebase/presentation/context/gym_context_screen.dart';
import '../firebase/presentation/member/personal_workspace_screen.dart';
import '../firebase/presentation/onboarding/consumer_intro_screen.dart';
import '../firebase/presentation/onboarding/consumer_onboarding_screen.dart';
import '../firebase/presentation/onboarding/start_gym_trial_screen.dart';
import '../firebase/presentation/workspace/gym_workspace_screen.dart';

GoRouter createFirebaseRouter(SessionCubit session) => GoRouter(
  initialLocation: '/',
  refreshListenable: RouterRefreshStream(session.stream),
  routes: [
    GoRoute(path: '/', builder: (_, _) => const _SessionLoadingScreen()),
    GoRoute(path: '/intro', builder: (_, _) => const ConsumerIntroScreen()),
    GoRoute(
      path: '/login',
      builder: (_, state) =>
          FirebaseLoginScreen(invitation: GymInvitationLink.fromUri(state.uri)),
    ),
    GoRoute(
      path: '/register',
      builder: (_, state) => FirebaseRegisterScreen(
        invitation: GymInvitationLink.fromUri(state.uri),
      ),
    ),
    GoRoute(path: '/spaces', builder: (_, _) => const GymContextScreen()),
    GoRoute(path: '/contexts', redirect: (_, _) => '/spaces'),
    GoRoute(
      path: '/onboarding',
      builder: (_, state) => ConsumerOnboardingScreen(
        nextLocation: state.uri.queryParameters['next'],
      ),
    ),
    GoRoute(
      path: '/join',
      builder: (_, state) =>
          GymContextScreen(invitation: GymInvitationLink.fromUri(state.uri)),
    ),
    GoRoute(path: '/start-gym', builder: (_, _) => const StartGymTrialScreen()),
    GoRoute(
      path: '/personal',
      builder: (_, _) => const PersonalWorkspaceScreen(),
    ),
    GoRoute(path: '/workspace', builder: (_, _) => const GymWorkspaceScreen()),
  ],
  redirect: (_, routerState) {
    final state = session.state;
    final location = routerState.matchedLocation;
    final invitation = GymInvitationLink.fromUri(routerState.uri);
    final authRoute = location == '/login' || location == '/register';
    return switch (state.status) {
      SessionStatus.initializing =>
        invitation != null || location == '/' ? null : '/',
      SessionStatus.signedOut =>
        !state.platformBrandingLoaded
            ? (location == '/' ? null : '/')
            : authRoute || (location == '/intro' && state.personalSpacesEnabled)
            ? null
            : invitation?.loginLocation ??
                  (state.personalSpacesEnabled ? '/intro' : '/login'),
      SessionStatus.failure =>
        authRoute ? null : invitation?.loginLocation ?? '/login',
      SessionStatus.selectingContext =>
        location == '/join'
            ? null
            : invitation != null && authRoute
            ? invitation.routeLocation
            : location == '/spaces' || location == '/start-gym'
            ? null
            : '/spaces',
      SessionStatus.ready => _readyRedirect(state, location, invitation),
    };
  },
);

String? _readyRedirect(
  SessionState state,
  String location,
  GymInvitationLink? invitation,
) {
  if (!state.personalSpacesEnabled) {
    if (location == '/join' || location == '/start-gym') {
      return null;
    }
    if (invitation != null &&
        (location == '/login' || location == '/register')) {
      return invitation.routeLocation;
    }
    if (state.activeMembership != null) {
      return location == '/workspace' ? null : '/workspace';
    }
    if (location == '/spaces') return null;
    return '/spaces';
  }
  if (state.needsPersonalOnboarding) {
    if (location == '/onboarding') return null;
    final next = invitation?.routeLocation;
    return Uri(
      path: '/onboarding',
      queryParameters: next == null ? null : {'next': next},
    ).toString();
  }
  if (location == '/join' || location == '/start-gym') {
    return null;
  }
  if (invitation != null && (location == '/login' || location == '/register')) {
    return invitation.routeLocation;
  }
  if (state.activeMembership != null) {
    return location == '/workspace' ? null : '/workspace';
  }
  if (location == '/spaces') return null;
  return location == '/personal' ? null : '/personal';
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
