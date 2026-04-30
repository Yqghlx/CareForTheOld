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
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationListProvider.notifier).loadNotifications();
    });
  }

  List<NotificationRecord> _filterNotifications(List<NotificationRecord> notifications) {
    if (_searchQuery.isEmpty) return notifications;
    final query = _searchQuery.toLowerCase();
    return notifications.where((n) =>
      n.title.toLowerCase().contains(query) ||
      n.content.toLowerCase().contains(query)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: AppTheme.hintSearchNotification,
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: AppTheme.grey400),
                ),
                style: AppTheme.textBody16,
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : const Text(AppTheme.titleNotification),
        actions: [
          // 搜索按钮
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) _searchQuery = '';
              });
            },
            tooltip: _isSearching ? AppTheme.tooltipCancelSearch : AppTheme.tooltipSearch,
          ),
          if (!_isSearching && state.unreadCount > 0)
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
        cacheExtent: 800,
        itemBuilder: (_, __) => const SkeletonListTile(),
      );
    }

    if (state.error != null && state.notifications.isEmpty) {
      return ErrorStateWidget(
        message: ErrorStateWidget.friendlyMessage(state.error),
        onRetry: () => ref.read(notificationListProvider.notifier).loadNotifications(),
      );
    }

    final filtered = _filterNotifications(state.notifications);

    if (state.notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          const EmptyStateWidget(
            icon: Icons.notifications_none,
            title: AppTheme.msgNoNotification,
          ),
        ],
      );
    }

    if (filtered.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          const EmptyStateWidget(
            icon: Icons.search_off,
            title: '未找到相关通知',
            subtitle: AppTheme.hintSearchEmpty,
          ),
        ],
      );
    }

    return ListView.builder(
      cacheExtent: 800,
      padding: AppTheme.paddingAll16,
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final notification = filtered[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(NotificationRecord notification) {
    return Card(
      key: ValueKey(notification.id),
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
                child: Icon(notification.icon, color: notification.color, size: AppTheme.iconSizeLg),
              ),
              AppTheme.hSpacer16,
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                    AppTheme.spacer6,
                    Text(
                      notification.content,
                      style: AppTheme.textSecondary14,
                      maxLines: _expandedNotificationId == notification.id ? null : 3,
                      overflow: _expandedNotificationId == notification.id ? null : TextOverflow.ellipsis,
                    ),
                    AppTheme.spacer8,
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
                            style: AppTheme.textCaption.copyWith(color: AppTheme.primaryColor),
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
