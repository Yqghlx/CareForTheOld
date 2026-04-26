import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// 用药频率枚举（与后端 Frequency 对应，整数序列化）
enum Frequency {
  onceDaily(0, '每日一次', Icons.looks_one),
  twiceDaily(1, '每日两次', Icons.looks_two),
  threeTimesDaily(2, '每日三次', Icons.looks_3),
  asNeeded(3, '按需服用', Icons.event_available);

  final int value;
  final String label;
  final IconData icon;

  const Frequency(this.value, this.label, this.icon);

  /// 从后端返回的值解析（支持字符串 "onceDaily" 和整数 0 两种格式）
  static Frequency fromDynamic(dynamic value) {
    if (value == null) return Frequency.onceDaily;
    if (value is int) return fromInt(value);
    if (value is String) {
      return Frequency.values.firstWhere(
        (e) => e.name == value,
        orElse: () => Frequency.onceDaily,
      );
    }
    return Frequency.onceDaily;
  }

  /// 从后端返回的整数值解析
  static Frequency fromInt(int? value) {
    if (value == null) return Frequency.onceDaily;
    return Frequency.values.firstWhere(
      (e) => e.value == value,
      orElse: () => Frequency.onceDaily,
    );
  }
}

/// 服药状态枚举（与后端 MedicationStatus 对应，整数序列化）
enum MedicationStatus {
  taken(0, '已服', Colors.green),
  skipped(1, '跳过', AppTheme.grey500),
  missed(2, '漏服', Colors.red);

  final int value;
  final String label;
  final Color color;

  const MedicationStatus(this.value, this.label, this.color);

  /// 从后端返回的值解析（支持字符串 "taken" 和整数 0 两种格式）
  static MedicationStatus fromDynamic(dynamic value) {
    if (value == null) return MedicationStatus.missed;
    if (value is int) return fromInt(value);
    if (value is String) {
      return MedicationStatus.values.firstWhere(
        (e) => e.name == value,
        orElse: () => MedicationStatus.missed,
      );
    }
    return MedicationStatus.missed;
  }

  /// 从后端返回的整数值解析
  static MedicationStatus fromInt(int? value) {
    if (value == null) return MedicationStatus.missed;
    return MedicationStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => MedicationStatus.missed,
    );
  }
}

/// 用药计划模型（对应后端 MedicationPlanResponse）
class MedicationPlan {
  final String id;
  final String elderId;
  final String? elderName;
  final String medicineName;
  final String dosage;
  final Frequency frequency;
  final List<String> reminderTimes;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MedicationPlan({
    required this.id,
    required this.elderId,
    this.elderName,
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.reminderTimes,
    required this.startDate,
    this.endDate,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MedicationPlan.fromJson(Map<String, dynamic> json) {
    return MedicationPlan(
      id: json['id'] as String,
      elderId: json['elderId'] as String,
      elderName: json['elderName'] as String?,
      medicineName: json['medicineName'] as String,
      dosage: json['dosage'] as String,
      frequency: Frequency.fromDynamic(json['frequency']),
      reminderTimes: (json['reminderTimes'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      // 后端 DateOnly 序列化为 "2026-04-12" 字符串
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      isActive: json['isActive'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// 格式化提醒时间显示
  String get reminderTimesText => reminderTimes.join('、');

  /// 序列化为 JSON（用于本地缓存）
  Map<String, dynamic> toJson() => {
    'id': id,
    'elderId': elderId,
    'elderName': elderName,
    'medicineName': medicineName,
    'dosage': dosage,
    'frequency': frequency.value,
    'reminderTimes': reminderTimes,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
