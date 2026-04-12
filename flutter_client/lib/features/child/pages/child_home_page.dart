import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/auth_provider.dart';
import '../../../shared/models/medication_plan.dart';
import '../../elder/services/medication_service.dart';
import '../../../core/api/api_client.dart';
import '../providers/family_provider.dart';

/// 子女端首页
class ChildHomePage extends ConsumerStatefulWidget {
  const ChildHomePage({super.key});

  @override
  ConsumerState<ChildHomePage> createState() => _ChildHomePageState();
}

class _ChildHomePageState extends ConsumerState<ChildHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(familyProvider.notifier).loadFamily();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final familyState = ref.watch(familyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('关爱老人'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: const Color(0xFFE86B4A),
                      child: const Icon(Icons.person,
                          size: 28, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.user?.realName ?? '子女',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text('关注家人的健康状况',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('关注的老人',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // 老人列表
            Expanded(child: _buildElderList(familyState)),

            const SizedBox(height: 16),

            // 快捷操作
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/child/family'),
                    icon: const Icon(Icons.people),
                    label: const Text('管理家庭成员'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAddPlanDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('添加用药计划'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 老人列表
  Widget _buildElderList(FamilyState familyState) {
    if (familyState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final elders = familyState.elders;

    if (elders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('暂无关注的老人',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => context.push('/child/family'),
              child: const Text('添加家庭成员'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: elders.length,
      itemBuilder: (context, index) {
        final elder = elders[index];
        return Card(
          child: InkWell(
            onTap: () =>
                context.push('/child/elder/${elder.userId}/health'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.person,
                        size: 32, color: Colors.blue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          elder.realName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          elder.relation,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 显示添加用药计划对话框
  void _showAddPlanDialog(BuildContext context) {
    final elders = ref.read(familyProvider).elders;
    if (elders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先添加老人到家庭成员')),
      );
      return;
    }

    final nameCtl = TextEditingController();
    final dosageCtl = TextEditingController();
    String selectedElderId = elders.first.userId;
    int selectedFrequency = 0;
    final timeControllers = [
      TextEditingController(text: '08:00'),
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('添加用药计划'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 选择老人
                    DropdownButtonFormField<String>(
                      value: selectedElderId,
                      decoration: const InputDecoration(labelText: '选择老人'),
                      items: elders
                          .map((e) => DropdownMenuItem(
                                value: e.userId,
                                child: Text(e.realName),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedElderId = v!),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtl,
                      decoration: const InputDecoration(labelText: '药品名称'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dosageCtl,
                      decoration: const InputDecoration(labelText: '剂量（如：100mg）'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selectedFrequency,
                      decoration: const InputDecoration(labelText: '用药频率'),
                      items: Frequency.values
                          .map((f) => DropdownMenuItem(
                                value: f.value,
                                child: Text(f.label),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedFrequency = v!),
                    ),
                    const SizedBox(height: 12),
                    // 提醒时间
                    ...timeControllers.asMap().entries.map((entry) {
                      return Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: entry.value,
                              decoration: InputDecoration(
                                labelText: '提醒时间 ${entry.key + 1}',
                                hintText: 'HH:mm',
                              ),
                            ),
                          ),
                          if (timeControllers.length > 1)
                            IconButton(
                              icon: const Icon(Icons.remove_circle,
                                  color: Colors.red),
                              onPressed: () => setDialogState(
                                  () => timeControllers.removeAt(entry.key)),
                            ),
                        ],
                      );
                    }),
                    TextButton.icon(
                      onPressed: () => setDialogState(
                          () => timeControllers.add(TextEditingController())),
                      icon: const Icon(Icons.add),
                      label: const Text('添加时间点'),
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
                  onPressed: () async {
                    if (nameCtl.text.trim().isEmpty ||
                        dosageCtl.text.trim().isEmpty) return;
                    Navigator.pop(ctx);
                    try {
                      final service =
                          MedicationService(ref.read(apiClientProvider).dio);
                      final now = DateTime.now();
                      await service.createPlan(
                        elderId: selectedElderId,
                        medicineName: nameCtl.text.trim(),
                        dosage: dosageCtl.text.trim(),
                        frequency: selectedFrequency,
                        reminderTimes: timeControllers
                            .map((c) => c.text.trim())
                            .where((t) => t.isNotEmpty)
                            .toList(),
                        startDate:
                            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('用药计划创建成功')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('创建失败: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('创建'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
