// screens/sidebar.dart
import 'package:flutter/material.dart';
import 'package:getwidget/getwidget.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return GFDrawer(
      child: Column(
        children: [
          // Drawer Header with Profile Info
          GFDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade800, Colors.blue.shade400],
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
                backgroundImage: NetworkImage(
                  "https://cdn.pixabay.com/photo/2017/12/03/18/04/christmas-balls-2995437_960_720.jpg",
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                SizedBox(height: 8),
                Text(
                  'John Doe',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'john@example.com',
                  style: TextStyle(color: Colors.white70),
                ),
                SizedBox(height: 8),
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
