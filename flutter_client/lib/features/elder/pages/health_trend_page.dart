import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/health_record.dart';
import '../providers/health_provider.dart';
import '../../../shared/widgets/health_trend_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/extensions/api_error_extension.dart';
import '../../../core/extensions/snackbar_extension.dart';
import '../../../shared/widgets/common_states.dart';
import '../../shared/services/health_report_service.dart';

/// 按类型过滤的健康记录 Provider（用于趋势页面）
final filteredHealthRecordsProvider =
    FutureProvider.family<List<HealthRecord>, HealthType>((ref, type) async {
  final service = ref.watch(healthServiceProvider);
  return service.getMyRecords(type: type, limit: 30);
});

/// 健康趋势页面
class HealthTrendPage extends ConsumerStatefulWidget {
  const HealthTrendPage({super.key});

  @override
  ConsumerState<HealthTrendPage> createState() => _HealthTrendPageState();
}

class _HealthTrendPageState extends ConsumerState<HealthTrendPage> {
  HealthType _selectedType = HealthType.bloodPressure;
  int _daysRange = 7; // 7天或30天

  @override
  Widget build(BuildContext context) {
    // 老人端使用大字体主题
    final theme = Theme.of(context).copyWith(
      textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: 1.2),
    );

    final recordsAsync = ref.watch(filteredHealthRecordsProvider(_selectedType));

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppTheme.msgHealthTrends),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(filteredHealthRecordsProvider(_selectedType)),
              tooltip: AppTheme.tooltipRefresh,
            ),
            // 导出报告按钮
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => _showExportDialog(context),
              tooltip: AppTheme.tooltipExportReport,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(filteredHealthRecordsProvider(_selectedType));
            ref.invalidate(healthStatsProvider);
          },
          child: Padding(
            padding: AppTheme.paddingAll20,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 健康类型切换
              _buildTypeSelector(),
              AppTheme.spacer20,

              // 时间范围切换
              _buildRangeSelector(),
              AppTheme.spacer20,

              // 图表标题
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _selectedType.color.withValues(alpha: 0.15),
                      borderRadius: AppTheme.radius10,
                    ),
                    child: Icon(_selectedType.icon, color: _selectedType.color),
                  ),
                  AppTheme.hSpacer12,
                  Flexible(
                    child: Text(
                      AppTheme.labelHealthTrend(_selectedType.label),
                      style: AppTheme.textSectionTitle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              AppTheme.spacer16,

              // 图表区域
              Expanded(
                child: recordsAsync.when(
                  data: (records) {
                    if (records.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_selectedType.icon, size: AppTheme.iconSizeHuge, color: AppTheme.grey400),
                            AppTheme.spacer16,
                            Text(
                              AppTheme.msgNoHealthRecord(_selectedType.label),
                              style: AppTheme.textSecondary16,
                            ),
                            AppTheme.spacer8,
                            Text(
                              AppTheme.msgRecordHealthFirst(_selectedType.label),
                              style: AppTheme.textGreyLight,
                            ),
                          ],
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: HealthTrendChart(
                        type: _selectedType,
                        records: records,
                        daysRange: _daysRange,
                      ),
                    );
                  },
                  loading: () => Column(
                    children: [
                      _buildTypeSelectorSkeleton(),
                      AppTheme.spacer20,
                      const Expanded(child: SkeletonCard()),
                    ],
                  ),
                  error: (e, _) => ErrorStateWidget(
                    message: AppTheme.msgLoadFailed,
                    onRetry: () => ref.invalidate(filteredHealthRecordsProvider(_selectedType)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  /// 健康类型选择器
  Widget _buildTypeSelector() {
    return Container(
      decoration: AppTheme.decorationCardLight,
      child: Row(
        children: HealthType.values.map((type) {
          final isSelected = type == _selectedType;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (type != _selectedType) {
                  setState(() => _selectedType = type);
                }
              },
              child: Container(
                padding: AppTheme.paddingV12,
                decoration: BoxDecoration(
                  color: isSelected ? type.color : AppTheme.transparentColor,
                  borderRadius: isSelected ? AppTheme.radiusL : AppTheme.radiusZero,
                ),
                child: Column(
                  children: [
                    Icon(
                      type.icon,
                      color: isSelected ? AppTheme.cardColor : AppTheme.grey500,
                      size: AppTheme.iconSizeMd,
                    ),
                    AppTheme.spacer2,
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 16,
                          color: isSelected ? AppTheme.cardColor : AppTheme.grey700,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 时间范围选择器
  Widget _buildRangeSelector() {
    return Row(
      children: [
        const Text(
          AppTheme.labelTimeRange,
          style: AppTheme.textBody16,
        ),
        AppTheme.hSpacer12,
        Expanded(
          child: Row(
            children: [
              _buildRangeButton(AppTheme.labelRecent7Days, 7),
              AppTheme.hSpacer12,
              _buildRangeButton(AppTheme.labelRecent30Days, 30),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRangeButton(String label, int days) {
    final isSelected = days == _daysRange;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (days != _daysRange) {
            setState(() => _daysRange = days);
          }
        },
        child: Container(
          padding: AppTheme.paddingV10,
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryColor : AppTheme.grey200,
            borderRadius: AppTheme.radiusS,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppTheme.cardColor : AppTheme.grey700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  /// 显示导出报告对话框
  void _showExportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.radiusXL,
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.infoBlue.withValues(alpha: 0.15),
                borderRadius: AppTheme.radius10,
              ),
              child: const Icon(Icons.picture_as_pdf, color: AppTheme.infoBlue),
            ),
            AppTheme.hSpacer12,
            const Text(AppTheme.msgExportReport),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(AppTheme.msgSelectDateRange),
            AppTheme.spacer16,
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      _exportReport(context, 7);
                    },
                    style: AppTheme.elevatedPrimaryStyle,
                    child: Text(AppTheme.labelRecent7Days, style: AppTheme.textWhite),
                  ),
                ),
                AppTheme.hSpacer16,
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      _exportReport(context, 30);
                    },
                    style: AppTheme.elevatedPrimaryStyle,
                    child: Text(AppTheme.labelRecent30Days, style: AppTheme.textWhite),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppTheme.msgCancel),
          ),
        ],
      ),
    );
  }

  /// 导出报告
  Future<void> _exportReport(BuildContext context, int days) async {
    try {
      final service = ref.read(healthReportServiceProvider);
      final success = await service.downloadAndShareReport(days: days);

      if (mounted && context.mounted) {
        if (success) {
          context.showSuccessSnackBar(AppTheme.msgReportGenerated);
        } else {
          context.showErrorSnackBar(AppTheme.msgOperationFailed);
        }
      }
    } catch (e) {
      if (mounted && context.mounted) {
        context.showErrorSnackBar(errorMessageFrom(e, fallback: AppTheme.msgOperationFailed));
      }
    }
  }

  /// 类型选择器骨架屏
  Widget _buildTypeSelectorSkeleton() {
    return const SkeletonLoader(
      child: Row(
        children: [
          Expanded(child: SizedBox(height: 56, child: DecoratedBox(decoration: BoxDecoration(color: AppTheme.grey300, borderRadius: AppTheme.radiusL)))),
          Expanded(child: SizedBox(height: 56, child: DecoratedBox(decoration: BoxDecoration(color: AppTheme.grey300, borderRadius: AppTheme.radiusL)))),
          Expanded(child: SizedBox(height: 56, child: DecoratedBox(decoration: BoxDecoration(color: AppTheme.grey300, borderRadius: AppTheme.radiusL)))),
          Expanded(child: SizedBox(height: 56, child: DecoratedBox(decoration: BoxDecoration(color: AppTheme.grey300, borderRadius: AppTheme.radiusL)))),
        ],
      ),
    );
  }
}