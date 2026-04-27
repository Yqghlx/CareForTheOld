import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/health_record.dart';
import '../providers/health_provider.dart';
import '../../../shared/widgets/health_trend_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/extensions/snackbar_extension.dart';
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
        body: Padding(
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
                  Text(
                    '${_selectedType.label}趋势',
                    style: AppTheme.textSectionTitle,
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
                              '暂无${_selectedType.label}记录',
                              style: AppTheme.textSecondary16,
                            ),
                            AppTheme.spacer8,
                            Text(
                              '请先在健康页面记录${_selectedType.label}数据',
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
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: AppTheme.iconSizeXxl, color: AppTheme.errorColor),
                        AppTheme.spacer12,
                        Text(AppTheme.msgLoadFailed, style: AppTheme.textError),
                        AppTheme.spacer12,
                        ElevatedButton(
                          onPressed: () => ref.invalidate(filteredHealthRecordsProvider(_selectedType)),
                          child: const Text(AppTheme.msgRetry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
                padding: const EdgeInsets.symmetric(vertical: 12),
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
          '时间范围：',
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
          padding: const EdgeInsets.symmetric(vertical: 10),
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
    final service = ref.read(healthReportServiceProvider);
    final success = await service.downloadAndShareReport(days: days);

    if (mounted && context.mounted) {
      if (success) {
        context.showSuccessSnackBar(AppTheme.msgReportGenerated);
      } else {
        context.showErrorSnackBar(AppTheme.msgOperationFailed);
      }
    }
  }
}