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
import '../../../shared/widgets/common_cards.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/services/health_report_service.dart';

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

/// 老人用药记录 Provider（支持日期筛选）
final elderMedicationLogsProvider =
    FutureProvider.family<List<MedicationLog>, ({String elderId, String? date})>((ref, args) async {
  final service = MedicationService(ref.read(apiClientProvider).dio);
  return service.getElderLogs(args.elderId, limit: 10, date: args.date);
});

/// 子女查看老人健康数据页面
class ElderHealthPage extends ConsumerStatefulWidget {
  final String elderId;

  const ElderHealthPage({super.key, required this.elderId});

  @override
  ConsumerState<ElderHealthPage> createState() => _ElderHealthPageState();
}

class _ElderHealthPageState extends ConsumerState<ElderHealthPage> {
  String? _selectedLogDate; // 用药记录日期筛选

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
        ref.watch(elderMedicationLogsProvider((elderId: widget.elderId, date: _selectedLogDate)));

    return Scaffold(
      appBar: AppBar(
        title: Text('$elderName - 健康数据'),
        actions: [
          // 导出报告按钮
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _showExportDialog(context, elderName),
            tooltip: '导出报告',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(elderHealthStatsProvider(widget.elderId));
          ref.invalidate(elderHealthRecordsProvider(widget.elderId));
          ref.invalidate(elderMedicationPlansProvider(widget.elderId));
          ref.invalidate(elderMedicationLogsProvider((elderId: widget.elderId, date: _selectedLogDate)));
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
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('加载统计失败: $e',
                      style: const TextStyle(color: AppTheme.errorColor)),
                ),
              ),
              const SizedBox(height: 24),

              // 最近健康记录
              const Text(
                '最近健康记录',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              recordsAsync.when(
                data: (records) => _buildRecordsList(records),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('加载记录失败: $e',
                    style: const TextStyle(color: AppTheme.errorColor)),
              ),
              const SizedBox(height: 24),

              // 用药计划
              const Text(
                '用药计划',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              plansAsync.when(
                data: (plans) => _buildPlansList(plans),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('加载计划失败: $e',
                    style: const TextStyle(color: AppTheme.errorColor)),
              ),
              const SizedBox(height: 24),

              // 最近用药记录（带日期筛选）
              Row(
                children: [
                  const Text(
                    '最近用药记录',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedLogDate != null
                            ? DateTime.parse(_selectedLogDate!)
                            : DateTime.now(),
                        firstDate: DateTime(2024, 1, 1),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedLogDate = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _selectedLogDate ?? '全部日期',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  if (_selectedLogDate != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _selectedLogDate = null),
                      tooltip: '清除日期筛选',
                    ),
                ],
              ),
              const SizedBox(height: 12),
              logsAsync.when(
                data: (logs) => _buildMedicationList(logs),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('加载用药记录失败: $e',
                    style: const TextStyle(color: AppTheme.errorColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 健康统计概览 - 使用 StatCard
  Widget _buildStatsGrid(List<HealthStats> stats) {
    if (stats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('暂无健康统计数据', style: TextStyle(color: Colors.grey)),
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
      childAspectRatio: 0.85,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        StatCard(
          icon: Icons.favorite,
          title: '血压',
          value: _getStatsValue(typeMap, '血压'),
          subtitle: _getStatsSubtitle(typeMap, '血压'),
          color: Colors.red,
        ),
        StatCard(
          icon: Icons.water_drop,
          title: '血糖',
          value: _getStatsValue(typeMap, '血糖'),
          subtitle: _getStatsSubtitle(typeMap, '血糖'),
          color: Colors.blue,
        ),
        StatCard(
          icon: Icons.monitor_heart,
          title: '心率',
          value: _getStatsValue(typeMap, '心率'),
          subtitle: _getStatsSubtitle(typeMap, '心率'),
          color: Colors.purple,
        ),
        StatCard(
          icon: Icons.thermostat,
          title: '体温',
          value: _getStatsValue(typeMap, '体温'),
          subtitle: _getStatsSubtitle(typeMap, '体温'),
          color: Colors.orange,
        ),
      ],
    );
  }

  String _getStatsValue(Map<String, HealthStats> map, String typeName) {
    final stat = map[typeName];
    if (stat == null || stat.latestValue == null) return '--';
    final unit = _getUnit(typeName);
    return '${stat.latestValue!.toStringAsFixed(1)} $unit';
  }

  /// 获取统计副标题（30天均值+记录数）
  String _getStatsSubtitle(Map<String, HealthStats> map, String typeName) {
    final stat = map[typeName];
    if (stat == null) return '';
    final avg30 = stat.average30Days?.toStringAsFixed(1) ?? '--';
    return '30天均值: $avg30 | ${stat.totalCount}条';
  }

  String _getUnit(String typeName) {
    return switch (typeName) {
      '血压' => 'mmHg',
      '血糖' => 'mmol/L',
      '心率' => '次/分',
      '体温' => '°C',
      _ => '',
    };
  }

  /// 用药计划列表
  Widget _buildPlansList(List<MedicationPlan> plans) {
    if (plans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('暂无用药计划', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(
      children: plans.map((plan) {
        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: plan.isActive
                ? BorderSide.none
                : BorderSide(color: Colors.grey.shade300, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: (plan.isActive ? Colors.blue : Colors.grey)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.medication,
                        color: plan.isActive ? Colors.blue : Colors.grey,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.medicineName,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: plan.isActive ? null : Colors.grey,
                            ),
                          ),
                          Text(
                            '剂量: ${plan.dosage}',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    // 启用/停用开关
                    Switch(
                      value: plan.isActive,
                      activeThumbColor: Colors.green,
                      onChanged: (value) => _togglePlan(plan, value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '频率: ${plan.frequency.label}',
                        style: TextStyle(
                          fontSize: 14,
                          color: plan.isActive ? null : Colors.grey,
                        ),
                      ),
                      Text(
                        '提醒时间: ${plan.reminderTimesText}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // 操作按钮行
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showEditPlanDialog(plan),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('编辑'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                      ),
                      if (!plan.isActive) ...[
                        TextButton.icon(
                          onPressed: () => _deletePlan(plan),
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                          label: const Text('删除', style: TextStyle(color: Colors.red)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!plan.isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _deletePlan(plan),
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        label: const Text('删除计划', style: TextStyle(color: Colors.red)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 编辑用药计划对话框
  Future<void> _showEditPlanDialog(MedicationPlan plan) async {
    final nameController = TextEditingController(text: plan.medicineName);
    final dosageController = TextEditingController(text: plan.dosage);
    Frequency selectedFrequency = plan.frequency;
    List<String> reminderTimes = List.from(plan.reminderTimes);
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.edit, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              const Text('编辑用药计划'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '药品名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dosageController,
                  decoration: const InputDecoration(
                    labelText: '剂量（如：1片、10ml）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Frequency>(
                  // ignore: deprecated_member_use - StatefulBuilder 中动态更新需要 value，initialValue 仅用于初始设置
                  value: selectedFrequency,
                  decoration: const InputDecoration(
                    labelText: '用药频率',
                    border: OutlineInputBorder(),
                  ),
                  items: Frequency.values.map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(f.label),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedFrequency = v!),
                ),
                const SizedBox(height: 12),
                // 提醒时间
                Wrap(
                  spacing: 8,
                  children: [
                    ...reminderTimes.asMap().entries.map((entry) => Chip(
                      label: Text(entry.value),
                      onDeleted: () => setDialogState(() => reminderTimes.removeAt(entry.key)),
                    )),
                    ActionChip(
                      label: const Text('+ 添加时间'),
                      onPressed: () async {
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                          setDialogState(() => reminderTimes.add(timeStr));
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: isSubmitting ? null : () async {
                if (nameController.text.trim().isEmpty || dosageController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请填写药品名称和剂量'), backgroundColor: AppTheme.warningColor),
                  );
                  return;
                }
                setDialogState(() => isSubmitting = true);
                try {
                  final service = MedicationService(ref.read(apiClientProvider).dio);
                  await service.updatePlan(
                    planId: plan.id,
                    medicineName: nameController.text.trim(),
                    dosage: dosageController.text.trim(),
                    frequency: selectedFrequency.value,
                    reminderTimes: reminderTimes,
                  );
                  ref.invalidate(elderMedicationPlansProvider(widget.elderId));
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('用药计划已更新'), backgroundColor: AppTheme.successColor),
                    );
                  }
                } catch (e) {
                  setDialogState(() => isSubmitting = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('更新失败: $e'), backgroundColor: AppTheme.errorColor),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
              child: const Text('保存', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  /// 切换用药计划启用/停用状态
  Future<void> _togglePlan(MedicationPlan plan, bool active) async {
    try {
      final service = MedicationService(ref.read(apiClientProvider).dio);
      await service.updatePlan(planId: plan.id, isActive: active);
      // 刷新计划列表
      ref.invalidate(elderMedicationPlansProvider(widget.elderId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(active ? '已启用 ${plan.medicineName} 的用药提醒' : '已停用 ${plan.medicineName} 的用药提醒'),
            backgroundColor: active ? AppTheme.successColor : Colors.grey.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('操作失败: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// 删除用药计划
  Future<void> _deletePlan(MedicationPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认删除'),
        content: Text('确定删除 ${plan.medicineName} 的用药计划吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final service = MedicationService(ref.read(apiClientProvider).dio);
      await service.deletePlan(plan.id);
      ref.invalidate(elderMedicationPlansProvider(widget.elderId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除 ${plan.medicineName} 的用药计划'),
            backgroundColor: Colors.grey.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  /// 健康记录列表
  Widget _buildRecordsList(List<HealthRecord> records) {
    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('暂无健康记录', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final time = record.recordedAt.toLocal();
        final timeStr =
            '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: record.type.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(record.type.icon, color: record.type.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${record.type.label}: ${record.displayValue} ${record.type.unit}',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 用药记录列表
  Widget _buildMedicationList(List<MedicationLog> logs) {
    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('暂无用药记录', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(
      children: logs.map((log) {
        final scheduledTime = log.scheduledAt.toLocal();
        final scheduledStr =
            '${scheduledTime.month}/${scheduledTime.day} ${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';

        // 计算实际服药时间
        String? takenStr;
        String? delayInfo;
        if (log.takenAt != null) {
          final takenTime = log.takenAt!.toLocal();
          takenStr =
              '${takenTime.hour.toString().padLeft(2, '0')}:${takenTime.minute.toString().padLeft(2, '0')}';
          // 计算延迟（超过30分钟视为延迟服药）
          final delay = log.takenAt!.difference(log.scheduledAt);
          if (delay.inMinutes > 30) {
            delayInfo = '延迟${delay.inHours > 0 ? '${delay.inHours}小时' : ''}${delay.inMinutes % 60}分钟';
          }
        }

        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // 状态图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: log.status.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    log.status == MedicationStatus.taken
                        ? Icons.check_circle
                        : log.status == MedicationStatus.skipped
                            ? Icons.skip_next
                            : Icons.alarm,
                    color: log.status.color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // 药品信息 + 时间
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.medicineName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '计划: $scheduledStr',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                      if (takenStr != null)
                        Text(
                          '实际: $takenStr',
                          style: TextStyle(
                            fontSize: 13,
                            color: delayInfo != null
                                ? Colors.orange.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                      if (delayInfo != null)
                        Text(
                          delayInfo,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (log.note != null && log.note!.isNotEmpty)
                        Text(
                          '备注: ${log.note}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                // 状态标签
                StatusChip(
                  label: log.status.label,
                  color: log.status.color,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 显示导出报告对话框
  void _showExportDialog(BuildContext context, String elderName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.picture_as_pdf, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Text('导出健康报告'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('为 $elderName 导出健康报告'),
            const SizedBox(height: 16),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
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
    final familyId = ref.read(familyProvider).familyId;
    if (familyId == null) return;

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('正在生成报告...', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final service = ref.read(healthReportServiceProvider);
    final success = await service.downloadAndShareReport(
      days: days,
      elderId: widget.elderId,
      familyId: familyId,
    );

    // 关闭加载对话框
    if (mounted && context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '报告已生成，请选择分享方式' : '导出失败，请稍后重试'),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }
}