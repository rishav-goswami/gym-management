// --- DATA SOURCE (Simulates API) ---

class TestingRemoteDataSource {
  // Mock database record with all fields from your Member model
  final Map<String, dynamic> _userProfile = {
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

  Future<Map<String, dynamic>> getMe(String token) async {
    await Future.delayed(const Duration(milliseconds: 500));

    Map<String, dynamic> data = {
      "success": true,
      "message": "User profile found Successfully !",
      "data": {
        "_id": "685da2b11853b166fa8ff639",
        "name": "Rishav",
        "email": "rishav@gmail.com",
        "performance": [],
        "verified": false,
        "createdAt": "2025-06-26T19:42:41.588Z",
        "updatedAt": "2025-06-26T19:42:41.589Z",
        "role": "MEMBER",
        ..._userProfile,
      },
      "statusCode": 200,
      "timestamp": "2025-06-28T17:40:43.304Z",
    };
    if (data['success'] == true) {
      return data['data'];
    } else {
      throw Exception(data['message'] ?? 'Failed to fetch user profile');
    }
  }
}
