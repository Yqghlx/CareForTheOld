import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:care_for_the_old_client/features/shared/services/notification_record_service.dart';
import '../../../core/helpers/mock_dio_helper.dart';

void main() {
  late MockDio mockDio;
  late NotificationRecordService service;

  /// 构建通知记录的测试 JSON 数据
  Map<String, dynamic> createNotificationJson({
    String id = 'n1',
    String type = 'HealthAlert',
    String title = '健康告警',
    String content = '血压偏高',
    bool isRead = false,
    String createdAt = '2026-01-01T00:00:00.000Z',
  }) {
    return {
      'id': id,
      'type': type,
      'title': title,
      'content': content,
      'isRead': isRead,
      'createdAt': createdAt,
    };
  }

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockDio = MockDio();
    service = NotificationRecordService(mockDio);
  });

  group('NotificationRecordService 通知记录服务测试', () {
    group('getMyNotifications 获取通知列表', () {
      test('默认分页参数应使用 skip=0 limit=50', () async {
        // 模拟返回空分页结果
        when(() => mockDio.get(
              '/notification/me',
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => mockResponse({
              'data': {'items': <dynamic>[], 'totalCount': 0, 'hasMore': false},
            }));

        await service.getMyNotifications();

        verify(() => mockDio.get(
              '/notification/me',
              queryParameters: {'skip': 0, 'limit': 50},
            )).called(1);
      });

      test('自定义分页参数应正确传递', () async {
        when(() => mockDio.get(
              '/notification/me',
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => mockResponse({
              'data': {'items': <dynamic>[], 'totalCount': 0, 'hasMore': false},
            }));

        await service.getMyNotifications(skip: 10, limit: 20);

        verify(() => mockDio.get(
              '/notification/me',
              queryParameters: {'skip': 10, 'limit': 20},
            )).called(1);
      });

      test('应正确解析通知列表数据', () async {
        final jsonList = [
          createNotificationJson(
            id: 'n1',
            type: 'HealthAlert',
            title: '健康告警',
            content: '血压偏高',
            isRead: false,
          ),
          createNotificationJson(
            id: 'n2',
            type: 'MedicationReminder',
            title: '用药提醒',
            content: '请按时服药',
            isRead: true,
          ),
        ];

        when(() => mockDio.get(
              '/notification/me',
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => mockResponse({
              'data': {'items': jsonList, 'totalCount': 2, 'hasMore': false},
            }));

        final result = await service.getMyNotifications();

        expect(result.items.length, 2);
        expect(result.items[0].id, 'n1');
        expect(result.items[0].type, 'HealthAlert');
        expect(result.items[0].title, '健康告警');
        expect(result.items[0].content, '血压偏高');
        expect(result.items[0].isRead, false);
        expect(result.items[1].id, 'n2');
        expect(result.items[1].type, 'MedicationReminder');
        expect(result.items[1].isRead, true);
        expect(result.totalCount, 2);
        expect(result.hasMore, false);
      });

      test('空列表应返回空 items', () async {
        when(() => mockDio.get(
              '/notification/me',
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => mockResponse({
              'data': {'items': <dynamic>[], 'totalCount': 0, 'hasMore': false},
            }));

        final result = await service.getMyNotifications();

        expect(result.items, isEmpty);
      });

      test('应正确解析单条通知', () async {
        when(() => mockDio.get(
              '/notification/me',
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => mockResponse({
              'data': {'items': [createNotificationJson()], 'totalCount': 1, 'hasMore': false},
            }));

        final result = await service.getMyNotifications();

        expect(result.items.length, 1);
        final record = result.items.first;
        expect(record.id, 'n1');
        expect(record.type, 'HealthAlert');
        expect(record.title, '健康告警');
        expect(record.content, '血压偏高');
        expect(record.isRead, false);
        expect(record.createdAt, DateTime.utc(2026, 1, 1, 0, 0, 0));
      });
    });

    group('getUnreadCount 获取未读数量', () {
      test('应返回正确的未读数量', () async {
        when(() => mockDio.get(
              '/notification/me/unread-count',
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => mockResponse({
              'data': {'count': 5},
            }));

        final count = await service.getUnreadCount();

        expect(count, 5);
      });

      test('未读数量为 0 时应返回 0', () async {
        when(() => mockDio.get(
              '/notification/me/unread-count',
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => mockResponse({
              'data': {'count': 0},
            }));

        final count = await service.getUnreadCount();

        expect(count, 0);
      });

      test('count 字段缺失时应返回 0', () async {
        when(() => mockDio.get(
              '/notification/me/unread-count',
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => mockResponse({
              'data': <String, dynamic>{},
            }));

        final count = await service.getUnreadCount();

        expect(count, 0);
      });

      test('应调用正确的 API 路径', () async {
        when(() => mockDio.get(
              '/notification/me/unread-count',
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
              data: any(named: 'data'),
            )).thenAnswer((_) async => mockResponse({
              'data': {'count': 3},
            }));

        await service.getUnreadCount();

        verify(() => mockDio.get(
              '/notification/me/unread-count',
            )).called(1);
      });
    });

    group('markAsRead 标记已读', () {
      test('成功标记应返回 true', () async {
        when(() => mockDio.put(
              '/notification/n1/read',
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onSendProgress: any(named: 'onSendProgress'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((_) async => mockResponse(null));

        final result = await service.markAsRead('n1');

        expect(result, true);
      });

      test('应使用正确的通知 ID 拼接路径', () async {
        when(() => mockDio.put(
              '/notification/notif-999/read',
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onSendProgress: any(named: 'onSendProgress'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((_) async => mockResponse(null));

        await service.markAsRead('notif-999');

        verify(() => mockDio.put(
              '/notification/notif-999/read',
            )).called(1);
      });

      test('应使用 PUT 方法', () async {
        when(() => mockDio.put(
              any(),
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onSendProgress: any(named: 'onSendProgress'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((_) async => mockResponse(null));

        await service.markAsRead('n1');

        verify(() => mockDio.put(any())).called(1);
      });
    });

    group('markAllAsRead 全部标记已读', () {
      test('成功标记应返回 true', () async {
        when(() => mockDio.put(
              '/notification/me/read-all',
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onSendProgress: any(named: 'onSendProgress'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((_) async => mockResponse(null));

        final result = await service.markAllAsRead();

        expect(result, true);
      });

      test('应调用正确的 API 路径', () async {
        when(() => mockDio.put(
              '/notification/me/read-all',
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onSendProgress: any(named: 'onSendProgress'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((_) async => mockResponse(null));

        await service.markAllAsRead();

        verify(() => mockDio.put(
              '/notification/me/read-all',
            )).called(1);
      });

      test('即使服务端返回异常状态码也应返回 true', () async {
        // NotificationRecordService 的 markAllAsRead 在成功调用 dio.put 后始终返回 true
        // 只要 dio.put 不抛异常，就返回 true
        when(() => mockDio.put(
              '/notification/me/read-all',
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onSendProgress: any(named: 'onSendProgress'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((_) async => mockResponse(null, statusCode: 204));

        final result = await service.markAllAsRead();

        expect(result, true);
      });
    });
  });
}
