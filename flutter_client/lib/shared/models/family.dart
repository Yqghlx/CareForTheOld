import 'user_role.dart';

/// 家庭组模型（对应后端 FamilyResponse）
class FamilyGroup {
  final String id;
  final String familyName;
  final String inviteCode;
  final List<FamilyMember> members;

  const FamilyGroup({
    required this.id,
    required this.familyName,
    required this.inviteCode,
    required this.members,
  });

  factory FamilyGroup.fromJson(Map<String, dynamic> json) {
    return FamilyGroup(
      id: json['id'] as String,
      familyName: json['familyName'] as String,
      inviteCode: json['inviteCode'] as String? ?? '',
      members: (json['members'] as List<dynamic>)
          .map((m) => FamilyMember.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 家庭成员模型（对应后端 FamilyMemberResponse）
class FamilyMember {
  final String userId;
  final String realName;
  final UserRole role;
  final String relation;
  final String? avatarUrl;

  const FamilyMember({
    required this.userId,
    required this.realName,
    required this.role,
    required this.relation,
    this.avatarUrl,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      userId: json['userId'] as String,
      realName: json['realName'] as String,
      role: UserRole.fromString(json['role']),
      relation: json['relation'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
