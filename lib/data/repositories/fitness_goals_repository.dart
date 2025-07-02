import 'package:fit_and_fine/data/datasources/fitness_goals_data_source.dart';
import 'package:fit_and_fine/data/models/fitness_goals_model.dart';

// --- REPOSITORY ---
class FitnessGoalsRepository {
  final FitnessGoalsDataSource _dataSource;

  FitnessGoalsRepository({required FitnessGoalsDataSource dataSource})
      : _dataSource = dataSource;

  Future<FitnessGoals> getFitnessGoals(String token) async {
    final data = await _dataSource.fetchFitnessGoals(token);
    return FitnessGoals.fromJson(data);
  }

  Future<FitnessGoals> updateFitnessGoals(
    String token,
    Map<String, dynamic> updates,
  ) async {
    final data = await _dataSource.updateFitnessGoals(token, updates);
    return FitnessGoals.fromJson(data);
  }
}
