import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/emergency_call.dart';
import '../../shared/providers/emergency_provider.dart';
import '../../../shared/widgets/common_cards.dart';
import '../../../shared/widgets/common_buttons.dart';
import '../../../shared/widgets/common_states.dart';
import '../../../core/extensions/snackbar_extension.dart';
import '../../../core/extensions/date_format_extension.dart';
import '../../../core/theme/app_theme.dart';

/// 子女端紧急呼叫页面
class EmergencyPage extends ConsumerStatefulWidget {
  const EmergencyPage({super.key});

  @override
  ConsumerState<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends ConsumerState<EmergencyPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(emergencyProvider.notifier).loadAll();
    });
  }

  Future<void> _refresh() async {
    await ref.read(emergencyProvider.notifier).loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final emergencyState = ref.watch(emergencyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('紧急呼叫'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showHistoryDialog(),
            tooltip: '历史记录',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: emergencyState.isLoading && emergencyState.unreadCalls.isEmpty
            ? ListView.builder(
                padding: AppTheme.paddingAll16,
                itemCount: 3,
                itemBuilder: (_, __) => const SkeletonListTile(),
              )
            : _buildContent(emergencyState),
      ),
    );
  }

  Widget _buildContent(EmergencyState state) {
    if (state.error != null && state.unreadCalls.isEmpty && state.historyCalls.isEmpty) {
      return ErrorStateWidget(
        message: ErrorStateWidget.friendlyMessage(state.error),
        onRetry: () => ref.read(emergencyProvider.notifier).loadAll(),
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: AppTheme.paddingAll20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 未处理的紧急呼叫
          if (state.unreadCalls.isNotEmpty) ...[
            Container(
              padding: AppTheme.paddingH16V8,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.radiusS,
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
                  const SizedBox(width: 8),
                  Text(
                    '有 ${state.unreadCount} 条待处理的紧急呼叫',
                    style: TextStyle(
                      color: AppTheme.errorColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...state.unreadCalls.map((call) => _buildUnreadCallCard(call)),
          ] else ...[
            Container(
              padding: AppTheme.paddingAll24,
              decoration: BoxDecoration(
                color: AppTheme.successColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.radiusL,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, color: AppTheme.successColor),
                  const SizedBox(width: 8),
                  const Text(
                    '暂无待处理的紧急呼叫',
                    style: TextStyle(color: AppTheme.successColor),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // 最近历史
          const Text(
            '最近呼叫记录',
            style: AppTheme.textTitle,
          ),
          const SizedBox(height: 12),

          if (state.historyCalls.isEmpty)
            Container(
              padding: AppTheme.paddingAll24,
              decoration: BoxDecoration(
                color: AppTheme.grey100,
                borderRadius: AppTheme.radiusL,
              ),
              child: const Center(
                child: Text('暂无呼叫记录', style: TextStyle(color: AppTheme.grey600)),
              ),
            )
          else
            ...state.historyCalls.take(5).map((call) => _buildHistoryCard(call)),
        ],
      ),
    );
  }

  /// 未处理呼叫卡片（高亮显示）
  Widget _buildUnreadCallCard(EmergencyCall call) {
    return Container(
      margin: AppTheme.marginBottom12,
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.05),
        borderRadius: AppTheme.radiusL,
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3), width: 2),
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
                    color: AppTheme.errorColor.withValues(alpha: 0.15),
                    borderRadius: AppTheme.radiusM,
                  ),
                  child: const Icon(
                    Icons.emergency,
                    color: AppTheme.errorColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${call.elderName} 发起紧急呼叫',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        call.relativeTime,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(
                  label: '待处理',
                  color: AppTheme.errorColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 位置和电量信息
            if (call.hasLocation || call.batteryLevel != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.grey100,
                  borderRadius: AppTheme.radius10,
                ),
                child: Row(
                  children: [
                    if (call.hasLocation) ...[
                      const Icon(Icons.location_on, size: 18, color: AppTheme.infoBlueDark),
                      const SizedBox(width: 4),
                      Text(
                        '${call.latitude!.toStringAsFixed(4)}, ${call.longitude!.toStringAsFixed(4)}',
                        style: TextStyle(fontSize: 13, color: AppTheme.grey700),
                      ),
                    ],
                    if (call.hasLocation && call.batteryLevel != null)
                      const SizedBox(width: 16),
                    if (call.batteryLevel != null) ...[
                      Icon(Icons.battery_std, size: 18, color: call.batteryColor),
                      const SizedBox(width: 4),
                      Text(
                        '电量 ${call.batteryText}',
                        style: TextStyle(
                          fontSize: 13,
                          color: call.batteryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (call.hasLocation || call.batteryLevel != null)
              const SizedBox(height: 12),
            Row(
              children: [
                // 拨打电话按钮
                if (call.elderPhoneNumber != null && call.elderPhoneNumber!.isNotEmpty)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _callElder(call.elderPhoneNumber!),
                      icon: const Icon(Icons.phone, size: 20),
                      label: const Text('拨打电话'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.infoBlue,
                        side: const BorderSide(color: AppTheme.infoBlue),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusS),
                      ),
                    ),
                  ),
                if (call.elderPhoneNumber != null && call.elderPhoneNumber!.isNotEmpty)
                  const SizedBox(width: 12),
                Expanded(
                  child: PrimaryIconButton(
                    text: '已处理',
                    icon: Icons.check,
                    onPressed: () => _respondCall(call),
                    gradient: const LinearGradient(
                      colors: [AppTheme.successColor, Colors.lightGreen],
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

  /// 历史记录卡片
  Widget _buildHistoryCard(EmergencyCall call) {
    return Card(
      elevation: 2,
      margin: AppTheme.marginBottom8,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.radiusM,
      ),
      child: Padding(
        padding: AppTheme.paddingAll16,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: call.status.color.withValues(alpha: 0.15),
                borderRadius: AppTheme.radius10,
              ),
              child: Icon(
                call.isPending ? Icons.warning_amber : Icons.check_circle,
                color: call.status.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    call.elderName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    call.relativeTime,
                    style: TextStyle(fontSize: 12, color: AppTheme.grey600),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusChip(
                  label: call.status.label,
                  color: call.status.color,
                ),
                if (call.respondedByRealName != null)
                  Text(
                    '处理人: ${call.respondedByRealName}',
                    style: TextStyle(fontSize: 12, color: AppTheme.grey600),
                  ),
                if (call.respondedAt != null)
                  Text(
                    _formatRespondedAt(call.respondedAt!),
                    style: TextStyle(fontSize: 11, color: AppTheme.grey500),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 处理呼叫
  /// 格式化响应时间
  String _formatRespondedAt(DateTime respondedAt) {
    final local = respondedAt.toLocal();
    return '${local.toShortDateTimeString()} 处理';
  }

  /// 拨打老人电话
  Future<void> _callElder(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      context.showWarningSnackBar(AppTheme.msgCannotDial);
    }
  }

  Future<void> _respondCall(EmergencyCall call) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.radiusL,
        ),
        title: const Text('确认处理'),
        content: Text('确定要标记 ${call.elderName} 的紧急呼叫为已处理吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          PrimaryButton(
            text: '确认',
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(emergencyProvider.notifier).respondCall(call.id);
      if (mounted) {
        if (success) {
          context.showSuccessSnackBar(AppTheme.msgMarkHandled);
        } else {
          context.showErrorSnackBar(AppTheme.msgOperationFailed);
        }
        // 处理后自动刷新列表，保持数据最新
        if (success) {
          ref.read(emergencyProvider.notifier).loadAll();
        }
      }
    }
  }

  /// 显示历史记录对话框
  void _showHistoryDialog() {
    final historyCalls = ref.read(emergencyProvider).historyCalls;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.radiusL,
        ),
        title: const Text('历史呼叫记录'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: historyCalls.isEmpty
              ? const Center(child: Text('暂无历史记录'))
              : ListView.builder(
                  itemCount: historyCalls.length,
                  itemBuilder: (context, index) {
                    final call = historyCalls[index];
                    return _buildHistoryCard(call);
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}