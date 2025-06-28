import 'package:fit_and_fine/core/widgets/custom_appbar.dart';
import 'package:flutter/material.dart';

class EditFitnessGoalsScreen extends StatefulWidget {
  const EditFitnessGoalsScreen({super.key});

  @override
  State<EditFitnessGoalsScreen> createState() => _EditFitnessGoalsScreenState();
}

class _EditFitnessGoalsScreenState extends State<EditFitnessGoalsScreen> {
  // State variables for the form fields
  String? _primaryGoal;
  String? _workoutFrequency;

  // Using a Set for multi-selection of preferred workouts
  final Set<String> _selectedWorkouts = {'Cardio', 'Strength Training'};

  // Options for the dropdowns and chips
  final List<String> _goalOptions = [
    'Weight Loss',
    'Muscle Gain',
    'Improve Endurance',
    'Maintain Fitness',
  ];
  final List<String> _frequencyOptions = [
    '1-2 times a week',
    '3-4 times a week',
    '5+ times a week',
  ];
  final List<String> _workoutTypeOptions = [
    'Cardio',
    'Strength Training',
    'Yoga',
    'Pilates',
    'CrossFit',
  ];

  @override
  void initState() {
    super.initState();
    // In a real app, you would initialize these values from a ProfileBloc state
    _primaryGoal = 'Weight Loss';
    _workoutFrequency = '3-4 times a week';
  }

  void _saveGoals() {
    // Dispatch an event to a ProfileBloc to save the data
    print('Saving goals...');
    print('Primary Goal: $_primaryGoal');
    print('Frequency: $_workoutFrequency');
    print('Preferred Workouts: $_selectedWorkouts');

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Fitness goals updated!')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Fitness Goals & Preferences',
        actions: [TextButton(onPressed: _saveGoals, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // --- Fitness Goals Section ---
          Text(
            'Your Goals',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _primaryGoal,
            items: _goalOptions.map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _primaryGoal = newValue;
              });
            },
            decoration: const InputDecoration(
              labelText: 'Primary Goal',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            value: _workoutFrequency,
            items: _frequencyOptions.map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _workoutFrequency = newValue;
              });
            },
            decoration: const InputDecoration(
              labelText: 'Workout Frequency',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 32),

          // --- Preferences Section ---
          Text(
            'Your Preferences',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Text('Preferred Workouts', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: _workoutTypeOptions.map((workout) {
              final isSelected = _selectedWorkouts.contains(workout);
              return FilterChip(
                label: Text(workout),
                selected: isSelected,
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      _selectedWorkouts.add(workout);
                    } else {
                      _selectedWorkouts.remove(workout);
                    }
                  });
                },
                selectedColor: theme.colorScheme.primaryContainer,
                checkmarkColor: theme.colorScheme.onPrimaryContainer,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
