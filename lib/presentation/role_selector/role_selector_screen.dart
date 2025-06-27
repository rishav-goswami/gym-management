import 'package:fit_and_fine/core/constants/user_role_enum.dart';
import 'package:fit_and_fine/core/services/storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  void _navigateToRole(BuildContext context, String role) {
    StorageService.saveUserRole(UserRole.fromString(role)!);
    context.go('/login/$role');
  }

  @override
  Widget build(BuildContext context) {
    final roles = [
      {
        'title': 'Member',
        'subtitle': 'Track workouts and progress',
        'icon': 'assets/images/welcome/user_role.svg',
      },
      {
        'title': 'Trainer',
        'subtitle': 'Manage clients and plans',
        'icon': 'assets/images/welcome/trainer_role.svg',
      },
      {
        'title': 'Admin',
        'subtitle': 'Manage gym operations',
        'icon': 'assets/images/welcome/admin_role.svg',
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
                            style: Theme.of(context).textTheme.bodyMedium,
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
