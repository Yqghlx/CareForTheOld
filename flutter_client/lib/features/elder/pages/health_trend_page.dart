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
          title: const Text('健康趋势'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.invalidate(filteredHealthRecordsProvider(_selectedType)),
              tooltip: '刷新',
            ),
            // 导出报告按钮
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => _showExportDialog(context),
              tooltip: '导出报告',
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
              const SizedBox(height: 20),

              // 时间范围切换
              _buildRangeSelector(),
              const SizedBox(height: 20),

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
                  const SizedBox(width: 12),
                  Text(
                    '${_selectedType.label}趋势',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 图表区域
              Expanded(
                child: recordsAsync.when(
                  data: (records) {
                    if (records.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_selectedType.icon, size: 64, color: AppTheme.grey400),
                            const SizedBox(height: 16),
                            Text(
                              '暂无${_selectedType.label}记录',
                              style: AppTheme.textSecondary16,
                            ),
                            const SizedBox(height: 8),
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
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
                        const SizedBox(height: 12),
                        const Text('加载失败，请重试', style: TextStyle(color: AppTheme.errorColor)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(filteredHealthRecordsProvider(_selectedType)),
                          child: const Text('重试'),
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
      decoration: BoxDecoration(
        color: AppTheme.grey100,
        borderRadius: AppTheme.radiusL,
      ),
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
                  color: isSelected ? type.color : Colors.transparent,
                  borderRadius: isSelected ? AppTheme.radiusL : BorderRadius.zero,
                ),
                child: Column(
                  children: [
                    Icon(
                      type.icon,
                      color: isSelected ? Colors.white : AppTheme.grey500,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 16,
                          color: isSelected ? Colors.white : AppTheme.grey700,
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
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              _buildRangeButton('最近7天', 7),
              const SizedBox(width: 12),
              _buildRangeButton('最近30天', 30),
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
              color: isSelected ? Colors.white : AppTheme.grey700,
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
            const SizedBox(width: 12),
            const Text('导出健康报告'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('选择报告时间范围：'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      _exportReport(context, 7);
                    },
                    style: AppTheme.elevatedPrimaryStyle,
                    child: const Text('最近7天', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      _exportReport(context, 30);
                    },
                    style: AppTheme.elevatedPrimaryStyle,
                    child: const Text('最近30天', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
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