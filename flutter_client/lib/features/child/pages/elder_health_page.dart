import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/health_record.dart';
import '../../../shared/models/health_stats.dart';
import '../../../shared/models/medication_plan.dart';
import '../../../shared/models/medication_log.dart';
import '../../elder/services/health_service.dart';
import '../../elder/services/medication_service.dart';
import '../../../core/api/api_client.dart';
import '../providers/family_provider.dart';

/// 老人健康数据 Provider（按 elderId 区分）
final elderHealthStatsProvider =
    FutureProvider.family<List<HealthStats>, String>((ref, elderId) async {
  final familyId = ref.watch(familyProvider).familyId;
  if (familyId == null) return [];
  final service = HealthService(ref.read(apiClientProvider).dio);
  return service.getFamilyMemberStats(
      familyId: familyId, memberId: elderId);
});

final elderHealthRecordsProvider =
    FutureProvider.family<List<HealthRecord>, String>((ref, elderId) async {
  final familyId = ref.watch(familyProvider).familyId;
  if (familyId == null) return [];
  final service = HealthService(ref.read(apiClientProvider).dio);
  return service.getFamilyMemberRecords(
      familyId: familyId, memberId: elderId, limit: 20);
});

/// 老人用药计划 Provider
final elderMedicationPlansProvider =
    FutureProvider.family<List<MedicationPlan>, String>((ref, elderId) async {
  final service = MedicationService(ref.read(apiClientProvider).dio);
  return service.getElderPlans(elderId);
});

/// 老人用药记录 Provider
final elderMedicationLogsProvider =
    FutureProvider.family<List<MedicationLog>, String>((ref, elderId) async {
  final service = MedicationService(ref.read(apiClientProvider).dio);
  return service.getElderLogs(elderId, limit: 10);
});

/// 子女查看老人健康数据页面
class ElderHealthPage extends ConsumerStatefulWidget {
  final String elderId;

  const ElderHealthPage({super.key, required this.elderId});

  @override
  ConsumerState<ElderHealthPage> createState() => _ElderHealthPageState();
}

class _ElderHealthPageState extends ConsumerState<ElderHealthPage> {
  @override
  Widget build(BuildContext context) {
    final familyState = ref.watch(familyProvider);
    final elder = familyState.members
        .where((m) => m.userId == widget.elderId)
        .firstOrNull;
    final elderName = elder?.realName ?? '老人';

    final statsAsync =
        ref.watch(elderHealthStatsProvider(widget.elderId));
    final recordsAsync =
        ref.watch(elderHealthRecordsProvider(widget.elderId));
    final plansAsync =
        ref.watch(elderMedicationPlansProvider(widget.elderId));
    final logsAsync =
        ref.watch(elderMedicationLogsProvider(widget.elderId));

    return Scaffold(
      appBar: AppBar(title: Text('$elderName - 健康数据')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(elderHealthStatsProvider(widget.elderId));
          ref.invalidate(elderHealthRecordsProvider(widget.elderId));
          ref.invalidate(elderMedicationPlansProvider(widget.elderId));
          ref.invalidate(elderMedicationLogsProvider(widget.elderId));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 健康概览卡片
              statsAsync.when(
                data: (stats) => _buildStatsGrid(stats),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('加载统计失败: $e',
                    style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 24),

              // 最近健康记录
              const Text('最近健康记录',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              recordsAsync.when(
                data: (records) => _buildRecordsList(records),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('加载记录失败: $e',
                    style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 24),

              // 用药计划
              const Text('用药计划',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              plansAsync.when(
                data: (plans) => _buildPlansList(plans),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('加载计划失败: $e',
                    style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 24),

              // 最近用药记录
              const Text('最近用药记录',
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              logsAsync.when(
                data: (logs) => _buildMedicationList(logs),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('加载用药记录失败: $e',
                    style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 健康统计概览
  Widget _buildStatsGrid(List<HealthStats> stats) {
    if (stats.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('暂无健康统计数据')),
        ),
      );
    }

    // 将统计按类型映射
    final typeMap = <String, HealthStats>{};
    for (final s in stats) {
      typeMap[s.typeName] = s;
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          icon: Icons.favorite,
          title: '血压',
          value: _getStatsValue(typeMap, '血压'),
          color: Colors.red,
        ),
        _buildStatCard(
          icon: Icons.water_drop,
          title: '血糖',
          value: _getStatsValue(typeMap, '血糖'),
          color: Colors.blue,
        ),
        _buildStatCard(
          icon: Icons.monitor_heart,
          title: '心率',
          value: _getStatsValue(typeMap, '心率'),
          color: Colors.purple,
        ),
        _buildStatCard(
          icon: Icons.thermostat,
          title: '体温',
          value: _getStatsValue(typeMap, '体温'),
          color: Colors.orange,
        ),
      ],
    );
  }

  String _getStatsValue(Map<String, HealthStats> map, String typeName) {
    final stat = map[typeName];
    if (stat == null || stat.latestValue == null) return '--';
    return stat.latestValue!.toStringAsFixed(1);
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  /// 用药计划列表
  Widget _buildPlansList(List<MedicationPlan> plans) {
    if (plans.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('暂无用药计划')),
        ),
      );
    }

    return Column(
      children: plans.map((plan) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.medication, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.medicineName,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '剂量: ${plan.dosage}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: plan.isActive
                            ? Colors.green.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        plan.isActive ? '启用' : '停用',
                        style: TextStyle(
                            color: plan.isActive ? Colors.green : Colors.grey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '频率: ${plan.frequency.label}',
                  style: const TextStyle(fontSize: 14),
                ),
                Text(
                  '提醒时间: ${plan.reminderTimesText}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 健康记录列表
  Widget _buildRecordsList(List<HealthRecord> records) {
    if (records.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('暂无健康记录')),
        ),
      );
    }

    return Column(
      children: records.map((record) {
        final time = record.recordedAt.toLocal();
        final timeStr =
            '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        return Card(
          child: ListTile(
            leading:
                Icon(record.type.icon, color: record.type.color, size: 28),
            title: Text(
              '${record.type.label}: ${record.displayValue} ${record.type.unit}',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(timeStr),
          ),
        );
      }).toList(),
    );
  }

  /// 用药记录列表
  Widget _buildMedicationList(List<MedicationLog> logs) {
    if (logs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('暂无用药记录')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: logs.map((log) {
            final isLast = log == logs.last;
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(log.medicineName),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: log.status.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(log.status.label,
                          style: TextStyle(color: log.status.color)),
                    ),
                  ],
                ),
                if (!isLast) const Divider(),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
