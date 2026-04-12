import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/medication_plan.dart';
import '../../../shared/models/medication_log.dart';
import '../providers/medication_provider.dart';

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
              // 今日用药概览
              _buildOverviewCard(medState),
              const SizedBox(height: 24),

              // 今日待服药
              const Text(
                '今日用药计划',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

  /// 概览卡片
  Widget _buildOverviewCard(MedicationState state) {
    return Card(
      color: const Color(0xFFE86B4A).withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
        Text(value,
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 16)),
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
            Text('加载失败: ${state.error}',
                style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.read(medicationProvider.notifier).loadAll(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.todayPending.isEmpty) {
      return const Center(
        child: Text(
          '今日暂无用药计划',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
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
    final scheduledTime = log.scheduledAt.toLocal();
    final timeStr =
        '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 药品信息行
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: log.status == MedicationStatus.taken
                        ? Colors.green
                        : log.isPending
                            ? Colors.orange
                            : Colors.grey,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.medication, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.medicineName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '计划时间: $timeStr',
                        style:
                            const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // 状态标签
                _buildStatusChip(log.status),
              ],
            ),
            // 待服用时显示操作按钮
            if (log.isPending)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () => _markTaken(log),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('标记为已服用'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        onPressed: () => _markSkipped(log),
                        child: const Text('跳过'),
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

  /// 状态标签
  Widget _buildStatusChip(MedicationStatus status) {
    return Chip(
      label: Text(
        status.label,
        style: TextStyle(color: status.color, fontSize: 14),
      ),
      backgroundColor: status.color.withOpacity(0.1),
      side: BorderSide.none,
    );
  }

  /// 标记已服用
  Future<void> _markTaken(MedicationLog log) async {
    final success =
        await ref.read(medicationProvider.notifier).markAsTaken(log);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '已标记为已服用' : '操作失败')),
      );
    }
  }

  /// 标记跳过
  Future<void> _markSkipped(MedicationLog log) async {
    final success =
        await ref.read(medicationProvider.notifier).markAsSkipped(log);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '已跳过本次用药' : '操作失败')),
      );
    }
  }
}
