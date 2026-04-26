import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_paths.dart';
import '../../../core/extensions/snackbar_extension.dart';
import '../../../core/extensions/date_format_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/health_record.dart';
import '../../../shared/models/health_stats.dart';
import '../../../shared/models/medication_plan.dart';
import '../../../shared/models/medication_log.dart';
import '../../../shared/models/anomaly_detection.dart';
import '../../elder/services/health_service.dart';
import '../../elder/services/medication_service.dart';
import '../../../core/api/api_client.dart';
import '../providers/family_provider.dart';
import '../../../shared/widgets/common_cards.dart';
import '../../../shared/widgets/common_states.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../shared/services/health_report_service.dart';

/// 老人健康数据 Provider（按 elderId 区分）
final elderHealthStatsProvider =
    FutureProvider.family<List<HealthStats>, String>((ref, elderId) async {
  final familyId = ref.watch(familyProvider.select((s) => s.familyId));
  if (familyId == null) return [];
  final service = HealthService(ref.read(apiClientProvider).dio);
  return service.getFamilyMemberStats(
      familyId: familyId, memberId: elderId);
});

final elderHealthRecordsProvider =
    FutureProvider.family<List<HealthRecord>, String>((ref, elderId) async {
  final familyId = ref.watch(familyProvider.select((s) => s.familyId));
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

/// 老人健康异常检测 Provider（按 elderId + healthType 区分）
final elderAnomalyDetectionProvider =
    FutureProvider.family<TrendAnomalyDetectionResponse, ({String elderId, HealthType? type})>((ref, args) async {
  final familyId = ref.watch(familyProvider.select((s) => s.familyId));
  if (familyId == null) {
    return TrendAnomalyDetectionResponse(
      type: 'BloodPressure',
      typeName: '血压',
      baseline: PersonalBaseline(),
      recentStats: RecentStatsSummary(),
    );
  }
  final service = HealthService(ref.read(apiClientProvider).dio);
  return service.getFamilyMemberAnomalyDetection(
    familyId: familyId,
    memberId: args.elderId,
    type: args.type,
  );
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
    final elderName = ref.watch(familyProvider
        .select((s) => s.members.where((m) => m.userId == widget.elderId).firstOrNull?.realName)) ?? '老人';

    final statsAsync =
        ref.watch(elderHealthStatsProvider(widget.elderId));
    final recordsAsync =
        ref.watch(elderHealthRecordsProvider(widget.elderId));
    final plansAsync =
        ref.watch(elderMedicationPlansProvider(widget.elderId));
    final logsAsync =
        ref.watch(elderMedicationLogsProvider((elderId: widget.elderId, date: _selectedLogDate)));
    final anomalyAsync =
        ref.watch(elderAnomalyDetectionProvider((elderId: widget.elderId, type: null)));

    return Scaffold(
      appBar: AppBar(
        title: Text('$elderName - 健康数据'),
        actions: [
          // 查看趋势按钮
          IconButton(
            icon: const Icon(Icons.show_chart),
            onPressed: () => context.push(
              '${RoutePaths.childElderHealthTrend(widget.elderId)}?name=$elderName',
            ),
            tooltip: '健康趋势',
          ),
          // 导出报告按钮
          Semantics(
            label: '导出$elderName的健康报告为PDF文件',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => _showExportDialog(context, elderName),
              tooltip: '导出报告',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(elderHealthStatsProvider(widget.elderId));
          ref.invalidate(elderHealthRecordsProvider(widget.elderId));
          ref.invalidate(elderMedicationPlansProvider(widget.elderId));
          ref.invalidate(elderMedicationLogsProvider((elderId: widget.elderId, date: _selectedLogDate)));
          ref.invalidate(elderAnomalyDetectionProvider((elderId: widget.elderId, type: null)));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AppTheme.paddingAll20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 健康概览卡片
              statsAsync.when(
                data: (stats) => _buildStatsGrid(stats),
                loading: () => GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 0.85,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: List.generate(4, (_) => const SkeletonCard()),
                ),
                error: (e, _) => ErrorStateWidget(
                  message: ErrorStateWidget.friendlyMessage(e.toString()),
                  onRetry: () => ref.invalidate(elderHealthStatsProvider(widget.elderId)),
                ),
              ),
              const SizedBox(height: 24),

              // AI 健康异常检测卡片
              anomalyAsync.when(
                data: (anomaly) => _buildAnomalyDetectionCard(anomaly, elderName),
                loading: () => Container(
                  padding: AppTheme.paddingAll16,
                  decoration: BoxDecoration(
                    color: AppTheme.grey100,
                    borderRadius: AppTheme.radiusL,
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('正在分析健康趋势...', style: AppTheme.textGreyLight),
                      ],
                    ),
                  ),
                ),
                error: (e, _) => Container(
                  padding: AppTheme.paddingAll16,
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: AppTheme.radiusS,
                  ),
                  child: const Text('异常检测加载失败，请重试',
                      style: AppTheme.textError),
                ),
              ),
              const SizedBox(height: 24),

              // 最近健康记录
              const Text(
                '最近健康记录',
                style: AppTheme.textTitle,
              ),
              const SizedBox(height: 12),
              recordsAsync.when(
                data: (records) => _buildRecordsList(records),
                loading: () => Column(children: List.generate(3, (_) => const SkeletonCard())),
                error: (e, _) => ErrorStateWidget(
                  message: ErrorStateWidget.friendlyMessage(e.toString()),
                  onRetry: () => ref.invalidate(elderHealthRecordsProvider(widget.elderId)),
                ),
              ),
              const SizedBox(height: 24),

              // 用药计划
              const Text(
                '用药计划',
                style: AppTheme.textTitle,
              ),
              const SizedBox(height: 12),
              plansAsync.when(
                data: (plans) => _buildPlansList(plans),
                loading: () => Column(children: List.generate(2, (_) => const SkeletonCard())),
                error: (e, _) => ErrorStateWidget(
                  message: ErrorStateWidget.friendlyMessage(e.toString()),
                  onRetry: () => ref.invalidate(elderMedicationPlansProvider(widget.elderId)),
                ),
              ),
              const SizedBox(height: 24),

              // 最近用药记录（带日期筛选）
              Row(
                children: [
                  const Text(
                    '最近用药记录',
                    style: AppTheme.textTitle,
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
                          _selectedLogDate = picked.toDateString();
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      _selectedLogDate ?? '全部日期',
                      style: AppTheme.textBody,
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
                loading: () => Column(children: List.generate(3, (_) => const SkeletonCard())),
                error: (e, _) => ErrorStateWidget(
                  message: ErrorStateWidget.friendlyMessage(e.toString()),
                  onRetry: () => ref.invalidate(elderMedicationLogsProvider((elderId: widget.elderId, date: _selectedLogDate))),
                ),
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
      return const EmptyStateWidget(
        icon: Icons.analytics_outlined,
        title: '暂无健康统计数据',
        subtitle: '老人记录健康数据后，这里会显示统计概览',
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
        Semantics(
          label: '血压: ${_getStatsValue(typeMap, '血压')}',
          child: StatCard(
            icon: Icons.favorite,
            title: '血压',
            value: _getStatsValue(typeMap, '血压'),
            subtitle: _getStatsSubtitle(typeMap, '血压'),
            color: AppTheme.errorColor,
          ),
        ),
        Semantics(
          label: '血糖: ${_getStatsValue(typeMap, '血糖')}',
          child: StatCard(
            icon: Icons.water_drop,
            title: '血糖',
            value: _getStatsValue(typeMap, '血糖'),
            subtitle: _getStatsSubtitle(typeMap, '血糖'),
            color: AppTheme.infoBlue,
          ),
        ),
        Semantics(
          label: '心率: ${_getStatsValue(typeMap, '心率')}',
          child: StatCard(
            icon: Icons.monitor_heart,
            title: '心率',
            value: _getStatsValue(typeMap, '心率'),
            subtitle: _getStatsSubtitle(typeMap, '心率'),
            color: AppTheme.purpleColor,
          ),
        ),
        Semantics(
          label: '体温: ${_getStatsValue(typeMap, '体温')}',
          child: StatCard(
            icon: Icons.thermostat,
            title: '体温',
            value: _getStatsValue(typeMap, '体温'),
            subtitle: _getStatsSubtitle(typeMap, '体温'),
            color: AppTheme.warningColor,
          ),
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
      return const EmptyStateWidget(
        icon: Icons.medication_outlined,
        title: '暂无用药计划',
        subtitle: '点击下方按钮为老人创建用药计划',
      );
    }

    return Column(
      children: plans.map((plan) {
        return Card(
          elevation: AppTheme.cardElevation,
          margin: AppTheme.marginBottom12,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusL,
            side: plan.isActive
                ? BorderSide.none
                : BorderSide(color: AppTheme.grey300, width: 1),
          ),
          child: Padding(
            padding: AppTheme.paddingAll16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: (plan.isActive ? AppTheme.infoBlue : AppTheme.grey500)
                            .withValues(alpha: 0.15),
                        borderRadius: AppTheme.radiusS,
                      ),
                      child: Icon(
                        Icons.medication,
                        color: plan.isActive ? AppTheme.infoBlue : AppTheme.grey500,
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
                              color: plan.isActive ? null : AppTheme.grey500,
                            ),
                          ),
                          Text(
                            '剂量: ${plan.dosage}',
                            style: AppTheme.textGrey,
                          ),
                        ],
                      ),
                    ),
                    // 启用/停用开关
                    Switch(
                      value: plan.isActive,
                      activeThumbColor: AppTheme.successColor,
                      onChanged: (value) => _togglePlan(plan, value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: AppTheme.paddingH12V8,
                  decoration: BoxDecoration(
                    color: AppTheme.grey50,
                    borderRadius: AppTheme.radiusXS,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '频率: ${plan.frequency.label}',
                        style: TextStyle(
                          fontSize: 14,
                          color: plan.isActive ? null : AppTheme.grey500,
                        ),
                      ),
                      Text(
                        '提醒时间: ${plan.reminderTimesText}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.grey600,
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
                          padding: AppTheme.paddingH12V4,
                        ),
                      ),
                      if (!plan.isActive) ...[
                        TextButton.icon(
                          onPressed: () => _deletePlan(plan),
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor),
                          label: const Text('删除', style: AppTheme.textError),
                          style: TextButton.styleFrom(
                            padding: AppTheme.paddingH12V4,
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
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.errorColor),
                        label: const Text('删除计划', style: AppTheme.textError),
                        style: TextButton.styleFrom(
                          padding: AppTheme.paddingH12V4,
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
          shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusXL),
          title: Row(
            children: [
              const Icon(Icons.edit, color: AppTheme.primaryColor),
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
                  context.showWarningSnackBar(AppTheme.msgMedicineNameRequired);
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
                  if (mounted && context.mounted) {
                    Navigator.pop(ctx);
                    context.showSuccessSnackBar(AppTheme.msgPlanUpdated);
                  }
                } catch (e) {
                  setDialogState(() => isSubmitting = false);
                  if (mounted && context.mounted) {
                    context.showErrorSnackBar(AppTheme.msgOperationFailed);
                  }
                }
              },
              style: AppTheme.elevatedPrimaryStyle,
              child: const Text('保存', style: AppTheme.textWhite),
            ),
          ],
        ),
      ),
    );

    // 延迟到下一帧释放控制器，确保对话框 Widget 树已完全卸载
    WidgetsBinding.instance.addPostFrameCallback((_) {
      nameController.dispose();
      dosageController.dispose();
    });
  }

  /// 切换用药计划启用/停用状态
  Future<void> _togglePlan(MedicationPlan plan, bool active) async {
    try {
      final service = MedicationService(ref.read(apiClientProvider).dio);
      await service.updatePlan(planId: plan.id, isActive: active);
      // 刷新计划列表
      ref.invalidate(elderMedicationPlansProvider(widget.elderId));
      if (mounted) {
        if (active) {
          context.showSuccessSnackBar(AppTheme.msgReminderEnabled(plan.medicineName));
        } else {
          context.showSnackBar(AppTheme.msgReminderDisabled(plan.medicineName));
        }
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(AppTheme.msgOperationFailed);
      }
    }
  }

  /// 删除用药计划
  Future<void> _deletePlan(MedicationPlan plan) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '确认删除',
      message: '确定删除 ${plan.medicineName} 的用药计划吗？此操作不可恢复。',
      confirmText: '删除',
    );
    if (confirmed != true) return;

    try {
      final service = MedicationService(ref.read(apiClientProvider).dio);
      await service.deletePlan(plan.id);
      ref.invalidate(elderMedicationPlansProvider(widget.elderId));
      if (mounted) {
        context.showSnackBar(AppTheme.msgPlanDeleted(plan.medicineName));
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(AppTheme.msgOperationFailed);
      }
    }
  }

  /// 健康记录列表
  Widget _buildRecordsList(List<HealthRecord> records) {
    if (records.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.note_add_outlined,
        title: '暂无健康记录',
        subtitle: '老人录入健康数据后，这里会显示记录列表',
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      itemBuilder: (context, index) {
        final record = records[index];
        final time = record.recordedAt.toLocal();
        final timeStr = time.toShortDateTimeString();
        return Card(
          elevation: AppTheme.cardElevation,
          margin: AppTheme.marginBottom8,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusM,
          ),
          child: Padding(
            padding: AppTheme.paddingAll12,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: record.type.color.withValues(alpha: 0.15),
                    borderRadius: AppTheme.radius10,
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
                        style: AppTheme.textHeading
                      ),
                      Text(
                        timeStr,
                        style: AppTheme.textCaptionDark,
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
        padding: AppTheme.paddingAll24,
        decoration: BoxDecoration(
          color: AppTheme.grey100,
          borderRadius: AppTheme.radiusL,
        ),
        child: const Center(
          child: Text('暂无用药记录', style: AppTheme.textGreyLight),
        ),
      );
    }

    return Column(
      children: logs.map((log) {
        final scheduledTime = log.scheduledAt.toLocal();
        final scheduledStr = scheduledTime.toShortDateTimeString();

        // 计算实际服药时间
        String? takenStr;
        String? delayInfo;
        if (log.takenAt != null) {
          final takenTime = log.takenAt!.toLocal();
          takenStr = takenTime.toTimeString();
          // 计算延迟（超过30分钟视为延迟服药）
          final delay = log.takenAt!.difference(log.scheduledAt);
          if (delay.inMinutes > 30) {
            delayInfo = '延迟${delay.inHours > 0 ? '${delay.inHours}小时' : ''}${delay.inMinutes % 60}分钟';
          }
        }

        return Card(
          elevation: AppTheme.cardElevation,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusM,
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
                    borderRadius: AppTheme.radius10,
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
                        style: AppTheme.textHeading
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '计划: $scheduledStr',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.grey600),
                      ),
                      if (takenStr != null)
                        Text(
                          '实际: $takenStr',
                          style: TextStyle(
                            fontSize: 13,
                            color: delayInfo != null
                                ? AppTheme.warningDark
                                : AppTheme.successDark,
                          ),
                        ),
                      if (delayInfo != null)
                        Text(
                          delayInfo,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.warningDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (log.note != null && log.note!.isNotEmpty)
                        Text(
                          '备注: ${log.note}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.grey500,
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
                    style: AppTheme.elevatedPrimaryStyle,
                    child: const Text('最近7天', style: AppTheme.textWhite),
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
                    child: const Text('最近30天', style: AppTheme.textWhite),
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
            shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusL),
            child: Padding(
              padding: AppTheme.paddingAll24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  const Text('正在生成报告...', style: AppTheme.textBody16),
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
      if (success) {
        context.showSuccessSnackBar(AppTheme.msgReportGenerated);
      } else {
        context.showErrorSnackBar(AppTheme.msgOperationFailed);
      }
    }
  }

  /// 构建 AI 健康异常检测卡片
  Widget _buildAnomalyDetectionCard(TrendAnomalyDetectionResponse anomaly, String elderName) {
    // 判断是否有异常
    final hasAnomalies = anomaly.hasAnomalies();
    final maxSeverity = anomaly.maxSeverity();

    // 根据严重度选择颜色
    Color severityColor;
    String severityText;
    IconData severityIcon;
    if (!hasAnomalies) {
      severityColor = AppTheme.successColor;
      severityText = '健康状态良好';
      severityIcon = Icons.check_circle;
    } else if (maxSeverity < 33) {
      severityColor = AppTheme.warningColor;
      severityText = '轻度关注';
      severityIcon = Icons.info_outline;
    } else if (maxSeverity < 66) {
      severityColor = AppTheme.grey800;
      severityText = '需要关注';
      severityIcon = Icons.warning_amber;
    } else {
      severityColor = AppTheme.errorDark;
      severityText = '需要重视';
      severityIcon = Icons.error_outline;
    }

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
            // 标题行
            Row(
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'AI 健康趋势分析',
                              style: AppTheme.textTitle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: AppTheme.paddingH8V2,
                            decoration: BoxDecoration(
                              color: severityColor.withValues(alpha: 0.15),
                              borderRadius: AppTheme.radius6,
                            ),
                            child: Text(
                              severityText,
                              style: TextStyle(
                                fontSize: 12,
                                color: severityColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '基于 ${anomaly.baseline.baselineDays} 天数据分析',
                        style: const TextStyle(fontSize: 13, color: AppTheme.grey600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // 查看详情按钮
                Semantics(
                  label: '查看$elderName的健康趋势分析详情',
                  button: true,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 18),
                    onPressed: () => _showAnomalyDetailDialog(anomaly, elderName),
                    tooltip: '查看详情',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 个人基线对比
            Container(
              padding: AppTheme.paddingAll12,
              decoration: BoxDecoration(
                color: AppTheme.grey50,
                borderRadius: AppTheme.radiusS,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 18, color: AppTheme.grey700),
                      const SizedBox(width: 8),
                      Text(
                        '个人基线',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildBaselineRow(anomaly),
                ],
              ),
            ),

            // 异常事件列表（如果有）
            if (hasAnomalies) ...[
              const SizedBox(height: 16),
              const Text(
                '检测到的异常',
                style: AppTheme.textCardTitle,
              ),
              const SizedBox(height: 8),
              ...anomaly.anomalies.take(3).map((event) => _buildAnomalyEventItem(event)),
            ] else ...[
              const SizedBox(height: 16),
              // 正向激励反馈（数据平稳时展示）
              if (anomaly.positiveFeedback != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
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
                          const SizedBox(width: 8),
                          Text(
                            anomaly.positiveFeedback!.quality,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successDark,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withValues(alpha: 0.12),
                              borderRadius: AppTheme.radius6,
                            ),
                            child: Text(
                              '连续${anomaly.positiveFeedback!.daysStable}天平稳',
                              style: TextStyle(fontSize: 12, color: AppTheme.successColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        anomaly.positiveFeedback!.message,
                        style: TextStyle(fontSize: 14, color: AppTheme.successDark, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.show_chart, size: 14, color: AppTheme.successMedium),
                          const SizedBox(width: 4),
                          Text(
                            '变异系数: ${anomaly.positiveFeedback!.coefficientOfVariation.toStringAsFixed(1)}%',
                            style: TextStyle(fontSize: 12, color: AppTheme.successMedium),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: AppTheme.paddingAll12,
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.08),
                    borderRadius: AppTheme.radiusS,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$elderName 的健康数据趋势稳定，未发现异常',
                          style: TextStyle(fontSize: 14, color: AppTheme.successDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    ),
  );
  }

  /// 构建基线数据行
  Widget _buildBaselineRow(TrendAnomalyDetectionResponse anomaly) {
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
        const SizedBox(width: 8),
        Text(
          '${anomaly.typeName}: ',
          style: AppTheme.textSubtitle,
        ),
        Text(
          baselineText,
          style: AppTheme.textHeading,
        ),
        const SizedBox(width: 4),
        Text(
          unit,
          style: AppTheme.textSubtitle,
        ),
        const Spacer(),
        Text(
          '(${anomaly.baseline.baselineRecordCount} 条记录)',
          style: AppTheme.textCaption,
        ),
      ],
    );
  }

  /// 构建单个异常事件项
  Widget _buildAnomalyEventItem(AnomalyEvent event) {
    // 根据严重度选择颜色
    Color color;
    if (event.severityScore < 33) {
      color = AppTheme.warningColor;
    } else if (event.severityScore < 66) {
      color = AppTheme.grey800;
    } else {
      color = AppTheme.errorDark;
    }

    final time = event.detectedAt.toLocal();
    final timeStr = '${time.month}/${time.day}';

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
              // 时间标签
              Container(
                padding: AppTheme.paddingH8V4,
                decoration: BoxDecoration(
                  color: AppTheme.grey200,
                  borderRadius: AppTheme.radius6,
                ),
                child: Text(
                  timeStr,
                  style: TextStyle(fontSize: 12, color: AppTheme.grey700),
                ),
              ),
              const SizedBox(width: 12),
              // 异常类型图标
              Icon(
                _getAnomalyTypeIcon(event.type),
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              // 异常描述
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.type.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      event.description,
                      style: TextStyle(fontSize: 13, color: AppTheme.grey700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // 严重度评分
              Container(
                padding: AppTheme.paddingH8V4,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: AppTheme.radius6,
                ),
                child: Text(
                  event.severityScore.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          // 行动建议
          if (event.recommendedAction != null && event.recommendedAction!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.grey50,
                borderRadius: AppTheme.radiusXS,
                border: Border.all(color: AppTheme.infoBlueLight),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: AppTheme.infoBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.recommendedAction!,
                      style: TextStyle(fontSize: 13, color: AppTheme.infoBlueDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 获取异常类型图标
  IconData _getAnomalyTypeIcon(AnomalyType type) {
    return switch (type) {
      AnomalyType.spike => Icons.arrow_upward,
      AnomalyType.continuousHigh => Icons.trending_up,
      AnomalyType.continuousLow => Icons.trending_down,
      AnomalyType.acceleration => Icons.speed,
      AnomalyType.volatility => Icons.show_chart,
    };
  }

  /// 显示异常检测详情对话框
  void _showAnomalyDetailDialog(TrendAnomalyDetectionResponse anomaly, String elderName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusXL),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
                borderRadius: AppTheme.radius10,
              ),
              child: const Icon(Icons.analytics, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            const Text('健康趋势详情'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 最近7天统计
              Container(
                padding: AppTheme.paddingAll12,
                decoration: BoxDecoration(
                  color: AppTheme.grey50,
                  borderRadius: AppTheme.radiusS,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '最近7天统计',
                      style: AppTheme.textCardTitle,
                    ),
                    const SizedBox(height: 8),
                    _buildRecentStatsRow('平均值', anomaly.recentStats.avg7Days),
                    _buildRecentStatsRow('最高值', anomaly.recentStats.max7Days),
                    _buildRecentStatsRow('最低值', anomaly.recentStats.min7Days),
                    _buildRecentStatsRow('波动性', anomaly.recentStats.stdDev7Days),
                    if (anomaly.recentStats.baselineDeviationPercent != null)
                      _buildRecentStatsRow(
                        '偏离基线',
                        anomaly.recentStats.baselineDeviationPercent,
                        isPercent: true,
                      ),
                  ],
                ),
              ),

              // 异常事件列表
              if (anomaly.hasAnomalies()) ...[
                const SizedBox(height: 16),
                Text(
                  '异常事件时间线',
                  style: AppTheme.textCardTitle,
                ),
                const SizedBox(height: 8),
                ...anomaly.anomalies.map((event) => _buildAnomalyEventItem(event)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 构建最近统计行
  Widget _buildRecentStatsRow(String label, double? value, {bool isPercent = false}) {
    if (value == null) return const SizedBox.shrink();
    final displayValue = isPercent
        ? '${value > 0 ? "+" : ""}${value.toStringAsFixed(1)}%'
        : value.toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: AppTheme.textSubtitle,
          ),
          Text(
            displayValue,
            style: AppTheme.textCardTitle,
          ),
        ],
      ),
    );
  }
}