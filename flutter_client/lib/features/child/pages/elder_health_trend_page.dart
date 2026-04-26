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
        padding: const EdgeInsets.all(20),
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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_selectedType.icon, color: _selectedType.color),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_selectedType.label}趋势',
                  style: const TextStyle(
                    fontSize: 20,
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
                          Icon(_selectedType.icon,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            '暂无${_selectedType.label}记录',
                            style: const TextStyle(
                                fontSize: 18, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.elderName}录入数据后即可查看趋势',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey.shade500),
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
                      Icon(Icons.error_outline,
                          size: 48, color: AppTheme.errorColor),
                      const SizedBox(height: 12),
                      const Text('加载失败，请重试',
                          style: TextStyle(color: AppTheme.errorColor)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(
                          elderFilteredRecordsProvider(
                            (elderId: widget.elderId, type: _selectedType),
                          ),
                        ),
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
    );
  }

  /// 健康类型选择器
  Widget _buildTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
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
                  borderRadius: BorderRadius.circular(isSelected ? 16 : 0),
                ),
                child: Column(
                  children: [
                    Icon(
                      type.icon,
                      color: isSelected ? Colors.white : Colors.grey,
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
                              ? Colors.white
                              : Colors.grey.shade700,
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
          style: TextStyle(fontSize: 16),
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
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
