import 'package:fit_and_fine/core/widgets/error_displayer.dart';
import 'package:fit_and_fine/data/datasources/workout_data_source.dart';
import 'package:fit_and_fine/data/models/workout_models.dart';
import 'package:fit_and_fine/data/repositories/workouts_repository.dart';
import 'package:fit_and_fine/logic/auth/auth_bloc.dart';
import 'package:fit_and_fine/logic/member/workout-tab/workout_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// This is the new entry point for your workouts tab in the router.
class WorkoutsTab extends StatelessWidget {
  const WorkoutsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WorkoutBloc(
        workoutRepository: WorkoutRepository(dataSource: WorkoutDataSource()),
        authBloc: BlocProvider.of<AuthBloc>(context),
      )..add(FetchWorkoutData()),
      child: const _WorkoutsView(),
    );
  }
}

// This is the main view that builds the UI based on the WorkoutBloc's state.
class _WorkoutsView extends StatelessWidget {
  const _WorkoutsView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutBloc, WorkoutState>(
      builder: (context, state) {
        if (state is WorkoutLoading || state is WorkoutInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is WorkoutError) {
          return ErrorDisplayer(
            errorMessage: state.message,
            onRetry: () {
              context.read<WorkoutBloc>().add(FetchWorkoutData());
            },
          );
        }
        if (state is WorkoutLoaded) {
          // Once data is loaded, build the main content view.
          return _WorkoutContent(
            workoutPlan: state.workoutPlan, // This can now be null
            exerciseLibrary: state.exerciseLibrary,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

// This widget contains the actual UI and local state management (like search).
class _WorkoutContent extends StatefulWidget {
  final WorkoutPlan? workoutPlan; // Made nullable
  final List<Exercise> exerciseLibrary;

  const _WorkoutContent({this.workoutPlan, required this.exerciseLibrary});

  @override
  State<_WorkoutContent> createState() => _WorkoutContentState();
}

class _WorkoutContentState extends State<_WorkoutContent> {
  late int _selectedDayIndex;
  final TextEditingController _searchController = TextEditingController();
  late List<Exercise> _filteredExercises;

  @override
  void initState() {
    super.initState();
    _selectedDayIndex = DateTime.now().weekday - 1;
    _filteredExercises = widget.exerciseLibrary;
    _searchController.addListener(_filterExercises);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterExercises);
    _searchController.dispose();
    super.dispose();
  }

  void _filterExercises() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredExercises = widget.exerciseLibrary.where((exercise) {
        return exercise.name.toLowerCase().contains(query) ||
            exercise.muscleGroup.toLowerCase().contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20.0),
      children: [
        Text(
          "This Week's Plan",
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // --- THIS IS THE FIX ---
        // Check if a workout plan exists before trying to build the UI for it.
        if (widget.workoutPlan != null)
          _PlanSection(
            workoutPlan: widget.workoutPlan!,
            selectedIndex: _selectedDayIndex,
            onDaySelected: (index) {
              setState(() {
                _selectedDayIndex = index;
              });
            },
          )
        else
          const _EmptyPlanView(), // Show a helpful message if no plan exists.

        const Divider(height: 48),

        Text(
          "Exercise Library",
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            labelText: 'Search exercises...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        ..._filteredExercises.map(
          (exercise) => _LibraryExerciseCard(exercise: exercise),
        ),
      ],
    );
  }
}

// A dedicated view for when no plan is assigned ---
class _EmptyPlanView extends StatelessWidget {
  const _EmptyPlanView();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.assignment_late_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            "No Workout Plan Assigned",
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Your trainer has not assigned a workout plan for this week yet. Please check back later or contact your trainer.",
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

//  The section that shows the plan if it exists ---
class _PlanSection extends StatelessWidget {
  final WorkoutPlan workoutPlan;
  final int selectedIndex;
  final ValueChanged<int> onDaySelected;

  const _PlanSection({
    required this.workoutPlan,
    required this.selectedIndex,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final selectedDayWorkout = workoutPlan.days[selectedIndex];
    return Column(
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: workoutPlan.days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final day = workoutPlan.days[index];
              return ChoiceChip(
                label: Text(day.day.substring(0, 3)),
                selected: index == selectedIndex,
                onSelected: (selected) {
                  if (selected) {
                    onDaySelected(index);
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        if (selectedDayWorkout.exercises.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Text("Rest Day! 🎉"),
            ),
          )
        else
          ...selectedDayWorkout.exercises.map(
            (exercise) => _WorkoutExerciseCard(exercise: exercise),
          ),
      ],
    );
  }
}

// --- The rest of the card widgets remain the same ---

class _WorkoutExerciseCard extends StatelessWidget {
  final AssignedExercise exercise;
  const _WorkoutExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.fitness_center,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          exercise.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${exercise.sets} sets x ${exercise.reps} reps'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () =>
            context.push('/member/workout-details/${exercise.exerciseId}'),
      ),
    );
  }
}

class _LibraryExerciseCard extends StatelessWidget {
  final Exercise exercise;
  const _LibraryExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(exercise.name),
        subtitle: Text(exercise.muscleGroup),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => context.push('/member/workout-details/${exercise.id}'),
      ),
    );
  }
}
