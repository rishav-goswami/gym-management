import 'package:fit_and_fine/presentation/member/dashboard/home_tab.dart';
import 'package:fit_and_fine/presentation/member/member-layout/member_screen_layout.dart';
import 'package:fit_and_fine/presentation/member/profile/profile_screen.dart';
import 'package:fit_and_fine/presentation/member/progress/progress_tab.dart';
import 'package:fit_and_fine/presentation/member/workouts/workout_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MemberRoutes {
  // A static GlobalKey can be used to navigate within the shell without losing state.
  static final GlobalKey<NavigatorState> _shellNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'MemberShell');

  // This static getter will contain all the routes for the member section.
  static ShellRoute get aLLMemberRoutes {
    return ShellRoute(
      navigatorKey: _shellNavigatorKey,
      // The 'builder' creates the shell UI (your dashboard screen).
      // The 'child' passed to it is the currently active route's content.
      builder: (context, state, child) {
        return MemberScreenLayout(child: child);
      },
      routes: [
        // Default route for the member section
        GoRoute(
          path: '/member/home',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomeTab()),
        ),
        GoRoute(
          path: '/member/workouts',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Center(child: Text('Workouts')), // Placeholder
          ),
        ),
        GoRoute(
          path: '/member/progress',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ProgressTab()),
        ),
        GoRoute(
          path: '/member/community',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: Center(child: Text('Community')), // Placeholder
          ),
        ),
        GoRoute(
          path: '/member/profile',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfileScreen(), // Your existing ProfileScreen
          ),
        ),
      ],
    );
  }

  // Define routes that are part of the member flow but not in the shell.
  static List<RouteBase> get detailRoutes => [
    GoRoute(
      path: '/member/workout-details',
      builder: (context, state) => const WorkoutDetailsScreen(),
    ),
    // You can add other detail screens here, like '/member/edit-profile'
  ];
}
