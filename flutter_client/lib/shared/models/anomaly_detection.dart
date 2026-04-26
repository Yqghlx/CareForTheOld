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

/// 从后端返回的值解析异常类型（支持字符串 "spike" 和整数 1 两种格式）
AnomalyType _parseAnomalyType(dynamic value) {
  if (value is String) {
    return AnomalyType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AnomalyType.spike,
    );
  }
  if (value is int) {
    // 后端枚举从 1 开始：Spike=1, ContinuousHigh=2, ContinuousLow=3, Acceleration=4, Volatility=5
    return AnomalyType.values.firstWhere(
      (e) => e.index + 1 == value,
      orElse: () => AnomalyType.spike,
    );
  }
  return AnomalyType.spike;
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
@JsonSerializable(createFactory: false)
class AnomalyEvent {
  final DateTime detectedAt;
  final AnomalyType type;
  final String description;
  final double severityScore;
  final double? anomalyValue;
  final double? baselineValue;
  final double? deviationPercent;

  /// 行动建议（如"建议今晚清淡饮食，若明早仍高请及时就医"）
  final String? recommendedAction;

  const AnomalyEvent({
    required this.detectedAt,
    required this.type,
    required this.description,
    required this.severityScore,
    this.anomalyValue,
    this.baselineValue,
    this.deviationPercent,
    this.recommendedAction,
  });

  /// 覆盖生成的 fromJson，兼容后端返回整数或字符串格式的枚举
  factory AnomalyEvent.fromJson(Map<String, dynamic> json) => AnomalyEvent(
        detectedAt: DateTime.parse(json['detectedAt'] as String),
        type: _parseAnomalyType(json['type']),
        description: json['description'] as String,
        severityScore: (json['severityScore'] as num).toDouble(),
        anomalyValue: (json['anomalyValue'] as num?)?.toDouble(),
        baselineValue: (json['baselineValue'] as num?)?.toDouble(),
        deviationPercent: (json['deviationPercent'] as num?)?.toDouble(),
        recommendedAction: json['recommendedAction'] as String?,
      );
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

/// 正向激励反馈（数据平稳时给予积极鼓励）
@JsonSerializable()
class PositiveFeedback {
  /// 控制质量评价：极佳/良好/平稳
  final String quality;

  /// 鼓励信息（如"过去一周血压控制极佳"）
  final String message;

  /// 连续平稳天数
  final int daysStable;

  /// 变异系数百分比（越小越稳定）
  final double coefficientOfVariation;

  const PositiveFeedback({
    required this.quality,
    required this.message,
    required this.daysStable,
    required this.coefficientOfVariation,
  });

  factory PositiveFeedback.fromJson(Map<String, dynamic> json) =>
      _$PositiveFeedbackFromJson(json);
  Map<String, dynamic> toJson() => _$PositiveFeedbackToJson(this);
}

/// 异常检测响应
@JsonSerializable(createFactory: false)
class TrendAnomalyDetectionResponse {
  final String type;
  final String typeName;
  final PersonalBaseline baseline;
  final List<AnomalyEvent> anomalies;
  final RecentStatsSummary recentStats;

  /// 正向激励反馈（数据平稳时生成积极鼓励信息）
  final PositiveFeedback? positiveFeedback;

  const TrendAnomalyDetectionResponse({
    required this.type,
    required this.typeName,
    required this.baseline,
    this.anomalies = const [],
    required this.recentStats,
    this.positiveFeedback,
  });

  /// 覆盖生成的 fromJson，兼容后端返回整数或字符串格式的 type 字段
  factory TrendAnomalyDetectionResponse.fromJson(Map<String, dynamic> json) =>
      TrendAnomalyDetectionResponse(
        type: json['type']?.toString() ?? '',
        typeName: json['typeName'] as String,
        baseline: PersonalBaseline.fromJson(
            json['baseline'] as Map<String, dynamic>),
        anomalies: (json['anomalies'] as List<dynamic>?)
                ?.map((e) => AnomalyEvent.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        recentStats: RecentStatsSummary.fromJson(
            json['recentStats'] as Map<String, dynamic>),
        positiveFeedback: json['positiveFeedback'] == null
            ? null
            : PositiveFeedback.fromJson(
                json['positiveFeedback'] as Map<String, dynamic>),
      );
  Map<String, dynamic> toJson() => _$TrendAnomalyDetectionResponseToJson(this);

  /// 是否有异常
  bool hasAnomalies() => anomalies.isNotEmpty;

  /// 最高严重度
  double maxSeverity() =>
      anomalies.isEmpty ? 0 : anomalies.map((a) => a.severityScore).reduce((a, b) => a > b ? a : b);
}