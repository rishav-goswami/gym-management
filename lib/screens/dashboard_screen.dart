// screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'sidebar.dart';

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
      appBar: AppBar(title: Text('Gym Dashboard')),
      body: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: exercises.length,
        itemBuilder: (_, index) => Card(
          child: ListTile(
            title: Text(exercises[index]),
            subtitle: Text("Suggested routine for ${exercises[index]}"),
          ),
        ),
      ),
    );
  }
}
