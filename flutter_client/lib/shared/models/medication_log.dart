import 'medication_plan.dart' show MedicationStatus;

/// 用药日志模型（对应后端 MedicationLogResponse）
class MedicationLog {
  final String id;
  final String planId;
  final String medicineName;
  final String elderId;
  final String? elderName;
  final MedicationStatus status;
  final DateTime scheduledAt;
  final DateTime? takenAt;
  final String? note;

  const MedicationLog({
    required this.id,
    required this.planId,
    required this.medicineName,
    required this.elderId,
    this.elderName,
    required this.status,
    required this.scheduledAt,
    this.takenAt,
    this.note,
  });

  factory MedicationLog.fromJson(Map<String, dynamic> json) {
    return MedicationLog(
      id: json['id'] as String,
      planId: json['planId'] as String,
      medicineName: json['medicineName'] as String,
      elderId: json['elderId'] as String,
      elderName: json['elderName'] as String?,
      status: MedicationStatus.fromInt(json['status'] as int?),
      // 后端统一使用 UTC 存储和返回，这里确保解析为 UTC
      scheduledAt: _parseUtcDateTime(json['scheduledAt'] as String),
      takenAt: json['takenAt'] != null
          ? _parseUtcDateTime(json['takenAt'] as String)
          : null,
      note: json['note'] as String?,
    );
  }

  /// 统一将后端返回的时间字符串解析为 UTC
  /// 兼容带 Z 后缀（如 "2026-04-20T08:00:00Z"）和不带 Z 后缀（如 "2026-04-20T08:00:00"）两种格式
  static DateTime _parseUtcDateTime(String dateTimeStr) {
    final dt = DateTime.parse(dateTimeStr);
    // 如果解析后不是 UTC，手动标记为 UTC（后端存储的是 UTC 时间）
    return dt.isUtc ? dt : DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, dt.millisecond, dt.microsecond);
  }

  /// 是否待服用（未记录状态）
  bool get isPending => status == MedicationStatus.missed && takenAt == null;
}
