import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget {
  final String name;
  final String memberSince;
  final String avatarUrl;

  const DashboardHeader({
    super.key,
    required this.name,
    required this.memberSince,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 40,
          backgroundColor: Color(0xFFFDEBD0),
          child: Icon(Icons.person, size: 50),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Member since $memberSince',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }
}
