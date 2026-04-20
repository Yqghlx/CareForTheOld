import 'package:flutter/material.dart';

/// 紧急呼叫状态枚举
enum EmergencyStatus {
  pending(0, '待处理', Colors.red),
  responded(1, '已响应', Colors.green);

  final int value;
  final String label;
  final Color color;

  const EmergencyStatus(this.value, this.label, this.color);

  /// 从整数值获取状态
  static EmergencyStatus fromInt(int? value) {
    if (value == null) return pending;
    return value == 1 ? responded : pending;
  }
}

/// 紧急呼叫模型
class EmergencyCall {
  final String id;
  final String elderId;
  final String elderName;
  final String? elderPhoneNumber;
  final String familyId;
  final DateTime calledAt;
  final EmergencyStatus status;
  final String? respondedBy;
  final String? respondedByRealName;
  final DateTime? respondedAt;
  final double? latitude;
  final double? longitude;
  final int? batteryLevel;

  EmergencyCall({
    required this.id,
    required this.elderId,
    required this.elderName,
    this.elderPhoneNumber,
    required this.familyId,
    required this.calledAt,
    required this.status,
    this.respondedBy,
    this.respondedByRealName,
    this.respondedAt,
    this.latitude,
    this.longitude,
    this.batteryLevel,
  });

  /// 从 JSON 解析
  factory EmergencyCall.fromJson(Map<String, dynamic> json) {
    return EmergencyCall(
      id: json['id'] ?? '',
      elderId: json['elderId'] ?? '',
      elderName: json['elderName'] ?? '',
      elderPhoneNumber: json['elderPhoneNumber'],
      familyId: json['familyId'] ?? '',
      calledAt: _parseUtcDateTime(json['calledAt']),
      status: EmergencyStatus.fromInt(json['status']),
      respondedBy: json['respondedBy'],
      respondedByRealName: json['respondedByRealName'],
      respondedAt: json['respondedAt'] != null
          ? _parseUtcDateTime(json['respondedAt'])
          : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      batteryLevel: json['batteryLevel'] as int?,
    );
  }

  /// 统一将后端返回的时间字符串解析为 UTC
  static DateTime _parseUtcDateTime(dynamic dateTimeStr) {
    final dt = DateTime.parse(dateTimeStr.toString());
    return dt.isUtc ? dt : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, dt.millisecond, dt.microsecond);
  }

  /// 是否待处理
  bool get isPending => status == EmergencyStatus.pending;

  /// 是否有位置信息
  bool get hasLocation => latitude != null && longitude != null;

  /// 电池电量描述
  String get batteryText {
    if (batteryLevel == null) return '未知';
    return '$batteryLevel%';
  }

  /// 电池状态颜色
  Color get batteryColor {
    if (batteryLevel == null) return Colors.grey;
    if (batteryLevel! > 50) return Colors.green;
    if (batteryLevel! > 20) return Colors.orange;
    return Colors.red;
  }

  /// 格式化呼叫时间
  String get formattedTime {
    final localTime = calledAt.toLocal();
    return '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} '
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
  }

  /// 相对时间描述
  String get relativeTime {
    final now = DateTime.now();
    final diff = now.difference(calledAt);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    } else {
      return formattedTime;
    }
  }
}