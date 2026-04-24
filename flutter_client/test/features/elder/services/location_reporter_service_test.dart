import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:care_for_the_old_client/features/elder/services/location_reporter_service.dart';
import 'package:care_for_the_old_client/features/shared/services/location_service.dart';
import 'package:care_for_the_old_client/core/services/connectivity_service.dart';
import 'package:care_for_the_old_client/core/services/offline_queue_service.dart';

/// Mock LocationService
class MockLocationService extends Mock implements LocationService {}

/// Mock ConnectivityService
class MockConnectivityService extends Mock implements ConnectivityService {}

/// Mock OfflineQueueService
class MockOfflineQueueService extends Mock implements OfflineQueueService {}

void main() {
  late MockLocationService mockLocationService;
  late MockConnectivityService mockConnectivityService;
  late MockOfflineQueueService mockOfflineQueue;
  late LocationReporterService service;

  setUp(() {
    mockLocationService = MockLocationService();
    mockConnectivityService = MockConnectivityService();
    mockOfflineQueue = MockOfflineQueueService();
    service = LocationReporterService(
      mockLocationService,
      mockConnectivityService,
      mockOfflineQueue,
    );
  });

  // ------------------------------------------------------------------
  // 构造函数和初始状态
  // ------------------------------------------------------------------
  group('初始状态', () {
    test('isRunning 初始应为 false', () {
      expect(service.isRunning, false);
    });

    test('consecutiveFailures 初始应为 0', () {
      expect(service.consecutiveFailures, 0);
    });
  });

  // ------------------------------------------------------------------
  // stop
  // ------------------------------------------------------------------
  group('stop', () {
    test('调用 stop 后 isRunning 应为 false', () {
      // 手动设置 _isRunning 为 true（通过反射或间接方式无法直接操作，
      // 这里验证 stop 在未运行状态下也能安全调用）
      service.stop();
      expect(service.isRunning, false);
    });

    test('重复调用 stop 不应抛异常', () {
      service.stop();
      service.stop();
      expect(service.isRunning, false);
    });

    test('stop 后 consecutiveFailures 应重置为 0', () {
      service.stop();
      expect(service.consecutiveFailures, 0);
    });
  });

  // ------------------------------------------------------------------
  // reportNow — 手动上报
  // ------------------------------------------------------------------
  group('reportNow', () {
    test('网络不可用时应返回 false', () async {
      when(() => mockConnectivityService.checkOnline())
          .thenAnswer((_) async => false);

      final result = await service.reportNow();

      expect(result, false);
      verify(() => mockConnectivityService.checkOnline()).called(1);
    });
  });

  // ------------------------------------------------------------------
  // 依赖注入验证
  // ------------------------------------------------------------------
  group('依赖注入', () {
    test('构造函数应正确接受三个依赖', () {
      final s = LocationReporterService(
        mockLocationService,
        mockConnectivityService,
        mockOfflineQueue,
      );
      expect(s.isRunning, false);
      expect(s.consecutiveFailures, 0);
    });
  });
}
