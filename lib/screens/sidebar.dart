// screens/sidebar.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../logic/member/profile/profile_bloc.dart';
import 'package:fit_and_fine/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        String name = 'Guest User';
        String email = 'guest@email.com';
        String avatarUrl = '';
        if (state is ProfileLoaded) {
          name = state.user.name;
          email = state.user.email;
          // avatarUrl = state.user.avatarUrl ?? '';
        }
        return GFDrawer(
          child: Column(
            children: [
              // Drawer Header with Profile Info
              GFDrawerHeader(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                centerAlign: true,
                currentAccountPicture: GestureDetector(
                  onTap: () {
                    // Navigate to profile edit screen
                    Navigator.pushNamed(context, '/edit-profile');
                  },
                  child: GFAvatar(
                    radius: 45,
                    backgroundImage: avatarUrl.isNotEmpty
                        ? AssetImage(avatarUrl) as ImageProvider
                        : const AssetImage('assets/avatars/avatar1.png'),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      email,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Drawer Menu Items
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 8),
                  children: [
                    _drawerItem(
                      icon: Icons.dashboard,
                      text: 'Dashboard',
                      onTap: () =>
                          Navigator.pushReplacementNamed(context, '/dashboard'),
                    ),
                    _drawerItem(
                      icon: Icons.person,
                      text: 'Profile',
                      onTap: () => Navigator.pushNamed(context, '/profile'),
                    ),
                    _drawerItem(
                      icon: Icons.settings,
                      text: 'Settings',
                      onTap: () => Navigator.pushNamed(context, '/settings'),
                    ),
                    Divider(thickness: 1.2),
                    _drawerItem(
                      icon: Icons.logout,
                      text: 'Logout',
                      color: Colors.red,
                      onTap: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color color = Colors.black87,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(text, style: TextStyle(color: color, fontSize: 16)),
      onTap: onTap,
      horizontalTitleGap: 10,
      visualDensity: VisualDensity.compact,
    );
  }
}
