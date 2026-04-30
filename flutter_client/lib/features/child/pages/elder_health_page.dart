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
import '../widgets/anomaly_detection_card.dart';

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
  bool _isToggling = false;

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
                data: (anomaly) => AnomalyDetectionCard(anomaly: anomaly, elderName: elderName),
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
        subtitle: AppTheme.subtitleHealthStatsEmpty,
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
        subtitle: AppTheme.subtitleMedPlanEmpty,
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
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
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
                      onChanged: _isToggling ? null : (value) => _togglePlan(plan, value),
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
              const Text(AppTheme.labelEditMedPlan),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
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
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: AppTheme.labelDosage,
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
                      label: const Text(AppTheme.labelAddTime),
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
                    context.showErrorSnackBar(errorMessageFrom(e, fallback: AppTheme.msgOperationFailed));
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
    if (_isToggling) return;
    setState(() => _isToggling = true);
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
    } finally {
      if (mounted) setState(() => _isToggling = false);
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
        context.showErrorSnackBar(errorMessageFrom(e, fallback: AppTheme.msgOperationFailed));
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
        subtitle: AppTheme.subtitleHealthRecordsEmpty,
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
      return EmptyStateWidget(
        icon: Icons.medication_outlined,
        title: AppTheme.titleNoMedRecord,
        subtitle: AppTheme.subtitleNoMedRecord,
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
          margin: AppTheme.marginBottom10,
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
            const Text(AppTheme.labelExportReport),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('为 $elderName 导出健康报告'),
            AppTheme.spacer16,
            const Text(AppTheme.labelSelectTimeRange),
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
        context.showErrorSnackBar(errorMessageFrom(e, fallback: AppTheme.msgOperationFailed));
      }
    }
  }
}
