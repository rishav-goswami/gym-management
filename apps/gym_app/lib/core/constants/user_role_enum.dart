enum UserRole {
  admin,
  trainer,
  member;

  /// Returns uppercase value for API requests, storage, etc.
  String get name => toString().split('.').last.toUpperCase();

  /// Parse from string (case-insensitive)
  static UserRole? fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'trainer':
        return UserRole.trainer;
      case 'member':
        return UserRole.member;
      default:
        return null;
    }
  }
}
