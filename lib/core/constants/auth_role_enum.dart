enum AuthRole {
  admin,
  trainer,
  member;

  /// Returns uppercase value for API requests, storage, etc.
  String get name => toString().split('.').last.toUpperCase();

  /// Parse from string (case-insensitive)
  static AuthRole? fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'admin':
        return AuthRole.admin;
      case 'trainer':
        return AuthRole.trainer;
      case 'member':
        return AuthRole.member;
      default:
        return null;
    }
  }
}
