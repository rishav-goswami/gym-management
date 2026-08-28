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
