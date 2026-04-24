import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';

import 'package:care_for_the_old_client/core/services/connectivity_service.dart';
import 'package:care_for_the_old_client/core/services/offline_queue_service.dart';
import '../helpers/mock_dio_helper.dart';

/// Mock ConnectivityService，用于控制网络状态
class MockConnectivityService extends Mock implements ConnectivityService {}

void main() {
  late MockDio mockDio;
  late MockConnectivityService mockConnectivityService;
  late OfflineQueueService service;
  late Directory tempDir;

  setUpAll(() {
    registerFallbackValues();
    // 使用系统临时目录初始化 Hive，避免文件系统依赖
    tempDir = Directory.systemTemp.createTempSync('hive_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    // 测试结束后清理临时目录
    try {
      await Hive.close();
    } catch (_) {}
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  setUp(() async {
    mockDio = MockDio();
    mockConnectivityService = MockConnectivityService();

    // 配置 MockConnectivityService 的默认行为
    when(() => mockConnectivityService.isOnline).thenReturn(true);
    when(() => mockConnectivityService.onConnectivityChanged)
        .thenAnswer((_) => const Stream.empty());

    // 确保每个测试开始前 box 是干净状态
    try {
      await Hive.deleteBoxFromDisk('offline_queue');
    } catch (_) {
      // box 不存在或已关闭，忽略
    }

    service = OfflineQueueService(mockDio, mockConnectivityService);
    await service.init();
  });

  tearDown(() async {
    service.dispose();
    // 等待 dispose 中的异步 close 操作完成
    await Future.delayed(const Duration(milliseconds: 50));
    // 清理 Hive 测试数据
    try {
      await Hive.deleteBoxFromDisk('offline_queue');
    } catch (_) {
      // 忽略清理异常
    }
  });

  group('OfflineQueueService 离线队列服务测试', () {
    group('init 初始化', () {
      test('初始化后队列长度应为 0', () {
        expect(service.queueLength, 0);
      });
    });

    group('enqueue 入队', () {
      test('入队后队列长度应增加', () async {
        expect(service.queueLength, 0);

        await service.enqueue('location', {'lat': 39.9, 'lng': 116.4});

        expect(service.queueLength, 1);
      });

      test('多次入队应累积增加队列长度', () async {
        await service.enqueue('location', {'lat': 39.9});
        await service.enqueue('health', {'heartRate': 80});
        await service.enqueue('medication', {'medId': 'm1'});

        expect(service.queueLength, 3);
      });

      test('入队不同类型的数据应正确存储', () async {
        await service.enqueue('location', {'lat': 39.9, 'lng': 116.4});
        await service.enqueue('health', {'heartRate': 80, 'bloodPressure': 120});
        await service.enqueue('medication', {'medId': 'm1', 'taken': true});

        expect(service.queueLength, 3);
      });

      test('队列满（100条）时应淘汰最旧的数据', () async {
        // 入队 101 条数据，第一条应被淘汰
        for (int i = 0; i < 101; i++) {
          await service.enqueue('location', {'index': i});
        }

        // 队列最大 100 条
        expect(service.queueLength, 100);
      });

      test('队列满时新数据应成功入队', () async {
        // 填满队列
        for (int i = 0; i < 100; i++) {
          await service.enqueue('location', {'index': i});
        }
        expect(service.queueLength, 100);

        // 再入队一条，最旧的应被淘汰
        await service.enqueue('health', {'note': '最新数据'});
        expect(service.queueLength, 100);
      });
    });

    group('flush 批量上传', () {
      test('成功上传后队列应清空', () async {
        // 配置 Dio mock：所有 POST 请求成功
        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onSendProgress: any(named: 'onSendProgress'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((_) async => mockResponse(null));

        await service.enqueue('location', {'lat': 39.9});
        await service.enqueue('health', {'heartRate': 80});
        expect(service.queueLength, 2);

        await service.flush();

        expect(service.queueLength, 0);
      });

      test('location 类型应 POST 到 /location', () async {
        when(() => mockDio.post(
              '/location',
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onSendProgress: any(named: 'onSendProgress'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((_) async => mockResponse(null));

        await service.enqueue('location', {'lat': 39.9, 'lng': 116.4});
        await service.flush();

        verify(() => mockDio.post(
              '/location',
              data: any(named: 'data'),
            )).called(1);
      });

      test('health 类型应 POST 到 /health', () async {
        when(() => mockDio.post(
              '/health',
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onSendProgress: any(named: 'onSendProgress'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((_) async => mockResponse(null));

        await service.enqueue('health', {'heartRate': 80});
        await service.flush();

        verify(() => mockDio.post(
              '/health',
              data: any(named: 'data'),
            )).called(1);
      });

      test('medication 类型应 POST 到 /medication/logs', () async {
        when(() => mockDio.post(
              '/medication/logs',
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onSendProgress: any(named: 'onSendProgress'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((_) async => mockResponse(null));

        await service.enqueue('medication', {'medId': 'm1'});
        await service.flush();

        verify(() => mockDio.post(
              '/medication/logs',
              data: any(named: 'data'),
            )).called(1);
      });

      test('上传部分失败时应保留失败的数据', () async {
        // location 成功，health 失败
        when(() => mockDio.post(
              '/location',
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onSendProgress: any(named: 'onSendProgress'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((_) async => mockResponse(null));

        when(() => mockDio.post(
              '/health',
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onSendProgress: any(named: 'onSendProgress'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenThrow(DioException(
              requestOptions: RequestOptions(path: ''),
              message: '服务器错误',
            ));

        await service.enqueue('location', {'lat': 39.9});
        await service.enqueue('health', {'heartRate': 80});
        expect(service.queueLength, 2);

        await service.flush();

        // location 成功出队，health 失败保留
        expect(service.queueLength, 1);
      });

      test('空队列调用 flush 不应抛异常', () async {
        expect(service.queueLength, 0);

        await expectLater(
          service.flush(),
          completes,
        );
        expect(service.queueLength, 0);
      });

      test('上传时传入的 data 应与入队时一致', () async {
        final testData = {'lat': 39.9042, 'lng': 116.4074, 'accuracy': 10.5};

        when(() => mockDio.post(
              '/location',
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onSendProgress: any(named: 'onSendProgress'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((_) async => mockResponse(null));

        await service.enqueue('location', testData);
        await service.flush();

        verify(() => mockDio.post(
              '/location',
              data: testData,
            )).called(1);
      });

      test('未知类型应直接移除（不重新入队）', () async {
        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onSendProgress: any(named: 'onSendProgress'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((_) async => mockResponse(null));

        // 通过 enqueue 方法的正常流程构建一个已知类型，验证 flush 清空队列
        // 同时通过手动操作 Hive box 注入未知类型项
        // 注意：由于 service.init() 已经打开了 offline_queue box，
        // Hive.openBox 会返回同一个已打开的 box 实例
        final box = await Hive.openBox<String>('offline_queue');
        final unknownItem = OfflineQueueItem(
          id: 'unknown-test-id',
          type: 'unknown_type',
          data: {'foo': 'bar'},
          createdAt: DateTime.now(),
        );
        await box.put(unknownItem.id, jsonEncode(unknownItem.toJson()));

        expect(service.queueLength, 1);

        await service.flush();

        // 未知类型的项应被移除（_uploadItem 返回 true）
        expect(service.queueLength, 0);
      });

      test('多条数据批量上传全部成功应清空队列', () async {
        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onSendProgress: any(named: 'onSendProgress'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((_) async => mockResponse(null));

        for (int i = 0; i < 5; i++) {
          await service.enqueue('location', {'index': i});
        }
        expect(service.queueLength, 5);

        await service.flush();

        expect(service.queueLength, 0);
      });
    });

    group('queueLength 队列长度', () {
      test('初始队列长度应为 0', () {
        expect(service.queueLength, 0);
      });

      test('入队后长度应正确反映', () async {
        await service.enqueue('location', {'lat': 1});
        expect(service.queueLength, 1);

        await service.enqueue('health', {'hr': 72});
        expect(service.queueLength, 2);
      });

      test('flush 成功后长度应归零', () async {
        when(() => mockDio.post(
              any(),
              data: any(named: 'data'),
              queryParameters: any(named: 'queryParameters'),
              options: any(named: 'options'),
              cancelToken: any(named: 'cancelToken'),
              onSendProgress: any(named: 'onSendProgress'),
              onReceiveProgress: any(named: 'onReceiveProgress'),
            )).thenAnswer((_) async => mockResponse(null));

        await service.enqueue('location', {'lat': 1});
        await service.enqueue('location', {'lat': 2});
        expect(service.queueLength, 2);

        await service.flush();
        expect(service.queueLength, 0);
      });
    });

    group('dispose 释放资源', () {
      test('未初始化时 dispose 不应抛异常', () {
        final tempService = OfflineQueueService(mockDio, mockConnectivityService);
        // 不初始化直接 dispose，也不应抛异常
        expect(() => tempService.dispose(), returnsNormally);
      });

      test('dispose 后访问 queueLength 应抛出 HiveError（box 已关闭）', () async {
        // 先关闭当前 service
        service.dispose();
        await Future.delayed(const Duration(milliseconds: 50));

        // 清理 box
        try {
          await Hive.deleteBoxFromDisk('offline_queue');
        } catch (_) {}

        // 创建新的 service 进行 dispose 测试
        final tempService = OfflineQueueService(mockDio, mockConnectivityService);
        await tempService.init();

        await tempService.enqueue('location', {'lat': 1});
        expect(tempService.queueLength, 1);

        tempService.dispose();
        await Future.delayed(const Duration(milliseconds: 50));

        // dispose 后 _box 被 close，访问 queueLength 会抛出 HiveError
        expect(() => tempService.queueLength, throwsA(isA<HiveError>()));

        // 清理
        try {
          await Hive.deleteBoxFromDisk('offline_queue');
        } catch (_) {}
      });
    });
  });
}
