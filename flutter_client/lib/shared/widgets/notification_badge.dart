import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/route_paths.dart';
import '../../core/theme/app_theme.dart';
import '../../features/shared/providers/notification_record_provider.dart';

/// 通知角标按钮
/// 在 AppBar 中显示通知图标，有未读消息时右上角显示红色圆点
class NotificationBadgeButton extends ConsumerWidget {
  const NotificationBadgeButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          tooltip: '通知',
          onPressed: () => context.push(RoutePaths.notifications),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Consumer(
            builder: (context, ref, _) {
              final unreadCount = ref.watch(
                notificationListProvider.select((s) => s.unreadCount),
              );
              if (unreadCount == 0) return const SizedBox.shrink();
              return Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppTheme.errorColor,
                  shape: BoxShape.circle,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
