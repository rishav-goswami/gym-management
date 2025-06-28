import 'package:fit_and_fine/core/constants/constant.dart';
import 'package:fit_and_fine/core/widgets/custom_appbar.dart';
import 'package:fit_and_fine/core/widgets/role_based_bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MemberScreenLayout extends StatelessWidget {
  // This 'child' widget is the screen content provided by go_router.
  final Widget child;
  const MemberScreenLayout({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The AppBar is part of the shell and remains constant.
      // We no longer need a list of titles, as each child screen can have its own AppBar if needed,
      // or we can determine the title from the route.
      appBar: const CustomAppBar(
        title: AppConstants.appName, // A generic title, or calculated from route.
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Icon(Icons.settings),
          ),
        ],
      ),
      body: child, // The content of the current tab.
      bottomNavigationBar: RoleBasedBottomNavBar(
        // Calculate the selected index based on the current route.
        selectedIndex: _calculateSelectedIndex(context),
        onItemTapped: (index) => _onItemTapped(index, context),
      ),
    );
  }

  // This method navigates to the correct route when a tab is tapped.
  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/member/home');
        break;
      case 1:
        context.go('/member/workouts');
        break;
      case 2:
        context.go('/member/progress');
        break;
      case 3:
        context.go('/member/community');
        break;
      case 4:
        context.go('/member/profile');
        break;
    }
  }

  // --- THIS METHOD IS NOW CORRECTED ---
  // This method determines which tab is active based on the current URL.
  int _calculateSelectedIndex(BuildContext context) {
    // Correct way to get the current location string.
    final location = GoRouterState.of(context).uri.toString();

    if (location.startsWith('/member/home')) {
      return 0;
    }
    if (location.startsWith('/member/workouts')) {
      return 1;
    }
    if (location.startsWith('/member/progress')) {
      return 2;
    }
    if (location.startsWith('/member/community')) {
      return 3;
    }
    if (location.startsWith('/member/profile')) {
      return 4;
    }
    return 0; // Default to home
  }
}
