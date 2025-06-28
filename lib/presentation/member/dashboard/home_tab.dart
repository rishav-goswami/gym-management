import 'package:fit_and_fine/core/widgets/activity_card.dart';
import 'package:fit_and_fine/core/widgets/dashboard_header.dart';
import 'package:fit_and_fine/core/widgets/quick_action_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    // This is the content that was previously in your dashboard's ListView.
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        InkWell(
          child: const DashboardHeader(
            name: 'Ethan Carter',
            memberSince: '2022',
            avatarUrl: '', // Provide from backend later
          ),
          onTap: () => context.push("/member-profile"),
        ),
        const SizedBox(height: 20),

        Text(
          'Today\'s Activity',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        const ActivityCard(
          icon: Icons.fitness_center,
          title: 'Strength Training',
          time: '10:00 AM - 11:00 AM',
        ),
        const ActivityCard(
          icon: Icons.favorite_outline,
          title: 'Cardio',
          time: '12:00 PM - 1:00 PM',
        ),
        const SizedBox(height: 20),

        Text(
          'Upcoming Workouts',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        const ActivityCard(
          icon: Icons.self_improvement,
          title: 'Yoga',
          time: 'Tomorrow, 9:00 AM',
        ),
        const ActivityCard(
          icon: Icons.spa,
          title: 'Pilates',
          time: 'Wednesday, 10:00 AM',
        ),
        const SizedBox(height: 20),

        Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Row(
          children: const [
            Expanded(
              child: QuickActionButton(label: "Book a Class", isPrimary: true),
            ),
            SizedBox(width: 12),
            Expanded(child: QuickActionButton(label: "View Schedule")),
          ],
        ),

      ],
    );
  }
}
