import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final int? age;
  final String? gender;
  final int? height;
  final int? weight;
  final String? bio;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.age,
    this.gender,
    this.height,
    this.weight,
    this.bio,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] ?? map['_id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      avatarUrl: map['avatarUrl'],
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
      'avatarUrl': avatarUrl,
      'age': age,
      'gender': gender,
      'height': height,
      'weight': weight,
      'bio': bio,
    };
  }

  @override
  List<Object?> get props => [id, name, email, avatarUrl, age, gender, height, weight, bio];
}
