import 'package:fit_and_fine/data/datasources/fitness_goals_data_source.dart';
import 'package:fit_and_fine/data/models/fitness_goals_model.dart';

class FitnessGoalsRepository {
  final FitnessGoalsDataSource dataSource;

  FitnessGoalsRepository({required this.dataSource});

  Future<FitnessGoals> getFitnessGoals(String token) {
    return dataSource.getFitnessGoals(token);
  }

  Future<FitnessGoals> updateFitnessGoals(
    String token,
    Map<String, dynamic> updates,
  ) {
    return dataSource.updateFitnessGoals(token, updates);
  }

  // NEW: Fetch all health goal options
  Future<List<OptionItem>> fetchHealthGoalsOptions(String token) {
    return dataSource.fetchHealthGoalsOptions(token);
  }

  // NEW: Fetch all workout frequency options
  Future<List<OptionItem>> fetchWorkoutFrequencyOptions(String token) {
    return dataSource.fetchWorkoutFrequencyOptions(token);
  }

  // NEW: Search workouts
  Future<List<OptionItem>> searchWorkouts(String token, String query) {
    return dataSource.searchWorkouts(token, query);
  }
}
