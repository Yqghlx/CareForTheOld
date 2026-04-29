import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/neighbor_help_request.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/route_paths.dart';
import '../providers/neighbor_help_provider.dart';
import '../../../core/extensions/snackbar_extension.dart';
import '../../../core/extensions/date_format_extension.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/common_states.dart';

/// 邻里互助页面（待响应求助 + 历史列表）
class NeighborHelpPage extends ConsumerStatefulWidget {
  const NeighborHelpPage({super.key});

  @override
  ConsumerState<NeighborHelpPage> createState() => _NeighborHelpPageState();
}

class _NeighborHelpPageState extends ConsumerState<NeighborHelpPage> {
  bool _isAccepting = false; // 接受求助防重复提交

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(neighborHelpProvider.notifier).loadPendingRequests();
      ref.read(neighborHelpProvider.notifier).loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(neighborHelpProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(AppTheme.titleNeighborHelp),
          bottom: const TabBar(
            tabs: [
              Tab(text: '待响应'),
              Tab(text: '历史记录'),
            ],
          ),
        ),
        body: state.isLoading
            ? Column(children: List.generate(3, (_) => const SkeletonCard()))
            : TabBarView(
                children: [
                  _buildPendingList(context, state.pendingRequests),
                  _buildHistoryList(context, state.history),
                ],
              ),
      ),
    );
  }

  /// 待响应求助列表
  Widget _buildPendingList(BuildContext context, List<NeighborHelpRequest> requests) {
    if (requests.isEmpty) {
      return const Center(child: Text(AppTheme.msgNoPendingHelp));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(neighborHelpProvider.notifier).loadPendingRequests(),
      child: ListView.builder(
        padding: AppTheme.paddingAll12,
        itemCount: requests.length,
        cacheExtent: 800,
        itemBuilder: (context, index) {
          final request = requests[index];
          return _HelpRequestCard(
            key: ValueKey(request.id),
            request: request,
            onAccept: () => _acceptRequest(request.id),
          );
        },
      ),
    );
  }

  /// 历史记录列表
  Widget _buildHistoryList(BuildContext context, List<NeighborHelpRequest> requests) {
    if (requests.isEmpty) {
      return const Center(child: Text(AppTheme.msgNoHelpRecord));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(neighborHelpProvider.notifier).loadHistory(),
      child: ListView.builder(
        padding: AppTheme.paddingAll12,
        itemCount: requests.length,
        cacheExtent: 800,
        itemBuilder: (context, index) {
          final request = requests[index];
          return _HelpRequestCard(
            key: ValueKey(request.id),
            request: request,
            isHistory: true,
            onRate: request.status == HelpRequestStatus.accepted
                ? () => context.push(RoutePaths.neighborHelpRate(request.id))
                : null,
          );
        },
      ),
    );
  }

  Future<void> _acceptRequest(String requestId) async {
    if (_isAccepting) return;
    final confirmed = await showConfirmDialog(
      context,
      title: '确认响应',
      message: '确定要响应此求助吗？您将是第一个响应的邻居。',
      confirmText: '我来帮忙',
    );
    if (!confirmed) return;

    _isAccepting = true;
    try {
      final success =
          await ref.read(neighborHelpProvider.notifier).acceptRequest(requestId);
      if (mounted) {
        context.showSnackBar(success ? AppTheme.msgHelpAccepted : AppTheme.msgHelpAlreadyTaken);
      }
    } catch (e) {
      if (mounted) {
        context.showErrorSnackBar(AppTheme.msgOperationFailed);
      }
    } finally {
      _isAccepting = false;
    }
  }
}

/// 求助请求卡片
class _HelpRequestCard extends StatelessWidget {
  final NeighborHelpRequest request;
  final VoidCallback? onAccept;
  final VoidCallback? onRate;
  final bool isHistory;

  const _HelpRequestCard({
    super.key,
    required this.request,
    this.onAccept,
    this.onRate,
    this.isHistory = false,
  });

  @override
  Widget build(BuildContext context) {
    final timeAgo = request.requestedAt.toTimeAgoString();
    final expiresIn = request.expiresAt.difference(DateTime.now());

    return Card(
      margin: AppTheme.marginBottom8,
      child: Padding(
        padding: AppTheme.paddingAll12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(request.requesterName[0])),
                AppTheme.hSpacer8,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.requesterName,
                          style: AppTheme.textBold,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                      Text(timeAgo, style: TextStyle(color: AppTheme.grey600, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                    ],
                  ),
                ),
                _buildStatusChip(context),
              ],
            ),
            AppTheme.spacer8,
            if (request.responderName != null)
              Text('响应者：${request.responderName}',
                  style: TextStyle(color: AppTheme.successDark)),
            if (!isHistory && expiresIn.inMinutes > 0)
              Text('${expiresIn.inMinutes} 分钟后过期',
                  style: TextStyle(color: AppTheme.warningDark, fontSize: 12)),
            if (isHistory && onRate != null) ...[
              AppTheme.spacer8,
              Align(
                alignment: Alignment.centerRight,
                child: Tooltip(
                  message: '评价此次互助',
                  child: Semantics(
                    label: '评价此次互助',
                    button: true,
                    child: TextButton.icon(
                      icon: const Icon(Icons.star, size: 16),
                      label: const Text('评价'),
                      onPressed: onRate,
                    ),
                  ),
                ),
              ),
            ],
            if (!isHistory && onAccept != null) ...[
              AppTheme.spacer8,
              SizedBox(
                width: double.infinity,
                child: Tooltip(
                  message: '接受求助，前往帮忙',
                  child: Semantics(
                    label: '接受求助，前往帮忙',
                    button: true,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.volunteer_activism),
                      label: const Text('我来帮忙'),
                      onPressed: onAccept,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final (label, color) = switch (request.status) {
      HelpRequestStatus.pending => ('待响应', AppTheme.warningColor),
      HelpRequestStatus.accepted => ('已响应', AppTheme.successColor),
      HelpRequestStatus.cancelled => ('已取消', AppTheme.grey500),
      HelpRequestStatus.resolved => ('已完成', AppTheme.infoBlue),
      HelpRequestStatus.expired => ('已过期', AppTheme.grey500),
    };
    return Chip(label: Text(label, style: AppTheme.textCaption), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap);
  }
}
