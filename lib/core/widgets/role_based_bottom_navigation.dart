import 'package:fit_and_fine/core/constants/user_role_enum.dart';
import 'package:fit_and_fine/logic/auth/auth_bloc.dart';
import 'package:fit_and_fine/logic/auth/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// The widget is now a much simpler StatelessWidget.
class RoleBasedBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const RoleBasedBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    // We get the AuthState directly from the BlocProvider in the widget tree.
    final state = context.watch<AuthBloc>().state;

    // If the user is not authenticated, don't show the nav bar.
    if (state is! AuthAuthenticated) {
      return const SizedBox.shrink(); // Use shrink to take up no space.
    }

    // We know the user is authenticated, so we can safely get their role.
    final role = state.user.role;

    // The rest of your logic remains the same.
    List<BottomNavigationBarItem> items;
    switch (role) {
      case UserRole.admin:
        items = const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Users'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ];
        break;
      case UserRole.trainer:
        items = const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Clients'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ];
        break;
      case UserRole.member:
      default:
        items = const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Dashboard'),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Workouts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Progress',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.group), label: 'Community'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ];
    }

    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onItemTapped,
      items: items,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).textTheme.bodyMedium?.color,
    );
  }
}
