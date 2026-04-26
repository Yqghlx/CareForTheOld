import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_logger.dart';

/// 网络连接状态服务
///
/// 封装 connectivity_plus，提供网络可用性检查和连接状态变化监听。
/// 可用于在发起网络请求前判断是否在线，或全局监听网络状态变化。
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// 连接状态变化流控制器
  late final StreamController<bool> _connectivityController;

  /// 连接状态变化监听订阅
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// 缓存当前连接状态，避免频繁查询
  bool _isOnline = true;

  ConnectivityService() {
    _connectivityController = StreamController<bool>.broadcast();
    _init();
  }

  /// 初始化：立即检查一次并开始监听变化
  void _init() {
    // 监听连接状态变化
    _subscription = _connectivity.onConnectivityChanged.listen(
      (results) {
        _isOnline = _resultsToOnline(results);
        if (!_connectivityController.isClosed) {
          _connectivityController.add(_isOnline);
        }
        AppLogger.debug('网络状态变化: ${_isOnline ? "在线" : "离线"} ($results)');
      },
    );

    // 初始检查（不阻塞构造函数）
    _checkInitial();
  }

  /// 初始网络状态检查
  Future<void> _checkInitial() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = _resultsToOnline(results);
      _connectivityController.add(_isOnline);
    } catch (e) {
      AppLogger.warning('初始网络检查失败: $e');
      // 检查失败时默认为在线，避免误判阻断用户操作
      _isOnline = true;
    }
  }

  /// 将连接结果列表转换为是否在线的布尔值
  ///
  /// 只要存在非 [none] 的连接方式即视为在线。
  static bool _resultsToOnline(List<ConnectivityResult> results) {
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// 当前是否在线
  bool get isOnline => _isOnline;

  /// 网络连接状态变化流（true=在线，false=离线）
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  /// 异步检查当前是否在线
  ///
  /// 适合在发起网络请求前调用，获取最新状态。
  Future<bool> checkOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = _resultsToOnline(results);
      return _isOnline;
    } catch (e) {
      AppLogger.error('网络检查异常: $e');
      return _isOnline;
    }
  }

  /// 释放资源
  void dispose() {
    _subscription?.cancel();
    _connectivityController.close();
  }
}

/// 网络连接服务 Provider
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService();
  // 当 Provider 被释放时自动清理资源
  ref.onDispose(() => service.dispose());
  return service;
});

/// 当前是否在线的便捷 Provider
final isOnlineProvider = StreamProvider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).onConnectivityChanged;
});
