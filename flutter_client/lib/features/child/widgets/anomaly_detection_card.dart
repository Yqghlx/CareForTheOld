import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/date_format_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/anomaly_detection.dart';

/// AI 健康趋势异常检测卡片
///
/// 显示异常检测结果，包括严重度评估、个人基线对比、异常事件列表和正向激励
class AnomalyDetectionCard extends ConsumerWidget {
  final TrendAnomalyDetectionResponse anomaly;
  final String elderName;

  const AnomalyDetectionCard({
    super.key,
    required this.anomaly,
    required this.elderName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAnomalies = anomaly.hasAnomalies();
    final maxSeverity = anomaly.maxSeverity();

    final severityColor = _severityColor(hasAnomalies, maxSeverity);
    final severityText = _severityText(hasAnomalies, maxSeverity);
    final severityIcon = _severityIcon(hasAnomalies, maxSeverity);

    return Semantics(
      label: hasAnomalies
          ? 'AI健康趋势分析: 检测到${anomaly.anomalies.length}个异常，$severityText'
          : 'AI健康趋势分析: 健康状态良好',
      child: Card(
        elevation: AppTheme.cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.radiusL,
          side: hasAnomalies && maxSeverity >= 66
              ? BorderSide(color: severityColor.withValues(alpha: 0.5), width: 2)
              : BorderSide.none,
        ),
        child: Padding(
          padding: AppTheme.paddingAll16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleRow(severityColor, severityText, severityIcon, context),
              AppTheme.spacer16,
              _buildBaselineSection(),
              if (hasAnomalies) ...[
                AppTheme.spacer16,
                const Text('检测到的异常', style: AppTheme.textCardTitle),
                AppTheme.spacer8,
                ...anomaly.anomalies.take(3).map((event) => _buildAnomalyEventItem(event)),
              ] else ...[
                AppTheme.spacer16,
                _buildPositiveSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow(Color severityColor, String severityText, IconData severityIcon, BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: severityColor.withValues(alpha: 0.15),
            borderRadius: AppTheme.radiusS,
          ),
          child: Icon(severityIcon, color: severityColor, size: 26),
        ),
        AppTheme.hSpacer12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Flexible(
                    child: Text('AI 健康趋势分析', style: AppTheme.textTitle, overflow: TextOverflow.ellipsis),
                  ),
                  AppTheme.hSpacer8,
                  Container(
                    padding: AppTheme.paddingH8V2,
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.15),
                      borderRadius: AppTheme.radius6,
                    ),
                    child: Text(severityText, style: TextStyle(fontSize: 12, color: severityColor, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              AppTheme.spacer4,
              Text('基于 ${anomaly.baseline.baselineDays} 天数据分析', style: AppTheme.textCaption13Grey600, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        Semantics(
          label: '查看$elderName的健康趋势分析详情',
          button: true,
          child: IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: AppTheme.iconSizeSm),
            onPressed: () => _showDetailDialog(context),
            tooltip: '查看详情',
          ),
        ),
      ],
    );
  }

  Widget _buildBaselineSection() {
    return Container(
      padding: AppTheme.paddingAll12,
      decoration: AppTheme.decorationInput,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: AppTheme.iconSizeSm, color: AppTheme.grey700),
              AppTheme.hSpacer8,
              Text('个人基线', style: AppTheme.textBody.copyWith(fontWeight: FontWeight.w600, color: AppTheme.grey700)),
            ],
          ),
          AppTheme.spacer8,
          _buildBaselineRow(),
        ],
      ),
    );
  }

  Widget _buildPositiveSection() {
    if (anomaly.positiveFeedback != null) {
      return Container(
        padding: AppTheme.paddingAll14,
        decoration: BoxDecoration(
          color: AppTheme.successColor.withValues(alpha: 0.06),
          borderRadius: AppTheme.radiusS,
          border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_outlined, color: AppTheme.successColor, size: 22),
                AppTheme.hSpacer8,
                Text(anomaly.positiveFeedback!.quality, style: AppTheme.textBody16.copyWith(fontWeight: FontWeight.bold, color: AppTheme.successDark)),
                const Spacer(),
                Container(
                  padding: AppTheme.paddingH8V3,
                  decoration: BoxDecoration(color: AppTheme.successColor.withValues(alpha: 0.12), borderRadius: AppTheme.radius6),
                  child: Text('连续${anomaly.positiveFeedback!.daysStable}天平稳', style: AppTheme.textSuccess12),
                ),
              ],
            ),
            AppTheme.spacer10,
            Text(anomaly.positiveFeedback!.message, style: AppTheme.textSuccessDark14.copyWith(height: 1.4)),
            AppTheme.spacer8,
            Row(
              children: [
                const Icon(Icons.show_chart, size: 14, color: AppTheme.successMedium),
                AppTheme.hSpacer4,
                Text('变异系数: ${anomaly.positiveFeedback!.coefficientOfVariation.toStringAsFixed(1)}%', style: AppTheme.textSuccessMedium12),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: AppTheme.paddingAll12,
      decoration: BoxDecoration(color: AppTheme.successColor.withValues(alpha: 0.08), borderRadius: AppTheme.radiusS),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: AppTheme.iconSizeMd),
          AppTheme.hSpacer8,
          Expanded(child: Text('$elderName 的健康数据趋势稳定，未发现异常', style: AppTheme.textSuccessDark14)),
        ],
      ),
    );
  }

  Widget _buildBaselineRow() {
    String baselineText;
    String unit;
    IconData icon;

    switch (anomaly.type) {
      case 'BloodPressure':
        final systolic = anomaly.baseline.avgSystolic?.toStringAsFixed(0) ?? '--';
        final diastolic = anomaly.baseline.avgDiastolic?.toStringAsFixed(0) ?? '--';
        baselineText = '$systolic/$diastolic';
        unit = 'mmHg';
        icon = Icons.favorite;
      case 'BloodSugar':
        baselineText = anomaly.baseline.avgBloodSugar?.toStringAsFixed(1) ?? '--';
        unit = 'mmol/L';
        icon = Icons.water_drop;
      case 'HeartRate':
        baselineText = anomaly.baseline.avgHeartRate?.toStringAsFixed(0) ?? '--';
        unit = '次/分';
        icon = Icons.monitor_heart;
      case 'Temperature':
        baselineText = anomaly.baseline.avgTemperature?.toStringAsFixed(1) ?? '--';
        unit = '°C';
        icon = Icons.thermostat;
      default:
        baselineText = '--';
        unit = '';
        icon = Icons.analytics;
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.grey600),
        AppTheme.hSpacer8,
        Text('${anomaly.typeName}: ', style: AppTheme.textSubtitle),
        Text(baselineText, style: AppTheme.textHeading),
        AppTheme.hSpacer4,
        Text(unit, style: AppTheme.textSubtitle),
        const Spacer(),
        Text('(${anomaly.baseline.baselineRecordCount} 条记录)', style: AppTheme.textCaption),
      ],
    );
  }

  Widget _buildAnomalyEventItem(AnomalyEvent event) {
    final color = _eventColor(event.severityScore);
    final time = event.detectedAt.toLocal();
    final timeStr = time.toMonthDay();

    return Container(
      margin: AppTheme.marginBottom8,
      padding: AppTheme.paddingAll12,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppTheme.radiusS,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: AppTheme.paddingH8V4,
                decoration: BoxDecoration(color: AppTheme.grey200, borderRadius: AppTheme.radius6),
                child: Text(timeStr, style: AppTheme.textGrey700_12),
              ),
              AppTheme.hSpacer12,
              Icon(_anomalyTypeIcon(event.type), color: color, size: AppTheme.iconSizeMd),
              AppTheme.hSpacer8,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.type.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                    Text(event.description, style: AppTheme.textCaption13Grey700, maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Container(
                padding: AppTheme.paddingH8V4,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: AppTheme.radius6),
                child: Text(event.severityScore.toStringAsFixed(0), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          if (event.recommendedAction != null && event.recommendedAction!.isNotEmpty) ...[
            AppTheme.spacer8,
            Container(
              width: double.infinity,
              padding: AppTheme.paddingAll10,
              decoration: BoxDecoration(color: AppTheme.grey50, borderRadius: AppTheme.radiusXS, border: Border.all(color: AppTheme.infoBlueLight)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.infoBlue),
                  AppTheme.hSpacer8,
                  Expanded(child: Text(event.recommendedAction!, style: AppTheme.textInfoDark13)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDetailDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusXL),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.15), borderRadius: AppTheme.radius10),
              child: const Icon(Icons.analytics, color: AppTheme.primaryColor),
            ),
            AppTheme.hSpacer12,
            const Text('健康趋势详情'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: AppTheme.paddingAll12,
                decoration: AppTheme.decorationInput,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('最近7天统计', style: AppTheme.textCardTitle),
                    AppTheme.spacer8,
                    _buildRecentStatsRow('平均值', anomaly.recentStats.avg7Days),
                    _buildRecentStatsRow('最高值', anomaly.recentStats.max7Days),
                    _buildRecentStatsRow('最低值', anomaly.recentStats.min7Days),
                    _buildRecentStatsRow('波动性', anomaly.recentStats.stdDev7Days),
                    if (anomaly.recentStats.baselineDeviationPercent != null)
                      _buildRecentStatsRow('偏离基线', anomaly.recentStats.baselineDeviationPercent, isPercent: true),
                  ],
                ),
              ),
              if (anomaly.hasAnomalies()) ...[
                AppTheme.spacer16,
                const Text('异常事件时间线', style: AppTheme.textCardTitle),
                AppTheme.spacer8,
                ...anomaly.anomalies.map((event) => _buildAnomalyEventItem(event)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text(AppTheme.labelClose)),
        ],
      ),
    );
  }

  Widget _buildRecentStatsRow(String label, double? value, {bool isPercent = false}) {
    if (value == null) return const SizedBox.shrink();
    final displayValue = isPercent ? '${value > 0 ? "+" : ""}${value.toStringAsFixed(1)}%' : value.toStringAsFixed(1);

    return Padding(
      padding: AppTheme.paddingV4,
      child: Row(
        children: [
          Text('$label: ', style: AppTheme.textSubtitle),
          Text(displayValue, style: AppTheme.textCardTitle),
        ],
      ),
    );
  }

  // ===== 辅助方法 =====

  Color _severityColor(bool hasAnomalies, double maxSeverity) {
    if (!hasAnomalies) return AppTheme.successColor;
    if (maxSeverity < 33) return AppTheme.warningColor;
    if (maxSeverity < 66) return AppTheme.grey800;
    return AppTheme.errorDark;
  }

  String _severityText(bool hasAnomalies, double maxSeverity) {
    if (!hasAnomalies) return '健康状态良好';
    if (maxSeverity < 33) return '轻度关注';
    if (maxSeverity < 66) return '需要关注';
    return '需要重视';
  }

  IconData _severityIcon(bool hasAnomalies, double maxSeverity) {
    if (!hasAnomalies) return Icons.check_circle;
    if (maxSeverity < 33) return Icons.info_outline;
    if (maxSeverity < 66) return Icons.warning_amber;
    return Icons.error_outline;
  }

  Color _eventColor(double severityScore) {
    if (severityScore < 33) return AppTheme.warningColor;
    if (severityScore < 66) return AppTheme.grey800;
    return AppTheme.errorDark;
  }

  IconData _anomalyTypeIcon(AnomalyType type) {
    return switch (type) {
      AnomalyType.spike => Icons.arrow_upward,
      AnomalyType.continuousHigh => Icons.trending_up,
      AnomalyType.continuousLow => Icons.trending_down,
      AnomalyType.acceleration => Icons.speed,
      AnomalyType.volatility => Icons.show_chart,
    };
  }
}
