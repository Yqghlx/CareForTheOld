import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/medication_plan.dart';
import '../../../shared/models/medication_log.dart';
import '../providers/medication_provider.dart';
import '../../../shared/widgets/common_cards.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../core/theme/app_theme.dart';

/// 用药提醒页面
class MedicationPage extends ConsumerStatefulWidget {
  const MedicationPage({super.key});

  @override
  ConsumerState<MedicationPage> createState() => _MedicationPageState();
}

class _MedicationPageState extends ConsumerState<MedicationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(medicationProvider.notifier).loadAll();
    });
  }

  Future<void> _refresh() async {
    await ref.read(medicationProvider.notifier).loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final medState = ref.watch(medicationProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('用药提醒')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 今日用药概览 - 渐变卡片
              _buildOverviewCard(medState),
              const SizedBox(height: 24),

              // 今日待服药
              const Text(
                '今日用药计划',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _buildContent(medState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 概览卡片 - 渐变背景
  Widget _buildOverviewCard(MedicationState state) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.primaryLight.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('待服用', '${state.pendingCount}', Colors.orange),
            _buildStatItem('已服用', '${state.takenCount}', Colors.green),
            _buildStatItem('已跳过', '${state.skippedCount}', Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  /// 内容区域
  Widget _buildContent(MedicationState state) {
    if (state.isLoading && state.todayPending.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.todayPending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 12),
            Text(
              '加载失败: ${state.error}',
              style: const TextStyle(color: AppTheme.errorColor),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              text: '重试',
              onPressed: () => ref.read(medicationProvider.notifier).loadAll(),
            ),
          ],
        ),
      );
    }

    if (state.todayPending.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              '今日暂无用药计划',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(
              '请让子女帮忙添加用药计划',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: state.todayPending.length,
      itemBuilder: (context, index) {
        final log = state.todayPending[index];
        return _buildMedicationCard(log);
      },
    );
  }

  /// 单条用药记录卡片
  Widget _buildMedicationCard(MedicationLog log) {
    if (log.isPending) {
      // 待服用卡片：使用脉冲动画提醒
      return _PendingMedicationCard(log: log, onTaken: () => _markTaken(log), onSkipped: () => _markSkipped(log));
    }
    return _buildStaticMedicationCard(log);
  }

  /// 已处理状态的卡片（已服用/已跳过）
  Widget _buildStaticMedicationCard(MedicationLog log) {
    final scheduledTime = log.scheduledAt.toLocal();
    final timeStr =
        '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 药品信息行
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: log.status == MedicationStatus.taken
                        ? Colors.green.withValues(alpha: 0.15)
                        : log.isPending
                            ? Colors.orange.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.medication,
                    color: log.status == MedicationStatus.taken
                        ? Colors.green
                        : log.isPending
                            ? Colors.orange
                            : Colors.grey,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.medicineName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '计划时间: $timeStr',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
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
            // 待服用时显示操作按钮
            if (log.isPending)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: PrimaryIconButton(
                        text: '已服用',
                        icon: Icons.check,
                        onPressed: () => _markTaken(log),
                        gradient: const LinearGradient(
                          colors: [Colors.green, Colors.lightGreen],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: SecondaryButton(
                        text: '跳过',
                        onPressed: () => _markSkipped(log),
                        borderColor: Colors.grey,
                        textColor: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 标记已服用
  Future<void> _markTaken(MedicationLog log) async {
    final success =
        await ref.read(medicationProvider.notifier).markAsTaken(log);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '已标记为已服用' : '操作失败'),
          backgroundColor: success ? AppTheme.successColor : AppTheme.errorColor,
        ),
      );
    }
  }

  /// 标记跳过
  Future<void> _markSkipped(MedicationLog log) async {
    final success =
        await ref.read(medicationProvider.notifier).markAsSkipped(log);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '已跳过本次用药' : '操作失败'),
          backgroundColor: Colors.grey.shade700,
        ),
      );
    }
  }
}

/// 待服用卡片 - 带脉冲边框动画提醒老人服药
class _PendingMedicationCard extends StatefulWidget {
  final MedicationLog log;
  final VoidCallback onTaken;
  final VoidCallback onSkipped;

  const _PendingMedicationCard({
    required this.log,
    required this.onTaken,
    required this.onSkipped,
  });

  @override
  State<_PendingMedicationCard> createState() => _PendingMedicationCardState();
}

class _PendingMedicationCardState extends State<_PendingMedicationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final log = widget.log;
    final scheduledTime = log.scheduledAt.toLocal();
    final timeStr =
        '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final glowAlpha = 0.15 + _pulseAnimation.value * 0.25;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.orange.withValues(alpha: glowAlpha),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: glowAlpha * 0.5),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Card(
        elevation: 4,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.medication, color: Colors.orange, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.medicineName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '计划时间: $timeStr',
                          style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  StatusChip(label: log.status.label, color: Colors.orange),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: PrimaryIconButton(
                        text: '已服用',
                        icon: Icons.check,
                        onPressed: widget.onTaken,
                        gradient: const LinearGradient(colors: [Colors.green, Colors.lightGreen]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: SecondaryButton(
                        text: '跳过',
                        onPressed: widget.onSkipped,
                        borderColor: Colors.grey,
                        textColor: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}