import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/medication_plan.dart';
import '../../../shared/models/medication_log.dart';
import '../providers/medication_provider.dart';
import '../services/voice_input_service.dart';
import '../../../shared/widgets/common_cards.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../shared/widgets/common_states.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/extensions/snackbar_extension.dart';
import '../../../core/extensions/date_format_extension.dart';

/// 用药提醒页面
class MedicationPage extends ConsumerStatefulWidget {
  const MedicationPage({super.key});

  @override
  ConsumerState<MedicationPage> createState() => _MedicationPageState();
}

class _MedicationPageState extends ConsumerState<MedicationPage> {
  final VoiceInputService _voiceService = VoiceInputService();
  bool _isListening = false;

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
  void dispose() {
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final medState = ref.watch(medicationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('用药提醒'),
        actions: [
          // 语音确认服药按钮
          IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? AppTheme.errorColor : null,
            ),
            onPressed: _startVoiceConfirm,
            tooltip: '语音确认服药',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Padding(
          padding: AppTheme.paddingAll20,
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
        borderRadius: AppTheme.radiusXL,
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: AppTheme.paddingAll24,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('待服用', '${state.pendingCount}', AppTheme.warningColor),
            _buildStatItem('已服用', '${state.takenCount}', AppTheme.successColor),
            _buildStatItem('已跳过', '${state.skippedCount}', AppTheme.grey500),
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
            borderRadius: AppTheme.radiusS,
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
            color: AppTheme.grey700,
          ),
        ),
      ],
    );
  }

  /// 内容区域
  Widget _buildContent(MedicationState state) {
    if (state.isLoading && state.todayPending.isEmpty) {
      return Column(children: List.generate(3, (_) => const SkeletonCard()));
    }

    if (state.error != null && state.todayPending.isEmpty) {
      return ErrorStateWidget(
        message: ErrorStateWidget.friendlyMessage(state.error),
        onRetry: () => ref.read(medicationProvider.notifier).loadAll(),
      );
    }

    if (state.todayPending.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.check_circle_outline,
        title: '今日暂无用药计划',
        subtitle: '请让子女帮忙添加用药计划',
      );
    }

    return ListView.builder(
      cacheExtent: 800,
      itemCount: state.todayPending.length,
      itemBuilder: (context, index) {
        final log = state.todayPending[index];
        if (log.isPending) {
          final key = ref.read(medicationProvider.notifier).logKey(log);
          final isSubmitting = ref.watch(medicationProvider).isSubmitting(key);
          // 限制脉冲动画卡片数量，超过3个时不再动画以节省性能
          final animate = index < 3;
          return _PendingMedicationCard(
            log: log,
            isSubmitting: isSubmitting,
            enableAnimation: animate,
            onTaken: () => _markTaken(log),
            onSkipped: () => _markSkipped(log),
          );
        }
        return _buildStaticMedicationCard(log);
      },
    );
  }

  /// 已处理状态的卡片（已服用/已跳过）
  Widget _buildStaticMedicationCard(MedicationLog log) {
    final scheduledTime = log.scheduledAt.toLocal();
    final timeStr = scheduledTime.toTimeString();

    return Card(
      elevation: 4,
      margin: AppTheme.marginBottom12,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.radiusL,
        side: log.status == MedicationStatus.taken
            ? BorderSide(color: AppTheme.successColor.withValues(alpha: 0.3), width: 1.5)
            : BorderSide.none,
      ),
      child: Padding(
        padding: AppTheme.paddingAll20,
        child: Row(
          children: [
            // 已服用时添加打勾弹出动画
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 400),
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: log.status == MedicationStatus.taken ? value : 1.0,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: log.status == MedicationStatus.taken
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF66BB6A),
                                Color(0xFFA5D6A7),
                              ],
                            )
                          : null,
                      color: log.status == MedicationStatus.taken
                          ? null
                          : AppTheme.grey300.withValues(alpha: 0.15),
                      borderRadius: AppTheme.radiusM,
                    ),
                    child: log.status == MedicationStatus.taken
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 32,
                          )
                        : Icon(
                            Icons.skip_next,
                            color: AppTheme.grey600,
                            size: 28,
                          ),
                  ),
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.medicineName,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: log.status == MedicationStatus.taken
                          ? AppTheme.successDark
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '计划时间: $timeStr',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppTheme.grey600,
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
      ),
    );
  }

  /// 标记已服用
  Future<void> _markTaken(MedicationLog log) async {
    final success =
        await ref.read(medicationProvider.notifier).markAsTaken(log);
    if (mounted) {
      if (success) {
          context.showSuccessSnackBar('已标记为已服用');
        } else {
          context.showErrorSnackBar('操作失败');
        }
    }
  }

  /// 标记跳过（带二次确认）
  Future<void> _markSkipped(MedicationLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusXL),
        title: const Text('确认跳过'),
        content: Text('确定跳过 ${log.medicineName} 本次用药吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          PrimaryButton(
            text: '确认跳过',
            onPressed: () => Navigator.pop(ctx, true),
            gradient: const LinearGradient(colors: [AppTheme.grey500, AppTheme.grey600]),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final success =
        await ref.read(medicationProvider.notifier).markAsSkipped(log);
    if (mounted) {
      context.showSnackBar(success ? '已跳过本次用药' : '操作失败');
    }
  }

  /// 语音确认服药
  /// 老人说"已服药"、"吃了"、"服用了"等语音指令来标记用药
  Future<void> _startVoiceConfirm() async {
    if (_isListening) {
      await _voiceService.stopListening();
      setState(() => _isListening = false);
      return;
    }

    final available = await _voiceService.initialize();
    if (!available) {
      if (mounted) {
        context.showWarningSnackBar('语音识别不可用，请检查设备设置');
      }
      return;
    }

    setState(() => _isListening = true);

    final started = await _voiceService.startListening(
      onResult: (text, isFinal) {
        if (isFinal && text.isNotEmpty) {
          _handleVoiceCommand(text);
        }
      },
    );

    if (!started) {
      setState(() => _isListening = false);
      if (mounted) {
        context.showWarningSnackBar('语音识别启动失败，请手动操作');
      }
    }
  }

  /// 处理语音命令
  void _handleVoiceCommand(String text) {
    _voiceService.stopListening();
    setState(() => _isListening = false);

    final medState = ref.read(medicationProvider);
    final pendingLogs = medState.todayPending.where((log) => log.isPending).toList();

    if (pendingLogs.isEmpty) {
      if (mounted) {
        context.showWarningSnackBar('当前没有待服用的药物');
      }
      return;
    }

    // 匹配语音指令关键词
    final lowerText = text.toLowerCase();

    // 已服药相关关键词
    final takenKeywords = ['已服药', '吃了', '服用了', '已服用', '吃过', '吃完了', '吃完', '服药了'];
    // 跳过相关关键词
    final skipKeywords = ['跳过', '不吃', '不需要'];

    if (takenKeywords.any((kw) => lowerText.contains(kw))) {
      // 标记第一个待服用的药物为已服用
      final log = pendingLogs.first;
      _markTaken(log);
    } else if (skipKeywords.any((kw) => lowerText.contains(kw))) {
      // 跳过第一个待服用的药物
      final log = pendingLogs.first;
      _markSkipped(log);
    } else {
      if (mounted) {
        context.showWarningSnackBar('未能识别指令"$text"，请说"已服药"或"跳过"');
      }
    }
  }
}

