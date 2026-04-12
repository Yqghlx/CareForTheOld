/// 健康统计数据模型（对应后端 HealthStatsResponse）
class HealthStats {
  /// 健康数据类型名称
  final String typeName;

  /// 最近7天平均值
  final double? average7Days;

  /// 最近30天平均值
  final double? average30Days;

  /// 最近记录值
  final double? latestValue;

  /// 最近记录时间
  final DateTime? latestRecordedAt;

  /// 记录总数
  final int totalCount;

  const HealthStats({
    required this.typeName,
    this.average7Days,
    this.average30Days,
    this.latestValue,
    this.latestRecordedAt,
    required this.totalCount,
  });

  factory HealthStats.fromJson(Map<String, dynamic> json) {
    return HealthStats(
      typeName: json['typeName'] as String,
      // 后端 decimal 类型 → Dart double
      average7Days: (json['average7Days'] as num?)?.toDouble(),
      average30Days: (json['average30Days'] as num?)?.toDouble(),
      latestValue: (json['latestValue'] as num?)?.toDouble(),
      latestRecordedAt: json['latestRecordedAt'] != null
          ? DateTime.parse(json['latestRecordedAt'] as String)
          : null,
      totalCount: json['totalCount'] as int,
    );
  }
}
