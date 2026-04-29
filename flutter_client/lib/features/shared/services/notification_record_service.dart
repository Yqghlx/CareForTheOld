import 'package:dio/dio.dart';
import '../../../shared/models/notification_record.dart';
import '../../../core/api/api_client.dart';
import '../../../core/constants/api_endpoints.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 通知记录 API 服务
class NotificationRecordService {
  final Dio _dio;

  NotificationRecordService(this._dio);

  /// 获取我的通知列表（支持分页）
  Future<({List<NotificationRecord> items, int totalCount, bool hasMore})> getMyNotifications({int skip = 0, int limit = 50}) async {
    final response = await _dio.get(
      ApiEndpoints.notificationMe,
      queryParameters: {'skip': skip, 'limit': limit},
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final List<dynamic> items = data['items'];
    final totalCount = data['totalCount'] as int? ?? 0;
    final hasMore = data['hasMore'] as bool? ?? false;
    return (
      items: items.map((json) => NotificationRecord.fromJson(json)).toList(),
      totalCount: totalCount,
      hasMore: hasMore,
    );
  }

  /// 获取未读数量
  Future<int> getUnreadCount() async {
    final response = await _dio.get(ApiEndpoints.notificationUnreadCount);
    return response.data['data']['count'] as int? ?? 0;
  }

  /// 标记已读
  Future<bool> markAsRead(String notificationId) async {
    await _dio.put(ApiEndpoints.notificationRead(notificationId));
    return true;
  }

  /// 全部标记已读
  Future<bool> markAllAsRead() async {
    await _dio.put(ApiEndpoints.notificationReadAll);
    return true;
  }
}

/// 通知记录服务 Provider
final notificationRecordServiceProvider = Provider<NotificationRecordService>((ref) {
  final dio = ref.read(apiClientProvider).dio;
  return NotificationRecordService(dio);
});
