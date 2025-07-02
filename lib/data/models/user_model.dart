/**
 * file: user_model.dart
 * This file contains the Dart data models corresponding to your backend schemas.
 * It defines the base User class and specific implementations for Member, Trainer, and Admin.
 **/

import 'package:flutter/foundation.dart';
import 'package:fit_and_fine/core/constants/user_role_enum.dart'; // Assuming you have this enum

// An enum for gender to ensure type safety on the front end.
enum Gender { male, female, other }

/// Abstract base class representing common properties for all user roles.
@immutable
abstract class User {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  // Made these nullable as they might not be in every response (like login)
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? phone;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.createdAt,
    this.updatedAt,
    this.phone,
  });
}

/// Represents a Member (your 'User' schema on the backend).
@immutable
class Member extends User {
  final String? avatarUrl;
  final String? trainerId; // this should not be here instead userId should be in trainer list
  final String? healthGoals;
  final String? subscription;
  final List<String>? performance;
  final int? age; // not required will remove it later
  final DateTime? dob;
  final Gender? gender;
  final double? height;
  final double? weight;
  final String? bio;
  final bool verified;
  final String? workoutFrequency;
  final List<String>? preferredWorkouts;
  final String? preferredWorkoutTime;

  const Member({
    required super.id,
    required super.name,
    required super.email,
    super.createdAt,
    super.updatedAt,
    this.avatarUrl,
    this.trainerId,
    this.healthGoals,
    this.subscription,
    this.performance,
    this.age,
    this.dob,
    super.phone,
    this.gender,
    this.height,
    this.weight,
    this.bio,
    required this.verified,
    this.workoutFrequency,
    this.preferredWorkouts,
    this.preferredWorkoutTime,
  }) : super(role: UserRole.member);

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      // Use 'id' from login response, fallback to '_id' for other scenarios
      id: json['id'] ?? json['_id'],
      name: json['name'],
      email: json['email'],
      // Safely parse dates: if the key is null, the property will be null.
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      dob: json['dob'] != null ? DateTime.parse(json['dob']) : null,
      phone: json['phone'],
      avatarUrl: json['avatarUrl'],
      trainerId: json['trainerId'],
      healthGoals: json['healthGoals'],
      subscription: json['subscription'],
      performance: List<String>.from(json['performance'] ?? []),
      age: json['age'],
      gender: json['gender'] != null
          ? Gender.values.byName(json['gender'])
          : null,
      height: (json['height'] as num?)?.toDouble(),
      weight: (json['weight'] as num?)?.toDouble(),
      bio: json['bio'],
      // Provide a default value for non-nullable types if they are missing.
      verified: json['verified'] ?? false,
      workoutFrequency: json['workoutFrequency'],
      preferredWorkouts: json['preferredWorkouts'] != null
          ? List<String>.from(json['preferredWorkouts'])
          : null,
      preferredWorkoutTime: json['preferredWorkoutTime'],
    );
  }
}

/// Represents a Trainer user.
@immutable
class Trainer extends User {
  final List<String> assignedUsers;
  final String? profileImage;
  final bool verified;

  const Trainer({
    required super.id,
    required super.name,
    required super.email,
    super.createdAt,
    super.updatedAt,
    required this.assignedUsers,
    this.profileImage,
    required this.verified,
  }) : super(role: UserRole.trainer);

  factory Trainer.fromJson(Map<String, dynamic> json) {
    return Trainer(
      id: json['id'] ?? json['_id'],
      name: json['name'],
      email: json['email'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      assignedUsers: List<String>.from(json['assignedUsers'] ?? []),
      profileImage: json['profileImage'],
      verified: json['verified'] ?? false,
    );
  }
}

/// Represents an Admin user.
@immutable
class Admin extends User {
  final String? profileImage;

  const Admin({
    required super.id,
    required super.name,
    required super.email,
    super.createdAt,
    super.updatedAt,
    this.profileImage,
  }) : super(role: UserRole.admin);

  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(
      id: json['id'] ?? json['_id'],
      name: json['name'],
      email: json['email'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      profileImage: json['profileImage'],
    );
  }
}
