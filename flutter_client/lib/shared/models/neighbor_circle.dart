import 'user_role.dart';

/// 邻里圈模型（对应后端 NeighborCircleResponse）
class NeighborCircle {
  final String id;
  final String circleName;
  final double centerLatitude;
  final double centerLongitude;
  final double radiusMeters;
  final String creatorId;
  final String creatorName;
  final String inviteCode;
  final DateTime? inviteCodeExpiresAt;
  final int memberCount;
  final bool isActive;
  final DateTime createdAt;

  /// 距当前位置的距离（米），搜索附近时使用
  final double? distanceMeters;

  const NeighborCircle({
    required this.id,
    required this.circleName,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusMeters,
    required this.creatorId,
    required this.creatorName,
    required this.inviteCode,
    this.inviteCodeExpiresAt,
    required this.memberCount,
    required this.isActive,
    required this.createdAt,
    this.distanceMeters,
  });

  factory NeighborCircle.fromJson(Map<String, dynamic> json) {
    return NeighborCircle(
      id: json['id'] as String,
      circleName: json['circleName'] as String,
      centerLatitude: (json['centerLatitude'] as num).toDouble(),
      centerLongitude: (json['centerLongitude'] as num).toDouble(),
      radiusMeters: (json['radiusMeters'] as num).toDouble(),
      creatorId: json['creatorId'] as String,
      creatorName: json['creatorName'] as String,
      inviteCode: json['inviteCode'] as String? ?? '',
      inviteCodeExpiresAt: json['inviteCodeExpiresAt'] != null
          ? DateTime.parse(json['inviteCodeExpiresAt'] as String)
          : null,
      memberCount: json['memberCount'] as int,
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
    );
  }
}

/// 邻里圈成员模型（对应后端 NeighborMemberResponse）
class NeighborCircleMember {
  final String userId;
  final String realName;
  final UserRole role;
  final String? nickname;
  final String? avatarUrl;
  final DateTime joinedAt;

  /// 距指定位置的距离（米）
  final double? distanceMeters;

  const NeighborCircleMember({
    required this.userId,
    required this.realName,
    required this.role,
    this.nickname,
    this.avatarUrl,
    required this.joinedAt,
    this.distanceMeters,
  });

  factory NeighborCircleMember.fromJson(Map<String, dynamic> json) {
    return NeighborCircleMember(
      userId: json['userId'] as String,
      realName: json['realName'] as String,
      role: UserRole.fromString(json['role'] as String),
      nickname: json['nickname'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
    );
  }
}
