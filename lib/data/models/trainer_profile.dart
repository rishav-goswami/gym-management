import 'package:equatable/equatable.dart';

class TrainerProfile extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? profileImage;
  final int? age;
  final String? gender;
  final int? height;
  final int? weight;
  final String? bio;
  final List<String>? assignedUsers;
  // verified: Boolean;

  const TrainerProfile({
    required this.id,
    required this.name,
    required this.email,
    this.profileImage,
    this.age,
    this.gender,
    this.height,
    this.weight,
    this.bio,
    this.assignedUsers,
  });

  factory TrainerProfile.fromMap(Map<String, dynamic> map) {
    return TrainerProfile(
      id: map['id'] ?? map['_id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      profileImage: map['profileImage'],
      age: map['age'],
      gender: map['gender'],
      height: map['height'],
      weight: map['weight'],
      bio: map['bio'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'profileImage': profileImage,
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'bio': bio,
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    email,
    profileImage,
    age,
    gender,
    height,
    weight,
    bio,
  ];
}
