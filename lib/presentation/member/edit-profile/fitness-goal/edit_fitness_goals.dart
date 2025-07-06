import 'dart:async';
import 'package:fit_and_fine/core/widgets/custom_appbar.dart';
import 'package:fit_and_fine/data/datasources/fitness_goals_data_source.dart';
import 'package:fit_and_fine/data/repositories/fitness_goals_repository.dart';
import 'package:fit_and_fine/logic/auth/auth_bloc.dart';
import 'package:fit_and_fine/logic/member/fitness-goals/fitness_goals_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart'; // For listEquals in BlocBuilder's buildWhen if needed

// Ensure your FitnessGoalsModel and OptionItem are correctly imported
import 'package:fit_and_fine/data/models/fitness_goals_model.dart';

class EditFitnessGoalsScreen extends StatelessWidget {
  const EditFitnessGoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          FitnessGoalsBloc(
              repository: FitnessGoalsRepository(
                dataSource: FitnessGoalsDataSource(),
              ),
              authBloc: context.read<AuthBloc>(),
            )
            ..add(LoadFitnessGoalsOptions()) // Load options first
            ..add(LoadFitnessGoals()), // Then load user's goals
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
  final _formKey = GlobalKey<FormState>();

  // Controllers are now for displaying names, not for storing IDs directly
  final TextEditingController _primaryGoalController = TextEditingController();
  final TextEditingController _workoutFrequencyController =
      TextEditingController();

  // Store selected IDs, not names
  String? _selectedGoalId;
  String? _selectedFrequencyId;
  final Set<String> _selectedWorkoutIds = {};

  // Cache for workout names to display selected chips correctly
  final Map<String, String> _workoutNameCache = {};

  @override
  void dispose() {
    _primaryGoalController.dispose();
    _workoutFrequencyController.dispose();
    super.dispose();
  }

