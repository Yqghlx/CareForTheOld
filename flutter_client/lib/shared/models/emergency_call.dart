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
  final String familyId;
  final DateTime calledAt;
  final EmergencyStatus status;
  final String? respondedBy;
  final String? respondedByRealName;
  final DateTime? respondedAt;

  EmergencyCall({
    required this.id,
    required this.elderId,
    required this.elderName,
    required this.familyId,
    required this.calledAt,
    required this.status,
    this.respondedBy,
    this.respondedByRealName,
    this.respondedAt,
  });

  /// 从 JSON 解析
  factory EmergencyCall.fromJson(Map<String, dynamic> json) {
    return EmergencyCall(
      id: json['id'] ?? '',
      elderId: json['elderId'] ?? '',
      elderName: json['elderName'] ?? '',
      familyId: json['familyId'] ?? '',
      calledAt: DateTime.parse(json['calledAt']),
      status: EmergencyStatus.fromInt(json['status']),
      respondedBy: json['respondedBy'],
      respondedByRealName: json['respondedByRealName'],
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'])
          : null,
    );
  }

  /// 是否待处理
  bool get isPending => status == EmergencyStatus.pending;

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