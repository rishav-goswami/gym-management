import 'package:fit_and_fine/data/datasources/workout_data_source.dart';
import 'package:fit_and_fine/data/models/workout_models.dart';

class WorkoutRepository {
  final WorkoutDataSource _dataSource;
  WorkoutRepository({required WorkoutDataSource dataSource})
    : _dataSource = dataSource;

  /// Fetches all data needed for the WorkoutsTab in parallel.
  Future<(WorkoutPlan?, List<Exercise>)> getWorkoutTabData(String token) async {
    try {
      // Run both API calls at the same time for efficiency.
      final results = await Future.wait([
        _dataSource.fetchWorkoutPlan(token),
        _dataSource.fetchExerciseLibrary(token),
      ]);

      final workoutPlanData = results[0] as Map<String, dynamic>?;
      final exerciseLibraryData = results[1] as List<dynamic>;
      print("workoutdataplan: $workoutPlanData exerciseLibraryData: $exerciseLibraryData");
      final WorkoutPlan? workoutPlan = workoutPlanData != null
          ? WorkoutPlan.fromJson(workoutPlanData)
          : null;

      final exerciseLibrary = exerciseLibraryData
          .map((json) => Exercise.fromJson(json))
          .toList();

      return (workoutPlan, exerciseLibrary);
    } catch (e) {
      throw Exception('Failed to load workout tab data: $e');
    }
  }
}
