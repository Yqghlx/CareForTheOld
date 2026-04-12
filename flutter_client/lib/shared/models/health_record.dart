import 'package:flutter/material.dart';

/// 健康数据类型枚举（与后端 HealthType 对应，整数序列化）
enum HealthType {
  bloodPressure(0, '血压', Icons.favorite, Colors.red),
  bloodSugar(1, '血糖', Icons.water_drop, Colors.blue),
  heartRate(2, '心率', Icons.monitor_heart, Colors.purple),
  temperature(3, '体温', Icons.thermostat, Colors.orange);

  final int value;
  final String label;
  final IconData icon;
  final Color color;

  const HealthType(this.value, this.label, this.icon, this.color);

  /// 从后端返回的整数值解析（C# 枚举默认序列化为 int）
  static HealthType fromInt(int? value) {
    if (value == null) return HealthType.bloodPressure;
    return HealthType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => HealthType.bloodPressure,
    );
  }

  /// 获取计量单位
  String get unit {
    switch (this) {
      case HealthType.bloodPressure:
        return 'mmHg';
      case HealthType.bloodSugar:
        return 'mmol/L';
      case HealthType.heartRate:
        return '次/分';
      case HealthType.temperature:
        return '°C';
    }
  }

  /// 格式化显示值
  String formatValue(HealthRecord record) {
    switch (this) {
      case HealthType.bloodPressure:
        return '${record.systolic ?? '-'}/${record.diastolic ?? '-'}';
      case HealthType.bloodSugar:
        return record.bloodSugar?.toStringAsFixed(1) ?? '-';
      case HealthType.heartRate:
        return record.heartRate?.toString() ?? '-';
      case HealthType.temperature:
        return record.temperature?.toStringAsFixed(1) ?? '-';
    }
  }
}

/// 健康记录模型（对应后端 HealthRecordResponse）
class HealthRecord {
  final String id;
  final String userId;
  final String? realName;
  final HealthType type;

  /// 收缩压（mmHg），血压类型时使用
  final int? systolic;

  /// 舒张压（mmHg），血压类型时使用
  final int? diastolic;

  /// 血糖值（mmol/L）
  final double? bloodSugar;

  /// 心率（次/分）
  final int? heartRate;

  /// 体温（°C）
  final double? temperature;

  final String? note;
  final DateTime recordedAt;
  final DateTime createdAt;

  const HealthRecord({
    required this.id,
    required this.userId,
    this.realName,
    required this.type,
    this.systolic,
    this.diastolic,
    this.bloodSugar,
    this.heartRate,
    this.temperature,
    this.note,
    required this.recordedAt,
    required this.createdAt,
  });

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: json['id'] as String,
      userId: json['userId'] as String,
      realName: json['realName'] as String?,
      type: HealthType.fromInt(json['type'] as int?),
      systolic: json['systolic'] as int?,
      diastolic: json['diastolic'] as int?,
      // 后端 decimal 类型 → Dart double
      bloodSugar: (json['bloodSugar'] as num?)?.toDouble(),
      heartRate: json['heartRate'] as int?,
      temperature: (json['temperature'] as num?)?.toDouble(),
      note: json['note'] as String?,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// 获取格式化的显示值
  String get displayValue => type.formatValue(this);
}
