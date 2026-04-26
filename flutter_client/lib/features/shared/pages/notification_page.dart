import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/notification_record.dart';
import '../../../shared/widgets/common_states.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/notification_record_provider.dart';

/// 通知中心页面
class NotificationPage extends ConsumerStatefulWidget {
  const NotificationPage({super.key});

  @override
  ConsumerState<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends ConsumerState<NotificationPage> {
  String? _expandedNotificationId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationListProvider.notifier).loadNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('通知中心'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref.read(notificationListProvider.notifier).markAllAsRead(),
              child: const Text('全部已读'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationListProvider.notifier).loadNotifications(),
        child: _buildContent(state),
      ),
    );
  }

  Widget _buildContent(NotificationListState state) {
    if (state.isLoading && state.notifications.isEmpty) {
      return ListView.builder(
        padding: AppTheme.paddingAll16,
        itemCount: 5,
        itemBuilder: (_, __) => const SkeletonListTile(),
      );
    }

    if (state.error != null && state.notifications.isEmpty) {
      return ErrorStateWidget(
        message: ErrorStateWidget.friendlyMessage(state.error),
        onRetry: () => ref.read(notificationListProvider.notifier).loadNotifications(),
      );
    }

    if (state.notifications.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          const EmptyStateWidget(
            icon: Icons.notifications_none,
            title: '暂无通知',
          ),
        ],
      );
    }

    return ListView.builder(
      cacheExtent: 800,
      padding: AppTheme.paddingAll16,
      itemCount: state.notifications.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.notifications.length) {
          // 滚动到底部，触发加载更多
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(notificationListProvider.notifier).loadMore();
          });
          return const Padding(
            padding: AppTheme.paddingAll16,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final notification = state.notifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(NotificationRecord notification) {
    return Card(
      elevation: notification.isRead ? AppTheme.cardElevationLow : AppTheme.cardElevation,
      margin: AppTheme.marginBottom12,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.radiusL,
        side: notification.isRead
            ? BorderSide.none
            : BorderSide(color: notification.color.withValues(alpha: 0.3), width: 1),
      ),
      child: InkWell(
        onTap: () {
          if (!notification.isRead) {
            ref.read(notificationListProvider.notifier).markAsRead(notification.id);
          }
          // 切换展开/收起
          setState(() {
            _expandedNotificationId = _expandedNotificationId == notification.id ? null : notification.id;
          });
        },
        borderRadius: AppTheme.radiusL,
        child: Padding(
          padding: AppTheme.paddingAll16,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图标
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: notification.color.withValues(alpha: 0.15),
                  borderRadius: AppTheme.radiusS,
                ),
                child: Icon(notification.icon, color: notification.color, size: 24),
              ),
              const SizedBox(width: 16),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                            ),
                          ),
                        ),
                        // 未读标记
                        if (!notification.isRead)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: notification.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.content,
                      style: AppTheme.textSecondary14,
                      maxLines: _expandedNotificationId == notification.id ? null : 3,
                      overflow: _expandedNotificationId == notification.id ? null : TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          notification.formattedTime,
                          style: AppTheme.textCaptionDark,
                        ),
                        // 展开/收起提示
                        if (notification.content.length > 60)
                          Text(
                            _expandedNotificationId == notification.id ? '收起' : '展开全文',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
