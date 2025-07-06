// lib/data/models/member_profile_data.dart

import 'package:fit_and_fine/data/models/user_model.dart'; // For Gender enum
import 'package:flutter/foundation.dart';

// -------------------
// The Main Composite Model
// -------------------
// This is the object that your ProfileLoaded state will hold.
@immutable
class MemberProfileData {
  final PersonalInfo personalInfo;
  final FitnessInfo fitnessInfo;
  final PaymentInfo paymentInfo;

  const MemberProfileData({
    required this.personalInfo,
    required this.fitnessInfo,
    required this.paymentInfo,
  });

  // This factory constructor is the orchestrator. It takes the full JSON
  // response from the API and delegates parsing to the sub-models.
  factory MemberProfileData.fromJson(Map<String, dynamic> json) {
    return MemberProfileData(
      personalInfo: PersonalInfo.fromJson(json['personal'] ?? {}),
      fitnessInfo: FitnessInfo.fromJson(json['fitness'] ?? {}),
      paymentInfo: PaymentInfo.fromJson(json['payment'] ?? {}),
    );
  }
}

// -------------------
// The "Satellite" Sub-Models
// -------------------

// Holds only the core, personal user info.
@immutable
class PersonalInfo {
  final String name;
  final String email;
  final double? phone;
  final String? avatarUrl;
  final DateTime? dob;
  final Gender? gender;
  final String? memberSince;
  final String? bio;
  final double? height;
  final double? weight;

  const PersonalInfo({
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.dob,
    this.gender,
    this.memberSince,
    this.bio,
    this.height,
    this.weight,
  });

  factory PersonalInfo.fromJson(Map<String, dynamic> json) {
    return PersonalInfo(
      name: json['name'] ?? 'N/A',
      email: json['email'] ?? 'N/A',
      phone: (json['phone'] as num?)?.toDouble(),
      avatarUrl: json['avatarUrl'],
      dob: json['dob'] != null ? DateTime.tryParse(json['dob']) : null,
      gender: json['gender'] != null
          ? Gender.values.byName(json['gender'])
          : null,
      memberSince: json['memberSince'],
      bio: json['bio'],
      height: (json['height'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
    );
  }
}

// Holds only fitness-related goals and preferences.
@immutable
class FitnessInfo {
  final String? healthGoals;
  final String? workoutFrequency;
  final List<String> preferredWorkouts;
  final String? preferredWorkoutTime;

  const FitnessInfo({
    this.healthGoals,
    this.workoutFrequency,
    required this.preferredWorkouts,
    this.preferredWorkoutTime,
  });

  factory FitnessInfo.fromJson(Map<String, dynamic> json) {
    return FitnessInfo(
      healthGoals: json['healthGoals'],
      workoutFrequency: json['workoutFrequency'],
      preferredWorkouts: json['preferredWorkouts'] != null
          ? List<String>.from(json['preferredWorkouts'])
          : [],
      preferredWorkoutTime: json['preferredWorkoutTime'],
    );
  }
}

// Holds only payment and subscription info.
@immutable
class PaymentInfo {
  final String subscriptionStatus;
  final String paymentMethod;

  const PaymentInfo({
    required this.subscriptionStatus,
    required this.paymentMethod,
  });

  factory PaymentInfo.fromJson(Map<String, dynamic> json) {
    return PaymentInfo(
      subscriptionStatus: json['subscriptionStatus'] ?? 'N/A',
      paymentMethod: json['paymentMethod'] ?? 'N/A',
    );
  }
}
