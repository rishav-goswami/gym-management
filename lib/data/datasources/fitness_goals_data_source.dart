// --- DATA SOURCE (Simulates API) ---
class FitnessGoalsDataSource {
  Map<String, dynamic> _userFitnessProfile = {
    '_id': '123',
    'name': 'Ethan Carter',
    'email': 'ethan.carter@email.com',
    'healthGoals': 'Muscle Gain',
    'workoutFrequency': '3-4 times a week',
    'preferredWorkouts': ['Strength Training', 'Yoga'],
    'preferredWorkoutTime': 'Morning',
  };

  Future<Map<String, dynamic>> fetchFitnessGoals(String userId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _userFitnessProfile;
  }

  Future<Map<String, dynamic>> updateFitnessGoals(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    await Future.delayed(const Duration(milliseconds: 700));
    _userFitnessProfile.addAll(updates);
    return _userFitnessProfile;
  }
}