  void _saveGoals() {
    if (_formKey.currentState?.validate() ?? false) {
      final updates = {
        'healthGoals': _selectedGoalId, // Send ID
        'workoutFrequency': _selectedFrequencyId, // Send ID
        'preferredWorkouts': _selectedWorkoutIds.toList(), // Send IDs
      }..removeWhere((k, v) => v == null);
      debugPrint('Updates: $updates');
      context.read<FitnessGoalsBloc>().add(
        UpdateFitnessGoals(
          primaryGoalId: updates['healthGoals'] as String?,
          workoutFrequencyId: updates['workoutFrequency'] as String?,
          preferredWorkoutIds: (updates['preferredWorkouts'] is List)
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
          // When user's goals data arrives, populate the form fields with names and store IDs
          // setState(() {
            _selectedGoalId = state.goals.healthGoals?.id;
            _primaryGoalController.text = state.goals.healthGoals?.name ?? '';

            _selectedFrequencyId = state.goals.workoutFrequency?.id;
            _workoutFrequencyController.text =
                state.goals.workoutFrequency?.name ?? '';

            _selectedWorkoutIds.clear();
            _workoutNameCache.clear();
            for (var workout in state.goals.preferredWorkouts) {
              _selectedWorkoutIds.add(workout.id);
              _workoutNameCache[workout.id] = workout.name;
            }
          // });
        } else if (state is FitnessGoalsUpdateSuccess) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Goals updated!')));
        } else if (state is FitnessGoalsError) {
          // You might want to show global errors, but specific search errors are handled in AsyncWorkoutChips
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
              // Build when options loading or goals loading changes
              buildWhen: (previous, current) =>
                  previous.isOptionsLoading != current.isOptionsLoading ||
                  (current is FitnessGoalsLoading &&
                      previous is! FitnessGoalsLoading) ||
                  (current is FitnessGoalsLoaded &&
                      previous is! FitnessGoalsLoaded),
              builder: (context, state) {
                // isOptionsLoading is used for the overall loading state of the form
                bool isLoading =
                    state.isOptionsLoading; // Use the common state property

                if (isLoading) {
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
          // Build the main form when relevant state changes (options, goals loaded/error)
          buildWhen: (previous, current) =>
              previous.isOptionsLoading != current.isOptionsLoading ||
              (current is FitnessGoalsLoaded &&
                  previous is! FitnessGoalsLoaded) ||
              (current is FitnessGoalsError &&
                  previous is! FitnessGoalsError) ||
              (current is FitnessGoalsInitial &&
                  previous is! FitnessGoalsInitial),
          builder: (context, state) {
            // Show full screen loader if options are still loading
            if (state.isOptionsLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            // Also show loader if goals are loading and options are already there
            if (state is FitnessGoalsLoading &&
                !state.healthGoalOptions.isNotEmpty) {
              // Only if not already loaded options
              return const Center(child: CircularProgressIndicator());
            }

            // Handle global error state (not search specific)
            if (state is FitnessGoalsError &&
                state.workoutSearchError == null) {
              return Center(
                child: Text(
                  'Error: ${state.message}',
                  style: TextStyle(color: Colors.red),
                ),
              );
            }

            // Only render form if options are loaded
            final List<OptionItem> healthGoalOptions = state.healthGoalOptions;
            final List<OptionItem> workoutFrequencyOptions =
                state.workoutFrequencyOptions;

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
                  // Primary Goal Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedGoalId, // Use ID as value
                    items: healthGoalOptions
                        .map(
                          (opt) => DropdownMenuItem<String>(
                            value: opt.id, // Value is the ID
                            child: Text(opt.name), // Display name
                          ),
                        )
                        .toList(),
                    onChanged: (newId) => setState(() {
                      _selectedGoalId = newId;
                      // Update controller text if you want to show selected name
                      _primaryGoalController.text = healthGoalOptions
                          .firstWhere(
                            (opt) => opt.id == newId,
                            orElse: () => OptionItem(id: '', name: ''),
                          )
                          .name;
                    }),
                    decoration: const InputDecoration(
                      labelText: 'Primary Goal',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select your primary goal';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  // Workout Frequency Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedFrequencyId, // Use ID as value
                    items: workoutFrequencyOptions
                        .map(
                          (opt) => DropdownMenuItem<String>(
                            value: opt.id, // Value is the ID
                            child: Text(opt.name), // Display name
                          ),
                        )
                        .toList(),
                    onChanged: (newId) => setState(() {
                      _selectedFrequencyId = newId;
                      // Update controller text if you want to show selected name
                      _workoutFrequencyController.text = workoutFrequencyOptions
                          .firstWhere(
                            (opt) => opt.id == newId,
                            orElse: () => OptionItem(id: '', name: ''),
                          )
                          .name;
                    }),
                    decoration: const InputDecoration(
                      labelText: 'Workout Frequency',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select your workout frequency';
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
                  // Async Searchable multi-select for workouts
                  AsyncWorkoutChips(
                    selectedIds: _selectedWorkoutIds,
                    onAdd: (id, name) {
                      setState(() {
                        _selectedWorkoutIds.add(id);
                        _workoutNameCache[id] = name;
                      });
                    },
                    onRemove: (id) {
                      setState(() {
                        _selectedWorkoutIds.remove(id);
                        _workoutNameCache.remove(id);
                      });
                    },
                    workoutNameCache: _workoutNameCache,
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

// --- Widget for async search and chips for workouts ---
class AsyncWorkoutChips extends StatefulWidget {
  final Set<String> selectedIds;
  final void Function(String id, String name) onAdd;
  final void Function(String id) onRemove;
  final Map<String, String> workoutNameCache;

  const AsyncWorkoutChips({
    required this.selectedIds,
    required this.onAdd,
    required this.onRemove,
    required this.workoutNameCache,
    Key? key,
  }) : super(key: key);

  @override
  State<AsyncWorkoutChips> createState() => _AsyncWorkoutChipsState();
}

class _AsyncWorkoutChipsState extends State<AsyncWorkoutChips> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // This is where you would typically load names for already selected IDs
    // if they weren't fully populated by the main FitnessGoalsLoaded state.
    // For now, _workoutNameCache is populated by _EditFitnessGoalsView.
  }

  void _search(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;

      // Dispatch the event with the query. Bloc will handle getting the token.
      context.read<FitnessGoalsBloc>().add(SearchWorkoutsEvent(query: query));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FitnessGoalsBloc, FitnessGoalsState>(
      // Only rebuild this widget when workout search related properties change
      buildWhen: (previous, current) {
        // We use the direct properties from the base FitnessGoalsState
        final prevIsLoading = previous.isWorkoutSearchLoading;
        final prevResults = previous.workoutSearchResults;
        final prevError = previous.workoutSearchError;

        final currentIsLoading = current.isWorkoutSearchLoading;
        final currentResults = current.workoutSearchResults;
        final currentError = current.workoutSearchError;

        return prevIsLoading != currentIsLoading ||
            !listEquals(
              prevResults,
              currentResults,
            ) || // listEquals requires flutter/foundation.dart
            prevError != currentError;
      },
      builder: (context, state) {
        // Access search-related properties directly from the state
        final List<OptionItem> searchResults = state.workoutSearchResults;
        final bool isLoading = state.isWorkoutSearchLoading;
        final String? error = state.workoutSearchError;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Search Workouts',
                border: const OutlineInputBorder(),
                suffixIcon: isLoading
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : null,
                hintText: 'e.g., Yoga, HIIT, Strength',
              ),
              onChanged: (q) => _search(q),
            ),
            const SizedBox(height: 8),
            if (error != null && error.isNotEmpty)
              Text(error, style: const TextStyle(color: Colors.red)),

            // Display search results as selectable FilterChips (only if not already selected)
            if (searchResults.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: searchResults.map((opt) {
                    final String id = opt.id;
                    final String name = opt.name;
                    final bool isSelected = widget.selectedIds.contains(id);

                    if (isSelected) {
                      return const SizedBox.shrink(); // Don't show already selected as options
                    }

                    return FilterChip(
                      label: Text(name),
                      selected:
                          false, // These are options to select, not currently selected
                      onSelected: (selected) {
                        if (selected) {
                          widget.onAdd(id, name); // Pass both id and name
                          _controller.clear(); // Clear search field
                          // Dispatch an event to clear search results in the Bloc
                          context.read<FitnessGoalsBloc>().add(
                            const ClearWorkoutSearchResultsEvent(),
                          );
                        }
                      },
                    );
                  }).toList(),
                ),
              ),

            // Display currently selected workouts as Chips
            if (widget.selectedIds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Currently Selected:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: widget.selectedIds.map((id) {
                  final workoutName =
                      widget.workoutNameCache[id] ?? 'Loading...';

                  return Chip(
                    label: Text(workoutName),
                    onDeleted: () => widget.onRemove(id),
                  );
                }).toList(),
              ),
            ],
          ],
        );
      },
    );
  }
}
