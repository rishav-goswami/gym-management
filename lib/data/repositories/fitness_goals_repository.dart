import 'package:fit_and_fine/data/datasources/fitness_goals_data_source.dart';
import 'package:fit_and_fine/data/models/user_model.dart';

// --- REPOSITORY ---
class FitnessGoalsRepository {
  final FitnessGoalsDataSource _dataSource;

  FitnessGoalsRepository({required FitnessGoalsDataSource dataSource})
    : _dataSource = dataSource;

  Future<Member> getFitnessGoals(String userId) async {
    // In a real app, you'd merge this with the full user profile
    // But for mock, we create a Member object from this specific data
    final data = await _dataSource.fetchFitnessGoals(userId);
    return Member.fromJson(data);
  }

  Future<Member> updateFitnessGoals(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    final data = await _dataSource.updateFitnessGoals(userId, updates);
    return Member.fromJson(data);
  }
}
