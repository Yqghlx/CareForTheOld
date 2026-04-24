/// 邻里求助状态枚举（对应后端 HelpRequestStatus）
enum HelpRequestStatus {
  pending('pending'),
  accepted('accepted'),
  cancelled('cancelled'),
  resolved('resolved'),
  expired('expired');

  final String value;
  const HelpRequestStatus(this.value);

  /// 从后端字符串解析枚举值
  static HelpRequestStatus fromString(String value) {
    return HelpRequestStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => HelpRequestStatus.pending,
    );
  }
}

/// 邻里求助请求模型（对应后端 NeighborHelpRequestResponse）
class NeighborHelpRequest {
  final String id;
  final String emergencyCallId;
  final String circleId;
  final String requesterId;
  final String requesterName;
  final String? responderId;
  final String? responderName;
  final HelpRequestStatus status;
  final double? latitude;
  final double? longitude;
  final DateTime requestedAt;
  final DateTime? respondedAt;
  final DateTime expiresAt;

  /// 距当前位置的距离（米）
  final double? distanceMeters;

  const NeighborHelpRequest({
    required this.id,
    required this.emergencyCallId,
    required this.circleId,
    required this.requesterId,
    required this.requesterName,
    this.responderId,
    this.responderName,
    required this.status,
    this.latitude,
    this.longitude,
    required this.requestedAt,
    this.respondedAt,
    required this.expiresAt,
    this.distanceMeters,
  });

  factory NeighborHelpRequest.fromJson(Map<String, dynamic> json) {
    return NeighborHelpRequest(
      id: json['id'] as String,
      emergencyCallId: json['emergencyCallId'] as String,
      circleId: json['circleId'] as String,
      requesterId: json['requesterId'] as String,
      requesterName: json['requesterName'] as String,
      responderId: json['responderId'] as String?,
      responderName: json['responderName'] as String?,
      status: HelpRequestStatus.fromString(json['status'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'] as String)
          : null,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
    );
  }
}

/// 邻里互助评价模型（对应后端 NeighborHelpRatingResponse）
class NeighborHelpRating {
  final String id;
  final String helpRequestId;
  final String raterId;
  final String rateeId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const NeighborHelpRating({
    required this.id,
    required this.helpRequestId,
    required this.raterId,
    required this.rateeId,
    required this.rating,
    this.comment,
    required this.createdAt,
  });

  factory NeighborHelpRating.fromJson(Map<String, dynamic> json) {
    return NeighborHelpRating(
      id: json['id'] as String,
      helpRequestId: json['helpRequestId'] as String,
      raterId: json['raterId'] as String,
      rateeId: json['rateeId'] as String,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
