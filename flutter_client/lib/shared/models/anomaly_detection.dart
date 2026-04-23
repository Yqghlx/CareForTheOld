import 'package:json_annotation/json_annotation.dart';

part 'anomaly_detection.g.dart';

/// 异常类型枚举
enum AnomalyType {
  spike,
  continuousHigh,
  continuousLow,
  acceleration,
  volatility,
}

/// 异常类型扩展
extension AnomalyTypeExtension on AnomalyType {
  String get label => switch (this) {
    AnomalyType.spike => '峰值异常',
    AnomalyType.continuousHigh => '持续偏高',
    AnomalyType.continuousLow => '持续偏低',
    AnomalyType.acceleration => '上升加速',
    AnomalyType.volatility => '波动增大',
  };

  String get description => switch (this) {
    AnomalyType.spike => '单次数值突增或突降',
    AnomalyType.continuousHigh => '连续多天高于基线',
    AnomalyType.continuousLow => '连续多天低于基线',
    AnomalyType.acceleration => '数值持续上升趋势',
    AnomalyType.volatility => '数值波动性增大',
  };
}

/// 个人基线数据
@JsonSerializable()
class PersonalBaseline {
  final double? avgSystolic;
  final double? avgDiastolic;
  final double? avgBloodSugar;
  final double? avgHeartRate;
  final double? avgTemperature;
  final int baselineDays;
  final int baselineRecordCount;

  const PersonalBaseline({
    this.avgSystolic,
    this.avgDiastolic,
    this.avgBloodSugar,
    this.avgHeartRate,
    this.avgTemperature,
    this.baselineDays = 30,
    this.baselineRecordCount = 0,
  });

  factory PersonalBaseline.fromJson(Map<String, dynamic> json) =>
      _$PersonalBaselineFromJson(json);
  Map<String, dynamic> toJson() => _$PersonalBaselineToJson(this);
}

/// 异常事件
@JsonSerializable()
class AnomalyEvent {
  final DateTime detectedAt;
  final AnomalyType type;
  final String description;
  final double severityScore;
  final double? anomalyValue;
  final double? baselineValue;
  final double? deviationPercent;

  const AnomalyEvent({
    required this.detectedAt,
    required this.type,
    required this.description,
    required this.severityScore,
    this.anomalyValue,
    this.baselineValue,
    this.deviationPercent,
  });

  factory AnomalyEvent.fromJson(Map<String, dynamic> json) =>
      _$AnomalyEventFromJson(json);
  Map<String, dynamic> toJson() => _$AnomalyEventToJson(this);

  /// 严重度颜色（0-33绿色/正常，33-66橙色/警告，66-100红色/高危）
  String get severityLevel => switch (severityScore) {
    < 33 => '正常关注',
    >= 33 && < 66 => '需要关注',
    _ => '需要重视',
  };
}

/// 最近统计摘要
@JsonSerializable()
class RecentStatsSummary {
  final double? avg7Days;
  final double? stdDev7Days;
  final double? max7Days;
  final double? min7Days;
  final int recordCount7Days;
  final String? trend;
  final double? baselineDeviationPercent;

  const RecentStatsSummary({
    this.avg7Days,
    this.stdDev7Days,
    this.max7Days,
    this.min7Days,
    this.recordCount7Days = 0,
    this.trend,
    this.baselineDeviationPercent,
  });

  factory RecentStatsSummary.fromJson(Map<String, dynamic> json) =>
      _$RecentStatsSummaryFromJson(json);
  Map<String, dynamic> toJson() => _$RecentStatsSummaryToJson(this);
}

/// 异常检测响应
@JsonSerializable()
class TrendAnomalyDetectionResponse {
  final String type;
  final String typeName;
  final PersonalBaseline baseline;
  final List<AnomalyEvent> anomalies;
  final RecentStatsSummary recentStats;

  const TrendAnomalyDetectionResponse({
    required this.type,
    required this.typeName,
    required this.baseline,
    this.anomalies = const [],
    required this.recentStats,
  });

  factory TrendAnomalyDetectionResponse.fromJson(Map<String, dynamic> json) =>
      _$TrendAnomalyDetectionResponseFromJson(json);
  Map<String, dynamic> toJson() => _$TrendAnomalyDetectionResponseToJson(this);

  /// 是否有异常
  bool hasAnomalies() => anomalies.isNotEmpty;

  /// 最高严重度
  double maxSeverity() =>
      anomalies.isEmpty ? 0 : anomalies.map((a) => a.severityScore).reduce((a, b) => a > b ? a : b);
}