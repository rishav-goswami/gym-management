import 'package:fit_and_fine/core/widgets/custom_appbar.dart';
import 'package:flutter/material.dart';

class WorkoutDetailsScreen extends StatelessWidget {
  const WorkoutDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const CustomAppBar(title: 'Workout Details'),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // --- Header Section ---
          Text(
            'Full Body Blast',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This workout targets all major muscle groups for a comprehensive full-body session.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),

          // --- Exercises Section ---
          Text(
            'Exercises',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _ExerciseListItem(
            iconData: Icons.fitness_center,
            title: 'Squats',
            details: 'Rest: 60 seconds\n3 sets x 10 reps',
          ),
          _ExerciseListItem(
            iconData: Icons.fitness_center,
            title: 'Push-ups',
            details: 'Rest: 45 seconds\n3 sets x 12 reps',
          ),
          _ExerciseListItem(
            iconData: Icons.fitness_center,
            title: 'Lunges',
            details: 'Rest: 60 seconds\n3 sets x 15 reps',
          ),
          _ExerciseListItem(
            iconData: Icons.fitness_center,
            title: 'Plank',
            details: 'Rest: 45 seconds\n3 sets x 10 reps',
          ),
          const SizedBox(height: 32),

          // --- Notes Section ---
          Text(
            'Notes',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Focus on maintaining proper form throughout each exercise. Adjust weight or resistance as needed to challenge yourself while ensuring safety.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A reusable widget for displaying a single exercise in the list.
class _ExerciseListItem extends StatelessWidget {
  final IconData iconData;
  final String title;
  final String details;

  const _ExerciseListItem({
    required this.iconData,
    required this.title,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              iconData,
              size: 28,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          // Title and details
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                details,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
