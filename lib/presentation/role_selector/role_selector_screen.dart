import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  void _navigateToRole(BuildContext context, String role) {
    context.go('/login/$role');
  }

  @override
  Widget build(BuildContext context) {
    final roles = [
      {
        'title': 'User',
        'subtitle': 'Track workouts and progress',
        'icon': 'assets/user_icon.svg',
      },
      {
        'title': 'Trainer',
        'subtitle': 'Manage clients and plans',
        'icon': 'assets/trainer_icon.svg',
      },
      {
        'title': 'Admin',
        'subtitle': 'Manage gym operations',
        'icon': 'assets/admin_icon.svg',
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Select Your Role'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: roles.map((role) {
            return GestureDetector(
              onTap: () => _navigateToRole(context, role['title']!),
              child: Card(
                margin: const EdgeInsets.symmetric(vertical: 10),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      SvgPicture.asset(role['icon']!, height: 48),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            role['title']!,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            role['subtitle']!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
