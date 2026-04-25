import 'user_role.dart';

/// 家庭成员状态枚举
enum FamilyMemberStatus {
  pending('pending', '待审批'),
  approved('approved', '已通过'),
  rejected('rejected', '已拒绝');

  final String value;
  final String label;
  const FamilyMemberStatus(this.value, this.label);

  static FamilyMemberStatus fromString(dynamic value) {
    if (value is int) {
      return FamilyMemberStatus.values[value];
    }
    return FamilyMemberStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => FamilyMemberStatus.approved,
    );
  }
}

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
  final FamilyMemberStatus status;

  const FamilyMember({
    required this.userId,
    required this.realName,
    required this.role,
    required this.relation,
    this.avatarUrl,
    this.status = FamilyMemberStatus.approved,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      userId: json['userId'] as String,
      realName: json['realName'] as String,
      role: UserRole.fromString(json['role']),
      relation: json['relation'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      status: json['status'] != null
          ? FamilyMemberStatus.fromString(json['status'])
          : FamilyMemberStatus.approved,
    );
  }
}

/// 加入家庭响应模型（对应后端 JoinFamilyResponse）
class JoinFamilyResult {
  final String message;
  final String familyName;
  final FamilyMemberStatus status;

  const JoinFamilyResult({
    required this.message,
    required this.familyName,
    required this.status,
  });

  factory JoinFamilyResult.fromJson(Map<String, dynamic> json) {
    return JoinFamilyResult(
      message: json['message'] as String? ?? '',
      familyName: json['familyName'] as String? ?? '',
      status: json['status'] != null
          ? FamilyMemberStatus.fromString(json['status'])
          : FamilyMemberStatus.pending,
    );
  }
}
