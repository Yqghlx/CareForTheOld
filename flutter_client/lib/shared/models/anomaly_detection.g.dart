// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'anomaly_detection.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PersonalBaseline _$PersonalBaselineFromJson(Map<String, dynamic> json) =>
    PersonalBaseline(
      avgSystolic: (json['avgSystolic'] as num?)?.toDouble(),
      avgDiastolic: (json['avgDiastolic'] as num?)?.toDouble(),
      avgBloodSugar: (json['avgBloodSugar'] as num?)?.toDouble(),
      avgHeartRate: (json['avgHeartRate'] as num?)?.toDouble(),
      avgTemperature: (json['avgTemperature'] as num?)?.toDouble(),
      baselineDays: (json['baselineDays'] as num?)?.toInt() ?? 30,
      baselineRecordCount: (json['baselineRecordCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$PersonalBaselineToJson(PersonalBaseline instance) =>
    <String, dynamic>{
      'avgSystolic': instance.avgSystolic,
      'avgDiastolic': instance.avgDiastolic,
      'avgBloodSugar': instance.avgBloodSugar,
      'avgHeartRate': instance.avgHeartRate,
      'avgTemperature': instance.avgTemperature,
      'baselineDays': instance.baselineDays,
      'baselineRecordCount': instance.baselineRecordCount,
    };

Map<String, dynamic> _$AnomalyEventToJson(AnomalyEvent instance) =>
    <String, dynamic>{
      'detectedAt': instance.detectedAt.toIso8601String(),
      'type': _$AnomalyTypeEnumMap[instance.type]!,
      'description': instance.description,
      'severityScore': instance.severityScore,
      'anomalyValue': instance.anomalyValue,
      'baselineValue': instance.baselineValue,
      'deviationPercent': instance.deviationPercent,
      'recommendedAction': instance.recommendedAction,
      'severityLevel': instance.severityLevel,
    };

const _$AnomalyTypeEnumMap = {
  AnomalyType.spike: 'spike',
  AnomalyType.continuousHigh: 'continuousHigh',
  AnomalyType.continuousLow: 'continuousLow',
  AnomalyType.acceleration: 'acceleration',
  AnomalyType.volatility: 'volatility',
};

RecentStatsSummary _$RecentStatsSummaryFromJson(Map<String, dynamic> json) =>
    RecentStatsSummary(
      avg7Days: (json['avg7Days'] as num?)?.toDouble(),
      stdDev7Days: (json['stdDev7Days'] as num?)?.toDouble(),
      max7Days: (json['max7Days'] as num?)?.toDouble(),
      min7Days: (json['min7Days'] as num?)?.toDouble(),
      recordCount7Days: (json['recordCount7Days'] as num?)?.toInt() ?? 0,
      trend: json['trend'] as String?,
      baselineDeviationPercent:
          (json['baselineDeviationPercent'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$RecentStatsSummaryToJson(RecentStatsSummary instance) =>
    <String, dynamic>{
      'avg7Days': instance.avg7Days,
      'stdDev7Days': instance.stdDev7Days,
      'max7Days': instance.max7Days,
      'min7Days': instance.min7Days,
      'recordCount7Days': instance.recordCount7Days,
      'trend': instance.trend,
      'baselineDeviationPercent': instance.baselineDeviationPercent,
    };

PositiveFeedback _$PositiveFeedbackFromJson(Map<String, dynamic> json) =>
    PositiveFeedback(
      quality: json['quality'] as String,
      message: json['message'] as String,
      daysStable: (json['daysStable'] as num).toInt(),
      coefficientOfVariation:
          (json['coefficientOfVariation'] as num).toDouble(),
    );

Map<String, dynamic> _$PositiveFeedbackToJson(PositiveFeedback instance) =>
    <String, dynamic>{
      'quality': instance.quality,
      'message': instance.message,
      'daysStable': instance.daysStable,
      'coefficientOfVariation': instance.coefficientOfVariation,
    };

Map<String, dynamic> _$TrendAnomalyDetectionResponseToJson(
        TrendAnomalyDetectionResponse instance) =>
    <String, dynamic>{
      'type': instance.type,
      'typeName': instance.typeName,
      'baseline': instance.baseline,
      'anomalies': instance.anomalies,
      'recentStats': instance.recentStats,
      'positiveFeedback': instance.positiveFeedback,
    };
