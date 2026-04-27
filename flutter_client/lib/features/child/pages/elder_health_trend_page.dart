import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/health_record.dart';
import '../../elder/services/health_service.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/widgets/health_trend_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/family_provider.dart';

/// 子女端查看老人健康趋势的 Provider（按 elderId + type）
final elderFilteredRecordsProvider = FutureProvider.family<List<HealthRecord>,
    ({String elderId, HealthType type})>((ref, args) async {
  final familyId = ref.watch(familyProvider.select((s) => s.familyId));
  if (familyId == null) return [];
  final service = HealthService(ref.read(apiClientProvider).dio);
  return service.getFamilyMemberRecords(
    familyId: familyId,
    memberId: args.elderId,
    type: args.type,
    limit: 30,
  );
});

/// 子女端 — 老人健康趋势页面
class ElderHealthTrendPage extends ConsumerStatefulWidget {
  final String elderId;
  final String elderName;

  const ElderHealthTrendPage({
    super.key,
    required this.elderId,
    required this.elderName,
  });

  @override
  ConsumerState<ElderHealthTrendPage> createState() =>
      _ElderHealthTrendPageState();
}

class _ElderHealthTrendPageState extends ConsumerState<ElderHealthTrendPage> {
  HealthType _selectedType = HealthType.bloodPressure;
  int _daysRange = 7;

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(
      elderFilteredRecordsProvider(
        (elderId: widget.elderId, type: _selectedType),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.elderName}的健康趋势'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(
              elderFilteredRecordsProvider(
                (elderId: widget.elderId, type: _selectedType),
              ),
            ),
            tooltip: '刷新',
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
                  style: AppTheme.textLargeTitle,
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
                          Icon(_selectedType.icon,
                              size: 64, color: AppTheme.grey400),
                          AppTheme.spacer16,
                          Text(
                            '暂无${_selectedType.label}记录',
                            style: const TextStyle(
                                fontSize: 18, color: AppTheme.grey500),
                          ),
                          AppTheme.spacer8,
                          Text(
                            '${widget.elderName}录入数据后即可查看趋势',
                            style: TextStyle(
                                fontSize: 16, color: AppTheme.grey500),
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
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppTheme.errorColor),
                      AppTheme.spacer12,
                      const Text('加载失败，请重试',
                          style: AppTheme.textError),
                      AppTheme.spacer12,
                      ElevatedButton(
                        onPressed: () => ref.invalidate(
                          elderFilteredRecordsProvider(
                            (elderId: widget.elderId, type: _selectedType),
                          ),
                        ),
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
                      color: isSelected ? AppTheme.cardColor : AppTheme.grey500,
                      size: 20,
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        type.label,
                        style: TextStyle(
                          fontSize: 14,
                          color: isSelected
                              ? AppTheme.cardColor
                              : AppTheme.grey700,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
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
              _buildRangeButton('最近7天', 7),
              AppTheme.hSpacer12,
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
              color: isSelected ? AppTheme.cardColor : AppTheme.grey700,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
