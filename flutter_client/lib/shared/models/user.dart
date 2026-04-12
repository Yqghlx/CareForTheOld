import 'user_role.dart';

/// 用户模型
class User {
  final String id;
  final String phoneNumber;
  final String? realName;
  final DateTime? birthDate;
  final UserRole role;
  final String? avatarUrl;

  const User({
    required this.id,
    required this.phoneNumber,
    this.realName,
    this.birthDate,
    required this.role,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String,
      realName: json['realName'] as String?,
      birthDate: json['birthDate'] != null
          ? DateTime.parse(json['birthDate'] as String)
          : null,
      role: UserRole.fromString(json['role']),
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phoneNumber': phoneNumber,
      'realName': realName,
      'birthDate': birthDate?.toIso8601String(),
      'role': role.value,
      'avatarUrl': avatarUrl,
    };
  }
}