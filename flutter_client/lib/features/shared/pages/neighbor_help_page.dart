import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/neighbor_help_request.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/neighbor_help_provider.dart';
import '../../../core/extensions/snackbar_extension.dart';

/// 邻里互助页面（待响应求助 + 历史列表）
class NeighborHelpPage extends ConsumerStatefulWidget {
  const NeighborHelpPage({super.key});

  @override
  ConsumerState<NeighborHelpPage> createState() => _NeighborHelpPageState();
}

class _NeighborHelpPageState extends ConsumerState<NeighborHelpPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
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
          title: const Text('邻里互助'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '待响应'),
              Tab(text: '历史记录'),
            ],
          ),
        ),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
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
      return const Center(child: Text('暂无待响应的求助'));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(neighborHelpProvider.notifier).loadPendingRequests(),
      child: ListView.builder(
        padding: AppTheme.paddingAll12,
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return _HelpRequestCard(
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
      return const Center(child: Text('暂无互助记录'));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(neighborHelpProvider.notifier).loadHistory(),
      child: ListView.builder(
        padding: AppTheme.paddingAll12,
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return _HelpRequestCard(
            request: request,
            isHistory: true,
            onRate: request.status == HelpRequestStatus.accepted
                ? () => context.push('/neighbor-help/${request.id}/rate')
                : null,
          );
        },
      ),
    );
  }

  Future<void> _acceptRequest(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认响应'),
        content: const Text('确定要响应此求助吗？您将是第一个响应的邻居。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('我来帮忙')),
        ],
      ),
    );
    if (confirmed != true) return;

    final success =
        await ref.read(neighborHelpProvider.notifier).acceptRequest(requestId);
    if (mounted) {
      context.showSnackBar(success ? AppTheme.msgHelpAccepted : AppTheme.msgHelpAlreadyTaken);
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
    required this.request,
    this.onAccept,
    this.onRate,
    this.isHistory = false,
  });

  @override
  Widget build(BuildContext context) {
    final timeAgo = _formatTimeAgo(request.requestedAt);
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
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.requesterName,
                          style: AppTheme.textBold),
                      Text(timeAgo, style: TextStyle(color: AppTheme.grey600, fontSize: 12)),
                    ],
                  ),
                ),
                _buildStatusChip(context),
              ],
            ),
            const SizedBox(height: 8),
            if (request.responderName != null)
              Text('响应者：${request.responderName}',
                  style: TextStyle(color: AppTheme.successDark)),
            if (!isHistory && expiresIn.inMinutes > 0)
              Text('${expiresIn.inMinutes} 分钟后过期',
                  style: TextStyle(color: AppTheme.warningDark, fontSize: 12)),
            if (isHistory && onRate != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.star, size: 16),
                  label: const Text('评价'),
                  onPressed: onRate,
                ),
              ),
            ],
            if (!isHistory && onAccept != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.volunteer_activism),
                  label: const Text('我来帮忙'),
                  onPressed: onAccept,
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

  String _formatTimeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }
}
