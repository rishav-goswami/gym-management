// --- DATA SOURCE (Simulates API) ---
class PersonalInfoDataSource {
  // Mock database record with all fields from your Member model
  Map<String, dynamic> _userProfile = {
    '_id': '123',
    'name': 'Ethan Carter',
    'email': 'ethan.carter@email.com',
    'phone': '555-123-4567',
    'avatarUrl': 'assets/images/avatars/avatar1.png',
    'bio': 'Fitness enthusiast from California, aiming to improve endurance.',
    'dob': DateTime(1990, 5, 15).toIso8601String(),
    'gender': 'male',
    'height': 180.5,
    'weight': 175.0,
    'healthGoals': 'Improve Endurances',
    'createdAt': DateTime.now().toIso8601String(),
    'updatedAt': DateTime.now().toIso8601String(),
    'verified': true,
    'performance': [],
  };

  Future<Map<String, dynamic>> fetchPersonalInfo(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _userProfile;
  }

  Future<Map<String, dynamic>> updatePersonalInfo(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    await Future.delayed(const Duration(milliseconds: 800));
    // Remove null values so we don't overwrite existing data with null
    updates.removeWhere((key, value) => value == null);
    _userProfile.addAll(updates);
    return _userProfile;
  }
}
