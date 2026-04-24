import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:care_for_the_old_client/features/shared/services/local_notification_service.dart';

/// 创建测试用的 ProviderContainer
ProviderContainer createContainer() {
  return ProviderContainer();
}

void main() {
  // LocalNotificationService 是全静态方法的服务，内部使用
  // FlutterLocalNotificationsPlugin 的静态单例。
  //
  // 在纯 Dart 单元测试环境中，平台插件未初始化会导致
  // LateInitializationError，因此无法直接调用 showNotification/cancel 等方法。
  //
  // 可验证的内容：
  // 1. Provider 注册是否正常（类型和实例）
  // 2. 服务的静态方法在初始化前的行为

  group('LocalNotificationService', () {
    test('Provider 应注册 LocalNotificationService 类型', () {
      expect(localNotificationServiceProvider, isNotNull);
    });

    test('每次从 Provider 获取应返回同一实例', () {
      final container = createContainer();
      final instance1 = container.read(localNotificationServiceProvider);
      final instance2 = container.read(localNotificationServiceProvider);
      expect(instance1, same(instance2));
      container.dispose();
    });

    test('Provider 返回的实例是 LocalNotificationService 类型', () {
      final container = createContainer();
      final instance = container.read(localNotificationServiceProvider);
      expect(instance, isA<LocalNotificationService>());
      container.dispose();
    });
  });
}