/// 待服用卡片 - 带脉冲边框动画提醒老人服药
class _PendingMedicationCard extends StatefulWidget {
  final MedicationLog log;
  final bool isSubmitting;
  final bool enableAnimation;
  final VoidCallback onTaken;
  final VoidCallback onSkipped;

  const _PendingMedicationCard({
    required this.log,
    required this.isSubmitting,
    this.enableAnimation = true,
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
    // 仅启用动画时才循环播放，节省性能
    if (widget.enableAnimation) {
      _pulseController.repeat(reverse: true);
    }
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
    final timeStr = scheduledTime.toTimeString();

    // 无动画时使用静态橙色边框
    if (!widget.enableAnimation) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: AppTheme.radiusL,
          border: Border.all(
            color: AppTheme.warningColor.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: _buildCardContent(log, timeStr),
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final glowAlpha = 0.15 + _pulseAnimation.value * 0.25;
        return Container(
          decoration: BoxDecoration(
            borderRadius: AppTheme.radiusL,
            border: Border.all(
              color: AppTheme.warningColor.withValues(alpha: glowAlpha),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.warningColor.withValues(alpha: glowAlpha * 0.5),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: _buildCardContent(log, timeStr),
    );
  }

  /// 卡片内容（动画和非动画共用）
  Widget _buildCardContent(MedicationLog log, String timeStr) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.radiusL,
      ),
      child: Padding(
        padding: AppTheme.paddingAll20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withValues(alpha: 0.15),
                    borderRadius: AppTheme.radiusM,
                  ),
                  child: const Icon(Icons.medication, color: AppTheme.warningColor, size: 28),
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
                        style: TextStyle(fontSize: 16, color: AppTheme.grey600),
                      ),
                    ],
                  ),
                ),
                StatusChip(label: log.status.label, color: AppTheme.warningColor),
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
                      onPressed: widget.isSubmitting ? null : widget.onTaken,
                      isLoading: widget.isSubmitting,
                      gradient: const LinearGradient(colors: [AppTheme.successColor, Colors.lightGreen]),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
                    child: SecondaryButton(
                      text: '跳过',
                      onPressed: widget.isSubmitting ? null : widget.onSkipped,
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
}