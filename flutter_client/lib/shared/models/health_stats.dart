import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

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

  /// 趋势方向："rising"、"falling"、"stable"、null（数据不足）
  final String? trend;

  /// 趋势预警提示文字
  final String? trendWarning;

  const HealthStats({
    required this.typeName,
    this.average7Days,
    this.average30Days,
    this.latestValue,
    this.latestRecordedAt,
    required this.totalCount,
    this.trend,
    this.trendWarning,
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
      trend: json['trend'] as String?,
      trendWarning: json['trendWarning'] as String?,
    );
  }

  /// 是否有趋势预警
  bool get hasWarning => trend != null && trend != 'stable' && trendWarning != null;

  /// 趋势图标
  IconData get trendIcon {
    switch (trend) {
      case 'rising': return Icons.trending_up;
      case 'falling': return Icons.trending_down;
      case 'stable': return Icons.trending_flat;
      default: return Icons.trending_flat;
    }
  }

  /// 趋势颜色
  Color get trendColor {
    switch (trend) {
      case 'rising': return AppTheme.warningColor;
      case 'falling': return AppTheme.infoBlue;
      case 'stable': return AppTheme.successColor;
      default: return AppTheme.grey500;
    }
  }
}
