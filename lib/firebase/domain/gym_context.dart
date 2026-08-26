import 'package:equatable/equatable.dart';

enum GymRole {
  owner,
  manager,
  receptionist,
  trainer,
  accountant,
  member;

  static GymRole fromJson(String value) => GymRole.values.firstWhere(
    (role) => role.name == value.toLowerCase(),
    orElse: () => GymRole.member,
  );
}

class GymMembership extends Equatable {
  const GymMembership({
    required this.id,
    required this.gymId,
    required this.uid,
    required this.role,
    required this.status,
    required this.permissions,
    this.gymName = 'Gym',
    this.logoUrl,
    this.primaryColor = '#2563EB',
    this.features = const {},
  });

  final String id;
  final String gymId;
  final String uid;
  final GymRole role;
  final String status;
  final Map<String, bool> permissions;
  final String gymName;
  final String? logoUrl;
  final String primaryColor;
  final Map<String, bool> features;

  bool can(String permission) => permissions[permission] == true;
  bool feature(String name, {bool defaultValue = true}) =>
      features[name] ?? defaultValue;

  GymMembership withGym(Map<String, dynamic>? gym) => GymMembership(
    id: id,
    gymId: gymId,
    uid: uid,
    role: role,
    status: status,
    permissions: permissions,
    gymName: gym?['name'] as String? ?? gymName,
    logoUrl: (gym?['branding'] as Map?)?['logoUrl'] as String?,
    primaryColor:
        (gym?['branding'] as Map?)?['primaryColor'] as String? ?? primaryColor,
    features: Map<String, bool>.from(gym?['features'] as Map? ?? const {}),
  );

  @override
  List<Object?> get props => [
    id,
    gymId,
    uid,
    role,
    status,
    permissions,
    gymName,
    features,
  ];
}
