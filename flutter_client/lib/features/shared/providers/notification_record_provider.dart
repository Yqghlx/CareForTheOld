import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/notification_record.dart';
import '../services/notification_record_service.dart';

/// 通知状态
class NotificationListState {
  final List<NotificationRecord> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const NotificationListState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationListState copyWith({
    List<NotificationRecord>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return NotificationListState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 通知状态 Notifier
class NotificationListNotifier extends StateNotifier<NotificationListState> {
  final NotificationRecordService _service;

  NotificationListNotifier(this._service) : super(const NotificationListState());

  /// 加载通知列表
  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final notifications = await _service.getMyNotifications();
      final unreadCount = notifications.where((n) => !n.isRead).length;
      state = state.copyWith(
        notifications: notifications,
        unreadCount: unreadCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 加载未读数量
  Future<void> loadUnreadCount() async {
    try {
      final count = await _service.getUnreadCount();
      state = state.copyWith(unreadCount: count);
    } catch (_) {}
  }

  /// 标记已读
  Future<void> markAsRead(String notificationId) async {
    try {
      await _service.markAsRead(notificationId);
      final updatedNotifications = state.notifications.map((n) {
        if (n.id == notificationId) {
          return NotificationRecord(
            id: n.id, type: n.type, title: n.title,
            content: n.content, isRead: true, createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();
      final unreadCount = updatedNotifications.where((n) => !n.isRead).length;
      state = state.copyWith(notifications: updatedNotifications, unreadCount: unreadCount);
    } catch (_) {}
  }

  /// 全部标记已读
  Future<void> markAllAsRead() async {
    try {
      await _service.markAllAsRead();
      final updatedNotifications = state.notifications.map((n) {
        return NotificationRecord(
          id: n.id, type: n.type, title: n.title,
          content: n.content, isRead: true, createdAt: n.createdAt,
        );
      }).toList();
      state = state.copyWith(notifications: updatedNotifications, unreadCount: 0);
    } catch (_) {}
  }
}

/// 通知列表 Provider
final notificationListProvider =
    StateNotifierProvider<NotificationListNotifier, NotificationListState>((ref) {
  final service = ref.watch(notificationRecordServiceProvider);
  return NotificationListNotifier(service);
});
