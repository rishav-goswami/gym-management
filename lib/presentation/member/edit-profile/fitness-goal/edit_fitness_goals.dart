import 'package:fit_and_fine/core/widgets/custom_appbar.dart';
import 'package:fit_and_fine/data/datasources/fitness_goals_data_source.dart';
import 'package:fit_and_fine/data/repositories/fitness_goals_repository.dart';
import 'package:fit_and_fine/logic/auth/auth_bloc.dart';
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
        authBloc: context.read<AuthBloc>(),
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
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _primaryGoalController = TextEditingController();
  final TextEditingController _workoutFrequencyController =
      TextEditingController();
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

  @override
  void dispose() {
    _primaryGoalController.dispose();
    _workoutFrequencyController.dispose();
    super.dispose();
  }

  void _saveGoals() {
    if (_formKey.currentState?.validate() ?? false) {
      final updates = {
        'healthGoals': _primaryGoalController.text.isNotEmpty
            ? _primaryGoalController.text
            : null,
        'workoutFrequency': _workoutFrequencyController.text.isNotEmpty
            ? _workoutFrequencyController.text
            : null,
        'preferredWorkouts': _selectedWorkouts.toList(),
      }..removeWhere((k, v) => v == null);
      debugPrint('Updates: $updates');
      context.read<FitnessGoalsBloc>().add(
        UpdateFitnessGoals(
          primaryGoal: updates['healthGoals'] as String?,
          workoutFrequency: updates['workoutFrequency'] as String?,
          preferredWorkouts: (updates['preferredWorkouts'] is List)
              ? Set<String>.from(updates['preferredWorkouts'] as List)
              : <String>{},
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocListener<FitnessGoalsBloc, FitnessGoalsState>(
      listener: (context, state) {
        if (state is FitnessGoalsLoaded) {
          // When data arrives, populate the form fields
          setState(() {
            _primaryGoalController.text = state.goals.healthGoals ?? '';
            _workoutFrequencyController.text =
                state.goals.workoutFrequency ?? '';
            _selectedWorkouts.clear();
            final workouts = state.goals.preferredWorkouts;
            _selectedWorkouts.addAll(workouts.whereType<String>());
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

            return Form(
              key: _formKey,
              child: ListView(
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
                    value:
                        _primaryGoalController.text.isNotEmpty &&
                            _goalOptions.contains(_primaryGoalController.text)
                        ? _primaryGoalController.text
                        : null,
                    items: _goalOptions
                        .map(
                          (String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (newValue) => setState(
                      () => _primaryGoalController.text = newValue ?? '',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Primary Goal',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select your primary goal';
                      }
                      if (!_goalOptions.contains(value)) {
                        return 'Please select a valid goal';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value:
                        _workoutFrequencyController.text.isNotEmpty &&
                            _frequencyOptions.contains(
                              _workoutFrequencyController.text,
                            )
                        ? _workoutFrequencyController.text
                        : null,
                    items: _frequencyOptions
                        .map(
                          (String value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (newValue) => setState(
                      () => _workoutFrequencyController.text = newValue ?? '',
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Workout Frequency',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select your workout frequency';
                      }
                      if (!_frequencyOptions.contains(value)) {
                        return 'Please select a valid frequency';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Your Preferences',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Preferred Workouts',
                    style: theme.textTheme.titleMedium,
                  ),
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
          },
        ),
      ),
    );
  }
}
