import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/notification_record.dart';
import '../services/notification_record_service.dart';
import 'package:dio/dio.dart';
import '../../../core/extensions/api_error_extension.dart';
import '../../../core/theme/app_theme.dart';

/// 通知状态
class NotificationListState {
  final List<NotificationRecord> notifications;
  final int unreadCount;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int _skip;
  final String? error;

  static const int _pageSize = 20;

  const NotificationListState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    int skip = 0,
    this.error,
  }) : _skip = skip;

  NotificationListState copyWith({
    List<NotificationRecord>? notifications,
    int? unreadCount,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? skip,
    String? error,
    bool clearError = false,
  }) {
    return NotificationListState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      skip: skip ?? _skip,
      error: clearError ? null : (error ?? this.error),
    );
  }

  int get skip => _skip;
  int get pageSize => _pageSize;
}

/// 通知状态 Notifier
class NotificationListNotifier extends StateNotifier<NotificationListState> {
  final NotificationRecordService _service;

  NotificationListNotifier(this._service) : super(const NotificationListState());

  /// 加载通知列表（首次加载/刷新）
  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final notifications = await _service.getMyNotifications(
        skip: 0,
        limit: NotificationListState._pageSize,
      );
      final unreadCount = notifications.where((n) => !n.isRead).length;
      state = state.copyWith(
        notifications: notifications,
        unreadCount: unreadCount,
        isLoading: false,
        hasMore: notifications.length >= NotificationListState._pageSize,
        skip: notifications.length,
      );
    } on DioException catch (e) {
      state = state.copyWith(isLoading: false, error: e.toDisplayMessage());
    } catch (e) {
      state = state.copyWith(isLoading: false, error: AppTheme.msgOperationFailed);
    }
  }

  /// 加载更多通知（滚动到底部时调用）
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final more = await _service.getMyNotifications(
        skip: state.skip,
        limit: state.pageSize,
      );
      final all = [...state.notifications, ...more];
      final unreadCount = all.where((n) => !n.isRead).length;
      state = state.copyWith(
        notifications: all,
        unreadCount: unreadCount,
        isLoadingMore: false,
        hasMore: more.length >= state.pageSize,
        skip: all.length,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  /// 加载未读数量
  Future<void> loadUnreadCount() async {
    try {
      final count = await _service.getUnreadCount();
      state = state.copyWith(unreadCount: count);
    } catch (e) {
      debugPrint('加载未读数量失败: $e');
    }
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
    } catch (e) {
      debugPrint('标记已读失败: $e');
    }
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
    } catch (e) {
      debugPrint('全部标记已读失败: $e');
    }
  }
}

/// 通知列表 Provider
final notificationListProvider =
    StateNotifierProvider<NotificationListNotifier, NotificationListState>((ref) {
  final service = ref.watch(notificationRecordServiceProvider);
  return NotificationListNotifier(service);
});
