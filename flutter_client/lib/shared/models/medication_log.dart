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
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      takenAt: json['takenAt'] != null
          ? DateTime.parse(json['takenAt'] as String)
          : null,
      note: json['note'] as String?,
    );
  }

  /// 是否待服用（未记录状态）
  bool get isPending => status == MedicationStatus.missed && takenAt == null;
}
