class ProfileDataSource {
  Future<Map<String, dynamic>> fetchFullProfile(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // The API returns a nested object, common in real-world scenarios
    return {
      'personal': {
        'name': 'Ethan Carter',
        'email': 'ethan.carter@email.com',
        'phone': '555-123-4567',
        'avatarUrl': 'assets/images/avatars/avatar3.png',
      },
      'fitness': {
        'healthGoals': 'Improve Endurance',
        'workoutFrequency': '5+ times a week',
        'preferredWorkouts': ['CrossFit', 'Cardio'],
        'preferredWorkoutTime': 'Evening',
      },
      'payment': {'status': 'Active', 'method': 'Mastercard **** 56780'},
    };
  }
}
