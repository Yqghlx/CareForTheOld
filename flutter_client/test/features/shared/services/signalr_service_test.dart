import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

import 'package:care_for_the_old_client/features/shared/services/signalr_service.dart';
import 'package:care_for_the_old_client/shared/providers/auth_provider.dart';

/// Mock Ref，用于测试 SignalRService
class MockRef extends Mock implements Ref {}

/// 注册 mocktail 所需的回退值
void _registerFallbacks() {
  registerFallbackValue(authProvider);
}

void main() {
  late MockRef mockRef;

  setUpAll(_registerFallbacks);

  setUp(() {
    mockRef = MockRef();
    // 默认 authProvider 返回未登录状态（accessToken 为 null）
    when(() => mockRef.read(authProvider)).thenReturn(const AuthState());
  });

  // ------------------------------------------------------------------
  // isConnected 属性
  // ------------------------------------------------------------------
  group('isConnected', () {
    test('未连接时 isConnected 应为 false', () {
      final service = SignalRService(mockRef);
      expect(service.isConnected, false);
    });
  });

  // ------------------------------------------------------------------
  // disconnect
  // ------------------------------------------------------------------
  group('disconnect', () {
    test('未连接时调用 disconnect 不应抛异常', () async {
      final service = SignalRService(mockRef);
      await service.disconnect();
      expect(service.isConnected, false);
    });

    test('重复调用 disconnect 不应抛异常', () async {
      final service = SignalRService(mockRef);
      await service.disconnect();
      await service.disconnect();
      expect(service.isConnected, false);
    });
  });

  // ------------------------------------------------------------------
  // connect — 无 Token 时
  // ------------------------------------------------------------------
  group('connect', () {
    test('无 Token 时连接应跳过且 isConnected 保持 false', () async {
      final service = SignalRService(mockRef);
      await service.connect();
      expect(service.isConnected, false);
    });
  });

  // ------------------------------------------------------------------
  // 构造函数
  // ------------------------------------------------------------------
  group('构造函数', () {
    test('构造函数接受 Ref 参数且初始状态正确', () {
      final service = SignalRService(mockRef);
      expect(service.isConnected, false);
    });
  });
}
