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

enum FitnessScopeKind { personal, gym }

sealed class AppSpace extends Equatable {
  const AppSpace();

  String get id;
  String get displayName;
  FitnessScope get fitnessScope;
}

class PersonalSpace extends AppSpace {
  const PersonalSpace({required this.uid});

  final String uid;

  @override
  String get id => 'personal';

  @override
  String get displayName => 'My Fitness';

  @override
  FitnessScope get fitnessScope => FitnessScope.personal(uid);

  @override
  List<Object?> get props => [uid];
}

class GymSpace extends AppSpace {
  const GymSpace({required this.membership});

  final GymMembership membership;

  @override
  String get id => 'gym:${membership.gymId}';

  @override
  String get displayName => membership.gymName;

  @override
  FitnessScope get fitnessScope => FitnessScope.gym(membership);

  @override
  List<Object?> get props => [membership];
}

/// Identifies where member-owned fitness data lives without pretending that a
/// standalone consumer belongs to a hidden gym tenant.
class FitnessScope extends Equatable {
  const FitnessScope._({
    required this.kind,
    required this.uid,
    this.membership,
  });

  const FitnessScope.personal(String uid)
    : this._(kind: FitnessScopeKind.personal, uid: uid);

  FitnessScope.gym(GymMembership membership)
    : this._(
        kind: FitnessScopeKind.gym,
        uid: membership.uid,
        membership: membership,
      );

  final FitnessScopeKind kind;
  final String uid;
  final GymMembership? membership;

  bool get isPersonal => kind == FitnessScopeKind.personal;
  String? get gymId => membership?.gymId;
  String get id => isPersonal ? 'personal' : 'gym:${membership!.gymId}';
  String get draftKey => isPersonal ? 'personal' : membership!.gymId;
  String get displayName => isPersonal ? 'My Fitness' : membership!.gymName;
  String get tagline => isPersonal
      ? 'Your training. Your progress. Your pace.'
      : membership!.tagline;

  bool feature(String name, {bool defaultValue = true}) => isPersonal
      ? defaultValue
      : membership!.feature(name, defaultValue: defaultValue);

  String collectionPath(String collection) {
    final gymCollection = collection == 'routines'
        ? 'member_routines'
        : collection;
    return isPersonal
        ? 'users/$uid/$collection'
        : 'gyms/${membership!.gymId}/$gymCollection';
  }

  String get profilePath => isPersonal
      ? 'users/$uid/fitness_profile/current'
      : 'gyms/${membership!.gymId}/members/$uid';

  @override
  List<Object?> get props => [kind, uid, membership];
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
    this.secondaryColor = '#0F172A',
    this.accentColor = '#F97316',
    this.tagline = 'Stronger every day',
    this.currency = 'INR',
    this.timezone = 'Asia/Kolkata',
    this.locale = 'en-IN',
    this.phone,
    this.city,
    this.website,
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
  final String secondaryColor;
  final String accentColor;
  final String tagline;
  final String currency;
  final String timezone;
  final String locale;
  final String? phone;
  final String? city;
  final String? website;
  final Map<String, bool> features;

  bool can(String permission) =>
      permissions[permission] ?? _legacySupportPermission(role, permission);
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
    secondaryColor:
        (gym?['branding'] as Map?)?['secondaryColor'] as String? ??
        secondaryColor,
    accentColor:
        (gym?['branding'] as Map?)?['accentColor'] as String? ?? accentColor,
    tagline: (gym?['branding'] as Map?)?['tagline'] as String? ?? tagline,
    currency: gym?['currency'] as String? ?? currency,
    timezone: gym?['timezone'] as String? ?? timezone,
    locale: gym?['locale'] as String? ?? locale,
    phone: gym?['phone'] as String? ?? phone,
    city: gym?['city'] as String? ?? city,
    website: gym?['website'] as String? ?? website,
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
    logoUrl,
    primaryColor,
    secondaryColor,
    accentColor,
    tagline,
    currency,
    timezone,
    locale,
    phone,
    city,
    website,
    features,
  ];
}

/// Compatibility fallback for memberships created before routed support was
/// introduced. A stored true/false value always wins, so per-user overrides
/// remain authoritative while old role snapshots receive the new template
/// defaults until the numbered backfill migration runs.
bool _legacySupportPermission(GymRole role, String permission) =>
    switch (permission) {
      'support.coaching' =>
        role == GymRole.owner ||
            role == GymRole.manager ||
            role == GymRole.trainer,
      'support.billing' =>
        role == GymRole.owner ||
            role == GymRole.manager ||
            role == GymRole.accountant,
      'support.manage' =>
        role == GymRole.owner ||
            role == GymRole.manager ||
            role == GymRole.receptionist,
      _ => false,
    };
