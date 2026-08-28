class GymInvitationLink {
  const GymInvitationLink({
    required this.gymId,
    required this.token,
    required this.gymName,
    required this.role,
    this.expiresInHours = 72,
  });

  static const _host = 'createmix-gym-app.web.app';

  final String gymId;
  final String token;
  final String gymName;
  final String role;
  final int expiresInHours;

  Map<String, String> get queryParameters => {
    'gymId': gymId,
    'token': token,
    'gymName': gymName,
    'role': role,
  };

  Uri get routeUri => Uri(path: '/join', queryParameters: queryParameters);

  String get routeLocation => routeUri.toString();

  String get loginLocation =>
      Uri(path: '/login', queryParameters: queryParameters).toString();

  String get registerLocation =>
      Uri(path: '/register', queryParameters: queryParameters).toString();

  Uri get shareUri => Uri.https(_host, '/join', queryParameters);

  String get roleLabel =>
      role == 'member' ? 'member' : role.replaceAll('_', ' ');

  String get shareMessage =>
      "You're invited to join $gymName as a $roleLabel on Gym Management.\n\n"
      'Open your secure invitation:\n$shareUri\n\n'
      'Sign in or create an account using the same email address that was invited. '
      'This invitation expires in $expiresInHours hours and can only be used once.';

  static GymInvitationLink? fromUri(Uri uri) {
    final values = uri.queryParameters;
    final gymId = values['gymId']?.trim() ?? '';
    final token = values['token']?.trim() ?? '';
    if (gymId.isEmpty || token.length < 20) return null;
    return GymInvitationLink(
      gymId: gymId,
      token: token,
      gymName: values['gymName']?.trim().isNotEmpty == true
          ? values['gymName']!.trim()
          : 'your gym',
      role: values['role']?.trim().isNotEmpty == true
          ? values['role']!.trim()
          : 'member',
    );
  }

  static GymInvitationLink? fromText(String value) {
    final trimmed = value.trim();
    final candidates = <String>[
      trimmed,
      ...RegExp(
        r'https?://[^\s<>]+',
      ).allMatches(trimmed).map((match) => match.group(0)!),
    ];
    for (final candidate in candidates) {
      final uri = Uri.tryParse(candidate);
      if (uri == null) continue;
      final invitation = fromUri(uri);
      if (invitation != null) return invitation;
    }
    return null;
  }
}
