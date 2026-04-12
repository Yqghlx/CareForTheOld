import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/health_record.dart';
import '../../../shared/models/health_stats.dart';
import '../providers/health_provider.dart';

/// 健康记录页面
class HealthRecordPage extends ConsumerStatefulWidget {
  const HealthRecordPage({super.key});

  @override
  ConsumerState<HealthRecordPage> createState() => _HealthRecordPageState();
}

class _HealthRecordPageState extends ConsumerState<HealthRecordPage> {
  @override
  void initState() {
    super.initState();
    // 首次进入自动加载数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(healthRecordsProvider.notifier).loadRecords();
    });
  }

  /// 下拉刷新
  Future<void> _refresh() async {
    final filter = ref.read(healthRecordsProvider).selectedFilter;
    await ref.read(healthRecordsProvider.notifier).loadRecords(type: filter);
    // 同时刷新统计
    ref.invalidate(healthStatsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final healthState = ref.watch(healthRecordsProvider);
    final statsAsync = ref.watch(healthStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('健康记录')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 健康类型选择
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                childAspectRatio: 1.6,
                children: HealthType.values
                    .map((type) => _buildHealthTypeCard(type))
                    .toList(),
              ),
              const SizedBox(height: 20),

              // 统计概览
              statsAsync.when(
                data: (stats) => _buildStatsBar(stats),
                loading: () => const SizedBox(
                  height: 48,
                  child: Center(child: Text('加载统计中...', style: TextStyle(color: Colors.grey))),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),

              // 记录列表标题
              const Text(
                '最近记录',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // 记录列表
              Expanded(
                child: _buildRecordList(healthState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 健康类型选择卡片
  Widget _buildHealthTypeCard(HealthType type) {
    return Card(
      child: InkWell(
        onTap: () => _showRecordDialog(type),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(type.icon, size: 40, color: type.color),
            const SizedBox(height: 6),
            Text(
              '记录${type.label}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  /// 统计概览条
  Widget _buildStatsBar(List<HealthStats> stats) {
    if (stats.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final stat = stats[index];
          final avg7 = stat.average7Days?.toStringAsFixed(1) ?? '--';
          return Chip(
            label: Text(
              '${stat.typeName}: ${avg7}（7日均值）',
              style: const TextStyle(fontSize: 14),
            ),
          );
        },
      ),
    );
  }

  /// 记录列表
  Widget _buildRecordList(HealthRecordsState state) {
    if (state.isLoading && state.records.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: ${state.error}', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.read(healthRecordsProvider.notifier).loadRecords(),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (state.records.isEmpty) {
      return const Center(
        child: Text(
          '暂无健康记录\n点击上方卡片开始记录',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: state.records.length,
      itemBuilder: (context, index) {
        final record = state.records[index];
        return _buildRecordItem(record);
      },
    );
  }

  /// 单条记录项
  Widget _buildRecordItem(HealthRecord record) {
    // 格式化时间为本地时间
    final localTime = record.recordedAt.toLocal();
    final timeStr =
        '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} '
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';

    return Card(
      child: ListTile(
        leading: Icon(record.type.icon, color: record.type.color, size: 32),
        title: Text(
          '${record.type.label}: ${record.displayValue} ${record.type.unit}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(timeStr, style: const TextStyle(fontSize: 14)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.grey),
          onPressed: () => _confirmDelete(record),
        ),
      ),
    );
  }

  /// 确认删除对话框
  void _confirmDelete(HealthRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${record.type.label}: ${record.displayValue} 这条记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(healthRecordsProvider.notifier)
                  .deleteRecord(record.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? '已删除' : '删除失败')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  /// 显示录入对话框
  void _showRecordDialog(HealthType type) {
    final valueController = TextEditingController();
    final valueController2 = TextEditingController(); // 血压舒张压
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('记录${type.label}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 根据类型显示不同输入字段
                if (type == HealthType.bloodPressure) ...[
                  TextField(
                    controller: valueController,
                    decoration: const InputDecoration(
                      labelText: '收缩压（mmHg）',
                      hintText: '60-250',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valueController2,
                    decoration: const InputDecoration(
                      labelText: '舒张压（mmHg）',
                      hintText: '40-150',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
                if (type == HealthType.bloodSugar)
                  TextField(
                    controller: valueController,
                    decoration: const InputDecoration(
                      labelText: '血糖值（mmol/L）',
                      hintText: '1.0-35.0',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                if (type == HealthType.heartRate)
                  TextField(
                    controller: valueController,
                    decoration: const InputDecoration(
                      labelText: '心率（次/分）',
                      hintText: '30-200',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                if (type == HealthType.temperature)
                  TextField(
                    controller: valueController,
                    decoration: const InputDecoration(
                      labelText: '体温（°C）',
                      hintText: '35.0-42.0',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: '备注（可选）'),
                  maxLines: 2,
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
              onPressed: () => _submitRecord(
                ctx,
                type,
                valueController.text,
                valueController2.text,
                noteController.text,
              ),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  /// 提交记录
  Future<void> _submitRecord(
    BuildContext dialogContext,
    HealthType type,
    String valueText,
    String valueText2,
    String note,
  ) async {
    // 解析并验证输入值
    int? systolic, diastolic, heartRate;
    double? bloodSugar, temperature;

    try {
      switch (type) {
        case HealthType.bloodPressure:
          systolic = int.parse(valueText);
          diastolic = int.parse(valueText2);
          if (systolic < 60 || systolic > 250 || diastolic < 40 || diastolic > 150) {
            throw const FormatException('血压值超出范围');
          }
        case HealthType.bloodSugar:
          bloodSugar = double.parse(valueText);
          if (bloodSugar < 1.0 || bloodSugar > 35.0) {
            throw const FormatException('血糖值超出范围');
          }
        case HealthType.heartRate:
          heartRate = int.parse(valueText);
          if (heartRate < 30 || heartRate > 200) {
            throw const FormatException('心率值超出范围');
          }
        case HealthType.temperature:
          temperature = double.parse(valueText);
          if (temperature < 35.0 || temperature > 42.0) {
            throw const FormatException('体温值超出范围');
          }
      }
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效的数值')),
      );
      return;
    }

    Navigator.pop(dialogContext);

    final success = await ref.read(healthRecordsProvider.notifier).createRecord(
          type: type,
          systolic: systolic,
          diastolic: diastolic,
          bloodSugar: bloodSugar,
          heartRate: heartRate,
          temperature: temperature,
          note: note,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ? '${type.label}记录已保存' : '保存失败')),
      );
      // 保存成功后刷新统计
      if (success) {
        ref.invalidate(healthStatsProvider);
      }
    }
  }
}
