import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:care_for_the_old_client/core/services/connectivity_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConnectivityService 网络连接服务测试', () {
    group('构造函数与默认值', () {
      test('构造不应抛异常', () async {
        // ConnectivityService 构造函数内部会调用 _init()，
        // 其中 connectivity_plus 在测试环境中会因缺少平台插件而报错，
        // 但该异常在构造函数中通过同步方式处理（StreamController 已初始化），
        // 构造本身不应抛出未捕获的异常。
        // 使用 async + 微任务让 _checkInitial 中的异步操作完成
        final service = ConnectivityService();
        // 等待异步初始化完成
        await Future.microtask(() {});
        expect(service, isNotNull);
        service.dispose();
      });

      test('isOnline 默认值应为 true', () async {
        // 服务初始状态 _isOnline = true，异步检查前保持为 true
        final service = ConnectivityService();
        await Future.microtask(() {});
        expect(service.isOnline, true);
        service.dispose();
      });
    });

    group('onConnectivityChanged 连接状态变化流', () {
      test('应提供一个广播 Stream', () async {
        final service = ConnectivityService();
        await Future.microtask(() {});

        // 验证返回的是 Stream<bool>
        expect(service.onConnectivityChanged, isA<Stream<bool>>());

        // 广播 Stream 允许多个监听者
        final stream = service.onConnectivityChanged;
        expect(stream.isBroadcast, true);
        service.dispose();
      });

      test('多个监听者应都能订阅且不抛异常', () async {
        final service = ConnectivityService();
        await Future.microtask(() {});

        final results1 = <bool>[];
        final results2 = <bool>[];

        final sub1 = service.onConnectivityChanged.listen(results1.add);
        final sub2 = service.onConnectivityChanged.listen(results2.add);

        // 等待一小段时间，让初始检查事件通过
        await Future.delayed(const Duration(milliseconds: 200));

        // 在测试环境中 connectivity_plus 抛异常，不会产生事件
        // 但两个监听者都不应抛异常
        expect(sub1, isNotNull);
        expect(sub2, isNotNull);

        await sub1.cancel();
        await sub2.cancel();
        service.dispose();
      });
    });

    group('dispose 释放资源', () {
      test('调用 dispose 不应抛异常', () async {
        final service = ConnectivityService();
        await Future.microtask(() {});
        expect(() => service.dispose(), returnsNormally);
      });

      test('重复调用 dispose 不应抛异常', () async {
        final service = ConnectivityService();
        await Future.microtask(() {});
        service.dispose();
        expect(() => service.dispose(), returnsNormally);
      });
    });

    group('checkOnline 异步检查', () {
      test('checkOnline 在测试环境中应返回默认值且不抛异常', () async {
        final service = ConnectivityService();
        await Future.microtask(() {});

        // connectivity_plus 在测试环境中因缺少平台插件而抛异常，
        // catch 块会捕获并返回缓存的 _isOnline 默认值
        final result = await service.checkOnline();
        expect(result, isA<bool>());

        service.dispose();
      });

      test('checkOnline 返回的值应与 isOnline 一致', () async {
        final service = ConnectivityService();
        await Future.microtask(() {});

        final onlineResult = await service.checkOnline();
        expect(onlineResult, service.isOnline);

        service.dispose();
      });
    });
  });
}
