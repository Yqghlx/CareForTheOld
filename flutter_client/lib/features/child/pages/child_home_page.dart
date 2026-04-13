import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/auth_provider.dart';
import '../../../shared/models/medication_plan.dart';
import '../../elder/services/medication_service.dart';
import '../../../core/api/api_client.dart';
import '../providers/family_provider.dart';
import '../../../shared/widgets/common_cards.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/providers/emergency_provider.dart';

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
      // 加载紧急呼叫状态
      ref.read(emergencyProvider.notifier).loadUnreadCalls();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final familyState = ref.watch(familyProvider);
    final emergencyState = ref.watch(emergencyProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('关爱老人'),
        automaticallyImplyLeading: false,
        actions: [
          // 紧急呼叫按钮（带红点提示）
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.emergency),
                onPressed: () => context.push('/child/emergency'),
                tooltip: '紧急呼叫',
              ),
              if (emergencyState.hasUnreadCalls)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 紧急呼叫提示（如果有未处理呼叫）
            if (emergencyState.hasUnreadCalls)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.red, Colors.redAccent],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  onTap: () => context.push('/child/emergency'),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '有紧急呼叫待处理！',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${emergencyState.unreadCount} 条待处理',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),

            // 用户信息 - 渐变卡片
            GradientCard(
              gradient: AppTheme.warmGradient,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.person, size: 32, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.user?.realName ?? '子女',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '关注家人的健康状况',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              '关注的老人',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // 老人列表
            Expanded(child: _buildElderList(familyState)),

            const SizedBox(height: 16),

            // 快捷操作 - 使用渐变按钮
            Row(
              children: [
                Expanded(
                  child: PrimaryIconButton(
                    text: '管理家庭成员',
                    icon: Icons.people,
                    onPressed: () => context.push('/child/family'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: PrimaryIconButton(
                    text: '添加用药计划',
                    icon: Icons.add,
                    onPressed: () => _showAddPlanDialog(context),
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.lightBlue],
                    ),
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
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              '暂无关注的老人',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              text: '添加家庭成员',
              onPressed: () => context.push('/child/family'),
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
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () => context.push('/child/elder/${elder.userId}/health'),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.person, size: 32, color: Colors.blue),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          elder.realName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          elder.relation,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.chevron_right,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 设置对话框（退出登录）
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('设置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('用户: ${ref.read(authProvider).user?.realName ?? "未知"}'),
            const SizedBox(height: 8),
            Text('角色: ${ref.read(authProvider).user?.role.label ?? "未知"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.red, Colors.redAccent],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: const Text('退出登录'),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示添加用药计划对话框
  void _showAddPlanDialog(BuildContext context) {
    final elders = ref.read(familyProvider).elders;
    if (elders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请先添加老人到家庭成员'),
          backgroundColor: AppTheme.warningColor,
        ),
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
                    child: const Icon(Icons.medication, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  const Text('添加用药计划'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 选择老人
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: selectedElderId,
                        decoration: const InputDecoration(
                          labelText: '选择老人',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        items: elders
                            .map((e) => DropdownMenuItem(
                                  value: e.userId,
                                  child: Text(e.realName),
                                ))
                            .toList(),
                        onChanged: (v) => setDialogState(() => selectedElderId = v!),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: nameCtl,
                        decoration: const InputDecoration(
                          labelText: '药品名称',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: dosageCtl,
                        decoration: const InputDecoration(
                          labelText: '剂量（如：100mg）',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonFormField<int>(
                        value: selectedFrequency,
                        decoration: const InputDecoration(
                          labelText: '用药频率',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        items: Frequency.values
                            .map((f) => DropdownMenuItem(
                                  value: f.value,
                                  child: Text(f.label),
                                ))
                            .toList(),
                        onChanged: (v) => setDialogState(() => selectedFrequency = v!),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 提醒时间
                    ...timeControllers.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  // 解析当前时间值
                                  final parts = entry.value.text.split(':');
                                  final initial = TimeOfDay(
                                    hour: parts.length == 2
                                        ? (int.tryParse(parts[0]) ?? 8)
                                        : 8,
                                    minute: parts.length == 2
                                        ? (int.tryParse(parts[1]) ?? 0)
                                        : 0,
                                  );
                                  final picked = await showTimePicker(
                                    context: ctx,
                                    initialTime: initial,
                                    builder: (context, child) {
                                      return MediaQuery(
                                        data: MediaQuery.of(context).copyWith(
                                          alwaysUse24HourFormat: true,
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null) {
                                    final timeStr =
                                        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                    setDialogState(() {
                                      entry.value.text = timeStr;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time, color: AppTheme.primaryColor),
                                      const SizedBox(width: 8),
                                      Text(
                                        entry.value.text.isEmpty
                                            ? '点击选择时间'
                                            : '提醒时间 ${entry.key + 1}: ${entry.value.text}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: entry.value.text.isEmpty
                                              ? Colors.grey
                                              : Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (timeControllers.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: Colors.red),
                                onPressed: () => setDialogState(
                                    () => timeControllers.removeAt(entry.key)),
                              ),
                          ],
                        ),
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
                PrimaryButton(
                  text: '创建',
                  onPressed: () async {
                    if (nameCtl.text.trim().isEmpty || dosageCtl.text.trim().isEmpty) {
                      return;
                    }
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
                          const SnackBar(
                            content: Text('用药计划创建成功'),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('创建失败: $e'),
                            backgroundColor: AppTheme.errorColor,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}