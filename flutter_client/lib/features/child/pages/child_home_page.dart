import '../../../core/router/route_paths.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/notification_badge.dart';

import '../../../shared/providers/auth_provider.dart';
import '../../../shared/models/medication_plan.dart';
import '../../../shared/models/family.dart';
import '../../elder/services/medication_service.dart';
import '../../../core/api/api_client.dart';
import '../providers/family_provider.dart';
import '../../../shared/widgets/common_cards.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../shared/widgets/common_states.dart';
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
  bool _isCreatingPlan = false;

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
    final user = ref.watch(authProvider.select((s) => s.user));
    final familyIsLoading = ref.watch(familyProvider.select((s) => s.isLoading));
    final elders = ref.watch(familyProvider.select((s) => s.elders));
    final emergencyInfo = ref.watch(emergencyProvider.select((s) => (s.hasUnreadCalls, s.unreadCount)));

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
                tooltip: AppTheme.tooltipEmergencyCall,
              ),
              if (emergencyInfo.$1)
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
            tooltip: AppTheme.tooltipSettings,
            onPressed: () => context.push(RoutePaths.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(familyProvider.notifier).loadFamily();
          ref.read(emergencyProvider.notifier).loadUnreadCalls();
          ref.read(notificationListProvider.notifier).loadNotifications();
        },
        child: Padding(
        padding: AppTheme.paddingAll20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 紧急呼叫提示（如果有未处理呼叫）- 循环脉冲动画
            if (emergencyInfo.$1)
              _EmergencyPulseBanner(
                onTap: () => context.push(RoutePaths.childEmergency),
                unreadCount: emergencyInfo.$2,
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
                        child: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: user.avatarUrl!,
                                fit: BoxFit.cover,
                                fadeInDuration: AppTheme.duration200ms,
                                memCacheWidth: 256,
                                memCacheHeight: 256,
                                maxWidthDiskCache: 512,
                                maxHeightDiskCache: 512,
                                placeholder: (_, __) => const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.cardColor))),
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
                          user?.realName ?? AppTheme.labelChild,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: AppTheme.textLargeTitle.copyWith(
                            color: AppTheme.cardColor,
                          ),
                        ),
                        AppTheme.spacer4,
                        Text(
                          AppTheme.subtitleFollowFamilyHealth,
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
              AppTheme.titleEldersFollowed,
              style: AppTheme.textLargeTitle,
            ),
            AppTheme.spacer16,

            // 老人列表
            Expanded(child: _buildElderList(familyIsLoading, elders)),

            AppTheme.spacer16,

            // 快捷操作 - 使用渐变按钮
            Row(
              children: [
                Expanded(
                  child: PrimaryIconButton(
                    text: AppTheme.labelManageFamily,
                    icon: Icons.people,
                    onPressed: () => context.push(RoutePaths.childFamily),
                  ),
                ),
                AppTheme.hSpacer16,
                Expanded(
                  child: PrimaryIconButton(
                    text: AppTheme.titleNeighborHelp,
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
                    text: AppTheme.titleNeighborCircle,
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
                    text: AppTheme.labelAddMedPlan,
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
      ),
    );
  }

  /// 老人列表
  Widget _buildElderList(bool isLoading, List<FamilyMember> elders) {
    if (isLoading) {
      return Column(children: List.generate(2, (_) => const SkeletonCard()));
    }

    if (elders.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.people_outline,
        title: AppTheme.msgNoElderConcern,
        action: PrimaryButton(
          text: AppTheme.labelAddFamilyMember,
          onPressed: () => context.push(RoutePaths.childFamily),
        ),
      );
    }

    return ListView.builder(
      cacheExtent: 800,
      itemCount: elders.length,
      itemBuilder: (context, index) {
        final elder = elders[index];
        return Card(
          key: ValueKey(elder.userId),
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
                Semantics(
                  label: '查看${elder.realName}的健康数据',
                  button: true,
                  child: InkWell(
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
                                  fadeInDuration: AppTheme.duration200ms,
                                  memCacheWidth: 256,
                                  memCacheHeight: 256,
                                  maxWidthDiskCache: 512,
                                  maxHeightDiskCache: 512,
                                  placeholder: (_, __) => const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.warningColor))),
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
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
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
                ),
                AppTheme.spacer12,
                // 操作按钮行
                Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: AppTheme.msgViewLocation,
                        child: Semantics(
                          label: AppTheme.msgViewLocation,
                          button: true,
                          child: OutlinedButton.icon(
                            onPressed: () => context.push(RoutePaths.childElderLocation(elder.userId)),
                            icon: const Icon(Icons.location_on, size: AppTheme.iconSizeSm),
                            label: const Text(AppTheme.labelViewLocation),
                            style: AppTheme.outlinedColorStyle(AppTheme.successColor),
                          ),
                        ),
                      ),
                    ),
                    AppTheme.hSpacer12,
                    Expanded(
                      child: Tooltip(
                        message: AppTheme.msgViewHealth,
                        child: Semantics(
                          label: AppTheme.msgViewHealth,
                          button: true,
                          child: OutlinedButton.icon(
                            onPressed: () => context.push(RoutePaths.childElderHealth(elder.userId)),
                            icon: const Icon(Icons.favorite, size: AppTheme.iconSizeSm),
                            label: const Text(AppTheme.labelViewHealth),
                            style: AppTheme.outlinedColorStyle(AppTheme.errorColor),
                          ),
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
                  const Text(AppTheme.labelAddMedPlan),
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
                        decoration: AppTheme.inputDecorationDropdown('选择老人'),
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
                        decoration: AppTheme.inputDecorationPlain(AppTheme.labelMedicineName),
                        textCapitalization: TextCapitalization.words,
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
                        decoration: AppTheme.inputDecorationPlain(AppTheme.hintDosageExample),
                        textCapitalization: TextCapitalization.sentences,
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
                        decoration: AppTheme.inputDecorationDropdown(AppTheme.labelFrequency),
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
                                tooltip: AppTheme.tooltipRemoveTimeSlot,
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
                      label: const Text(AppTheme.labelAddTimePoint),
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
                  text: AppTheme.msgCreate,
                  isLoading: _isCreatingPlan,
                  onPressed: _isCreatingPlan ? null : () async {
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
                    setState(() => _isCreatingPlan = true);
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
                    } finally {
                      if (mounted) setState(() => _isCreatingPlan = false);
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
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
                      AppTheme.titleEmergencyPending,
                      style: TextStyle(
                        color: AppTheme.cardColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${widget.unreadCount} ${AppTheme.msgEmergencyPendingAction}',
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
    ),
    );
  }
}