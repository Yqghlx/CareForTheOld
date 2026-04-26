import 'package:flutter/material.dart';
import '../../core/extensions/date_format_extension.dart';

/// 通知记录模型
class NotificationRecord {
  final String id;
  final String type;
  final String title;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  const NotificationRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    return NotificationRecord(
      id: json['id'] as String,
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// 通知类型对应的图标
  IconData get icon {
    switch (type) {
      case 'MedicationReminder':
      case 'MedicationReminderFamily':
      case 'MedicationReminderUrgent':
      case 'MedicationMissed':
        return Icons.medication;
      case 'EmergencyCall':
      case 'EmergencyCallReminder':
        return Icons.emergency;
      case 'GeoFenceAlert':
        return Icons.location_off;
      case 'HealthAlert':
        return Icons.warning_amber_rounded;
      case 'HeartbeatAlert':
        return Icons.phonelink_off;
      default:
        return Icons.notifications;
    }
  }

  /// 通知类型对应的颜色
  Color get color {
    switch (type) {
      case 'MedicationReminder':
      case 'MedicationReminderFamily':
        return Colors.blue;
      case 'MedicationReminderUrgent':
        return Colors.orange;
      case 'MedicationMissed':
        return Colors.deepOrange;
      case 'EmergencyCall':
      case 'EmergencyCallReminder':
        return Colors.red;
      case 'GeoFenceAlert':
        return Colors.purple;
      case 'HealthAlert':
        return Colors.orange;
      case 'HeartbeatAlert':
        return Colors.grey;
      default:
        return Colors.green;
    }
  }

  /// 格式化时间
  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(createdAt.toLocal());

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';

    return createdAt.toShortDateTimeString();
  }
}
