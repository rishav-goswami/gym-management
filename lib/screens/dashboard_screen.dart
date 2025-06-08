// screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'sidebar.dart';
import '../theme.dart';

class DashboardScreen extends StatelessWidget {
  final List<String> exercises = [
    'Push Ups',
    'Squats',
    'Deadlifts',
    'Bench Press',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Sidebar(),
      appBar: AppBar(
        title: const Text('Gym Dashboard'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: Theme.of(context).appBarTheme.elevation,
        titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: exercises.length,
        itemBuilder: (_, index) => Card(
          color: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Theme.of(context).colorScheme.secondary, width: 1.5),
          ),
          elevation: 6,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: Icon(Icons.fitness_center, color: Theme.of(context).colorScheme.onSecondary),
            ),
            title: Text(
              exercises[index],
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Suggested routine for "+exercises[index],
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            trailing: Icon(Icons.arrow_forward_ios, color: Theme.of(context).colorScheme.secondary, size: 18),
          ),
        ),
      ),
    );
  }
}
