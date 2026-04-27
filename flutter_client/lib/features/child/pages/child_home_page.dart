import '../../../core/router/route_paths.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/notification_badge.dart';

import '../../../shared/providers/auth_provider.dart';
import '../../../shared/models/medication_plan.dart';
import '../../elder/services/medication_service.dart';
import '../../../core/api/api_client.dart';
import '../providers/family_provider.dart';
import '../../../shared/widgets/common_cards.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../core/extensions/snackbar_extension.dart';
import '../../../core/extensions/date_format_extension.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/providers/emergency_provider.dart';
import '../../shared/providers/notification_record_provider.dart';
import 'elder_health_page.dart';

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
      ref.read(emergencyProvider.notifier).loadUnreadCalls();
      ref.read(notificationListProvider.notifier).loadNotifications();
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
        title: const Text(AppTheme.appName),
        automaticallyImplyLeading: false,
        actions: [
          // 紧急呼叫按钮（带红点提示）
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.emergency),
                onPressed: () => context.push(RoutePaths.childEmergency),
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
                      color: AppTheme.errorColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          // 通知按钮（带未读红点）
          const NotificationBadgeButton(),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () => context.push(RoutePaths.settings),
          ),
        ],
      ),
      body: Padding(
        padding: AppTheme.paddingAll20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 紧急呼叫提示（如果有未处理呼叫）- 循环脉冲动画
            if (emergencyState.hasUnreadCalls)
              _EmergencyPulseBanner(
                onTap: () => context.push(RoutePaths.childEmergency),
                unreadCount: emergencyState.unreadCount,
              ),

            // 用户信息 - 渐变卡片
            GradientCard(
              gradient: AppTheme.warmGradient,
              child: Padding(
                padding: AppTheme.paddingAll20,
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.cardColor.withValues(alpha: 0.2),
                        borderRadius: AppTheme.radiusM,
                      ),
                      child: ClipRRect(
                        borderRadius: AppTheme.radiusM,
                        child: authState.user?.avatarUrl != null && authState.user!.avatarUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: authState.user!.avatarUrl!,
                                fit: BoxFit.cover,
                                memCacheWidth: 256,
                                memCacheHeight: 256,
                                maxWidthDiskCache: 512,
                                maxHeightDiskCache: 512,
                                errorWidget: (_, __, ___) => const Icon(Icons.person, size: AppTheme.iconSizeXl, color: AppTheme.cardColor),
                              )
                            : const Icon(Icons.person, size: AppTheme.iconSizeXl, color: AppTheme.cardColor),
                      ),
                    ),
                    AppTheme.hSpacer16,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authState.user?.realName ?? '子女',
                          style: AppTheme.textLargeTitle.copyWith(
                            color: AppTheme.cardColor,
                          ),
                        ),
                        AppTheme.spacer4,
                        Text(
                          '关注家人的健康状况',
                          style: TextStyle(
                            color: AppTheme.cardColor.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            AppTheme.spacer24,

            const Text(
              '关注的老人',
              style: AppTheme.textLargeTitle,
            ),
            AppTheme.spacer16,

            // 老人列表
            Expanded(child: _buildElderList(familyState)),

            AppTheme.spacer16,

            // 快捷操作 - 使用渐变按钮
            Row(
              children: [
                Expanded(
                  child: PrimaryIconButton(
                    text: '管理家庭成员',
                    icon: Icons.people,
                    onPressed: () => context.push(RoutePaths.childFamily),
                  ),
                ),
                AppTheme.hSpacer16,
                Expanded(
                  child: PrimaryIconButton(
                    text: '邻里互助',
                    icon: Icons.volunteer_activism,
                    onPressed: () => context.push(RoutePaths.neighborHelp),
                    gradient: const LinearGradient(
                      colors: [AppTheme.warningColor, AppTheme.deepOrangeColor],
                    ),
                  ),
                ),
              ],
            ),
            AppTheme.spacer16,
            Row(
              children: [
                Expanded(
                  child: PrimaryIconButton(
                    text: '邻里圈',
                    icon: Icons.diversity_3,
                    onPressed: () => context.push(RoutePaths.neighborCircle),
                    gradient: const LinearGradient(
                      colors: [AppTheme.tealColor, AppTheme.cyanColor],
                    ),
                  ),
                ),
                AppTheme.hSpacer16,
                Expanded(
                  child: PrimaryIconButton(
                    text: '添加用药计划',
                    icon: Icons.add,
                    onPressed: () => _showAddPlanDialog(context),
                    gradient: const LinearGradient(
                      colors: [AppTheme.infoBlue, AppTheme.infoBlueLight],
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
              size: AppTheme.iconSizeHuge,
              color: AppTheme.grey400,
            ),
            AppTheme.spacer16,
            const Text(
              '暂无关注的老人',
              style: AppTheme.textSecondary16,
            ),
            AppTheme.spacer12,
            PrimaryButton(
              text: '添加家庭成员',
              onPressed: () => context.push(RoutePaths.childFamily),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      cacheExtent: 800,
      itemCount: elders.length,
      itemBuilder: (context, index) {
        final elder = elders[index];
        return Card(
          elevation: AppTheme.cardElevation,
          margin: AppTheme.marginBottom12,
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.radiusL,
          ),
          child: Padding(
            padding: AppTheme.paddingAll16,
            child: Column(
              children: [
                // 老人信息行
                InkWell(
                  onTap: () => context.push(RoutePaths.childElderHealth(elder.userId)),
                  borderRadius: AppTheme.radiusL,
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.infoBlue.withValues(alpha: 0.15),
                          borderRadius: AppTheme.radiusM,
                        ),
                        child: ClipRRect(
                          borderRadius: AppTheme.radiusM,
                          child: elder.avatarUrl != null && elder.avatarUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: elder.avatarUrl!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 256,
                                  memCacheHeight: 256,
                                  maxWidthDiskCache: 512,
                                  maxHeightDiskCache: 512,
                                  errorWidget: (_, __, ___) => const Icon(Icons.elderly, size: AppTheme.iconSizeXl, color: AppTheme.warningColor),
                                )
                              : const Icon(Icons.elderly, size: AppTheme.iconSizeXl, color: AppTheme.warningColor),
                        ),
                      ),
                      AppTheme.hSpacer16,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              elder.realName,
                              style: AppTheme.textTitle,
                            ),
                            AppTheme.spacer4,
                            Text(
                              elder.relation,
                              style: AppTheme.textSecondary14,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: AppTheme.radius10,
                        ),
                        child: Icon(
                          Icons.chevron_right,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                AppTheme.spacer12,
                // 操作按钮行
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(RoutePaths.childElderLocation(elder.userId)),
                        icon: const Icon(Icons.location_on, size: AppTheme.iconSizeSm),
                        label: const Text('查看位置'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.successColor,
                          side: const BorderSide(color: AppTheme.successColor),
                        ),
                      ),
                    ),
                    AppTheme.hSpacer12,
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push(RoutePaths.childElderHealth(elder.userId)),
                        icon: const Icon(Icons.favorite, size: AppTheme.iconSizeSm),
                        label: const Text('查看健康'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: const BorderSide(color: AppTheme.errorColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
      context.showWarningSnackBar(AppTheme.msgAddElderFirst);
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
                    child: const Icon(Icons.medication, color: AppTheme.infoBlue),
                  ),
                  AppTheme.hSpacer12,
                  const Text('添加用药计划'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 选择老人
                    Container(
                      decoration: AppTheme.decorationInput,
                      child: DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use - StatefulBuilder 中动态更新需要 value
                        value: selectedElderId,
                        decoration: const InputDecoration(
                          labelText: '选择老人',
                          border: InputBorder.none,
                          contentPadding: AppTheme.paddingH16V8,
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
                    AppTheme.spacer12,
                    Container(
                      decoration: AppTheme.decorationInput,
                      child: TextField(
                        controller: nameCtl,
                        decoration: const InputDecoration(
                          labelText: '药品名称',
                          border: InputBorder.none,
                          contentPadding: AppTheme.paddingH16V12,
                        ),
                        style: AppTheme.textBody16,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s一-龥·]')),
                          LengthLimitingTextInputFormatter(50),
                        ],
                      ),
                    ),
                    AppTheme.spacer12,
                    Container(
                      decoration: AppTheme.decorationInput,
                      child: TextField(
                        controller: dosageCtl,
                        decoration: const InputDecoration(
                          labelText: '剂量（如：100mg）',
                          border: InputBorder.none,
                          contentPadding: AppTheme.paddingH16V12,
                        ),
                        style: AppTheme.textBody16,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s一-龥.]')),
                          LengthLimitingTextInputFormatter(30),
                        ],
                      ),
                    ),
                    AppTheme.spacer12,
                    Container(
                      decoration: AppTheme.decorationInput,
                      child: DropdownButtonFormField<int>(
                        // ignore: deprecated_member_use - StatefulBuilder 中动态更新需要 value
                        value: selectedFrequency,
                        decoration: const InputDecoration(
                          labelText: '用药频率',
                          border: InputBorder.none,
                          contentPadding: AppTheme.paddingH16V8,
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
                    AppTheme.spacer12,
                    // 提醒时间
                    ...timeControllers.asMap().entries.map((entry) {
                      return Padding(
                        padding: AppTheme.marginBottom12,
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
                                  padding: AppTheme.paddingH16V12,
                                  decoration: AppTheme.decorationInput,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time, color: AppTheme.primaryColor),
                                      AppTheme.hSpacer8,
                                      Text(
                                        entry.value.text.isEmpty
                                            ? '点击选择时间'
                                            : '提醒时间 ${entry.key + 1}: ${entry.value.text}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: entry.value.text.isEmpty
                                              ? AppTheme.grey500
                                              : AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            if (timeControllers.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle, color: AppTheme.errorColor),
                                tooltip: '移除时间点',
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
                  child: const Text(AppTheme.msgCancel),
                ),
                PrimaryButton(
                  text: '创建',
                  onPressed: () async {
                    final name = nameCtl.text.trim();
                    final dosage = dosageCtl.text.trim();
                    if (name.isEmpty || name.length > 50) {
                      ctx.showSnackBar(AppTheme.msgMedicineNameInvalid);
                      return;
                    }
                    if (dosage.isEmpty || dosage.length > 30) {
                      ctx.showSnackBar(AppTheme.msgDosageInvalid);
                      return;
                    }
                    final validTimes = timeControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                    if (validTimes.isEmpty) {
                      ctx.showSnackBar(AppTheme.msgReminderTimeRequired);
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
                        startDate: now.toDateString(),
                      );
                      if (mounted && context.mounted) {
                        // 刷新子女端老人健康页面的用药计划/记录
                        ref.invalidate(elderMedicationPlansProvider);
                        ref.invalidate(elderMedicationLogsProvider);
                        context.showSuccessSnackBar(AppTheme.msgPlanCreated);
                      }
                    } catch (e) {
                      if (mounted && context.mounted) {
                        context.showErrorSnackBar(AppTheme.msgPlanCreateFailed);
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      // 延迟到下一帧释放控制器，确保对话框 Widget 树已完全卸载
      WidgetsBinding.instance.addPostFrameCallback((_) {
        nameCtl.dispose();
        dosageCtl.dispose();
        for (final c in timeControllers) {
          c.dispose();
        }
      });
    });
  }
}

/// 紧急呼叫横幅 - 循环脉冲动画
class _EmergencyPulseBanner extends StatefulWidget {
  final VoidCallback onTap;
  final int unreadCount;

  const _EmergencyPulseBanner({
    required this.onTap,
    required this.unreadCount,
  });

  @override
  State<_EmergencyPulseBanner> createState() => _EmergencyPulseBannerState();
}

class _EmergencyPulseBannerState extends State<_EmergencyPulseBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: AppTheme.duration1500ms,
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final alpha = 0.3 + _animation.value * 0.4;
        return Container(
          margin: AppTheme.marginBottom16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.errorColor, AppTheme.errorAccent],
            ),
            borderRadius: AppTheme.radiusL,
            boxShadow: [
              BoxShadow(
                color: AppTheme.errorColor.withValues(alpha: alpha),
                blurRadius: 8 + _animation.value * 16,
                spreadRadius: _animation.value * 4,
              ),
            ],
          ),
          child: child,
        );
      },
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: AppTheme.radiusL,
        child: Padding(
          padding: AppTheme.paddingAll16,
          child: Row(
            children: [
              const Icon(Icons.emergency, color: AppTheme.cardColor, size: 36),
              AppTheme.hSpacer12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '有紧急呼叫待处理！',
                      style: TextStyle(
                        color: AppTheme.cardColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.unreadCount} 条待处理，点击查看',
                      style: AppTheme.textBody16.copyWith(
                        color: AppTheme.cardColor.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppTheme.cardColor, size: AppTheme.iconSize2xl),
            ],
          ),
        ),
      ),
    );
  }
}