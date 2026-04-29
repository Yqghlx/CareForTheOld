import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../core/extensions/api_error_extension.dart';

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
      typeName: AppTheme.labelBloodPressure,
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
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final elderName = ref.watch(familyProvider
        .select((s) => s.members.where((m) => m.userId == widget.elderId).firstOrNull?.realName)) ?? AppTheme.labelElder;

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
            tooltip: AppTheme.tooltipViewTrend,
          ),
          // 导出报告按钮
          Semantics(
            label: '导出$elderName的健康报告为PDF文件',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => _showExportDialog(context, elderName),
              tooltip: AppTheme.tooltipExportReport,
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
              AppTheme.spacer24,

              // AI 健康异常检测卡片
              anomalyAsync.when(
                data: (anomaly) => _buildAnomalyDetectionCard(anomaly, elderName),
                loading: () => Container(
                  padding: AppTheme.paddingAll16,
                  decoration: AppTheme.decorationCardLight,
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        AppTheme.hSpacer12,
                        Text(AppTheme.msgAnomalyAnalyzing, style: AppTheme.textGreyLight),
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
                  child: const Text(AppTheme.msgAnomalyLoadFailed,
                      style: AppTheme.textError),
                ),
              ),
              AppTheme.spacer24,

              // 最近健康记录
              const Text(
                '最近健康记录',
                style: AppTheme.textTitle,
              ),
              AppTheme.spacer12,
              recordsAsync.when(
                data: (records) => _buildRecordsList(records),
                loading: () => Column(children: List.generate(3, (_) => const SkeletonCard())),
                error: (e, _) => ErrorStateWidget(
                  message: ErrorStateWidget.friendlyMessage(e.toString()),
                  onRetry: () => ref.invalidate(elderHealthRecordsProvider(widget.elderId)),
                ),
              ),
              AppTheme.spacer24,

              // 用药计划
              const Text(
                '用药计划',
                style: AppTheme.textTitle,
              ),
              AppTheme.spacer12,
              plansAsync.when(
                data: (plans) => _buildPlansList(plans),
                loading: () => Column(children: List.generate(2, (_) => const SkeletonCard())),
                error: (e, _) => ErrorStateWidget(
                  message: ErrorStateWidget.friendlyMessage(e.toString()),
                  onRetry: () => ref.invalidate(elderMedicationPlansProvider(widget.elderId)),
                ),
              ),
              AppTheme.spacer24,

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
                      if (picked != null && mounted) {
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
                      icon: const Icon(Icons.close, size: AppTheme.iconSizeSm),
                      onPressed: () => setState(() => _selectedLogDate = null),
                      tooltip: '清除日期筛选',
                    ),
                ],
              ),
              AppTheme.spacer12,
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
        title: AppTheme.msgNoStats,
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
          label: '${AppTheme.labelBloodPressure}: ${_getStatsValue(typeMap, AppTheme.labelBloodPressure)}',
          child: StatCard(
            icon: Icons.favorite,
            title: AppTheme.labelBloodPressure,
            value: _getStatsValue(typeMap, AppTheme.labelBloodPressure),
            subtitle: _getStatsSubtitle(typeMap, AppTheme.labelBloodPressure),
            color: AppTheme.errorColor,
          ),
        ),
        Semantics(
          label: '${AppTheme.labelBloodSugar}: ${_getStatsValue(typeMap, AppTheme.labelBloodSugar)}',
          child: StatCard(
            icon: Icons.water_drop,
            title: AppTheme.labelBloodSugar,
            value: _getStatsValue(typeMap, AppTheme.labelBloodSugar),
            subtitle: _getStatsSubtitle(typeMap, AppTheme.labelBloodSugar),
            color: AppTheme.infoBlue,
          ),
        ),
        Semantics(
          label: '${AppTheme.labelHeartRate}: ${_getStatsValue(typeMap, AppTheme.labelHeartRate)}',
          child: StatCard(
            icon: Icons.monitor_heart,
            title: AppTheme.labelHeartRate,
            value: _getStatsValue(typeMap, AppTheme.labelHeartRate),
            subtitle: _getStatsSubtitle(typeMap, AppTheme.labelHeartRate),
            color: AppTheme.purpleColor,
          ),
        ),
        Semantics(
          label: '${AppTheme.labelTemperature}: ${_getStatsValue(typeMap, AppTheme.labelTemperature)}',
          child: StatCard(
            icon: Icons.thermostat,
            title: AppTheme.labelTemperature,
            value: _getStatsValue(typeMap, AppTheme.labelTemperature),
            subtitle: _getStatsSubtitle(typeMap, AppTheme.labelTemperature),
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
      AppTheme.labelBloodPressure => 'mmHg',
      AppTheme.labelBloodSugar => 'mmol/L',
      AppTheme.labelHeartRate => '次/分',
      AppTheme.labelTemperature => '°C',
      _ => '',
    };
  }

  /// 用药计划列表
  Widget _buildPlansList(List<MedicationPlan> plans) {
    if (plans.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.medication_outlined,
        title: AppTheme.msgNoHealthRecord,
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
                        size: AppTheme.iconSize2xl,
                      ),
                    ),
                    AppTheme.hSpacer12,
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
                AppTheme.spacer12,
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
                  padding: AppTheme.marginTop12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showEditPlanDialog(plan),
                        icon: const Icon(Icons.edit_outlined, size: AppTheme.iconSizeSm),
                        label: const Text(AppTheme.msgEdit),
                        style: TextButton.styleFrom(
                          padding: AppTheme.paddingH12V4,
                        ),
                      ),
                      if (!plan.isActive) ...[
                        TextButton.icon(
                          onPressed: _isDeleting ? null : () => _deletePlan(plan),
                          icon: const Icon(Icons.delete_outline, size: AppTheme.iconSizeSm, color: AppTheme.errorColor),
                          label: Text(AppTheme.msgDelete, style: AppTheme.textError),
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
                    padding: AppTheme.marginTop12,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _isDeleting ? null : () => _deletePlan(plan),
                        icon: const Icon(Icons.delete_outline, size: AppTheme.iconSizeSm, color: AppTheme.errorColor),
                        label: Text('${AppTheme.msgDelete}计划', style: AppTheme.textError),
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
              AppTheme.hSpacer12,
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
                    labelText: AppTheme.labelMedicineName,
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s一-龥·]')),
                    LengthLimitingTextInputFormatter(50),
                  ],
                ),
                AppTheme.spacer12,
                TextField(
                  controller: dosageController,
                  decoration: const InputDecoration(
                    labelText: '剂量（如：1片、10ml）',
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s一-龥.]')),
                    LengthLimitingTextInputFormatter(30),
                  ],
                ),
                AppTheme.spacer12,
                DropdownButtonFormField<Frequency>(
                  // ignore: deprecated_member_use - StatefulBuilder 中动态更新需要 value，initialValue 仅用于初始设置
                  value: selectedFrequency,
                  decoration: const InputDecoration(
                    labelText: AppTheme.labelFrequency,
                    border: OutlineInputBorder(),
                  ),
                  items: Frequency.values.map((f) => DropdownMenuItem(
                    value: f,
                    child: Text(f.label),
                  )).toList(),
                  onChanged: (v) => setDialogState(() => selectedFrequency = v!),
                ),
                AppTheme.spacer12,
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
              child: const Text(AppTheme.msgCancel),
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
              child: Text(AppTheme.msgSave, style: AppTheme.textWhite),
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
        context.showErrorSnackBar(errorMessageFrom(e));
      }
    }
  }

  /// 删除用药计划
  Future<void> _deletePlan(MedicationPlan plan) async {
    if (_isDeleting) return;
    final confirmed = await showConfirmDialog(
      context,
      title: AppTheme.msgConfirmDelete,
      message: '确定删除 ${plan.medicineName} 的用药计划吗？此操作不可恢复。',
      confirmText: AppTheme.msgDelete,
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
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
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  /// 健康记录列表
  Widget _buildRecordsList(List<HealthRecord> records) {
    if (records.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.note_add_outlined,
        title: AppTheme.msgNoHealthRecord,
        subtitle: '老人录入健康数据后，这里会显示记录列表',
      );
    }

    return ListView.builder(
      cacheExtent: 800,
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
                AppTheme.hSpacer12,
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
        decoration: AppTheme.decorationCardLight,
        child: const Center(
          child: Text(AppTheme.msgNoMedicationLog, style: AppTheme.textGreyLight),
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
            padding: AppTheme.paddingAll14,
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
                AppTheme.hSpacer12,
                // 药品信息 + 时间
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.medicineName,
                        style: AppTheme.textHeading
                      ),
                      AppTheme.spacer4,
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
                          style: AppTheme.textCaption.copyWith(
                            color: AppTheme.warningDark,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (log.note != null && log.note!.isNotEmpty)
                        Text(
                          '备注: ${log.note}',
                          style: AppTheme.textCaption.copyWith(
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
            AppTheme.hSpacer12,
            const Text('导出健康报告'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('为 $elderName 导出健康报告'),
            AppTheme.spacer16,
            const Text('选择报告时间范围：'),
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
                  AppTheme.spacer16,
                  const Text('正在生成报告...', style: AppTheme.textBody16),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
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
    } catch (e) {
      // 异常时也要关闭加载对话框
      if (mounted && context.mounted) {
        Navigator.pop(context);
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
                AppTheme.hSpacer12,
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
                          AppTheme.hSpacer8,
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
                      AppTheme.spacer4,
                      Text(
                        '基于 ${anomaly.baseline.baselineDays} 天数据分析',
                        style: AppTheme.textCaption13Grey600,
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
                    icon: const Icon(Icons.arrow_forward_ios, size: AppTheme.iconSizeSm),
                    onPressed: () => _showAnomalyDetailDialog(anomaly, elderName),
                    tooltip: '查看详情',
                  ),
                ),
              ],
            ),
            AppTheme.spacer16,

            // 个人基线对比
            Container(
              padding: AppTheme.paddingAll12,
              decoration: AppTheme.decorationInput,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: AppTheme.iconSizeSm, color: AppTheme.grey700),
                      AppTheme.hSpacer8,
                      Text(
                        '个人基线',
                        style: AppTheme.textBody.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grey700,
                        ),
                      ),
                    ],
                  ),
                  AppTheme.spacer8,
                  _buildBaselineRow(anomaly),
                ],
              ),
            ),

            // 异常事件列表（如果有）
            if (hasAnomalies) ...[
              AppTheme.spacer16,
              const Text(
                '检测到的异常',
                style: AppTheme.textCardTitle,
              ),
              AppTheme.spacer8,
              ...anomaly.anomalies.take(3).map((event) => _buildAnomalyEventItem(event)),
            ] else ...[
              AppTheme.spacer16,
              // 正向激励反馈（数据平稳时展示）
              if (anomaly.positiveFeedback != null) ...[
                Container(
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
                          Text(
                            anomaly.positiveFeedback!.quality,
                            style: AppTheme.textBody16.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.successDark,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: AppTheme.paddingH8V3,
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withValues(alpha: 0.12),
                              borderRadius: AppTheme.radius6,
                            ),
                            child: Text(
                              '连续${anomaly.positiveFeedback!.daysStable}天平稳',
                              style: AppTheme.textSuccess12,
                            ),
                          ),
                        ],
                      ),
                      AppTheme.spacer10,
                      Text(
                        anomaly.positiveFeedback!.message,
                        style: AppTheme.textSuccessDark14.copyWith(height: 1.4),
                      ),
                      AppTheme.spacer8,
                      Row(
                        children: [
                          const Icon(Icons.show_chart, size: 14, color: AppTheme.successMedium),
                          AppTheme.hSpacer4,
                          Text(
                            '变异系数: ${anomaly.positiveFeedback!.coefficientOfVariation.toStringAsFixed(1)}%',
                            style: AppTheme.textSuccessMedium12,
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
                      const Icon(Icons.check_circle_outline, color: AppTheme.successColor, size: AppTheme.iconSizeMd),
                      AppTheme.hSpacer8,
                      Expanded(
                        child: Text(
                          '$elderName 的健康数据趋势稳定，未发现异常',
                          style: AppTheme.textSuccessDark14,
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
        AppTheme.hSpacer8,
        Text(
          '${anomaly.typeName}: ',
          style: AppTheme.textSubtitle,
        ),
        Text(
          baselineText,
          style: AppTheme.textHeading,
        ),
        AppTheme.hSpacer4,
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
              // 时间标签
              Container(
                padding: AppTheme.paddingH8V4,
                decoration: BoxDecoration(
                  color: AppTheme.grey200,
                  borderRadius: AppTheme.radius6,
                ),
                child: Text(
                  timeStr,
                  style: AppTheme.textGrey700_12,
                ),
              ),
              AppTheme.hSpacer12,
              // 异常类型图标
              Icon(
                _getAnomalyTypeIcon(event.type),
                color: color,
                size: AppTheme.iconSizeMd,
              ),
              AppTheme.hSpacer8,
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
                      style: AppTheme.textCaption13Grey700,
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
            AppTheme.spacer8,
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
                  AppTheme.hSpacer8,
                  Expanded(
                    child: Text(
                      event.recommendedAction!,
                      style: AppTheme.textInfoDark13,
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
            AppTheme.hSpacer12,
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
                decoration: AppTheme.decorationInput,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '最近7天统计',
                      style: AppTheme.textCardTitle,
                    ),
                    AppTheme.spacer8,
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
                AppTheme.spacer16,
                Text(
                  '异常事件时间线',
                  style: AppTheme.textCardTitle,
                ),
                AppTheme.spacer8,
                ...anomaly.anomalies.map((event) => _buildAnomalyEventItem(event)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(AppTheme.labelClose),
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