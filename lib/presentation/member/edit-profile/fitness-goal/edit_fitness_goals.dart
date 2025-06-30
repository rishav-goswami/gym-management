import 'package:fit_and_fine/core/widgets/custom_appbar.dart';
import 'package:fit_and_fine/data/datasources/fitness_goals_data_source.dart';
import 'package:fit_and_fine/data/repositories/fitness_goals_repository.dart';
import 'package:fit_and_fine/logic/member/fitness-goals/fitness_goals_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class EditFitnessGoalsScreen extends StatelessWidget {
  const EditFitnessGoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => FitnessGoalsBloc(
        repository: FitnessGoalsRepository(
          dataSource: FitnessGoalsDataSource(),
        ),
      )..add(LoadFitnessGoals()),
      child: const _EditFitnessGoalsView(),
    );
  }
}

class _EditFitnessGoalsView extends StatefulWidget {
  const _EditFitnessGoalsView();

  @override
  State<_EditFitnessGoalsView> createState() => _EditFitnessGoalsViewState();
}

class _EditFitnessGoalsViewState extends State<_EditFitnessGoalsView> {
  // State variables for the form fields
  String? _primaryGoal;
  String? _workoutFrequency;
  final Set<String> _selectedWorkouts = {};

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

  void _saveGoals() {
    context.read<FitnessGoalsBloc>().add(
      UpdateFitnessGoals(
        primaryGoal: _primaryGoal,
        workoutFrequency: _workoutFrequency,
        preferredWorkouts: _selectedWorkouts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<FitnessGoalsBloc, FitnessGoalsState>(
      listener: (context, state) {
        if (state is FitnessGoalsLoaded) {
          // When data arrives, populate the form fields
          setState(() {
            _primaryGoal = state.user.healthGoals;
            _workoutFrequency = state.user.workoutFrequency;
            _selectedWorkouts.clear();
            if (state.user.preferredWorkouts != null) {
              _selectedWorkouts.addAll(state.user.preferredWorkouts!);
            }
          });
        } else if (state is FitnessGoalsUpdateSuccess) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Goals updated!')));
        } else if (state is FitnessGoalsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Fitness Goals & Preferences',
          actions: [
            BlocBuilder<FitnessGoalsBloc, FitnessGoalsState>(
              builder: (context, state) {
                if (state is FitnessGoalsLoading) {
                  return const Padding(
                    padding: EdgeInsets.only(right: 16.0),
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return TextButton(
                  onPressed: _saveGoals,
                  child: const Text('Save'),
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<FitnessGoalsBloc, FitnessGoalsState>(
          builder: (context, state) {
            if (state is FitnessGoalsInitial ||
                (state is FitnessGoalsLoading &&
                    state is! FitnessGoalsLoaded)) {
              return const Center(child: CircularProgressIndicator());
            }

            return ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                Text(
                  'Your Goals',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _primaryGoal,
                  items: _goalOptions
                      .map(
                        (String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (newValue) =>
                      setState(() => _primaryGoal = newValue),
                  decoration: const InputDecoration(
                    labelText: 'Primary Goal',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _workoutFrequency,
                  items: _frequencyOptions
                      .map(
                        (String value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: (newValue) =>
                      setState(() => _workoutFrequency = newValue),
                  decoration: const InputDecoration(
                    labelText: 'Workout Frequency',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 32),
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
            );
          },
        ),
      ),
    );
  }
}
